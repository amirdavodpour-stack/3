/**
 * Pure reconciliation helpers. These deliberately do not know about HTTP or DB.
 * They normalize amounts to fixed precision before comparing provider/internal data.
 */

function cents(value) {
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.round(n * 100);
}

function exactAmountEqual(internal, provider, currency) {
  if (String(currency || '').toUpperCase() === 'TOMAN') {
    try {
      const a = String(internal ?? '').trim();
      const b = String(provider ?? '').trim();
      if (!/^\d+$/.test(a) || !/^\d+$/.test(b)) return false;
      return BigInt(a) === BigInt(b);
    } catch {
      return false;
    }
  }
  return cents(internal) === cents(provider);
}

export function reconcileSettlement(internal, provider) {
  const issues = [];
  if (!internal) return {status:'MISSING_INTERNAL', issues:['INTERNAL_SETTLEMENT_MISSING']};
  if (!provider) return {status:'MISSING_PROVIDER', issues:['PROVIDER_SETTLEMENT_MISSING']};
  if (String(internal.paymentId) !== String(provider.paymentId)) issues.push('PAYMENT_ID_MISMATCH');
  const currency = String(internal.currency || provider.currency || '').toUpperCase();
  if (!exactAmountEqual(internal.amount, provider.amount, currency)) issues.push('AMOUNT_MISMATCH');
  if (String(internal.currency || '') !== String(provider.currency || '')) issues.push('CURRENCY_MISMATCH');
  if (String(internal.status || '').toUpperCase() !== String(provider.status || '').toUpperCase()) issues.push('STATUS_MISMATCH');
  if (provider.providerRef && internal.providerRef && String(provider.providerRef) !== String(internal.providerRef)) issues.push('PROVIDER_REF_MISMATCH');
  return {status: issues.length ? 'MISMATCH' : 'MATCH', issues};
}

export function reconcileBatch(internalRows, providerRows) {
  const internalCounts = new Map();
  const providerCounts = new Map();
  const internal = new Map();
  const provider = new Map();

  for (const row of internalRows || []) {
    const paymentId = String(row.paymentId);
    internalCounts.set(paymentId, (internalCounts.get(paymentId) || 0) + 1);
    internal.set(paymentId, row);
  }
  for (const row of providerRows || []) {
    const paymentId = String(row.paymentId);
    providerCounts.set(paymentId, (providerCounts.get(paymentId) || 0) + 1);
    provider.set(paymentId, row);
  }

  const ids = new Set([...internal.keys(), ...provider.keys()]);
  const results = [];
  for (const paymentId of ids) {
    const base = reconcileSettlement(internal.get(paymentId), provider.get(paymentId));
    const issues = [...base.issues];
    if ((internalCounts.get(paymentId) || 0) > 1) issues.push('DUPLICATE_INTERNAL');
    if ((providerCounts.get(paymentId) || 0) > 1) issues.push('DUPLICATE_PROVIDER');
    results.push({
      paymentId,
      status: base.status.startsWith('MISSING_') ? base.status : (issues.length ? 'MISMATCH' : base.status),
      issues,
    });
  }
  const mismatches = results.filter(x => x.status !== 'MATCH');
  return {total:results.length, matched:results.length - mismatches.length, mismatches};
}
