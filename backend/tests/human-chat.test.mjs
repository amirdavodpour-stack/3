import test from 'node:test';
import assert from 'node:assert/strict';
import { canAccessConversation, canSendToConversation, normalizeChatMessageType, isSupportedChatAttachment, canAttachToChat } from '../src/services/human_chat.js';
import { normalizeUploadContentType } from '../src/routes/storage_routes.js';

test('job chat is accessible only to its owner and assigned worker', () => {
  const c = { kind: 'JOB', status: 'OPEN', ownerId: 'owner', workerId: 'worker' };
  assert.equal(canAccessConversation(c, 'owner', 'USER'), true);
  assert.equal(canAccessConversation(c, 'worker', 'USER'), true);
  assert.equal(canAccessConversation(c, 'other', 'USER'), false);
});

test('admin room is accessible to admins and closed conversations reject sends', () => {
  assert.equal(canAccessConversation({ kind: 'ADMIN', status: 'OPEN' }, 'a1', 'ADMIN'), true);
  assert.equal(canAccessConversation({ kind: 'ADMIN', status: 'OPEN' }, 'u1', 'USER'), false);
  assert.equal(canSendToConversation({ kind: 'JOB', status: 'CLOSED', ownerId: 'o', workerId: 'w' }, 'o', 'USER'), false);
  assert.equal(canSendToConversation({ kind: 'JOB', status: 'OPEN', ownerId: 'o', workerId: 'w' }, 'o', 'USER'), true);
});

test('chat message type normalization rejects unknown types',()=>{
  assert.equal(normalizeChatMessageType(' voice '),'VOICE');
  assert.equal(normalizeChatMessageType('attachment'),'ATTACHMENT');
  assert.equal(normalizeChatMessageType('GIF'),null);
});
test('chat attachment policy accepts supported files and audio voice notes only',()=>{
  assert.equal(isSupportedChatAttachment('application/pdf'),true);
  assert.equal(isSupportedChatAttachment('audio/mp4'),true);
  assert.equal(isSupportedChatAttachment('application/x-msdownload'),false);
  assert.equal(canAttachToChat({messageType:'TEXT',contentTypes:[],text:'hello'}),true);
  assert.equal(canAttachToChat({messageType:'ATTACHMENT',contentTypes:['application/pdf'],text:''}),true);
  assert.equal(canAttachToChat({messageType:'VOICE',contentTypes:['audio/mp4'],text:''}),true);
  assert.equal(canAttachToChat({messageType:'VOICE',contentTypes:['application/pdf'],text:''}),false);
  assert.equal(canAttachToChat({messageType:'VOICE',contentTypes:['audio/mp4','audio/mp4'],text:''}),false);
  assert.equal(canAttachToChat({messageType:'ATTACHMENT',contentTypes:[],text:''}),false);
});


test('direct multipart upload resolves only supported extensions for octet-stream clients', () => {
  assert.equal(normalizeUploadContentType('application/octet-stream','voice.m4a'), 'audio/mp4');
  assert.equal(normalizeUploadContentType('application/octet-stream','voice.mp3'), 'audio/mpeg');
  assert.equal(normalizeUploadContentType('application/octet-stream','brief.pdf'), 'application/pdf');
  assert.equal(normalizeUploadContentType('application/octet-stream','payload.exe'), 'application/octet-stream');
  assert.equal(normalizeUploadContentType('application/pdf','voice.m4a'), 'application/pdf');
});
