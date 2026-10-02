import { requirePool } from './context.js';
import { withSqlTransaction } from '../db.js';

const disputeView = (row) => row ? ({
  id: row.id, jobId: row.job_id, openedBy: row.opened_by, triggerType: row.trigger_type, status: row.status,
  aiDecision: row.ai_decision, aiConfidence: row.ai_confidence == null ? null : Number(row.ai_confidence),
  aiReport: row.ai_report || {}, legalRulesetVersion: row.legal_ruleset_version,
  resolution: row.resolution, resolutionReason: row.resolution_reason || '', resolvedBy: row.resolved_by,
  resolvedAt: row.resolved_at?.toISOString?.() ?? row.resolved_at ?? null,
  createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
  updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at ?? null,
}) : null;

export async function getJobDisputeContext(jobId) {
  const p = requirePool();
  const [jobResult, paymentResult, feedbackResult, evidenceResult, auditResult] = await Promise.all([
    p.query(`SELECT id,owner_id,provider_id,title,description,acceptance_criteria,status,kind,budget_type,budget_min,budget_max,duration,city,schedule,attributes FROM jobs WHERE id=$1`, [jobId]),
    p.query(`SELECT id,job_id,payer_id,payee_id,amount,status,currency,base_amount,employer_charge,provider_payout,created_at,updated_at FROM payments WHERE job_id=$1`, [jobId]),
    p.query(`SELECT id,job_id,user_id,role,overall_rating,completed_as_agreed,communication_rating,report_text,ai_summary,ai_satisfaction_score,ai_sentiment,ai_tags,ai_risk_flags,status,created_at,updated_at FROM job_satisfaction_feedback WHERE job_id=$1 ORDER BY created_at ASC`, [jobId]),
    p.query(`SELECT id,submitted_by,uri,notes,type,created_at FROM evidence WHERE job_id=$1 ORDER BY created_at ASC LIMIT 100`, [jobId]),
    p.query(`SELECT action,actor_id,entity_type,entity_id,meta,created_at FROM audit_logs WHERE entity_type='job' AND entity_id=$1 ORDER BY created_at ASC LIMIT 100`, [jobId]),
  ]);
  const job = jobResult.rows[0]; if (!job) return null;
  return {
    job: { id: job.id, ownerId: job.owner_id, providerId: job.provider_id, title: job.title, description: job.description, acceptanceCriteria: job.acceptance_criteria, status: job.status, kind: job.kind, budgetType: job.budget_type, budgetMin: job.budget_min, budgetMax: job.budget_max, duration: job.duration, city: job.city, schedule: job.schedule, attributes: job.attributes || {} },
    payment: paymentResult.rows[0] ? { id: paymentResult.rows[0].id, amount: Number(paymentResult.rows[0].amount), status: paymentResult.rows[0].status, currency: paymentResult.rows[0].currency, providerPayout: Number(paymentResult.rows[0].provider_payout || paymentResult.rows[0].amount) } : null,
    feedback: feedbackResult.rows.map(row => ({ id: row.id, role: row.role, overallRating: Number(row.overall_rating), completedAsAgreed: row.completed_as_agreed === true, communicationRating: Number(row.communication_rating), reportText: row.report_text || '', aiSummary: row.ai_summary || '', aiSatisfactionScore: Number(row.ai_satisfaction_score || 0), aiSentiment: row.ai_sentiment, aiTags: row.ai_tags || [], aiRiskFlags: row.ai_risk_flags || [], status: row.status })),
    evidence: evidenceResult.rows.map(row => ({ id: row.id, submittedBy: row.submitted_by, uri: row.uri, notes: row.notes || '', type: row.type, createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null })),
    auditTrail: auditResult.rows.map(row => ({ action: row.action, actorId: row.actor_id, entityType: row.entity_type, entityId: row.entity_id, meta: row.meta || {}, createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null })),
  };
}

export async function getJobDispute(jobId) {
  const { rows } = await requirePool().query(`SELECT * FROM job_disputes WHERE job_id=$1`, [jobId]);
  return disputeView(rows[0]);
}

export async function createJobDispute({ jobId, openedBy = null, triggerType = 'USER' }) {
  const { rows } = await requirePool().query(`
    INSERT INTO job_disputes(id,job_id,opened_by,trigger_type,status)
    VALUES(gen_random_uuid(),$1,$2,$3,'OPEN')
    ON CONFLICT(job_id) DO UPDATE SET updated_at=NOW()
    RETURNING *
  `, [jobId, openedBy, triggerType]);
  return disputeView(rows[0]);
}

export async function updateJobDisputeAnalysis(id, analysis) {
  const { rows } = await requirePool().query(`UPDATE job_disputes SET status=CASE WHEN ($6::jsonb->>'manualReview')::boolean THEN 'ADMIN_REVIEW' ELSE 'AI_ANALYZED' END,ai_decision=$2,ai_confidence=$3,ai_report=$4::jsonb,legal_ruleset_version=$5,updated_at=NOW() WHERE id=$1 RETURNING *`, [id, analysis.decision, analysis.confidence, JSON.stringify(analysis), analysis.rulesetVersion, JSON.stringify(analysis)]);
  return disputeView(rows[0]);
}

export async function markJobDisputeAdminReview(id) {
  const { rows } = await requirePool().query(`UPDATE job_disputes SET status='ADMIN_REVIEW',updated_at=NOW() WHERE id=$1 AND status IN ('OPEN','AI_ANALYZED','ADMIN_REVIEW') RETURNING *`, [id]);
  return disputeView(rows[0]);
}

export async function resolveJobDispute(id, { resolution, reason, adminId }) {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`SELECT * FROM job_disputes WHERE id=$1 FOR UPDATE`, [id]);
    if (!rows[0]) return null;
    if (rows[0].status === 'RESOLVED') return disputeView(rows[0]);
    const { rows: updated } = await client.query(`UPDATE job_disputes SET status='RESOLVED',resolution=$2,resolution_reason=$3,resolved_by=$4,resolved_at=NOW(),updated_at=NOW() WHERE id=$1 RETURNING *`, [id, resolution, reason || '', adminId]);
    return disputeView(updated[0]);
  });
}

export async function listAdminDisputes(limit = 100) {
  const safeLimit = Math.min(Math.max(Number(limit) || 100, 1), 200);
  const { rows } = await requirePool().query(`
    SELECT d.*,j.title,j.status AS job_status,p.amount AS payment_amount,p.status AS payment_status,
           u.display_name AS owner_name,w.display_name AS worker_name
    FROM job_disputes d
    JOIN jobs j ON j.id=d.job_id
    LEFT JOIN payments p ON p.job_id=j.id
    LEFT JOIN users u ON u.id=j.owner_id
    LEFT JOIN users w ON w.id=j.provider_id
    ORDER BY d.created_at DESC LIMIT $1`, [safeLimit]);
  return rows.map((row) => ({ ...disputeView(row), jobTitle: row.title, jobStatus: row.job_status, paymentAmount: row.payment_amount == null ? null : Number(row.payment_amount), paymentStatus: row.payment_status, ownerName: row.owner_name || '', workerName: row.worker_name || '' }));
}

export async function getAdminDispute(id) {
  const { rows } = await requirePool().query(`
    SELECT d.*,j.title,j.status AS job_status,j.owner_id,j.provider_id,p.amount AS payment_amount,p.status AS payment_status,
           u.display_name AS owner_name,w.display_name AS worker_name,u.email AS owner_email,w.email AS worker_email
    FROM job_disputes d JOIN jobs j ON j.id=d.job_id
    LEFT JOIN payments p ON p.job_id=j.id
    LEFT JOIN users u ON u.id=j.owner_id LEFT JOIN users w ON w.id=j.provider_id
    WHERE d.id=$1`, [id]);
  if (!rows[0]) return null;
  const context = await getJobDisputeContext(rows[0].job_id);
  return { ...disputeView(rows[0]), jobTitle: rows[0].title, jobStatus: rows[0].job_status, paymentAmount: rows[0].payment_amount == null ? null : Number(rows[0].payment_amount), paymentStatus: rows[0].payment_status, owner: { id: rows[0].owner_id, name: rows[0].owner_name || '', email: rows[0].owner_email || '' }, worker: { id: rows[0].provider_id, name: rows[0].worker_name || '', email: rows[0].worker_email || '' }, context };
}

export async function setAdminPanelVerified(userId) {
  const { rows } = await requirePool().query(`UPDATE users SET admin_panel_verified_at=NOW() WHERE id=$1 AND role='ADMIN' RETURNING id,admin_panel_verified_at`, [userId]);
  return rows[0] ? { verifiedAt: rows[0].admin_panel_verified_at?.toISOString?.() ?? rows[0].admin_panel_verified_at } : null;
}

export async function isAdminPanelVerified(userId, ttlMinutes = 15) {
  const { rows } = await requirePool().query(`SELECT role,admin_panel_verified_at FROM users WHERE id=$1`, [userId]);
  const at = rows[0]?.admin_panel_verified_at;
  return rows[0]?.role === 'ADMIN' && at && (Date.now() - new Date(at).getTime()) <= Math.max(1, Number(ttlMinutes) || 15) * 60000;
}

export async function clearAdminPanelVerification(userId) {
  await requirePool().query(`UPDATE users SET admin_panel_verified_at=NULL WHERE id=$1`, [userId]);
  return true;
}