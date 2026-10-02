import { requirePool, withSqlTransaction } from './context.js';
import { canAccessConversation, canSendToConversation } from '../services/human_chat.js';

const conversationFromRow = (row) => row ? ({
  id: row.id, kind: row.kind, jobId: row.job_id, status: row.status, title: row.title || '',
  ownerId: row.owner_id || null, workerId: row.worker_id || null, otherUserName: row.other_user_name || null,
  createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
  closedAt: row.closed_at?.toISOString?.() ?? row.closed_at ?? null,
}) : null;

const messageFromRow = (row) => ({
  id: row.id, conversationId: row.conversation_id, senderId: row.sender_id, senderName: row.sender_name || '',
  body: row.body, createdAt: row.created_at?.toISOString?.() ?? row.created_at ?? null,
});

export async function ensureJobChat(jobId) {
  return withSqlTransaction(async (client) => {
    const { rows: jobs } = await client.query('SELECT id,owner_id,provider_id,title,status FROM jobs WHERE id=$1 FOR UPDATE', [jobId]);
    const job = jobs[0];
    if (!job || !job.provider_id) return null;
    if (!['ASSIGNED','FUNDED','IN_PROGRESS','DELIVERED','UNDER_REVIEW','COMPLETED'].includes(job.status)) return null;
    const { rows } = await client.query(
      "INSERT INTO chat_conversations(id,kind,job_id,status,title) VALUES(gen_random_uuid(),'JOB',$1,'OPEN',$2) ON CONFLICT(job_id) DO UPDATE SET status=CASE WHEN chat_conversations.status='CLOSED' THEN 'OPEN' ELSE chat_conversations.status END,title=EXCLUDED.title RETURNING *",
      [job.id, job.title || ''],
    );
    return conversationFromRow({ ...rows[0], owner_id: job.owner_id, worker_id: job.provider_id });
  });
}

export async function closeJobChatForJob(jobId) {
  const { rowCount } = await requirePool().query("UPDATE chat_conversations SET status='CLOSED',closed_at=COALESCE(closed_at,NOW()) WHERE kind='JOB' AND job_id=$1 AND status='OPEN'", [jobId]);
  return rowCount > 0;
}

export async function ensureAdminChat() {
  const { rows } = await requirePool().query("INSERT INTO chat_conversations(id,kind,job_id,status,title) VALUES(gen_random_uuid(),'ADMIN',NULL,'OPEN','HOPE Admin Room') ON CONFLICT DO NOTHING RETURNING *");
  if (rows[0]) return conversationFromRow(rows[0]);
  const { rows: existing } = await requirePool().query("SELECT * FROM chat_conversations WHERE kind='ADMIN' LIMIT 1");
  return conversationFromRow(existing[0]);
}

async function loadConversation(id) {
  const { rows } = await requirePool().query(
    'SELECT c.*,j.owner_id,j.provider_id,CASE WHEN j.owner_id=$2 THEN wu.display_name ELSE ou.display_name END AS other_user_name FROM chat_conversations c LEFT JOIN jobs j ON j.id=c.job_id LEFT JOIN users ou ON ou.id=j.owner_id LEFT JOIN users wu ON wu.id=j.provider_id WHERE c.id=$1',
    [id, '__VIEWER__'],
  );
  return rows[0] || null;
}

export async function getChatConversationForUser(id, userId, role) {
  if (String(role).toUpperCase() === 'ADMIN') await ensureAdminChat();
  const { rows } = await requirePool().query(
    'SELECT c.*,j.owner_id,j.provider_id,CASE WHEN j.owner_id=$2 THEN wu.display_name ELSE ou.display_name END AS other_user_name FROM chat_conversations c LEFT JOIN jobs j ON j.id=c.job_id LEFT JOIN users ou ON ou.id=j.owner_id LEFT JOIN users wu ON wu.id=j.provider_id WHERE c.id=$1',
    [id, userId],
  );
  const c = conversationFromRow(rows[0]);
  return c && canAccessConversation(c, userId, role) ? c : null;
}

export async function listChatConversations(userId, role) {
  const { rows: jobRows } = await requirePool().query(
    'SELECT c.*,j.owner_id,j.provider_id,CASE WHEN j.owner_id=$1 THEN wu.display_name ELSE ou.display_name END AS other_user_name FROM chat_conversations c JOIN jobs j ON j.id=c.job_id LEFT JOIN users ou ON ou.id=j.owner_id LEFT JOIN users wu ON wu.id=j.provider_id WHERE c.kind=\'JOB\' AND (j.owner_id=$1 OR j.provider_id=$1) ORDER BY c.status ASC,c.created_at DESC',
    [userId],
  );
  const jobs = jobRows.map(conversationFromRow);
  if (String(role).toUpperCase() !== 'ADMIN') return jobs;
  const admin = await ensureAdminChat();
  return [admin, ...jobs];
}

export async function listChatMessages(conversationId, userId, role, limit = 100) {
  const conversation = await getChatConversationForUser(conversationId, userId, role);
  if (!conversation) return null;
  const safeLimit = Math.min(Math.max(Number(limit) || 100, 1), 200);
  const { rows } = await requirePool().query(
    'SELECT m.id,m.conversation_id,m.sender_id,m.body,m.created_at,u.display_name AS sender_name FROM chat_messages m JOIN users u ON u.id=m.sender_id WHERE m.conversation_id=$1 ORDER BY m.created_at ASC,m.id ASC LIMIT $2',
    [conversationId, safeLimit],
  );
  return { conversation, messages: rows.map(messageFromRow) };
}

export async function postChatMessage(conversationId, userId, role, body) {
  const conversation = await getChatConversationForUser(conversationId, userId, role);
  if (!conversation || !canSendToConversation(conversation, userId, role)) {
    const error = new Error('CHAT_CLOSED_OR_FORBIDDEN'); error.code = 'CHAT_CLOSED_OR_FORBIDDEN'; throw error;
  }
  const { rows } = await requirePool().query('INSERT INTO chat_messages(id,conversation_id,sender_id,body) VALUES(gen_random_uuid(),$1,$2,$3) RETURNING *', [conversationId, userId, body]);
  const { rows: sender } = await requirePool().query('SELECT display_name FROM users WHERE id=$1', [userId]);
  return messageFromRow({ ...rows[0], sender_name: sender[0]?.display_name || '' });
}