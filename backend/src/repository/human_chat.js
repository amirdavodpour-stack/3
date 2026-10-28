import { requirePool } from './context.js';
import { withSqlTransaction } from '../db.js';
import { canAccessConversation, canSendToConversation, canAttachToChat, normalizeChatMessageType } from '../services/human_chat.js';

const conversationFromRow = (r) => r ? ({
  id:r.id,kind:r.kind,jobId:r.job_id||'',status:r.status,title:r.title||'',
  ownerId:r.owner_id||null,workerId:r.worker_id||null,otherUserName:r.other_user_name||null,
  createdAt:r.created_at?.toISOString?.()??r.created_at??null,
  closedAt:r.closed_at?.toISOString?.()??r.closed_at??null,
  lastMessageBody:r.last_message_body||'',lastMessageType:r.last_message_type||'TEXT',
  lastMessageAt:r.last_message_at?.toISOString?.()??r.last_message_at??null,
  unreadCount:Math.max(0,Number(r.unread_count)||0),
  isPinned:r.is_pinned===true,isImportant:r.is_important===true,isArchived:r.is_archived===true,
}) : null;
const messageFromRow = (r) => ({
  id:r.id,conversationId:r.conversation_id,senderId:r.sender_id,senderName:r.sender_name||'',
  body:r.body,messageType:r.message_type||'TEXT',
  createdAt:r.created_at?.toISOString?.()??r.created_at??null,
  attachments:Array.isArray(r.attachments)?r.attachments:[],
  readReceipts:Array.isArray(r.read_receipts)?r.read_receipts:[],
});
const CHAT_MIME=new Set(['application/pdf','image/png','image/jpeg','image/webp','text/plain','audio/mp4','audio/mpeg','audio/wav']);
const safeFilename=(value)=>String(value||'attachment').replace(/[\u0000-\u001f\u007f]/g,'').split(/[\\/]/).pop().trim().slice(0,255)||'attachment';
async function lockActiveChatAccount(client,userId){
  // Match account deletion's row-lock mode and lock order. The SQL comment is
  // also an observable serialization marker for the PostgreSQL race contract.
  const {rows}=await client.query(
    'SELECT status FROM users WHERE id=$1 /* lockActiveChatAccount */ FOR NO KEY UPDATE',
    [userId],
  );
  if(!rows[0]||rows[0].status!=='ACTIVE'){
    const error=new Error('ACCOUNT_INACTIVE');error.code='ACCOUNT_INACTIVE';throw error;
  }
}

export async function ensureJobChat(jobId) {
  return withSqlTransaction(async(client)=>{
    const {rows:jobs}=await client.query('SELECT id,owner_id,provider_id,title,status FROM jobs WHERE id=$1 FOR UPDATE',[jobId]);
    const job=jobs[0]; if(!job||!job.provider_id)return null;
    if(!['ASSIGNED','FUNDED','IN_PROGRESS','DELIVERED','UNDER_REVIEW','COMPLETED'].includes(job.status))return null;
    const {rows}=await client.query("INSERT INTO chat_conversations(id,kind,job_id,status,title) VALUES(gen_random_uuid(),'JOB',$1,'OPEN',$2) ON CONFLICT(job_id) DO UPDATE SET status=chat_conversations.status,title=EXCLUDED.title RETURNING *",[job.id,job.title||'']);
    return conversationFromRow({...rows[0],owner_id:job.owner_id,worker_id:job.provider_id});
  });
}
export async function closeJobChatForJob(jobId,client=requirePool()){
  const {rowCount}=await client.query("UPDATE chat_conversations SET status='CLOSED',closed_at=COALESCE(closed_at,NOW()) WHERE kind='JOB' AND job_id=$1 AND status='OPEN'",[jobId]);
  return rowCount>0;
}
export async function ensureAdminChat(){
  const {rows}=await requirePool().query("INSERT INTO chat_conversations(id,kind,job_id,status,title) VALUES(gen_random_uuid(),'ADMIN',NULL,'OPEN','HOPE Admin Room') ON CONFLICT DO NOTHING RETURNING *");
  if(rows[0])return conversationFromRow(rows[0]);
  const {rows:existing}=await requirePool().query("SELECT * FROM chat_conversations WHERE kind='ADMIN' LIMIT 1");
  return conversationFromRow(existing[0]);
}
export async function getChatConversationForUser(id,userId,role){
  if(String(role).toUpperCase()==='ADMIN')await ensureAdminChat();
  const {rows}=await requirePool().query(
    'SELECT c.*,j.owner_id,j.provider_id AS worker_id,CASE WHEN j.owner_id=$2 THEN wu.display_name ELSE ou.display_name END AS other_user_name FROM chat_conversations c LEFT JOIN jobs j ON j.id=c.job_id LEFT JOIN users ou ON ou.id=j.owner_id LEFT JOIN users wu ON wu.id=j.provider_id WHERE c.id=$1',
    [id,userId]);
  const c=conversationFromRow(rows[0]); return c&&canAccessConversation(c,userId,role)?c:null;
}
const listQuery=`
  SELECT c.*,j.owner_id,j.provider_id AS worker_id,
    CASE WHEN j.owner_id=$1 THEN wu.display_name ELSE ou.display_name END AS other_user_name,
    lm.body AS last_message_body,lm.message_type AS last_message_type,lm.created_at AS last_message_at,
    COALESCE(unread.unread_count,0)::int AS unread_count,
    COALESCE(pref.is_pinned,FALSE) AS is_pinned,COALESCE(pref.is_important,FALSE) AS is_important,
    COALESCE(pref.is_archived,FALSE) AS is_archived
  FROM chat_conversations c LEFT JOIN jobs j ON j.id=c.job_id
  LEFT JOIN users ou ON ou.id=j.owner_id LEFT JOIN users wu ON wu.id=j.provider_id
  LEFT JOIN LATERAL (SELECT m.body,m.message_type,m.created_at FROM chat_messages m
    WHERE m.conversation_id=c.id ORDER BY m.created_at DESC,m.id DESC LIMIT 1) lm ON TRUE
  LEFT JOIN LATERAL (SELECT COUNT(*) AS unread_count FROM chat_messages m
    WHERE m.conversation_id=c.id AND m.sender_id IS DISTINCT FROM $1
      AND NOT EXISTS(SELECT 1 FROM chat_message_reads r WHERE r.message_id=m.id AND r.user_id=$1)) unread ON TRUE
  LEFT JOIN chat_conversation_preferences pref ON pref.conversation_id=c.id AND pref.user_id=$1
  WHERE (c.kind='JOB' AND (j.owner_id=$1 OR j.provider_id=$1))
     OR (c.kind='ADMIN' AND UPPER($2)='ADMIN')
  ORDER BY COALESCE(pref.is_pinned,FALSE) DESC,COALESCE(pref.is_important,FALSE) DESC,
    c.status ASC,COALESCE(lm.created_at,c.created_at) DESC`;
export async function listChatConversations(userId,role){
  if(String(role).toUpperCase()==='ADMIN')await ensureAdminChat();
  const {rows}=await requirePool().query(listQuery,[userId,role]); return rows.map(conversationFromRow);
}
export async function listChatMessages(conversationId,userId,role,limit=100){
  const conversation=await getChatConversationForUser(conversationId,userId,role); if(!conversation)return null;
  const safeLimit=Math.min(Math.max(Number(limit)||100,1),200);
  const {rows}=await requirePool().query(`
    SELECT m.id,m.conversation_id,m.sender_id,m.body,m.message_type,m.created_at,COALESCE(u.display_name,'') AS sender_name,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('id',a.id,'filename',a.filename,'contentType',a.content_type,'size',a.size,
        'downloadPath','/messaging/attachments/'||a.id||'/content') ORDER BY a.created_at,a.id)
        FROM chat_message_attachments a WHERE a.message_id=m.id),'[]'::jsonb) AS attachments,
      COALESCE((SELECT jsonb_agg(jsonb_build_object('userId',r.user_id,'userName',reader.display_name,'readAt',r.read_at) ORDER BY r.read_at)
        FROM chat_message_reads r JOIN users reader ON reader.id=r.user_id WHERE r.message_id=m.id),'[]'::jsonb) AS read_receipts
    FROM (
      SELECT latest.* FROM chat_messages latest
      WHERE latest.conversation_id=$1
      ORDER BY latest.created_at DESC,latest.id DESC LIMIT $2
    ) m LEFT JOIN users u ON u.id=m.sender_id
    ORDER BY m.created_at ASC,m.id ASC`,[conversationId,safeLimit]);
  return {conversation,messages:rows.map(messageFromRow)};
}
export async function postChatMessage(conversationId,userId,role,body,options={}){
  const conversation=await getChatConversationForUser(conversationId,userId,role);
  if(!conversation||!canSendToConversation(conversation,userId,role)){const e=new Error('CHAT_CLOSED_OR_FORBIDDEN');e.code='CHAT_CLOSED_OR_FORBIDDEN';throw e;}
  const messageType=normalizeChatMessageType(options.messageType||'TEXT');
  const text=String(body??'').trim(),files=Array.isArray(options.attachments)?options.attachments:[];
  if(!messageType||files.length>5||(messageType==='TEXT'&&files.length===0&&!text)){const e=new Error('CHAT_MESSAGE_INVALID');e.code='CHAT_MESSAGE_INVALID';throw e;}
  if(text.length>4000){const e=new Error('MESSAGE_TOO_LONG');e.code='MESSAGE_TOO_LONG';throw e;}
  if(files.some(f=>!f||typeof f.key!=='string'||!f.key.trim())){const e=new Error('CHAT_ATTACHMENTS_INVALID');e.code='CHAT_ATTACHMENTS_INVALID';throw e;}
  const keys=files.map(f=>f.key.trim());
  if(new Set(keys).size!==keys.length){const e=new Error('CHAT_ATTACHMENTS_INVALID');e.code='CHAT_ATTACHMENTS_INVALID';throw e;}
  if(messageType==='VOICE'&&files.length!==1){const e=new Error('CHAT_VOICE_ATTACHMENT_REQUIRED');e.code='CHAT_VOICE_ATTACHMENT_REQUIRED';throw e;}
  if(messageType==='ATTACHMENT'&&files.length===0){const e=new Error('CHAT_ATTACHMENT_REQUIRED');e.code='CHAT_ATTACHMENT_REQUIRED';throw e;}
  if(messageType==='TEXT'&&files.length){const e=new Error('CHAT_ATTACHMENTS_INVALID');e.code='CHAT_ATTACHMENTS_INVALID';throw e;}
  return withSqlTransaction(async(client)=>{
    // Serialize sends against closeJobChatForJob. The outer precheck improves
    // fast rejection, but only this locked read is authoritative: a concurrent
    // close may commit after that precheck and before this transaction starts.
    const {rows: lockedRows}=await client.query(`
      SELECT c.*,j.owner_id,j.provider_id AS worker_id,
        CASE WHEN j.owner_id=$2 THEN wu.display_name ELSE ou.display_name END AS other_user_name
      FROM chat_conversations c
      LEFT JOIN jobs j ON j.id=c.job_id
      LEFT JOIN users ou ON ou.id=j.owner_id
      LEFT JOIN users wu ON wu.id=j.provider_id
      WHERE c.id=$1 AND (
        (c.kind='JOB' AND (j.owner_id=$2 OR j.provider_id=$2))
        OR (c.kind='ADMIN' AND UPPER($3)='ADMIN')
      )
      FOR UPDATE OF c
    `,[conversationId,userId,role]);
    const lockedConversation=conversationFromRow(lockedRows[0]);
    if(!lockedConversation||!canSendToConversation(lockedConversation,userId,role)){
      const e=new Error('CHAT_CLOSED_OR_FORBIDDEN');e.code='CHAT_CLOSED_OR_FORBIDDEN';throw e;
    }

    let uploads=[];
    if(keys.length){
      const {rows}=await client.query('SELECT id,storage_key,uploaded_by,content_type,size FROM uploads WHERE storage_key=ANY($1::text[]) AND uploaded_by=$2 ORDER BY id FOR UPDATE',[keys,userId]);
      if(rows.length!==keys.length){const e=new Error('CHAT_ATTACHMENT_UPLOAD_NOT_FOUND');e.code='CHAT_ATTACHMENT_UPLOAD_NOT_FOUND';throw e;}
      if(rows.some(u=>!CHAT_MIME.has(String(u.content_type).toLowerCase()))){const e=new Error('CHAT_ATTACHMENT_TYPE_UNSUPPORTED');e.code='CHAT_ATTACHMENT_TYPE_UNSUPPORTED';throw e;}
      if(messageType==='VOICE'&&!String(rows[0].content_type).toLowerCase().startsWith('audio/')){const e=new Error('CHAT_VOICE_ATTACHMENT_INVALID');e.code='CHAT_VOICE_ATTACHMENT_INVALID';throw e;}
      if(!canAttachToChat({messageType,contentTypes:rows.map(u=>u.content_type),text})){const e=new Error('CHAT_ATTACHMENT_TYPE_UNSUPPORTED');e.code='CHAT_ATTACHMENT_TYPE_UNSUPPORTED';throw e;}
      const {rows:used}=await client.query('SELECT upload_id FROM chat_message_attachments WHERE upload_id=ANY($1::uuid[])',[rows.map(u=>u.id)]);
      if(used.length){const e=new Error('CHAT_ATTACHMENT_ALREADY_USED');e.code='CHAT_ATTACHMENT_ALREADY_USED';throw e;}
      uploads=rows;
    } else if(!canAttachToChat({messageType,contentTypes:[],text})){const e=new Error('CHAT_MESSAGE_INVALID');e.code='CHAT_MESSAGE_INVALID';throw e;}
    const placeholder=messageType==='VOICE'?'Voice message':messageType==='ATTACHMENT'?(text||'Attachment'):text;
    const {rows:messageRows}=await client.query('INSERT INTO chat_messages(id,conversation_id,sender_id,body,message_type) VALUES(gen_random_uuid(),$1,$2,$3,$4) RETURNING *',[conversationId,userId,placeholder,messageType]);
    const message=messageRows[0],inserted=[];
    for(const upload of uploads){
      const req=files.find(f=>f.key.trim()===upload.storage_key);
      const filename=safeFilename(req?.filename);
      const {rows}=await client.query('INSERT INTO chat_message_attachments(id,message_id,upload_id,storage_key,filename,content_type,size) VALUES(gen_random_uuid(),$1,$2,$3,$4,$5,$6) RETURNING id,filename,content_type,size,created_at',[message.id,upload.id,upload.storage_key,filename,upload.content_type,upload.size]);
      const a=rows[0]; inserted.push({id:a.id,filename:a.filename,contentType:a.content_type,size:a.size,downloadPath:'/messaging/attachments/'+a.id+'/content'});
    }
    const {rows:sender}=await client.query('SELECT display_name FROM users WHERE id=$1',[userId]);
    return messageFromRow({...message,sender_name:sender[0]?.display_name||'',attachments:inserted,read_receipts:[]});
  });
}
export async function markChatConversationRead(conversationId,userId,role){
  return withSqlTransaction(async(client)=>{
    await lockActiveChatAccount(client,userId);
    const conversation=await getChatConversationForUser(conversationId,userId,role);if(!conversation)return null;
    const {rows}=await client.query(`INSERT INTO chat_message_reads(message_id,user_id,read_at)
      SELECT m.id,$2,NOW() FROM chat_messages m WHERE m.conversation_id=$1 AND m.sender_id IS DISTINCT FROM $2
      ON CONFLICT(message_id,user_id) DO NOTHING RETURNING read_at`,[conversationId,userId]);
    const latest=rows.reduce((v,r)=>!v||new Date(r.read_at).getTime()>new Date(v).getTime()?r.read_at:v,null);
    return {conversationId,readCount:rows.length,readAt:latest?.toISOString?.()??latest??new Date().toISOString()};
  });
}
export async function updateChatPresence(conversationId,userId,role,{online=true,typing=false}={}){
  return withSqlTransaction(async(client)=>{
    await lockActiveChatAccount(client,userId);
    const conversation=await getChatConversationForUser(conversationId,userId,role);if(!conversation)return null;
    if(!online){await client.query('DELETE FROM chat_presence WHERE conversation_id=$1 AND user_id=$2',[conversationId,userId]);return {conversationId,userId,online:false,typing:false};}
    const {rows}=await client.query(`INSERT INTO chat_presence(conversation_id,user_id,last_seen_at,typing_until)
      VALUES($1,$2,NOW(),CASE WHEN $3 THEN NOW()+INTERVAL '8 seconds' ELSE NULL END)
      ON CONFLICT(conversation_id,user_id) DO UPDATE SET last_seen_at=EXCLUDED.last_seen_at,typing_until=EXCLUDED.typing_until
      RETURNING last_seen_at,typing_until`,[conversationId,userId,Boolean(typing)]);
    return {conversationId,userId,online:true,typing:Boolean(rows[0]?.typing_until&&new Date(rows[0].typing_until).getTime()>Date.now()),lastSeenAt:rows[0]?.last_seen_at?.toISOString?.()??rows[0]?.last_seen_at??null};
  });
}
export async function listChatPresence(conversationId,userId,role){
  const conversation=await getChatConversationForUser(conversationId,userId,role);if(!conversation)return null;
  const {rows}=await requirePool().query(`SELECT p.user_id,u.display_name,p.last_seen_at,p.typing_until
    FROM chat_presence p LEFT JOIN users u ON u.id=p.user_id
    WHERE p.conversation_id=$1 AND p.user_id<>$2 AND p.last_seen_at>NOW()-INTERVAL '60 seconds' ORDER BY p.last_seen_at DESC`,[conversationId,userId]);
  return rows.map(r=>({userId:r.user_id,userName:r.display_name||'',online:true,typing:Boolean(r.typing_until&&new Date(r.typing_until).getTime()>Date.now()),lastSeenAt:r.last_seen_at?.toISOString?.()??r.last_seen_at??null}));
}
export async function updateChatConversationPreferences(conversationId,userId,role,value={}){
  return withSqlTransaction(async(client)=>{
    await lockActiveChatAccount(client,userId);
    const conversation=await getChatConversationForUser(conversationId,userId,role);if(!conversation)return null;
    const pinned=typeof value.isPinned==='boolean'?value.isPinned:null,important=typeof value.isImportant==='boolean'?value.isImportant:null,archived=typeof value.isArchived==='boolean'?value.isArchived:null;
    const {rows}=await client.query(`INSERT INTO chat_conversation_preferences(conversation_id,user_id,is_pinned,is_important,is_archived)
      VALUES($1,$2,COALESCE($3,FALSE),COALESCE($4,FALSE),COALESCE($5,FALSE))
      ON CONFLICT(conversation_id,user_id) DO UPDATE SET is_pinned=COALESCE($3,chat_conversation_preferences.is_pinned),
        is_important=COALESCE($4,chat_conversation_preferences.is_important),is_archived=COALESCE($5,chat_conversation_preferences.is_archived),updated_at=NOW()
      RETURNING is_pinned,is_important,is_archived,updated_at`,[conversationId,userId,pinned,important,archived]);
    const p=rows[0];return {conversationId,isPinned:p.is_pinned,isImportant:p.is_important,isArchived:p.is_archived,updatedAt:p.updated_at?.toISOString?.()??p.updated_at??null};
  });
}
export async function getChatAttachmentForUser(attachmentId,userId,role){
  const {rows}=await requirePool().query(`SELECT a.id AS attachment_id,a.storage_key,a.filename,a.content_type,a.size,
    c.id AS conversation_id,c.kind,c.job_id,c.status,c.title,c.created_at,c.closed_at,j.owner_id,j.provider_id AS worker_id
    FROM chat_message_attachments a JOIN chat_messages m ON m.id=a.message_id
    JOIN chat_conversations c ON c.id=m.conversation_id LEFT JOIN jobs j ON j.id=c.job_id WHERE a.id=$1`,[attachmentId]);
  const r=rows[0];if(!r||!canAccessConversation({kind:r.kind,status:r.status,ownerId:r.owner_id,workerId:r.worker_id},userId,role))return null;
  return {id:r.attachment_id,storageKey:r.storage_key,filename:r.filename,contentType:r.content_type,size:Number(r.size)||0,conversationId:r.conversation_id};
}
