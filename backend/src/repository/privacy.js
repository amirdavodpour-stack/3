import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { userFromRow, jobFromRow, offerFromRow, paymentFromRow, applicationFromRow } from './mappers.js';


function accountFinancialObligationsPendingError() {
  const error = new Error('ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING');
  error.code = 'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING';
  error.status = 409;
  return error;
}

async function assertNoFinancialObligations(client, userId) {
  const { rows: wallets } = await client.query(`
    SELECT id,available_balance,locked_balance
      FROM wallet_accounts
     WHERE user_id=$1
     ORDER BY id
     FOR UPDATE
  `, [userId]);

  if (wallets.some((wallet) =>
    BigInt(String(wallet.available_balance ?? '0')) > 0n ||
    BigInt(String(wallet.locked_balance ?? '0')) > 0n
  )) {
    throw accountFinancialObligationsPendingError();
  }

  const { rows: activeHolds } = await client.query(`
    SELECT h.id
      FROM wallet_holds h
      JOIN wallet_accounts w ON w.id=h.wallet_id
     WHERE w.user_id=$1 AND h.status='ACTIVE'
     LIMIT 1
  `, [userId]);
  if (activeHolds.length) throw accountFinancialObligationsPendingError();

  // These are deliberately read without FOR UPDATE: release/refund callbacks lock
  // payment rows before wallets. Wallet rows above are locked, so an in-flight
  // settlement either remains nonterminal (and blocks deletion) or commits its
  // wallet changes before the locked balance snapshot is accepted.
  const { rows: payments } = await client.query(`
    SELECT id
      FROM payments
     WHERE (payer_id=$1 OR payee_id=$1)
       AND status NOT IN ('RELEASED','REFUNDED','HOLD_FAILED')
     LIMIT 1
  `, [userId]);
  if (payments.length) throw accountFinancialObligationsPendingError();

  const { rows: refunds } = await client.query(`
    SELECT r.id
      FROM refunds r
      JOIN payments p ON p.id=r.payment_id
     WHERE (p.payer_id=$1 OR p.payee_id=$1)
       AND r.status NOT IN ('REFUNDED','FAILED')
     LIMIT 1
  `, [userId]);
  if (refunds.length) throw accountFinancialObligationsPendingError();

  const { rows: payouts } = await client.query(`
    SELECT id
      FROM payouts
     WHERE user_id=$1 AND status NOT IN ('SUCCEEDED','FAILED')
     LIMIT 1
  `, [userId]);
  if (payouts.length) throw accountFinancialObligationsPendingError();

  const { rows: operations } = await client.query(`
    SELECT id
      FROM financial_operations
     WHERE actor_id=$1 AND status NOT IN ('SUCCEEDED','FAILED','CANCELLED')
     LIMIT 1
  `, [userId]);
  if (operations.length) throw accountFinancialObligationsPendingError();
}

const userSelect = `id,email,password_hash,password_hash AS "passwordHash",display_name AS "displayName",role,status,session_version,created_at AS "createdAt"`;

export async function getUserPrivacyBundle(userId) {
  const pool = requirePool();
  const [u,p,j,a,o,pay,n,prefs,savedSearches,ev,up,analytics,crashes,trust,recommendationProfile,satisfaction] = await Promise.all([
    pool.query(`SELECT ${userSelect} FROM users WHERE id=$1`, [userId]),
    pool.query(`SELECT id,user_id,provider_type,capacity,verification_status,created_at,updated_at FROM providers WHERE user_id=$1`, [userId]),
    pool.query(`SELECT * FROM jobs WHERE owner_id=$1 OR provider_id=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT * FROM job_applications WHERE candidate_id=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT o.* FROM offers o JOIN jobs j ON j.id=o.job_id WHERE o.provider_id=$1 OR j.owner_id=$1 ORDER BY o.created_at DESC`, [userId]),
    pool.query(`SELECT * FROM payments WHERE payer_id=$1 OR payee_id=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT id,type,title,body,created_at,read_at FROM notifications WHERE user_id=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT * FROM notification_preferences WHERE user_id=$1`, [userId]),
    pool.query(`SELECT * FROM saved_searches WHERE user_id=$1 ORDER BY updated_at DESC LIMIT 20`, [userId]),
    pool.query(`SELECT * FROM evidence WHERE submitted_by=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT * FROM uploads WHERE uploaded_by=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT * FROM analytics_events WHERE user_id=$1 ORDER BY occurred_at DESC`, [userId]),
    pool.query(`SELECT * FROM crash_reports WHERE user_id=$1 ORDER BY occurred_at DESC`, [userId]),
    pool.query(`SELECT * FROM trust_reports WHERE reporter_id=$1 ORDER BY created_at DESC`, [userId]),
    pool.query(`SELECT * FROM recommendation_profiles WHERE user_id=$1`, [userId]),
    pool.query(`SELECT * FROM job_satisfaction_feedback WHERE user_id=$1 ORDER BY created_at DESC`, [userId]),
  ]);
  if (!u.rows[0]) return null;
  return { user:userFromRow(u.rows[0]), provider:p.rows[0] ? {id:p.rows[0].id,userId:p.rows[0].user_id,providerType:p.rows[0].provider_type,capacity:p.rows[0].capacity,verificationStatus:p.rows[0].verification_status,createdAt:p.rows[0].created_at?.toISOString?.()??p.rows[0].created_at,updatedAt:p.rows[0].updated_at?.toISOString?.()??p.rows[0].updated_at} : null,
    jobs:j.rows.map(jobFromRow), applications:a.rows.map(applicationFromRow), offers:o.rows.map(offerFromRow), payments:pay.rows.map(paymentFromRow),
    notifications:n.rows.map(r=>({id:r.id,type:r.type,title:r.title,body:r.body,createdAt:r.created_at?.toISOString?.()??r.created_at,readAt:r.read_at?.toISOString?.()??r.read_at})),
    preferences:prefs.rows[0]||null,
    savedSearches: savedSearches.rows.map(r=>({id:r.id,name:r.name,query:r.query,kind:r.kind,visibility:r.visibility,city:r.city,category:r.category,createdAt:r.created_at?.toISOString?.()??r.created_at,updatedAt:r.updated_at?.toISOString?.()??r.updated_at})),
    evidence:ev.rows.map(r=>({id:r.id,jobId:r.job_id,submittedBy:r.submitted_by,uri:r.uri,notes:r.notes,type:r.type,createdAt:r.created_at?.toISOString?.()??r.created_at})), uploads:up.rows.map(r=>({id:r.id,storageKey:r.storage_key,uploadedBy:r.uploaded_by,contentType:r.content_type,size:r.size,createdAt:r.created_at?.toISOString?.()??r.created_at})),
    analyticsEvents:analytics.rows.map(r=>({id:r.id,eventName:r.event_name,userId:r.user_id,anonymousId:r.anonymous_id,sessionId:r.session_id,appVersion:r.app_version,platform:r.platform,properties:r.properties||{},dedupeKey:r.dedupe_key,occurredAt:r.occurred_at?.toISOString?.()??r.occurred_at,createdAt:r.created_at?.toISOString?.()??r.created_at})),
    crashReports:crashes.rows.map(r=>({id:r.id,userId:r.user_id,anonymousId:r.anonymous_id,appVersion:r.app_version,platform:r.platform,releaseChannel:r.release_channel,fingerprint:r.fingerprint,message:r.message,stack:r.stack,context:r.context||{},occurredAt:r.occurred_at?.toISOString?.()??r.occurred_at,createdAt:r.created_at?.toISOString?.()??r.created_at})),
    trustReports:trust.rows.map(r=>({id:r.id,reporterId:r.reporter_id,entityType:r.entity_type,entityId:r.entity_id,reason:r.reason,details:r.details||'',status:r.status,createdAt:r.created_at?.toISOString?.()??r.created_at,updatedAt:r.updated_at?.toISOString?.()??r.updated_at})),
    recommendationProfile: recommendationProfile.rows[0] || null,
    satisfactionHistory: satisfaction.rows.map(r => ({ id:r.id, jobId:r.job_id, userId:r.user_id, role:r.role, overallRating:r.overall_rating, completedAsAgreed:r.completed_as_agreed, communicationRating:r.communication_rating, reportText:r.report_text || '', aiSummary:r.ai_summary || '', aiSatisfactionScore:r.ai_satisfaction_score, aiSentiment:r.ai_sentiment, aiTags:r.ai_tags || [], aiRiskFlags:r.ai_risk_flags || [], status:r.status, createdAt:r.created_at?.toISOString?.() ?? r.created_at, updatedAt:r.updated_at?.toISOString?.() ?? r.updated_at })),
  };
}

export async function deleteUserPrivacyBundle(userId, replacement) {
  return withSqlTransaction(async(client)=>{
    // NO KEY UPDATE still serializes account deletion but remains compatible with
    // FK KEY SHARE locks taken when an in-flight chat/evidence write references the user.
    // A stronger FOR UPDATE here can deadlock with the upload lock below.
    const u = await client.query(`SELECT id,role FROM users WHERE id=$1 FOR NO KEY UPDATE`, [userId]);
    if (!u.rows[0]) return null;

    // Do not anonymize an account while money, holds, or financial operations remain unresolved.
    // Wallet operations that create/change account funds lock the same user row before the wallet.
    await assertNoFinancialObligations(client, userId);

    // Serialize deletion cleanup with every association path that locks the upload
    // before adding an evidence/chat reference. Candidate keys are computed while
    // these row locks are held, not in a stale pre-delete query in the route.
    const { rows: ownedUploads } = await client.query(
      `SELECT id,storage_key FROM uploads WHERE uploaded_by=$1 ORDER BY id FOR UPDATE`,
      [userId],
    );
    const { rows: deletableUploads } = ownedUploads.length
      ? await client.query(
          `SELECT u.storage_key
             FROM uploads u
            WHERE u.id=ANY($1::uuid[])
              AND NOT EXISTS (SELECT 1 FROM evidence e WHERE e.uri=('storage://' || u.storage_key))
              AND NOT EXISTS (SELECT 1 FROM chat_message_attachments a WHERE a.upload_id=u.id)
            ORDER BY u.id`,
          [ownedUploads.map((upload) => upload.id)],
        )
      : { rows: [] };
    const deletableUploadKeys = deletableUploads.map((upload) => upload.storage_key);

    // Keep pending presigned intents as bounded cleanup tombstones. A signed PUT URL
    // cannot be revoked when the account is deleted; the route attempts immediate
    // deletion, and the existing worker retries after expiry + grace. Removing the
    // intent here would lose the durable key if the client uploads after that attempt.
    const { rows: pendingIntents } = await client.query(
      `SELECT id,storage_key FROM upload_intents WHERE uploaded_by=$1 ORDER BY id FOR UPDATE`,
      [userId],
    );
    const pendingUploadIntentKeys = pendingIntents.map((intent) => intent.storage_key);

    const tables = ['refresh_tokens','reset_tokens','notification_devices','notification_preferences','notifications','chat_presence','chat_conversation_preferences','chat_message_reads'];
    for (const t of tables) await client.query(`DELETE FROM ${t} WHERE user_id=$1`, [userId]);
    // Keep only coarse event metadata for aggregate analytics; remove linkable and arbitrary payload fields.
    await client.query(`UPDATE analytics_events SET user_id=NULL, anonymous_id=NULL, session_id=NULL, properties='{}'::jsonb, dedupe_key=NULL WHERE user_id=$1`, [userId]);
    // Crash text/context can contain historical PII even after identifiers are detached.
    await client.query(`UPDATE crash_reports SET user_id=NULL, anonymous_id=NULL, message='[REDACTED]', stack=NULL, context='{}'::jsonb WHERE user_id=$1`, [userId]);
    // Pending upload intents are intentionally retained for the expiry/grace cleanup worker.
    await client.query(`UPDATE evidence SET submitted_by=NULL WHERE submitted_by=$1`, [userId]);
    await client.query(`UPDATE uploads SET uploaded_by=NULL WHERE uploaded_by=$1`, [userId]);
    await client.query(`UPDATE jobs SET provider_id=NULL WHERE provider_id=$1 AND status IN ('DRAFT','PUBLISHED')`, [userId]);
    await client.query(`UPDATE users SET email=$2,password_hash=$3,display_name='Deleted user',status='DELETED',session_version=session_version+1 WHERE id=$1`, [userId,replacement.email,replacement.passwordHash]);
    await client.query(`UPDATE audit_logs SET actor_id=NULL WHERE actor_id=$1`, [userId]);
    await client.query(`DELETE FROM trust_reports WHERE reporter_id=$1`, [userId]);
    await client.query(`DELETE FROM recommendation_profiles WHERE user_id=$1`, [userId]);
    await client.query(`DELETE FROM saved_searches WHERE user_id=$1`, [userId]);
    // Keep application lifecycle history for marketplace integrity, but erase the applicant's personal resume/skills content.
    await client.query(`UPDATE job_applications SET resume_text='', skills='' WHERE candidate_id=$1`, [userId]);
    await client.query(`DELETE FROM job_satisfaction_feedback WHERE user_id=$1`, [userId]);
    return { deleted: true, deletableUploadKeys, pendingUploadIntentKeys };
  });
}
