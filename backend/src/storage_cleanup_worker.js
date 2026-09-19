import { config } from './config.js';
import { storage } from './storage.js';
import { deleteUploadIntents, listExpiredUploadIntents } from './repository/storage.js';
import { logEvent } from './observability.js';

let stopped = false;
let timer = null;
let running = false;

export async function cleanupExpiredUploadIntents({
  limit = config.uploadCleanupBatchSize,
  graceSeconds = config.uploadOrphanGraceSeconds,
  storageBackend = storage,
} = {}) {
  if (!process.env.DATABASE_URL) return { scanned: 0, deletedObjects: 0, deletedIntents: 0, failedObjects: 0 };
  const cutoffIso = new Date(Date.now() - graceSeconds * 1000).toISOString();
  const intents = await listExpiredUploadIntents({ cutoffIso, limit });
  if (!intents.length) return { scanned: 0, deletedObjects: 0, deletedIntents: 0, failedObjects: 0 };

  const cleanedIds = [];
  let deletedObjects = 0;
  let failedObjects = 0;
  for (const intent of intents) {
    try {
      await storageBackend.delete({ key: intent.storageKey });
      deletedObjects += 1;
      cleanedIds.push(intent.id);
    } catch (error) {
      failedObjects += 1;
      logEvent({
        level: 'warn',
        action: 'UPLOAD_ORPHAN_CLEANUP_DELETE_FAILED',
        uploadIntentId: intent.id,
        key: intent.storageKey,
        error: error?.message || String(error),
      });
    }
  }

  const deletedIntents = cleanedIds.length ? await deleteUploadIntents(cleanedIds) : 0;
  return { scanned: intents.length, deletedObjects, deletedIntents, failedObjects };
}

export function startStorageCleanupWorker() {
  if (!process.env.DATABASE_URL) return { stop() {} };
  stopped = false;
  const tick = async () => {
    if (stopped || running) return;
    running = true;
    try {
      const result = await cleanupExpiredUploadIntents();
      if (result.scanned || result.failedObjects) {
        logEvent({ level: result.failedObjects ? 'warn' : 'info', action: 'UPLOAD_ORPHAN_CLEANUP', ...result });
      }
    } catch (error) {
      logEvent({ level: 'warn', action: 'UPLOAD_ORPHAN_CLEANUP_WORKER_ERROR', error: error?.message || String(error) });
    } finally {
      running = false;
    }
  };
  void tick();
  timer = setInterval(() => { void tick(); }, config.uploadCleanupIntervalMs);
  timer.unref();
  return {
    stop() {
      stopped = true;
      if (timer) clearInterval(timer);
      timer = null;
    },
  };
}
