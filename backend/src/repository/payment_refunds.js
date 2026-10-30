import { closeJobChatForJob } from './human_chat.js';
import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { config } from '../config.js';
import { normalizeFinancialAmount, fundingJournal, releaseJournal, payoutJournal, refundJournal, calculatePaymentBreakdown } from '../financial.js';
import { jobFromRow, offerFromRow, paymentFromRow } from './mappers.js';
import { postInternalPaymentRefundWithClient } from '../wallet_ledger.js';
import { postExternalLedgerJournalWithClient } from './external_payment_ledger.js';

export function refundablePaymentStateAllowed(status, allowPendingRelease = false) {
  const allowed = allowPendingRelease ? ['HELD','RELEASE_PENDING','RELEASE_FAILED'] : ['HELD'];
  return allowed.includes(String(status || '').toUpperCase());
}

export async function createRefundAtomic({jobId,paymentId,ownerId,amount,id,idempotencyKey,createdAt,allowPendingRelease=false}) {
  return withSqlTransaction(async(client)=>{
    if (idempotencyKey) {
      await client.query(`SELECT pg_advisory_xact_lock(hashtextextended($1, 918273645))`, [`refund:${paymentId}:${idempotencyKey}`]);
    }
    const {rows:jr}=await client.query(`SELECT * FROM jobs WHERE id=$1 FOR UPDATE`,[jobId]);
    if(!jr[0]) return null;
    if(jr[0].owner_id!==ownerId){const e=new Error('FORBIDDEN');e.code='FORBIDDEN';throw e;}
    // A terminal release failure locks the outbox row before updating payments.
    // Acquire the release event before the payment row so refund supersession
    // cannot form payment -> outbox against failOutboxEvent's outbox -> payment.
    // The job lock above still serializes normal release completion and webhooks.
    const {rows:paymentMetadataRows}=await client.query(
      `SELECT status FROM payments WHERE id=$1 AND job_id=$2`,
      [paymentId,jobId],
    );
    const paymentMetadata=paymentMetadataRows[0];
    if(!paymentMetadata){const e=new Error('PAYMENT_NOT_FOUND');e.code='PAYMENT_NOT_FOUND';throw e;}
    if (allowPendingRelease && ['RELEASE_PENDING', 'RELEASE_FAILED'].includes(paymentMetadata.status)) {
      const releaseEvents = await client.query(
        `SELECT id,status FROM outbox_events
          WHERE aggregate_type='payment' AND aggregate_id=$1
            AND event_type='PAYMENT_RELEASE'
            AND status IN ('PENDING','FAILED','PROCESSING')
          ORDER BY id FOR UPDATE`,
        [paymentId],
      );
      if (releaseEvents.rows.some((event) => event.status === 'PROCESSING')) {
        const e = new Error('PAYMENT_RELEASE_IN_PROGRESS');
        e.code = 'PAYMENT_RELEASE_IN_PROGRESS';
        throw e;
      }
      for (const release of releaseEvents.rows) {
        if (['PENDING', 'FAILED'].includes(release.status)) {
          await client.query(
            `UPDATE outbox_events
               SET status='DONE',
                   processed_at=COALESCE(processed_at,NOW()),
                   locked_at=NULL,
                   lease_token=NULL,
                   last_error='SUPERSEDED_BY_REFUND'
             WHERE id=$1`,
            [release.id],
          );
        }
      }
    }

    const {rows:pr}=await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`,[paymentId,jobId]);
    const payment=pr[0]; if(!payment){const e=new Error('PAYMENT_NOT_FOUND');e.code='PAYMENT_NOT_FOUND';throw e;}
    if(!refundablePaymentStateAllowed(payment.status, allowPendingRelease)){const e=new Error('INVALID_PAYMENT_STATE');e.code='INVALID_PAYMENT_STATE';throw e;}
    const refundCurrency=String(payment.currency || config.paymentCurrency).toUpperCase(); const refundAmount=normalizeFinancialAmount(refundCurrency, amount || payment.amount); if(String(refundAmount)!==String(normalizeFinancialAmount(refundCurrency, payment.amount))){const e=new Error('PARTIAL_REFUND_UNSUPPORTED');e.code='PARTIAL_REFUND_UNSUPPORTED';throw e;}
    let refundRow = null;
    if (idempotencyKey) {
      const prior = await client.query(`SELECT * FROM refunds WHERE payment_id=$1 AND idempotency_key=$2 FOR UPDATE`, [paymentId, idempotencyKey]);
      refundRow = prior.rows[0] || null;
      if (refundRow?.status === 'REFUNDED') return { refund: refundRow, payment };
    }

    // One immutable PAYMENT_REFUND event exists per payment. A different
    // failed operation key cannot safely create another refund row because
    // the existing event payload must continue to identify the original row.
    // Check failed rows before returning a matching PENDING row so an older
    // stranded operation cannot be silently acknowledged as a new retry.
    const { rows: failedRefunds } = await client.query(
      `SELECT * FROM refunds
        WHERE payment_id=$1 AND status='FAILED'
        ORDER BY created_at DESC,id DESC
        FOR UPDATE`,
      [paymentId],
    );
    if (failedRefunds.length) {
      const suppliedKey = String(idempotencyKey || '');
      const matchingFailed = failedRefunds.filter(
        (candidate) => String(candidate.idempotency_key || '') === suppliedKey,
      );
      if (failedRefunds.length !== 1 || matchingFailed.length !== 1 ||
          (refundRow && refundRow.id !== matchingFailed[0].id)) {
        const error = new Error('REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY');
        error.code = 'REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY';
        error.status = 409;
        throw error;
      }
      refundRow = matchingFailed[0];
    }

    if (refundRow?.status === 'PENDING') {
      return { refund: refundRow, payment:{...payment,status:'REFUND_PENDING'} };
    }
    // Reopen the same semantic refund; never create a second refund operation.
    if (refundRow?.status === 'FAILED') {
      const { rows: reopened } = await client.query(
        `UPDATE refunds SET status='PENDING',provider_ref=NULL,updated_at=$2 WHERE id=$1 RETURNING *`,
        [refundRow.id, createdAt],
      );
      refundRow = reopened[0];
    }
    if (!refundRow) {
      const {rows:rr}=await client.query(`INSERT INTO refunds(id,payment_id,amount,currency,status,provider_ref,idempotency_key,created_at,updated_at) VALUES($1,$2,$3,$4,'PENDING',NULL,$5,$6,$6) RETURNING *`,[id,paymentId,refundAmount,payment.currency || config.paymentCurrency,idempotencyKey||null,createdAt]);
      refundRow = rr[0];
    }
    await client.query(`UPDATE payments SET status='REFUND_PENDING',updated_at=$2 WHERE id=$1`,[paymentId,createdAt]);
    const dedupe=`PAYMENT_REFUND:${paymentId}`;
    const {rows:ev}=await client.query(
      `INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at)
       VALUES(gen_random_uuid(),'PAYMENT_REFUND','payment',$1,$2,$3::jsonb,'PENDING',0,NOW(),NOW())
       ON CONFLICT(dedupe_key) DO UPDATE SET
         status=CASE WHEN outbox_events.status='FAILED' THEN 'PENDING' ELSE outbox_events.status END,
         attempts=CASE WHEN outbox_events.status='FAILED' THEN 0 ELSE outbox_events.attempts END,
         available_at=CASE WHEN outbox_events.status='FAILED' THEN NOW() ELSE outbox_events.available_at END,
         locked_at=CASE WHEN outbox_events.status='FAILED' THEN NULL ELSE outbox_events.locked_at END,
         lease_token=CASE WHEN outbox_events.status='FAILED' THEN NULL ELSE outbox_events.lease_token END,
         last_error=CASE WHEN outbox_events.status='FAILED' THEN NULL ELSE outbox_events.last_error END,
         processed_at=CASE WHEN outbox_events.status='FAILED' THEN NULL ELSE outbox_events.processed_at END
       RETURNING *`,
      [paymentId,dedupe,JSON.stringify({
        jobId,ownerId,paymentId,refundId:refundRow.id,providerRef:payment.provider_ref,
        idempotencyKey:idempotencyKey||`refund:${refundRow.id}`,
      })],
    );
    return {refund:refundRow,payment:{...payment,status:'REFUND_PENDING'},outboxEvent:{id:ev[0].id}};
  });
}
export async function completePaymentRefundOutbox({eventId,jobId,paymentId,refundId,providerRef,actorId,leaseToken}) {
  return withSqlTransaction(async(client)=>{
    // Match request/webhook lock ordering: serialize the job aggregate before
    // claiming the outbox row or locking its payment/refund records.
    const {rows:jr}=await client.query(`SELECT id FROM jobs WHERE id=$1 FOR UPDATE`,[jobId]);
    if(!jr[0])return {completed:false,reason:'PAYMENT_NOT_FOUND'};
    const {rows:er}=await client.query(`SELECT lease_token FROM outbox_events WHERE id=$1 FOR UPDATE`,[eventId]);
    if(!er[0])return {completed:false,reason:'OUTBOX_NOT_FOUND'};
    if(leaseToken && String(er[0].lease_token)!==String(leaseToken))return {completed:false,reason:'STALE_LEASE'};
    const {rows:pr}=await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`,[paymentId,jobId]);
    const payment=pr[0]; if(!payment)return {completed:false,reason:'PAYMENT_NOT_FOUND'};
    const {rows:rr}=await client.query(`SELECT * FROM refunds WHERE id=$1 AND payment_id=$2 FOR UPDATE`,[refundId,paymentId]); const refund=rr[0]; if(!refund)return {completed:false,reason:'REFUND_NOT_FOUND'};
    if(payment.status==='REFUNDED' && refund.status==='REFUNDED'){await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL WHERE id=$1`,[eventId]);return {completed:true,alreadyDone:true};}
    if(payment.status!=='REFUND_PENDING' || refund.status!=='PENDING'){return {completed:false,reason:'INVALID_REFUND_STATE'};}
    const breakdown={baseAmount:normalizeFinancialAmount(payment.currency,payment.base_amount||payment.amount),employerFee:normalizeFinancialAmount(payment.currency,payment.employer_fee||0),workerFee:normalizeFinancialAmount(payment.currency,payment.worker_fee||0),platformFee:normalizeFinancialAmount(payment.currency,payment.platform_fee||0),employerCharge:normalizeFinancialAmount(payment.currency,payment.employer_charge||payment.amount),providerPayout:normalizeFinancialAmount(payment.currency,payment.provider_payout||payment.amount),currency:payment.currency||config.paymentCurrency,policyVersion:payment.fee_policy_version||'legacy',kind:'JOB'};
    await client.query(`UPDATE refunds SET status='REFUNDED',provider_ref=$2,updated_at=NOW() WHERE id=$1`,[refundId,providerRef]);
    await client.query(`UPDATE payments SET status='REFUNDED',provider_ref=$2,updated_at=NOW() WHERE id=$1`,[paymentId,payment.provider_ref]);
    await client.query(`UPDATE jobs SET status=CASE WHEN provider_id IS NULL THEN 'PUBLISHED' ELSE 'ASSIGNED' END,updated_at=NOW() WHERE id=$1`,[jobId]);
    await closeJobChatForJob(jobId, client);
    if (config.paymentProvider === 'internal') {
      if (breakdown.currency !== 'TOMAN') {
        const e = new Error('INTERNAL_CURRENCY_MISMATCH'); e.code = 'INTERNAL_CURRENCY_MISMATCH'; throw e;
      }
      // The Financial Core refund operation already posts the canonical wallet
      // entry and balanced journal. Avoid a second legacy accounting journal.
      await postInternalPaymentRefundWithClient(client, {
        paymentId, payerId:payment.payer_id, providerPayout:breakdown.providerPayout,
        platformFee:breakdown.platformFee, employerCharge:breakdown.employerCharge,
        currency:breakdown.currency, idempotencyKey:`internal:refund:${paymentId}`,
      });
    } else {
      await postExternalLedgerJournalWithClient(client, {
        operationType:'REFUND', journalType:'EXTERNAL_REFUND', referenceType:'PAYMENT_REFUND',
        referenceId:paymentId, currency:breakdown.currency, entries:refundJournal(breakdown),
        idempotencyKey:`external:REFUND:${paymentId}`,
      });
    }
    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES($1,'PAYMENT_REFUND',$2,'payment',$3,$4::jsonb,NOW())`,[crypto.randomUUID(),actorId,paymentId,JSON.stringify({jobId,refundId,eventId,providerRef})]);
    await client.query(`UPDATE outbox_events SET status='DONE',processed_at=NOW(),locked_at=NULL,last_error=NULL WHERE id=$1`,[eventId]);
    return {completed:true,alreadyDone:false};
  });
}
