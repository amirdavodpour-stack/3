import test from 'node:test';
import assert from 'node:assert/strict';
import { runMaintenanceOnce, MAINTENANCE_LOCK_NAME } from '../src/maintenance_runner.js';

function fakePool({ lease = null, failRelease = false } = {}) {
  const state = {
    requests: new Map(),
    lease,
    renewals: 0,
    releases: 0,
    failRelease,
    queries: [],
  };
  return {
    state,
    async query(sql, values = []) {
      state.queries.push({ sql, values });
      if (sql.includes('INSERT INTO maintenance_leases')) {
        const [lockName, ownerRequestId, leaseSeconds] = values;
        if (state.lease && state.lease.expiresAt > Date.now()) return { rows: [] };
        state.lease = { lockName, ownerRequestId, expiresAt: Date.now() + leaseSeconds * 1000 };
        return { rows: [{ owner_request_id: ownerRequestId }] };
      }
      if (sql.includes('UPDATE maintenance_leases')) {
        const [lockName, ownerRequestId, leaseSeconds] = values;
        if (!state.lease || state.lease.lockName !== lockName || state.lease.ownerRequestId !== ownerRequestId || state.lease.expiresAt <= Date.now()) return { rows: [] };
        state.lease.expiresAt = Date.now() + leaseSeconds * 1000;
        state.renewals += 1;
        return { rows: [{ owner_request_id: ownerRequestId }] };
      }
      if (sql.includes('DELETE FROM maintenance_leases')) {
        const [lockName, ownerRequestId] = values;
        if (state.failRelease) throw new Error('simulated lease release failure');
        if (state.lease?.lockName === lockName && state.lease?.ownerRequestId === ownerRequestId) {
          state.lease = null;
          state.releases += 1;
          return { rows: [], rowCount: 1 };
        }
        return { rows: [], rowCount: 0 };
      }
      if (sql.includes('INSERT INTO maintenance_runs')) {
        const requestId = values[0];
        if (state.requests.has(requestId)) return { rows: [] };
        state.requests.set(requestId, { status: 'RUNNING', startedAt: Date.now() });
        return { rows: [{ request_id: requestId }] };
      }
      if (sql.includes("failure_code='RUN_ABANDONED'")) {
        const staleSeconds = values[0] + 30;
        for (const request of state.requests.values()) {
          if (request.status === 'RUNNING' && request.startedAt < Date.now() - staleSeconds * 1000) {
            request.status = 'FAILED';
            request.failureCode = 'RUN_ABANDONED';
          }
        }
        return { rows: [], rowCount: 0 };
      }
      if (sql.includes('DELETE FROM maintenance_runs')) return { rows: [], rowCount: 0 };
      if (sql.includes('UPDATE maintenance_runs')) {
        const request = state.requests.get(values[0]);
        if (!request) return { rows: [], rowCount: 0 };
        if (sql.includes("status='COMPLETED'")) {
          request.status = 'COMPLETED';
          request.result = JSON.parse(values[1]);
        } else {
          request.status = 'FAILED';
          request.failureCode = values[1];
        }
        return { rows: [], rowCount: 1 };
      }
      throw new Error(`Unexpected SQL in fake pool: ${sql}`);
    },
  };
}

const jobs = () => ({
  outbox: async () => ({ claimed: 2, processed: 2 }),
  reconciliation: async () => ({ scanned: 1, resolved: 1 }),
  cleanup: async () => ({ scanned: 1, deletedObjects: 1 }),
});

const requestId = '0e9bb0b7-f22a-4c13-9ba5-649c6900a0bb';

test('maintenance runner acquires a durable lease and records one completed bounded run', async () => {
  const pool = fakePool();
  const calls = [];
  const result = await runMaintenanceOnce({
    pool,
    requestId,
    jobs: {
      outbox: async () => { calls.push('outbox'); return { claimed: 2, processed: 2 }; },
      reconciliation: async () => { calls.push('reconciliation'); return { scanned: 1, resolved: 1 }; },
      cleanup: async () => { calls.push('cleanup'); return { scanned: 1, deletedObjects: 1 }; },
    },
  });
  assert.equal(result.status, 'completed');
  assert.deepEqual(calls, ['outbox', 'reconciliation', 'cleanup']);
  assert.equal(pool.state.requests.get(requestId).status, 'COMPLETED');
  assert.equal(pool.state.lease, null);
  assert.equal(pool.state.renewals, 3);
  assert.equal(pool.state.releases, 1);
});

test('maintenance runner rejects a replayed request id without executing any job twice', async () => {
  const pool = fakePool();
  let calls = 0;
  const task = async () => { calls += 1; return { processed: true }; };
  const work = { outbox: task, reconciliation: task, cleanup: task };
  assert.equal((await runMaintenanceOnce({ pool, requestId, jobs: work })).status, 'completed');
  assert.equal((await runMaintenanceOnce({ pool, requestId, jobs: work })).status, 'replay');
  assert.equal(calls, 3);
  assert.equal(pool.state.lease, null);
});

test('maintenance runner returns busy and does not record work while another unexpired lease exists', async () => {
  const pool = fakePool({ lease: {
    lockName: MAINTENANCE_LOCK_NAME,
    ownerRequestId: '5a785781-1c95-4b4e-9df7-6a6b92be3a80',
    expiresAt: Date.now() + 60000,
  } });
  let calls = 0;
  const task = async () => { calls += 1; return {}; };
  const result = await runMaintenanceOnce({ pool, requestId, jobs: { outbox: task, reconciliation: task, cleanup: task } });
  assert.equal(result.status, 'busy');
  assert.equal(calls, 0);
  assert.equal(pool.state.requests.size, 0);
  assert.equal(pool.state.lease.ownerRequestId, '5a785781-1c95-4b4e-9df7-6a6b92be3a80');
});

test('maintenance runner stores a redacted failure code and releases its lease', async () => {
  const pool = fakePool();
  const error = Object.assign(new Error('private provider token must never be stored'), { code: 'PROVIDER_UNAVAILABLE' });
  await assert.rejects(
    () => runMaintenanceOnce({ pool, requestId, jobs: { outbox: async () => { throw error; }, reconciliation: async () => ({}), cleanup: async () => ({}) } }),
    /private provider token/,
  );
  assert.equal(pool.state.requests.get(requestId).status, 'FAILED');
  assert.equal(pool.state.requests.get(requestId).failureCode, 'PROVIDER_UNAVAILABLE');
  assert.equal(pool.state.lease, null);
});

test('maintenance runner marks abandoned RUNNING rows as failed before pruning terminal history', async () => {
  const pool = fakePool();
  const abandonedId = '5a785781-1c95-4b4e-9df7-6a6b92be3a80';
  pool.state.requests.set(abandonedId, { status: 'RUNNING', startedAt: 0 });
  const result = await runMaintenanceOnce({ pool, requestId, jobs: jobs() });
  assert.equal(result.status, 'completed');
  assert.equal(pool.state.requests.get(abandonedId).status, 'FAILED');
  assert.equal(pool.state.requests.get(abandonedId).failureCode, 'RUN_ABANDONED');
});

test('maintenance runner renews the lease after each completed bounded batch and releases it only after all work', async () => {
  const pool = fakePool();
  const calls = [];
  const task = async (name) => {
    assert.equal(pool.state.lease?.ownerRequestId, requestId);
    calls.push(name);
    return {};
  };
  const result = await runMaintenanceOnce({
    pool,
    requestId,
    jobs: { outbox: () => task('outbox'), reconciliation: () => task('reconciliation'), cleanup: () => task('cleanup') },
  });
  assert.equal(result.status, 'completed');
  assert.deepEqual(calls, ['outbox', 'reconciliation', 'cleanup']);
  assert.equal(pool.state.renewals, 3);
  assert.equal(pool.state.lease, null);
});

test('maintenance runner can take over an expired lease but never releases a newer owner lease', async () => {
  const pool = fakePool({ lease: {
    lockName: MAINTENANCE_LOCK_NAME,
    ownerRequestId: '5a785781-1c95-4b4e-9df7-6a6b92be3a80',
    expiresAt: Date.now() - 1000,
  } });
  const result = await runMaintenanceOnce({ pool, requestId, jobs: jobs() });
  assert.equal(result.status, 'completed');
  assert.equal(pool.state.lease, null);
  assert.equal(pool.state.releases, 1);
});

test('maintenance runner does not fail a completed run when best-effort lease release fails', async () => {
  const pool = fakePool({ failRelease: true });
  const result = await runMaintenanceOnce({ pool, requestId, jobs: jobs() });
  assert.equal(result.status, 'completed');
  assert.equal(pool.state.requests.get(requestId).status, 'COMPLETED');
});
