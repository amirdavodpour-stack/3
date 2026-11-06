import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { jobFromRow, applicationFromRow, userFromRow } from './mappers.js';

const userSelect = `id,email,password_hash,password_hash AS "passwordHash",display_name AS "displayName",role,status,session_version,created_at AS "createdAt",google_subject AS "googleSubject"`;

export async function getAdminSummary() {
  const p = requirePool();
  const { rows } = await p.query(`
    SELECT
      (SELECT COUNT(*) FROM users)::int AS users,
      (SELECT COUNT(*) FROM users WHERE role='ADMIN')::int AS admins,
      (SELECT COUNT(*) FROM users WHERE role='USER' AND status='ACTIVE')::int AS active_users,
      (SELECT COUNT(*) FROM users WHERE status<>'ACTIVE')::int AS suspended_users,
      (SELECT COUNT(*) FROM jobs)::int AS opportunities,
      (SELECT COUNT(*) FROM jobs WHERE status='PUBLISHED')::int AS published_opportunities,
      (SELECT COUNT(*) FROM jobs WHERE status='DRAFT')::int AS draft_opportunities,
      (SELECT COUNT(*) FROM jobs WHERE kind='MISSION')::int AS missions,
      (SELECT COUNT(*) FROM jobs WHERE kind='JOB')::int AS jobs,
      (SELECT COUNT(*) FROM job_applications)::int AS applications,
      (SELECT COUNT(*) FROM job_applications WHERE status IN ('PENDING','SHORTLISTED'))::int AS pending_applications,
      (SELECT COUNT(*) FROM audit_logs)::int AS audit_events
  `);
  return rows[0] ? Object.fromEntries(Object.entries(rows[0]).map(([k,v])=>[k,Number(v||0)])) : {};
}

export async function listAdminUsers(limit=100, offset=0) {
  const { rows } = await requirePool().query(`
    SELECT u.id,u.email,u.password_hash,
           u.password_hash AS "passwordHash",
           u.display_name AS "displayName",
           u.role,u.status,u.session_version,
           u.created_at AS "createdAt",
           u.google_subject AS "googleSubject",
           r.id AS "statusReviewCaseId",
           r.reason AS "statusReviewReason",
           r.review_due_at AS "statusReviewDueAt"
      FROM users u
      LEFT JOIN LATERAL (
        SELECT id,reason,review_due_at
          FROM admin_user_status_review_cases
         WHERE user_id=u.id AND status='OPEN'
         ORDER BY created_at DESC,id DESC
         LIMIT 1
      ) r ON TRUE
     ORDER BY u.created_at DESC,u.id DESC
     LIMIT $1 OFFSET $2
  `, [Math.min(Math.max(Number(limit)||100,1),200), Math.max(Number(offset)||0,0)]);
  return rows.map((row) => ({
    ...userFromRow(row),
    statusReviewCaseId: row.statusReviewCaseId || null,
    statusReviewReason: row.statusReviewReason || null,
    statusReviewDueAt: row.statusReviewDueAt?.toISOString?.() ?? row.statusReviewDueAt ?? null,
  }));
}
export async function getAdminUser(id) {
  const { rows } = await requirePool().query(`SELECT ${userSelect} FROM users WHERE id=$1`, [id]);
  return rows[0] ? userFromRow(rows[0]) : null;
}
export async function setUserStatus(id,status,{actorId,reason,reviewDueAt}={}) {
  const targetStatus=String(status || '').trim().toUpperCase();
  if(!['ACTIVE','SUSPENDED'].includes(targetStatus)) {
    const error=new Error('INVALID_STATUS'); error.code='INVALID_STATUS'; error.status=400; throw error;
  }
  const why=String(reason || '').trim();
  if(why.length<3 || why.length>1000) {
    const error=new Error('ADMIN_USER_STATUS_REASON_REQUIRED'); error.code='ADMIN_USER_STATUS_REASON_REQUIRED'; error.status=400; throw error;
  }
  let due=null;
  if(targetStatus==='SUSPENDED') {
    due=new Date(reviewDueAt);
    const delta=due.getTime()-Date.now();
    if(!Number.isFinite(due.getTime()) || delta<60*60*1000 || delta>7*24*60*60*1000) {
      const error=new Error('INVALID_REVIEW_DEADLINE'); error.code='INVALID_REVIEW_DEADLINE'; error.status=400; throw error;
    }
  }
  const actor=String(actorId || '').trim();
  if(!actor) {
    const error=new Error('ADMIN_ACTOR_REQUIRED'); error.code='ADMIN_ACTOR_REQUIRED'; error.status=401; throw error;
  }

  return withSqlTransaction(async (client) => {
    const { rows: actors } = await client.query(
      `SELECT id,role,status FROM users WHERE id=$1 FOR UPDATE`,
      [actor],
    );
    if(!actors[0] || actors[0].role!=='ADMIN' || actors[0].status!=='ACTIVE') {
      const error=new Error('ADMIN_REQUIRED'); error.code='ADMIN_REQUIRED'; error.status=403; throw error;
    }
    if(actor===String(id) && targetStatus==='SUSPENDED') {
      const error=new Error('SELF_SUSPEND_FORBIDDEN'); error.code='SELF_SUSPEND_FORBIDDEN'; error.status=400; throw error;
    }

    const { rows: current } = await client.query(
      `SELECT id,email,role,status FROM users WHERE id=$1 FOR UPDATE`,
      [id],
    );
    if (!current[0]) return null;
    if (current[0].status === 'DELETED') {
      const error = new Error('ACCOUNT_DELETION_TERMINAL');
      error.code = 'ACCOUNT_DELETION_TERMINAL';
      error.status = 409;
      throw error;
    }
    if(current[0].status===targetStatus) {
      const error=new Error('USER_STATUS_UNCHANGED'); error.code='USER_STATUS_UNCHANGED'; error.status=409; throw error;
    }

    const { rows } = await client.query(
      `UPDATE users
          SET status=$2,
              session_version=session_version+1,
              admin_panel_verified_at=NULL,
              admin_panel_verified_session_jti=NULL,
              admin_panel_verified_scope=NULL
        WHERE id=$1 AND status <> 'DELETED'
        RETURNING ${userSelect}`,
      [id,targetStatus],
    );
    if (!rows[0]) return null;
    await client.query(
      `UPDATE refresh_tokens SET revoked_at=COALESCE(revoked_at,NOW()) WHERE user_id=$1 AND revoked_at IS NULL`,
      [id],
    );

    let reviewCaseId=null;
    let reviewDeadline=null;
    if(targetStatus==='SUSPENDED') {
      const { rows: cases } = await client.query(
        `INSERT INTO admin_user_status_review_cases(
           id,user_id,status,reason,created_by,created_at,review_due_at
         ) VALUES(gen_random_uuid(),$1,'OPEN',$2,$3,NOW(),$4)
         RETURNING id,review_due_at`,
        [id,why,actor,due],
      );
      reviewCaseId=cases[0].id;
      reviewDeadline=cases[0].review_due_at?.toISOString?.() ?? cases[0].review_due_at;
    } else {
      const { rows: cases } = await client.query(
        `UPDATE admin_user_status_review_cases
            SET status='RESOLVED',resolved_by=$2,resolved_at=NOW(),resolution_reason=$3
          WHERE user_id=$1 AND status='OPEN'
          RETURNING id`,
        [id,actor,why],
      );
      reviewCaseId=cases[0]?.id || null;
    }

    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),'ADMIN_USER_STATUS',$1,'user',$2,$3::jsonb,NOW())`,
      [actor,id,JSON.stringify({
        status:targetStatus,
        reason:why,
        reviewCaseId,
        reviewDueAt:reviewDeadline,
        manualReviewRequired:targetStatus==='SUSPENDED',
        reviewAction:targetStatus==='SUSPENDED'?'OPENED':'HUMAN_RESOLUTION',
      })],
    );
    return {
      ...userFromRow(rows[0]),
      reviewCaseId,
      reviewDueAt:reviewDeadline,
    };
  });
}
export async function revokeAdminById(id, actorId) {
  return withSqlTransaction(async (client) => {
    const { rows: actors } = await client.query(`SELECT id,email,role,google_subject FROM users WHERE id=$1 FOR UPDATE`, [actorId]);
    if (!actors[0] || actors[0].role !== 'ADMIN' || String(actors[0].email || '').trim().toLowerCase() !== 'amir.davodpour@gmail.com' || !String(actors[0].google_subject || '').trim()) {
      const error = new Error('PRIMARY_ADMIN_ONLY'); error.code='PRIMARY_ADMIN_ONLY'; error.status=403; throw error;
    }
    const { rows } = await client.query(`SELECT ${userSelect} FROM users WHERE id=$1 FOR UPDATE`, [id]);
    if (!rows[0]) return null;
    if (String(rows[0].email || '').trim().toLowerCase() === 'amir.davodpour@gmail.com') {
      const error = new Error('PRIMARY_ADMIN_PROTECTED'); error.code='PRIMARY_ADMIN_PROTECTED'; error.status=403; throw error;
    }
    if (String(rows[0].role || '').toUpperCase() !== 'ADMIN') {
      const error = new Error('NOT_AN_ADMIN'); error.code='NOT_AN_ADMIN'; error.status=409; throw error;
    }
    const { rows: updated } = await client.query(`UPDATE users SET role='USER', session_version=session_version+1, admin_panel_verified_at=NULL,admin_panel_verified_session_jti=NULL WHERE id=$1 RETURNING ${userSelect}`, [id]);
    await client.query(`UPDATE refresh_tokens SET revoked_at=COALESCE(revoked_at,NOW()) WHERE user_id=$1 AND revoked_at IS NULL`, [id]);
    return updated[0] ? userFromRow(updated[0]) : null;
  });
}
export async function revokeUserSessions(id) {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`UPDATE users SET session_version=session_version+1,admin_panel_verified_at=NULL,admin_panel_verified_session_jti=NULL WHERE id=$1 RETURNING id,session_version`, [id]);
    if (!rows[0]) return null;
    await client.query(`UPDATE refresh_tokens SET revoked_at=COALESCE(revoked_at,NOW()) WHERE user_id=$1 AND revoked_at IS NULL`, [id]);
    return { id: rows[0].id, sessionVersion: Number(rows[0].session_version) };
  });
}
export async function listAdminAudit(limit=100, offset=0) {
  const { rows } = await requirePool().query(`SELECT a.id,a.action,a.actor_id,a.entity_type,a.entity_id,a.meta,a.created_at,u.display_name AS actor_name FROM audit_logs a LEFT JOIN users u ON u.id=a.actor_id ORDER BY a.created_at DESC LIMIT $1 OFFSET $2`, [Math.min(Math.max(Number(limit)||100,1),200), Math.max(Number(offset)||0,0)]);
  return rows.map(r=>({id:r.id,action:r.action,actorId:r.actor_id,actorName:r.actor_name||null,entityType:r.entity_type,entityId:r.entity_id,meta:r.meta||{},createdAt:r.created_at?.toISOString?.() ?? r.created_at}));
}
export async function moderateJob(id,toStatus) {
  const allowed = new Set(['DRAFT','PUBLISHED','CANCELLED']);
  if (!allowed.has(toStatus)) { const e=new Error('INVALID_STATUS'); e.code='INVALID_STATUS'; throw e; }
  return withSqlTransaction(async(client)=>{
    const {rows}=await client.query(`SELECT * FROM jobs WHERE id=$1 FOR UPDATE`,[id]);
    if(!rows[0]) return null;
    const job=jobFromRow(rows[0]);
    if(['COMPLETED','ASSIGNED','FUNDED','IN_PROGRESS','DELIVERED','UNDER_REVIEW'].includes(job.status)) { const e=new Error('JOB_LOCKED'); e.code='JOB_LOCKED'; throw e; }
    const {rows:u}=await client.query(`UPDATE jobs SET status=$2,updated_at=NOW(),published_at=CASE WHEN $2='PUBLISHED' THEN COALESCE(published_at,NOW()) ELSE published_at END WHERE id=$1 RETURNING *`,[id,toStatus]);
    return jobFromRow(u[0]);
  });
}

export async function listAdminJobs() { const {rows}=await requirePool().query(`SELECT * FROM jobs ORDER BY created_at DESC`); return rows.map(jobFromRow); }
export async function deleteJob(id) {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`SELECT id,status FROM jobs WHERE id=$1 FOR UPDATE`, [id]);
    if (!rows[0]) return null;
    if (!['DRAFT','PUBLISHED'].includes(rows[0].status)) { const e=new Error('JOB_LOCKED'); e.code='JOB_LOCKED'; throw e; }
    const { rows: financial } = await client.query(`SELECT COUNT(*)::int AS count FROM payments WHERE job_id=$1`, [id]);
    if (Number(financial[0]?.count || 0) > 0) { const e=new Error('JOB_HAS_FINANCIAL_RECORDS'); e.code='JOB_HAS_FINANCIAL_RECORDS'; throw e; }
    const { rowCount } = await client.query(`DELETE FROM jobs WHERE id=$1`, [id]);
    return rowCount > 0;
  });
}


export async function grantAdminByEmail(email, actorId) {
  return withSqlTransaction(async (client) => {
    const { rows: actors } = await client.query(`SELECT id,email,role,google_subject FROM users WHERE id=$1 FOR UPDATE`, [actorId]);
    if (!actors[0] || actors[0].role !== 'ADMIN' || String(actors[0].email || '').trim().toLowerCase() !== 'amir.davodpour@gmail.com' || !String(actors[0].google_subject || '').trim()) {
      const error = new Error('PRIMARY_ADMIN_ONLY');
      error.code = 'PRIMARY_ADMIN_ONLY';
      throw error;
    }
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const { rows } = await client.query(`SELECT ${userSelect} FROM users WHERE LOWER(email)=LOWER($1) FOR UPDATE`, [normalizedEmail]);
    if (!rows[0]) return null;
    if (String(rows[0].role || '').toUpperCase() === 'ADMIN') return userFromRow(rows[0]);
    const { rows: updated } = await client.query(`UPDATE users SET role='ADMIN', session_version=session_version+1, admin_panel_verified_at=NULL,admin_panel_verified_session_jti=NULL WHERE id=$1 RETURNING ${userSelect}`, [rows[0].id]);
    return updated[0] ? userFromRow(updated[0]) : null;
  });
}