import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-storage-cleanup-postgres-integration.json';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository/storage.js'),
      import('../src/storage_cleanup_worker.js'),
    ])
  : [];

const dbModule = modules[0];
const storageRepository = modules[1];
const { cleanupExpiredUploadIntents } = modules[2] || {};

if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const { createUploadIntent } = storageRepository || {};

test('PostgreSQL upload-intent cleanup respects expiry grace and retains failed deletions for retry', {
  skip: !enabled,
  timeout: 30_000,
}, async () => {
  const userId = crypto.randomUUID();
  const successIntentId = crypto.randomUUID();
  const retryIntentId = crypto.randomUUID();
  const graceIntentId = crypto.randomUUID();
  const suffix = crypto.randomUUID();
  const successKey = `cleanup-test/${suffix}/success.pdf`;
  const retryKey = `cleanup-test/${suffix}/retry.pdf`;
  const graceKey = `cleanup-test/${suffix}/inside-grace.pdf`;
  const now = Date.now();
  const createdAt = new Date(now - 3 * 60 * 60 * 1000).toISOString();

  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES($1,$2,'integration-only','Storage cleanup test','USER','ACTIVE',0,NOW())`,
    [userId, `storage-cleanup-${suffix}@example.test`],
  );

  try {
    const expiredTwoHoursAgo = new Date(now - 2 * 60 * 60 * 1000).toISOString();
    const expiredThirtyMinutesAgo = new Date(now - 30 * 60 * 1000).toISOString();

    for (const intent of [
      { id: successIntentId, storageKey: successKey, expiresAt: expiredTwoHoursAgo },
      { id: retryIntentId, storageKey: retryKey, expiresAt: expiredTwoHoursAgo },
      { id: graceIntentId, storageKey: graceKey, expiresAt: expiredThirtyMinutesAgo },
    ]) {
      await createUploadIntent({
        ...intent,
        uploadedBy: userId,
        contentType: 'application/pdf',
        createdAt,
      });
    }

    const failedKeys = new Set([retryKey]);
    const deleteAttempts = [];
    const storageBackend = {
      async delete({ key }) {
        deleteAttempts.push(key);
        if (failedKeys.has(key)) throw new Error('SIMULATED_OBJECT_DELETE_FAILURE');
      },
    };

    const first = await cleanupExpiredUploadIntents({
      limit: 10,
      graceSeconds: 60 * 60,
      storageBackend,
    });

    assert.deepEqual(first, {
      scanned: 2,
      deletedObjects: 1,
      deletedIntents: 1,
      failedObjects: 1,
    });
    assert.deepEqual(new Set(deleteAttempts), new Set([successKey, retryKey]));
    assert.equal(deleteAttempts.includes(graceKey), false,
      'an intent inside the expiry grace period must not be touched');

    const afterFirstAttempt = await pool.query(
      'SELECT id,storage_key FROM upload_intents WHERE id=ANY($1::uuid[]) ORDER BY id',
      [[successIntentId, retryIntentId, graceIntentId]],
    );
    assert.deepEqual(
      afterFirstAttempt.rows.map((row) => row.storage_key).sort(),
      [retryKey, graceKey].sort(),
      'a successful object deletion removes its tombstone; a failed deletion and a grace-period intent remain',
    );

    failedKeys.clear();
    const second = await cleanupExpiredUploadIntents({
      limit: 10,
      graceSeconds: 60 * 60,
      storageBackend,
    });

    assert.deepEqual(second, {
      scanned: 1,
      deletedObjects: 1,
      deletedIntents: 1,
      failedObjects: 0,
    });

    const afterRetry = await pool.query(
      'SELECT id,storage_key FROM upload_intents WHERE id=ANY($1::uuid[]) ORDER BY id',
      [[successIntentId, retryIntentId, graceIntentId]],
    );
    assert.deepEqual(afterRetry.rows.map((row) => row.storage_key), [graceKey],
      'the failed object is retried and its tombstone is removed only after deletion succeeds');
    assert.equal(deleteAttempts.filter((key) => key === retryKey).length, 2);
  } finally {
    await pool.query(
      'DELETE FROM upload_intents WHERE id=ANY($1::uuid[])',
      [[successIntentId, retryIntentId, graceIntentId]],
    ).catch(() => {});
    await pool.query('DELETE FROM users WHERE id=$1', [userId]).catch(() => {});
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
