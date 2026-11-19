import { config } from './config.js';
import { getPool } from './db.js';
import { runOutboxBatch } from './outbox_worker.js';
import { reconcileUnknownPayouts } from './reconciliation_worker.js';
import { cleanupExpiredUploadIntents } from './storage_cleanup_worker.js';
import { runMaintenanceOnce } from './maintenance_runner.js';

function stagingMaintenanceEnabled() {
  return process.env.VERCEL_ENV === 'preview' && process.env.HOPE_STAGING_MODE === 'true' && process.env.HOPE_SERVERLESS_MODE === 'true';
}

function assertNoLiveProviderEgress() {
  if (
    config.paymentProvider === 'webhook'
    || config.alertWebhookUrl
    || config.notificationEmailUrl
    || config.notificationPushUrl
    || config.resetDeliveryMode === 'webhook'
  ) {
    const error = new Error('Maintenance refuses external payment, notification, or alert delivery in Preview');
    error.code = 'MAINTENANCE_EXTERNAL_EGRESS_DISABLED';
    throw error;
  }
  if (config.storageBackend !== 's3' || config.s3Bucket !== 'v2hope-private' || config.s3Endpoint !== 'https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3' || config.s3Region !== 'eu-west-1' || !config.s3ForcePathStyle) {
    const error = new Error('Staging private S3-compatible object storage must be configured before cleanup can run');
    error.code = 'STAGING_OBJECT_STORAGE_REQUIRED';
    throw error;
  }
}

export async function runStagingMaintenance({ requestId } = {}) {
  if (!stagingMaintenanceEnabled()) {
    const error = new Error('Staging maintenance is disabled outside the Vercel Preview environment');
    error.code = 'STAGING_MAINTENANCE_DISABLED';
    throw error;
  }
  if (Buffer.byteLength(config.maintenanceHmacSecret, 'utf8') < 32) {
    const error = new Error('Staging maintenance authentication is not configured');
    error.code = 'MAINTENANCE_AUTH_NOT_CONFIGURED';
    throw error;
  }
  assertNoLiveProviderEgress();

  const pool = getPool();
  if (!pool) {
    const error = new Error('PostgreSQL is required for staging maintenance');
    error.code = 'MAINTENANCE_DATABASE_REQUIRED';
    throw error;
  }

  return runMaintenanceOnce({
    pool,
    requestId,
    leaseSeconds: config.maintenanceLeaseSeconds,
    jobs: {
      outbox: () => runOutboxBatch({
        maxEvents: config.maintenanceOutboxBatchSize,
        maxDurationMs: config.maintenanceBatchMaxDurationMs,
      }),
      reconciliation: () => reconcileUnknownPayouts({ limit: config.maintenanceReconciliationBatchSize }),
      cleanup: () => cleanupExpiredUploadIntents({
        limit: config.maintenanceCleanupBatchSize,
        graceSeconds: config.uploadOrphanGraceSeconds,
        deleteTimeoutMs: config.maintenanceStorageRequestTimeoutMs,
      }),
    },
  });
}

export { stagingMaintenanceEnabled, assertNoLiveProviderEgress };
