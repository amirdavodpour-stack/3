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
  assert.match(app,/createHumanChatRoutes\(\{\s*authUser,\s*readBody,\s*sendJson,\s*HttpError,\s*repo,\s*storage\s*\}\)/);
});
test('chat attachments belong to the sender and only conversation participants can download them',()=>{
  const repository=read('backend/src/repository/human_chat.js'),routes=read('backend/src/routes/human_chat_routes.js');
  assert.match(repository,/uploaded_by=\$2 FOR UPDATE/);
  assert.match(repository,/canAccessConversation/);
  assert.match(routes,/Cache-Control':'private, no-store'/);
  assert.match(routes,/X-Content-Type-Options':'nosniff'/);
});

test('direct chat uploads normalize known extensions when multipart MIME defaults to octet-stream',()=>{
  const routeSource=read('backend/src/routes/storage_routes.js');
  assert.match(routeSource,/normalizeUploadContentType/);
  assert.match(routeSource,/application\\/octet-stream/);
  assert.match(routeSource,/file\\.contentType = contentType/);
});
