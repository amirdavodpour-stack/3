import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';

const toRow = (row) => row ? ({
  id: row.id,
  jobId: row.job_id,
  openedBy: row.opened_by,
  triggerType: row.trigger_type,
  status: row.status,
  aiDecision: row.ai_decision,
  aiConfidence: row.ai_confidence == null ? null : Number(row.ai_confidence),
  aiReport: row.ai_report || {},
  legalRulesetVersion: row.legal_ruleset_version,
  resolution: row.resolution,
  resolutionReason: row.resolution_reason || '',
  resolvedBy: row.resolved_by,
  resolvedAt: row.resolved_at,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
  job: row.job_title ? {
    id: row.job_id,
    title: row.job_title,
    status: row.job_status,
    ownerId: row.owner_id,
    providerId: row.provider_id,
  } : null,
  employer: row.employer_name ? { id: row.owner_id, displayName: row.employer_name } : null,
  worker: row.worker_name ? { id: row.provider_id, displayName: row.worker_name } : null,
  payment: row.payment_id ? {
    id: row.payment_id,
    status: row.payment_status,
    amount: row.payment_amount == null ? null : Number(row.payment_amount),
    currency: row.payment_currency,
  } : null,
  feedback: Array.isArray(row.feedback) ? row.feedback : [],
});

const selectBase = `
  d.*,
  j.title AS job_title,
  j.status AS job_status,
  j.owner_id,
  j.provider_id,
  owner.display_name AS employer_name,
  worker.display_name AS worker_name,
  p.id AS payment_id,
  p.status AS payment_status,
  p.amount AS payment_amount,
  p.currency AS payment_currency,
  COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', f.id,
      'userId', f.user_id,
      'role', f.role,
      'overallRating', f.overall_rating,
      'completedAsAgreed', f.completed_as_agreed,
      'communicationRating', f.communication_rating,
      'reportText', f.report_text,
      'aiSummary', f.ai_summary,
      'aiSatisfactionScore', f.ai_satisfaction_score,
      'aiSentiment', f.ai_sentiment,
      'aiTags', f.ai_tags,
      'aiRiskFlags', f.ai_risk_flags,
      'status', f.status,
      'createdAt', f.created_at
    ) ORDER BY f.created_at)
    FROM job_satisfaction_feedback f
    WHERE f.job_id = d.job_id
  ), '[]'::jsonb) AS feedback
  FROM job_disputes d
  JOIN jobs j ON j.id = d.job_id
  LEFT JOIN users owner ON owner.id = j.owner_id
  LEFT JOIN users worker ON worker.id = j.provider_id
  LEFT JOIN payments p ON p.job_id = j.id
`;

export async function getJobDispute(jobId) {
  const { rows } = await requirePool().query(`SELECT ${selectBase} WHERE d.job_id=$1`, [jobId]);
  return toRow(rows[0]);
}

export async function createJobDispute({ jobId, openedBy = null, triggerType = 'USER', aiReport = {}, legalRulesetVersion = 'IR-2026-10-02-v1' }) {
  if (!['USER','SATISFACTION_CONFLICT','ADMIN'].includes(triggerType)) {
    const e = new Error('INVALID_DISPUTE_TRIGGER'); e.code = 'INVALID_DISPUTE_TRIGGER'; throw e;
  }
  return withSqlTransaction(async (client) => {
    const existing = await client.query(`SELECT * FROM job_disputes WHERE job_id=$1 FOR UPDATE`, [jobId]);
    if (existing.rows[0]) {
      const { rows } = await client.query(`SELECT ${selectBase} WHERE d.job_id=$1`, [jobId]);
      return toRow(rows[0]);
    }
    const decision = ['RELEASE','REFUND','HOLD'].includes(String(aiReport?.decision || '')) ? aiReport.decision : 'HOLD';
    const confidence = Number.isFinite(Number(aiReport?.confidence)) ? Math.max(0, Math.min(1, Number(aiReport.confidence))) : 0;
    const needsReview = aiReport?.manualReview === true || decision === 'HOLD' || confidence < 0.8;
    const status = needsReview ? 'ADMIN_REVIEW' : 'AI_ANALYZED';
    const { rows } = await client.query(`
      INSERT INTO job_disputes(job_id,opened_by,trigger_type,status,ai_decision,ai_confidence,ai_report,legal_ruleset_version)
      VALUES($1,$2,$3,$4,$5,$6,$7::jsonb,$8)
      RETURNING *
    `, [jobId, openedBy, triggerType, status, decision, confidence, JSON.stringify(aiReport || {}), legalRulesetVersion]);
    const full = await client.query(`SELECT ${selectBase} WHERE d.id=$1`, [rows[0].id]);
    return toRow(full.rows[0]);
  });
}

export async function listAdminDisputes(limit = 100, offset = 0) {
  const safeLimit = Math.min(Math.max(Number(limit) || 100, 1), 200);
  const safeOffset = Math.max(Number(offset) || 0, 0);
  const { rows } = await requirePool().query(`SELECT ${selectBase} WHERE d.status IN ('OPEN','AI_ANALYZED','ADMIN_REVIEW','ESCALATED') ORDER BY d.created_at DESC LIMIT $1 OFFSET $2`, [safeLimit, safeOffset]);
  return rows.map(toRow);
}

export async function getAdminDispute(id) {
  const { rows } = await requirePool().query(`SELECT ${selectBase} WHERE d.id=$1`, [id]);
  return toRow(rows[0]);
}

export async function resolveJobDispute({ id, resolution, adminId, reason = '' }) {
  if (!['RELEASE','REFUND','HOLD'].includes(String(resolution || '').toUpperCase())) {
    const e = new Error('INVALID_DISPUTE_RESOLUTION'); e.code = 'INVALID_DISPUTE_RESOLUTION'; throw e;
  }
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`UPDATE job_disputes SET resolution=$2,resolution_reason=$3,resolved_by=$4,resolved_at=NOW(),status='RESOLVED',updated_at=NOW() WHERE id=$1 AND status <> 'RESOLVED' RETURNING *`, [id, String(resolution).toUpperCase(), String(reason).slice(0, 2000), adminId]);
    if (!rows[0]) {
      const existing = await client.query(`SELECT * FROM job_disputes WHERE id=$1`, [id]);
      return existing.rows[0] || null;
    }
    const full = await client.query(`SELECT ${selectBase} WHERE d.id=$1`, [id]);
    return toRow(full.rows[0]);
  });
}
