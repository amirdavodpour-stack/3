import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { applicationFromRow, employerCandidateFromRow } from './mappers.js';
import { lockAuthorizedAdminActor } from './admin_authorization.js';
import { queueNotificationWithClient } from './notifications.js';

export async function listAdminApplications() { const {rows}=await requirePool().query(`SELECT a.*, j.title AS job_title, u.display_name AS candidate_name FROM job_applications a JOIN jobs j ON j.id=a.job_id JOIN users u ON u.id=a.candidate_id ORDER BY a.created_at DESC`); return rows.map(r=>({...applicationFromRow(r),jobTitle:r.job_title,candidateName:r.candidate_name})); }
export async function transitionJobApplication(id, fromStatuses, toStatus) {
  const statuses = Array.isArray(fromStatuses) ? fromStatuses : [fromStatuses];
  const {rows}=await requirePool().query(`UPDATE job_applications SET status=$2,updated_at=NOW() WHERE id=$1 AND status = ANY($3::text[]) RETURNING *`,[id,toStatus,statuses]);
  return rows[0]?applicationFromRow(rows[0]):null;
}
export async function selectJobApplication(id) { return transitionJobApplication(id,['PENDING','SHORTLISTED'],'FORWARDED'); }

const ADMIN_APPLICATION_ACTIONS = Object.freeze({
  SHORTLISTED: { auditAction:'ADMIN_APPLICATION_SHORTLIST', notificationType:'APPLICATION_SHORTLISTED' },
  FORWARDED: { auditAction:'ADMIN_APPLICATION_FORWARD', notificationType:'APPLICATION_FORWARDED' },
  REJECTED: { auditAction:'ADMIN_APPLICATION_REJECT', notificationType:'APPLICATION_REJECTED' },
});

export async function transitionAdminJobApplication(id,fromStatuses,toStatus,{actorId,sessionJti,verificationMinutes=5,notification}={}) {
  const statuses=Array.isArray(fromStatuses)?fromStatuses:[fromStatuses];
  const action=ADMIN_APPLICATION_ACTIONS[toStatus];
  if(!action) throw Object.assign(new Error('INVALID_ADMIN_APPLICATION_TRANSITION'),{code:'INVALID_ADMIN_APPLICATION_TRANSITION'});
  if(!notification || notification.type!==action.notificationType || !String(notification.title||'').trim() || !String(notification.body||'').trim()) {
    throw Object.assign(new Error('ADMIN_APPLICATION_NOTIFICATION_REQUIRED'),{code:'ADMIN_APPLICATION_NOTIFICATION_REQUIRED'});
  }
  return withSqlTransaction(async(client)=>{
    const {actor}=await lockAuthorizedAdminActor(client,{actorId,sessionJti,verificationMinutes,requiredScope:'WRITE'});
    const {rows:references}=await client.query('SELECT job_id,candidate_id FROM job_applications WHERE id=$1',[id]);
    if(!references[0]) return null;
    // Recipient first, then job/application: this mirrors account erasure's
    // user-first lock order and avoids a job -> user inversion.
    const {rows:recipientRows}=await client.query(
      'SELECT id,status FROM users WHERE id=$1 FOR SHARE',
      [references[0].candidate_id],
    );
    if(!recipientRows[0] || String(recipientRows[0].status || '').toUpperCase()==='DELETED') return null;
    const {rows:jobs}=await client.query('SELECT id FROM jobs WHERE id=$1 FOR UPDATE',[references[0].job_id]);
    if(!jobs[0]) return null;
    const {rows:applications}=await client.query('SELECT * FROM job_applications WHERE id=$1 FOR UPDATE',[id]);
    const current=applications[0];
    if(!current || !statuses.includes(current.status)) return null;
    const {rows:updated}=await client.query('UPDATE job_applications SET status=$2,updated_at=NOW() WHERE id=$1 RETURNING *',[id,toStatus]);
    if(!updated[0]) return null;
    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),$1,$2,'job_application',$3,$4::jsonb,NOW())`,
      [action.auditAction,actor.id,id,JSON.stringify({jobId:current.job_id,candidateId:current.candidate_id,fromStatus:current.status,toStatus,sessionJti})],
    );
    await queueNotificationWithClient(client,{
      userId:current.candidate_id,
      type:action.notificationType,
      title:notification.title,
      body:notification.body,
      data:{jobId:current.job_id,applicationId:id},
      dedupeKey:`application:${id}:${action.notificationType}`,
      channels:notification.channels||['IN_APP','PUSH','EMAIL'],
    });
    return applicationFromRow(updated[0]);
  });
}

export async function listForwardedCandidatesForJob(jobId) { const {rows}=await requirePool().query(`SELECT id,resume_text,skills,status,created_at,updated_at FROM job_applications WHERE job_id=$1 AND status IN ('FORWARDED','INTERVIEW','OFFERED','ACCEPTED') ORDER BY updated_at DESC`,[jobId]); return rows.map(employerCandidateFromRow); }
// Backward-compatible repository contract name retained for older integrations/tests.
export async function listSelectedCandidatesForJob(jobId) { return listForwardedCandidatesForJob(jobId); }
export async function getJobApplicationById(id) { const {rows}=await requirePool().query(`SELECT * FROM job_applications WHERE id=$1`,[id]); return rows[0]?applicationFromRow(rows[0]):null; }
export async function getJobApplicationForCandidate(id,candidateId) { const {rows}=await requirePool().query(`SELECT * FROM job_applications WHERE id=$1 AND candidate_id=$2`,[id,candidateId]); return rows[0]?applicationFromRow(rows[0]):null; }
export async function listCandidateApplications(candidateId) { const {rows}=await requirePool().query(`SELECT a.*, j.title AS job_title, j.city AS job_city, j.kind AS job_kind, j.category_id, j.monthly_salary FROM job_applications a JOIN jobs j ON j.id=a.job_id WHERE a.candidate_id=$1 ORDER BY a.updated_at DESC`,[candidateId]); return rows.map(r=>({...applicationFromRow(r),jobTitle:r.job_title,jobCity:r.job_city,jobKind:r.job_kind,categoryId:r.category_id,monthlySalary:r.monthly_salary})); }
export async function transitionCandidateApplication(id, candidateId, fromStatuses, toStatus) { const statuses=Array.isArray(fromStatuses)?fromStatuses:[fromStatuses]; const {rows}=await requirePool().query(`UPDATE job_applications SET status=$3,updated_at=NOW() WHERE id=$1 AND candidate_id=$2 AND status = ANY($4::text[]) RETURNING *`,[id,candidateId,toStatus,statuses]); return rows[0]?applicationFromRow(rows[0]):null; }
export async function transitionEmployerApplication(id, ownerId, fromStatuses, toStatus, expectedJobId = null) {
  const statuses = Array.isArray(fromStatuses) ? fromStatuses : [fromStatuses];
  return withSqlTransaction(async(client)=>{
    // Serialize every employer-side lifecycle mutation on the job aggregate
    // first. Locking only the application row allowed two different
    // applications for the same job to both reach ACCEPTED and subsequently
    // overwrite jobs.provider_id in turn. The canonical lock order is now
    // job -> application, matching offer acceptance/funding mutations.
    const {rows:jobRows}=await client.query(`SELECT id,owner_id,kind,status FROM jobs WHERE id=(SELECT job_id FROM job_applications WHERE id=$1) FOR UPDATE`,[id]);
    const job=jobRows[0]; if(!job) return null;
    if(expectedJobId && job.id!==expectedJobId){const e=new Error('APPLICATION_JOB_MISMATCH');e.code='APPLICATION_JOB_MISMATCH';throw e;}
    if(job.owner_id!==ownerId){const e=new Error('FORBIDDEN');e.code='FORBIDDEN';throw e;}
    if(job.kind!=='JOB'){const e=new Error('JOB_ONLY');e.code='JOB_ONLY';throw e;}
    const {rows}=await client.query(`SELECT * FROM job_applications WHERE id=$1 FOR UPDATE`,[id]);
    const a=rows[0]; if(!a) return null;
    if(!statuses.includes(a.status)){const e=new Error('INVALID_APPLICATION_STATE');e.code='INVALID_APPLICATION_STATE';throw e;}
    if(toStatus==='ACCEPTED') {
      const {rows:accepted}=await client.query(`SELECT id FROM job_applications WHERE job_id=$1 AND status='ACCEPTED' FOR UPDATE`,[a.job_id]);
      if(accepted[0] && accepted[0].id!==a.id){const e=new Error('CANDIDATE_ALREADY_HIRED');e.code='CANDIDATE_ALREADY_HIRED';throw e;}
    }
    const {rows:updated}=await client.query(`UPDATE job_applications SET status=$2,updated_at=NOW() WHERE id=$1 RETURNING *`,[id,toStatus]);
    if (!updated[0]) return null;
    if (toStatus === 'ACCEPTED') {
      const accepted = updated[0];
      const { rows: jobRows } = await client.query(
        `UPDATE jobs
            SET provider_id=$2,status='ASSIGNED',updated_at=NOW()
          WHERE id=$1 AND owner_id=$3 AND kind='JOB' AND status IN ('PUBLISHED','ASSIGNED')
          RETURNING *`,
        [accepted.job_id, accepted.candidate_id, ownerId],
      );
      if (!jobRows[0]) {
        const e=new Error('JOB_NOT_HIRABLE'); e.code='JOB_NOT_HIRABLE'; throw e;
      }
    }
    return applicationFromRow(updated[0]);
  });
}

