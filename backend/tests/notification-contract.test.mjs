import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const db=fs.readFileSync(new URL('../src/db.js',import.meta.url),'utf8');
const schema=fs.readFileSync(new URL('../src/db/schema.js',import.meta.url),'utf8');
const repo=fs.readFileSync(new URL('../src/repository.js',import.meta.url),'utf8');
const notificationsRepo=fs.readFileSync(new URL('../src/repository/notifications.js',import.meta.url),'utf8');
const worker=fs.readFileSync(new URL('../src/outbox_worker.js',import.meta.url),'utf8');
const handlers=fs.readFileSync(new URL('../src/outbox_handlers.js',import.meta.url),'utf8');
const app=fs.readFileSync(new URL('../src/app.js',import.meta.url),'utf8');
const notificationRoutes=fs.readFileSync(new URL('../src/routes/notification_routes.js',import.meta.url),'utf8');
const mobile=fs.readFileSync(new URL('../../lib/features/notifications/notifications_page.dart',import.meta.url),'utf8');
const notificationRepo=fs.readFileSync(new URL('../../lib/core/notifications/notification_repository.dart',import.meta.url),'utf8');
const notificationModel=fs.readFileSync(new URL('../../lib/core/notifications/notification.dart',import.meta.url),'utf8');
const privacyRepo=fs.readFileSync(new URL('../src/repository/privacy.js',import.meta.url),'utf8');

test('notification persistence has user isolation and preference defaults',()=>{
  assert.match(schema,/CREATE TABLE IF NOT EXISTS notifications/);
  assert.match(schema,/CREATE TABLE IF NOT EXISTS notification_preferences/);
  assert.match(schema,/CREATE TABLE IF NOT EXISTS notification_devices/);
  assert.match(notificationsRepo,/export async function queueNotification/);
  assert.match(notificationsRepo,/NOTIFICATION_DISPATCH/);
});

test('notification worker supports in-app delivery and configured push/email webhooks',()=>{
  assert.match(handlers,/event\.event_type === 'NOTIFICATION_DISPATCH'/);
  assert.match(handlers,/notificationPushUrl/);
  assert.match(handlers,/notificationEmailUrl/);
});

test('notification HTTP surface exposes read, preferences and device registration',()=>{
  assert.match(app,/parts\[0\] === 'notifications'/);
  assert.match(app,/createNotificationRoutes/);
  assert.match(notificationRoutes,/read-all/);
  assert.match(notificationRoutes,/preferences/);
  assert.match(notificationRoutes,/devices/);
});

test('mobile notifications are repository-backed and typed',()=>{
  assert.match(mobile,/ApplicationRegistry/);
  assert.match(mobile,/listNotifications/);
  assert.match(mobile,/markNotificationRead/);
  assert.match(mobile,/markAllNotificationsRead/);
  assert.doesNotMatch(mobile,/ApiClient/);
  assert.doesNotMatch(mobile,/read-all/);
  assert.match(notificationRepo,/abstract interface class NotificationRepository/);
  assert.match(notificationRepo,/markAllRead/);
  assert.match(notificationModel,/class HopeNotification/);
  assert.match(notificationModel,/class HopeNotificationPreferences/);
  assert.match(notificationModel,/final Map<String, dynamic> data/);
  assert.match(notificationModel,/bool get hasAction/);
  assert.match(mobile,/openNotification/);
  assert.match(mobile,/HopeRoutes\.jobDetail/);
  assert.match(mobile,/HopeRoutes\.transaction/);
  assert.match(mobile,/TransactionRepository/);
  assert.match(mobile,/UploadQueue/);
  assert.match(notificationRepo,/getPreferences/);
  assert.match(notificationRepo,/updatePreferences/);
  assert.match(mobile,/loadNotificationPreferences/);
  assert.match(mobile,/updateNotificationPreferences/);
});


const privacyRepo=fs.readFileSync(new URL('../src/repository/privacy.js',import.meta.url),'utf8');
const applicationsRepo=fs.readFileSync(new URL('../src/repository/applications.js',import.meta.url),'utf8');
const outboxRepo=fs.readFileSync(new URL('../src/repository/outbox.js',import.meta.url),'utf8');
const cancellationMigration=fs.readFileSync(new URL('../src/db/migrations/054_outbox_notification_cancellation.js',import.meta.url),'utf8');

test('notification Outbox dispatch uses explicit cancellation and an account-erasure recipient barrier',()=>{
  assert.match(notificationsRepo,/export async function dispatchNotificationOutbox/);
  assert.match(handlers,/dispatchNotificationOutbox/);
  assert.match(privacyRepo,/NOTIFICATION_OUTBOX_CANCELLED_ACCOUNT_ERASURE/);
  assert.match(notificationsRepo,/SELECT id,status FROM users WHERE id=\$1 FOR SHARE/);
  assert.match(notificationsRepo,/RECIPIENT_UNAVAILABLE/);
  assert.match(applicationsRepo,/SELECT id,status FROM users WHERE id=\$1 FOR SHARE/);
  assert.ok(applicationsRepo.indexOf('FOR SHARE') < applicationsRepo.indexOf('FOR UPDATE'));
  assert.match(cancellationMigration,/CANCELLED/);
  assert.match(outboxRepo,/currentStatus === 'CANCELLED'.*alreadyCancelled/s);
});


test('new notification Outbox events use a content-free v2 payload and dispatch reads canonical database content',()=>{
  const producerStart=notificationsRepo.indexOf('export async function queueNotificationWithClient(');
  const producer=notificationsRepo.slice(producerStart);
  assert.match(producer,/const eventPayload = \{\s*schemaVersion:\s*2,\s*channel\s*\}/s);
  assert.match(producer,/JSON\.stringify\(eventPayload\)/);

  const dispatchStart=notificationsRepo.indexOf('export async function dispatchNotificationOutbox(');
  const dispatch=notificationsRepo.slice(dispatchStart);
  assert.match(dispatch,/SELECT id,user_id,type,title,body,data\s+FROM notifications/);
  assert.match(dispatch,/await deliverTargets\(\{[^}]*notificationId, userId, notification/s);

  const notificationHandlerStart=handlers.indexOf("} else if (event.event_type === 'NOTIFICATION_DISPATCH')");
  const notificationHandler=handlers.slice(notificationHandlerStart);
  assert.match(notificationHandler,/notification\.title/);
  assert.match(notificationHandler,/notification\.body/);
  assert.match(notificationHandler,/notification\.data/);
  assert.doesNotMatch(notificationHandler,/payload\.(title|body|data|userId|notificationId)/);
});


test('account erasure identifies notification Outbox rows through canonical aggregate identity',()=>{
  const deletion=privacyRepo.slice(privacyRepo.indexOf('export async function deleteUserPrivacyBundle'));
  assert.match(deletion,/EXISTS\\s*\\(\\s*SELECT 1 FROM notifications n\\s+WHERE n\\.id=outbox_events\\.aggregate_id\\s+AND n\\.user_id=\\$1/s);
  assert.doesNotMatch(deletion,/payload->>'userId'/);
});
