import { config } from './config.js';
import { paymentProvider } from './payment_provider.js';
import { listUnknownPayoutsForReconciliation, openReconciliationCase, resolveLatestReconciliationCase } from './repository/reconciliation.js';
import { resolvePayoutUnknown } from './repository/payouts.js';
import { logEvent } from './observability.js';

let stopped = false;
let timer = null;
let running = false;

function normalizeProviderStatus(result) {
  const status = String(result?.status || '').trim().toUpperCase();
  if (!['SUCCEEDED', 'FAILED', 'UNKNOWN', 'PENDING', 'PROCESSING'].includes(status)) return 'INVALID';
  return status;
}

export async function reconcileUnknownPayouts({ limit = config.reconciliationBatchSize, provider = paymentProvider } = {}) {
  if (!process.env.DATABASE_URL) return { scanned: 0, resolved: 0, pending: 0, cases: 0 };
  const candidates = await listUnknownPayoutsForReconciliation({ limit });
  let resolved = 0;
  let pending = 0;
  let cases = 0;

  for (const payout of candidates) {
    let result;
    try {
      if (typeof provider.getPayoutStatus !== 'function') throw new Error('PAYOUT_STATUS_LOOKUP_UNSUPPORTED');
      result = await provider.getPayoutStatus({
        payoutId: payout.id,
        amount: String(payout.amount ?? '0'),
        currency: payout.currency,
        idempotencyKey: `reconcile:${payout.id}`,
      });
    } catch (error) {
      cases += 1;
      await openReconciliationCase({
        caseType: 'PAYOUT_STATUS_LOOKUP_FAILED',
        resourceType: 'payout',
        resourceId: payout.id,
        severity: 'HIGH',
        expected: { status: 'SUCCEEDED|FAILED|UNKNOWN' },
        observed: { error: error?.message || String(error), payoutStatus: payout.status },
      });
      logEvent({ level: 'warn', action: 'PAYOUT_RECONCILIATION_LOOKUP_FAILED', payoutId: payout.id, error: error?.message || String(error) });
      continue;
    }

    const status = normalizeProviderStatus(result);
    if (status === 'SUCCEEDED' || status === 'FAILED') {
      if (status === 'SUCCEEDED' && !result.providerRef) {
        cases += 1;
        await openReconciliationCase({
          caseType: 'PAYOUT_SUCCESS_MISSING_PROVIDER_REF',
          resourceType: 'payout',
          resourceId: payout.id,
          severity: 'CRITICAL',
          expected: { status: 'SUCCEEDED', providerRef: 'required' },
          observed: { status: result.status, amount: result.amount, currency: result.currency },
        });
        continue;
      }
      const resolution = await resolvePayoutUnknown({
        payoutId: payout.id,
        decision: status,
        providerRef: result.providerRef || null,
        adminId: null,
        reason: result.errorCode || 'PROVIDER_RECONCILIATION',
      });
      if (!resolution) continue;
      resolved += 1;
      await resolveLatestReconciliationCase({
        resourceType: 'payout',
        resourceId: payout.id,
        resolutionReference: `provider:${result.providerRef || result.errorCode || status}`,
      });
      logEvent({ level: 'info', action: 'PAYOUT_RECONCILED', payoutId: payout.id, status });
      continue;
    }

    if (status === 'UNKNOWN' || status === 'PENDING' || status === 'PROCESSING') {
      pending += 1;
      cases += 1;
      await openReconciliationCase({
        caseType: 'PAYOUT_PROVIDER_PENDING',
        resourceType: 'payout',
        resourceId: payout.id,
        severity: status === 'UNKNOWN' ? 'HIGH' : 'MEDIUM',
        expected: { status: 'SUCCEEDED|FAILED' },
        observed: { status, providerRef: result.providerRef || null },
      });
      continue;
    }

    cases += 1;
    await openReconciliationCase({
      caseType: 'PAYOUT_PROVIDER_INVALID_STATUS',
      resourceType: 'payout',
      resourceId: payout.id,
      severity: 'CRITICAL',
      expected: { status: 'SUCCEEDED|FAILED|UNKNOWN' },
      observed: { status: result?.status ?? null },
    });
  }

  return { scanned: candidates.length, resolved, pending, cases };
}

export function startReconciliationWorker() {
  if (!process.env.DATABASE_URL) return { stop() {} };
  stopped = false;
  const tick = async () => {
    if (stopped || running) return;
    running = true;
    try {
      await reconcileUnknownPayouts();
    } catch (error) {
      logEvent({ level: 'warn', action: 'RECONCILIATION_WORKER_ERROR', error: error?.message || String(error) });
    } finally {
      running = false;
    }
  };
  void tick();
  timer = setInterval(() => { void tick(); }, config.reconciliationPollMs);
  return {
    stop() {
      stopped = true;
      if (timer) clearInterval(timer);
      timer = null;
    },
  };
}

export { normalizeProviderStatus };
