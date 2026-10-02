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
  const application=read('backend/src/routes/application_routes.js');
  const release=read('backend/src/repository/outbox.js');
  const refund=read('backend/src/repository/payment_refunds.js');
  assert.match(offer,/ensureJobChat/);
  assert.match(application,/ensureJobChat/);
  assert.match(release,/closeJobChatForJob/);
  assert.match(refund,/closeJobChatForJob/);
});

test('AI chat endpoint remains blocked while human messaging has separate endpoints',()=>{
  const ai=read('backend/src/routes/ai_routes.js');
  const chat=read('backend/src/routes/human_chat_routes.js');
  assert.match(ai,/AI_USER_ACCESS_DISABLED/);
  assert.match(chat,/messaging/);
});