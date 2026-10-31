import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');

test('human messaging wiring separates human chat from AI chat',()=>{
  const app=read('backend/src/app.js');
  assert.match(app,/createHumanChatRoutes/);
  assert.match(app,/parts\[0\] === 'messaging'/);
});

test('job chat is provisioned on agreement and closed with financial settlement',()=>{
  const offer=read('backend/src/routes/offer_routes.js');
  const handlers=read('backend/src/routes/job_handlers.js');
  const release=read('backend/src/repository/outbox.js');
  const refund=read('backend/src/repository/payment_refunds.js');
  assert.match(offer,/ensureJobChat/);
  assert.match(handlers,/ensureJobChat/);
  assert.match(release,/closeJobChatForJob/);
  assert.match(refund,/closeJobChatForJob/);
});

test('AI chat endpoint remains blocked while human messaging has separate endpoints',()=>{
  const ai=read('backend/src/routes/ai_routes.js');
  const chat=read('backend/src/routes/human_chat_routes.js');
  assert.match(ai,/assertAutomatedAiAccess/);
  assert.match(ai,/source:\s*['"]USER['"]/);
  assert.match(chat,/messaging/);
});

test('chat capabilities route read receipts, private presence, preferences and guarded attachment streams',()=>{
  const routes=read('backend/src/routes/human_chat_routes.js'), repository=read('backend/src/repository/human_chat.js');
  const migration=read('backend/src/db/migrations/034_chat_capabilities.js'), app=read('backend/src/app.js');
  assert.match(routes,/parts\[3\]\s*===\s*'read'/);
  assert.match(routes,/parts\[3\]\s*===\s*'presence'/);
  assert.match(routes,/parts\[3\]\s*===\s*'preferences'/);
  assert.match(repository,/markChatConversationRead/);
  assert.match(repository,/updateChatPresence/);
  assert.match(repository,/getChatAttachmentForUser/);
  assert.match(repository,/text\|\|'Attachment'/);
  assert.match(migration,/chat_message_reads/);
  assert.match(migration,/chat_presence/);
  assert.match(migration,/chat_conversation_preferences/);
  assert.match(app,/createHumanChatRoutes\(\{\s*authUser,\s*readBody,\s*sendJson,\s*HttpError,\s*repo,\s*storage,\s*config\s*\}\)/);
  assert.match(routes,/requireAdmin\(me\)/);
  assert.match(routes,/assertAdminPermission\(admin,ADMIN_PERMISSIONS\.VIEW_ADMIN_CENTER\)/);
  assert.match(routes,/isAdminPanelVerified\(admin\.id/);
});
test('chat attachments belong to the sender and only conversation participants can download them',()=>{
  const repository=read('backend/src/repository/human_chat.js'),routes=read('backend/src/routes/human_chat_routes.js');
  assert.match(repository,/uploaded_by=\$2 ORDER BY id FOR UPDATE/);
  assert.match(repository,/canAccessConversation/);
  assert.match(routes,/Cache-Control':'private, no-store'/);
  assert.match(routes,/X-Content-Type-Options':'nosniff'/);
});

test('chat attachment objects are excluded from ordinary user-upload cleanup',()=>{
  const uploadRepository=read('backend/src/repository/storage.js');
  assert.match(uploadRepository,/chat_message_attachments a WHERE a\.upload_id=u\.id/);
});

test('OpenAPI documents every implemented human messaging endpoint and capability schema',()=>{
  const contract=read('backend/openapi/openapi.yaml');
  for(const marker of [
    '  /messaging/conversations:',
    '  /messaging/conversations/{conversationId}:',
    '  /messaging/conversations/{conversationId}/read:',
    '  /messaging/conversations/{conversationId}/presence:',
    '  /messaging/conversations/{conversationId}/preferences:',
    '  /messaging/attachments/{attachmentId}/content:',
    '    ChatConversation:',
    '    ChatMessage:',
    '    ChatAttachment:',
    '    ChatReadReceipt:',
    '    ChatPresence:',
    '    ChatPresenceUpdate:',
    '    ChatConversationPreferences:',
    '    ChatUpload:',
    'multipart/form-data:',
    'format: binary',
    'audio/mp4',
    'audio/mpeg',
    'audio/wav',
  ]) assert.ok(contract.includes(marker),marker);
  assert.match(contract,/\/messaging\/attachments\/\{attachmentId\}\/content:[\s\S]*?security:\s*\[\{bearerAuth:\s*\[\]\}\]/);
  assert.match(contract,/\/messaging\/conversations:[\s\S]*?required:\s*\[data\][\s\S]*?items:/);
  assert.match(contract,/\/messaging\/conversations\/\{conversationId\}\/read:[\s\S]*?required:\s*\[data\][\s\S]*?readCount:/);
});

test('direct chat uploads normalize known extensions when multipart MIME defaults to octet-stream',()=>{
  const routeSource=read('backend/src/routes/storage_routes.js');
  assert.ok(routeSource.includes('normalizeUploadContentType'));
  assert.ok(routeSource.includes('application/octet-stream'));
  assert.ok(routeSource.includes('file.contentType = contentType'));
});

test('chat message history returns the newest bounded window in chronological display order',()=>{
  const repository=read('backend/src/repository/human_chat.js');
  assert.match(repository,/SELECT latest\.\* FROM chat_messages latest[\s\S]*?WHERE latest\.conversation_id=\$1[\s\S]*?ORDER BY latest\.created_at DESC,latest\.id DESC LIMIT \$2/);
  assert.match(repository,/\) m LEFT JOIN users u ON u\.id=m\.sender_id[\s\S]*?ORDER BY m\.created_at ASC,m\.id ASC/);
});
