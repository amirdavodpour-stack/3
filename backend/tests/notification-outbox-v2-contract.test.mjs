import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const notificationsRepo = fs.readFileSync(new URL('../src/repository/notifications.js', import.meta.url), 'utf8');
const privacyRepo = fs.readFileSync(new URL('../src/repository/privacy.js', import.meta.url), 'utf8');
const handlers = fs.readFileSync(new URL('../src/outbox_handlers.js', import.meta.url), 'utf8');

test('new notification Outbox payloads are versioned references and contain no recipient or message content', () => {
  const producerStart = notificationsRepo.indexOf('export async function queueNotificationWithClient(');
  const producerEnd = notificationsRepo.indexOf('export async function queueNotification(', producerStart);
  assert.ok(producerStart >= 0 && producerEnd > producerStart, 'notification producer must be present');
  const producer = notificationsRepo.slice(producerStart, producerEnd);
  const payloadMatch = producer.match(/const outboxPayload\s*=\s*\{([^}]+)\}/);
  assert.ok(payloadMatch, 'producer must build one explicit v2 Outbox payload');
  assert.match(payloadMatch[1], /schemaVersion\s*:\s*2/);
  assert.match(payloadMatch[1], /channel/);
  assert.doesNotMatch(payloadMatch[1], /\b(userId|notificationId|type|title|body|data)\b/);
  assert.match(producer, /JSON\.stringify\(outboxPayload\)/);
});

test('notification dispatcher resolves v2 recipient and message from database while preserving legacy v1 support', () => {
  const dispatchStart = notificationsRepo.indexOf('export async function dispatchNotificationOutbox(');
  const dispatchEnd = notificationsRepo.indexOf('export async function disableNotificationDevice(', dispatchStart);
  assert.ok(dispatchStart >= 0 && dispatchEnd > dispatchStart, 'notification dispatcher must be present');
  const dispatch = notificationsRepo.slice(dispatchStart, dispatchEnd);
  assert.match(dispatch, /schemaVersion/);
  assert.match(dispatch, /FROM notifications/);
  assert.match(dispatch, /FOR SHARE/);
  assert.match(dispatch, /FOR KEY SHARE/);
  assert.match(dispatch, /payload\.userId/);
  assert.match(dispatch, /payload\.notificationId/);
  assert.match(dispatch, /notification:/);
  assert.match(dispatch, /deliveryData/);
});

test('account erasure cancels notification Outbox by notification ownership, not by content-bearing payload fields', () => {
  const deleteStart = privacyRepo.indexOf('export async function deleteUserPrivacyBundle(');
  const cancelStart = privacyRepo.indexOf('UPDATE outbox_events', deleteStart);
  const cancelEnd = privacyRepo.indexOf('[userId]', cancelStart);
  assert.ok(deleteStart >= 0 && cancelStart > deleteStart && cancelEnd > cancelStart,
    'account erasure must include a notification Outbox cancellation query');
  const cancellation = privacyRepo.slice(cancelStart, cancelEnd);
  assert.match(cancellation, /FROM notifications/);
  assert.match(cancellation, /aggregate_id/);
  assert.match(cancellation, /user_id\s*=\s*\$1/);
  assert.doesNotMatch(cancellation, /payload->>'userId'/);
});

test('notification provider adapter uses database-loaded content for both payload versions', () => {
  const handlerStart = handlers.indexOf("} else if (event.event_type === 'NOTIFICATION_DISPATCH') {");
  assert.ok(handlerStart >= 0, 'notification handler branch must be present');
  const branch = handlers.slice(handlerStart);
  assert.match(branch, /notification\.title/);
  assert.match(branch, /notification\.body/);
  assert.match(branch, /notification\.data/);
  assert.doesNotMatch(branch, /payload\.(?:userId|notificationId|title|body|data)/);
});
