import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';

function feedbackFromRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    jobId: row.job_id,
    userId: row.user_id,
    role: row.role,
    overallRating: Number(row.overall_rating),
    completedAsAgreed: Boolean(row.completed_as_agreed),
    communicationRating: Number(row.communication_rating),
    reportText: row.report_text || '',
    aiSummary: row.ai_summary || '',
    aiSatisfactionScore: Number(row.ai_satisfaction_score || 0),
    aiSentiment: row.ai_sentiment || 'NEEDS_REVIEW',
    aiTags: Array.isArray(row.ai_tags) ? row.ai_tags : [],
    aiRiskFlags: Array.isArray(row.ai_risk_flags) ? row.ai_risk_flags : [],
    status: row.status,
    createdAt: row.created_at?.toISOString?.() ?? row.created_at,
    updatedAt: row.updated_at?.toISOString?.() ?? row.updated_at,
  };
}

export async function listJobSatisfactionFeedback(jobId) {
  const { rows } = await requirePool().query(
    `SELECT * FROM job_satisfaction_feedback WHERE job_id=$1 ORDER BY role ASC,created_at ASC`,
    [jobId],
  );
  return rows.map(feedbackFromRow);
}

export async function getJobSatisfactionFeedbackForUser(jobId, userId) {
  const { rows } = await requirePool().query(
    `SELECT * FROM job_satisfaction_feedback WHERE job_id=$1 AND user_id=$2`,
    [jobId, userId],
  );
  return feedbackFromRow(rows[0]);
}

export async function listUserSatisfactionHistory(userId, limit = 50) {
  const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const { rows } = await requirePool().query(
    `SELECT f.*, j.title AS job_title, j.owner_id, j.provider_id
       FROM job_satisfaction_feedback f
       JOIN jobs j ON j.id=f.job_id
      WHERE f.user_id=$1
      ORDER BY f.created_at DESC
      LIMIT $2`,
    [userId, safeLimit],
  );
  return rows.map((row) => ({ ...feedbackFromRow(row), jobTitle: row.job_title || '' }));
}

export async function insertJobSatisfactionFeedback({
  jobId, userId, role, overallRating, completedAsAgreed, communicationRating,
  reportText, analysis, status = 'ANALYZED',
}) {
  return withSqlTransaction(async (client) => {
    const { rows: jobs } = await client.query(`SELECT id,owner_id,provider_id,status FROM jobs WHERE id=$1 FOR UPDATE`, [jobId]);
    const job = jobs[0];
    if (!job) return null;
    if (job.status !== 'COMPLETED') {
      const e = new Error('JOB_NOT_COMPLETED'); e.code='JOB_NOT_COMPLETED'; throw e;
    }
    const normalizedRole = String(role || '').toUpperCase();
    const expectedUserId = normalizedRole === 'EMPLOYER' ? job.owner_id : normalizedRole === 'WORKER' ? job.provider_id : null;
    if (!expectedUserId || String(expectedUserId) !== String(userId)) {
      const e = new Error('INVALID_FEEDBACK_PARTICIPANT'); e.code='INVALID_FEEDBACK_PARTICIPANT'; throw e;
    }
    const { rows: existing } = await client.query(
      `SELECT id,status FROM job_satisfaction_feedback WHERE job_id=$1 AND user_id=$2 FOR UPDATE`,
      [jobId, userId],
    );
    if (existing[0] && existing[0].status !== 'ANALYSIS_FAILED') {
      const e = new Error('FEEDBACK_ALREADY_SUBMITTED'); e.code='FEEDBACK_ALREADY_SUBMITTED'; throw e;
    }
    const sql = existing[0]
      ? `UPDATE job_satisfaction_feedback
            SET overall_rating=$3,completed_as_agreed=$4,communication_rating=$5,report_text=$6,
                ai_summary=$7,ai_satisfaction_score=$8,ai_sentiment=$9,ai_tags=$10::jsonb,ai_risk_flags=$11::jsonb,
                status=$12,updated_at=NOW()
          WHERE id=$1
          RETURNING *`
      : `INSERT INTO job_satisfaction_feedback(
            id,job_id,user_id,role,overall_rating,completed_as_agreed,communication_rating,report_text,
            ai_summary,ai_satisfaction_score,ai_sentiment,ai_tags,ai_risk_flags,status
         ) VALUES(gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11::jsonb,$12::jsonb,$13)
         RETURNING *`;
    const params = existing[0]
      ? [existing[0].id, jobId, overallRating, completedAsAgreed, communicationRating, reportText,
         analysis.summary, analysis.satisfactionScore, analysis.sentiment, JSON.stringify(analysis.tags), JSON.stringify(analysis.riskFlags), status]
      : [jobId, userId, normalizedRole, overallRating, completedAsAgreed, communicationRating, reportText,
         analysis.summary, analysis.satisfactionScore, analysis.sentiment, JSON.stringify(analysis.tags), JSON.stringify(analysis.riskFlags), status];
    const { rows } = await client.query(sql, params);
    return feedbackFromRow(rows[0]);
  });
}
