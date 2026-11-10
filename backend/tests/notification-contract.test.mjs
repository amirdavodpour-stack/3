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


test('new notification Outbox events use content-free v2 payloads',()=>{
  const start=notificationsRepo.indexOf('export async function queueNotificationWithClient(');
  const end=notificationsRepo.indexOf('\nexport async function queueNotification(',start);
  assert.ok(start>=0&&end>start,'notification producer must exist');
  const producer=notificationsRepo.slice(start,end);
  assert.match(producer,/schemaVersion\s*:\s*2/);
  assert.match(producer,/JSON\.stringify\(outboxPayload\)/);
  const payloadStart=producer.indexOf('const outboxPayload');
  const payloadEnd=producer.indexOf(';',payloadStart);
  assert.ok(payloadStart>=0&&payloadEnd>payloadStart,'producer must build an explicit v2 payload');
  const payloadBuilder=producer.slice(payloadStart,payloadEnd);
  assert.match(payloadBuilder,/channel/);
  assert.doesNotMatch(payloadBuilder,/\b(userId|type|title|body|data|email|token)\b/,
    'Outbox v2 must not duplicate recipient identifiers or notification content');
});

test('notification worker hydrates canonical content from the database after the recipient and Outbox locks',()=>{
  const start=notificationsRepo.indexOf('export async function dispatchNotificationOutbox(');
  const end=notificationsRepo.indexOf('\nexport async function disableNotificationDevice(',start);
  assert.ok(start>=0&&end>start,'notification Outbox dispatcher must exist');
  const dispatch=notificationsRepo.slice(start,end);
  const ownerLookup=dispatch.indexOf('SELECT user_id FROM notifications WHERE id=$1');
  const recipientLock=dispatch.indexOf('SELECT id,email,status FROM users WHERE id=$1 FOR SHARE');
  const eventLock=dispatch.indexOf('FROM outbox_events');
  const contentHydration=dispatch.indexOf('SELECT id,user_id,type,title,body,data FROM notifications');
  assert.ok(ownerLookup>=0,'dispatcher must resolve the recipient from the canonical notification row');
  assert.ok(recipientLock>ownerLookup,'recipient barrier must be acquired after the non-locking owner lookup');
  assert.ok(eventLock>recipientLock,'recipient lock must precede the Outbox row lock');
  assert.ok(contentHydration>eventLock,'notification content must be read only after both locks');
  assert.match(dispatch,/deliverTargets\(\{\s*channel,\s*targets,\s*notificationId,\s*userId,\s*notification\s*\}\)/s);
});

test('notification provider dispatch uses hydrated content and preserves legacy v1 event compatibility',()=>{
  const start=handlers.indexOf("} else if (event.event_type === 'NOTIFICATION_DISPATCH') {");
  const end=handlers.indexOf("\n    } else {",start);
  assert.ok(start>=0&&end>start,'notification Outbox handler must exist');
  const branch=handlers.slice(start,end);
  assert.match(branch,/title:notification\.title/);
  assert.match(branch,/body:notification\.body/);
  assert.match(branch,/data:notification\.data/);
  assert.doesNotMatch(branch,/payload\.(?:userId|title|body|data|notificationId)/,
    'provider delivery must not trust duplicated v1 content or recipient fields');
  assert.match(notificationsRepo,/String\(event\?\.aggregate_id\s*\|\|\s*payload\.notificationId/);
});
