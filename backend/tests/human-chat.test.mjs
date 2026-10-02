import test from 'node:test';
import assert from 'node:assert/strict';
import { canAccessConversation, canSendToConversation } from '../src/services/human_chat.js';

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