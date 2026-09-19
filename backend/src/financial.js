import { config } from './config.js';

export const FEE_POLICY_VERSION = '2026-08-v1';
export const ACCOUNT = Object.freeze({
  PLATFORM_CASH: 'PLATFORM_CASH',
  ESCROW_LIABILITY: 'ESCROW_LIABILITY',
  USER_PAYABLE: 'USER_PAYABLE',
  PLATFORM_FEE_REVENUE: 'PLATFORM_FEE_REVENUE',
});

const MAX_TOMAN_UNITS = 9_000_000_000_000_000n;
const TOMAN = 'TOMAN';

function roundMoney(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100;
}

function moneyToCents(value) {
  const raw = String(value ?? '').trim();
  if (!/^(?:\d+)(?:\.\d{1,2})?$/.test(raw)) throw new Error('INVALID_AMOUNT');
  const [whole, fraction = ''] = raw.split('.');
  const cents = Number(whole) * 100 + Number(fraction.padEnd(2, '0'));
  if (!Number.isSafeInteger(cents) || cents <= 0 || cents > 100_000_000_000) throw new Error('INVALID_AMOUNT');
  return cents;
}

function tomanUnits(value, { allowZero = false } = {}) {
  const raw = String(value ?? '').trim();
  if (!/^\d+$/.test(raw)) throw new Error('INVALID_AMOUNT');
  const units = BigInt(raw);
  if ((!allowZero && units <= 0n) || units < 0n || units > MAX_TOMAN_UNITS) throw new Error('INVALID_AMOUNT');
  return units;
}

function roundedPercent(units, rate) {
  return (units * BigInt(rate) + 50n) / 100n;
}

const centsToMoney = (cents) => cents / 100;
const tomanToMoney = (units) => units.toString();

export function normalizeFinancialAmount(currency, value) {
  if (String(currency || config.paymentCurrency).toUpperCase() === TOMAN) {
    let raw = String(value ?? '0').trim();
    if (/^\d+\.0+$/.test(raw)) raw = raw.slice(0, raw.indexOf('.'));
    if (!/^\d+$/.test(raw)) throw new Error('INVALID_TOMAN_AMOUNT');
    const units = BigInt(raw);
    if (units < 0n || units > MAX_TOMAN_UNITS) throw new Error('INVALID_TOMAN_AMOUNT');
    return units.toString();
  }
  return Number(value ?? 0);
}

export function calculatePaymentBreakdown(kind, baseAmount, currency = config.paymentCurrency) {
  const normalizedKind = String(kind || '').toUpperCase();
  const employerFeeRate = normalizedKind === 'MISSION' ? 10 : 30;
  const workerFeeRate = normalizedKind === 'MISSION' ? 10 : 0;
  const normalizedCurrency = String(currency || config.paymentCurrency).toUpperCase();

  if (normalizedCurrency === TOMAN) {
    const amount = tomanUnits(baseAmount);
    const employerFee = roundedPercent(amount, employerFeeRate);
    const workerFee = roundedPercent(amount, workerFeeRate);
    const platformFee = employerFee + workerFee;
    const employerCharge = amount + employerFee;
    const providerPayout = amount - workerFee;
    return {
      policyVersion: FEE_POLICY_VERSION,
      kind: normalizedKind,
      baseAmount: tomanToMoney(amount),
      employerFeeRate,
      workerFeeRate,
      employerFee: tomanToMoney(employerFee),
      workerFee: tomanToMoney(workerFee),
      platformFee: tomanToMoney(platformFee),
      employerCharge: tomanToMoney(employerCharge),
      providerPayout: tomanToMoney(providerPayout),
      currency: TOMAN,
    };
  }

  const amountCents = moneyToCents(baseAmount);
  const employerFeeCents = Math.round(amountCents * employerFeeRate / 100);
  const workerFeeCents = Math.round(amountCents * workerFeeRate / 100);
  const platformFeeCents = employerFeeCents + workerFeeCents;
  const employerChargeCents = amountCents + employerFeeCents;
  const providerPayoutCents = amountCents - workerFeeCents;
  const amount = centsToMoney(amountCents);
  const employerFee = centsToMoney(employerFeeCents);
  const workerFee = centsToMoney(workerFeeCents);
  const platformFee = centsToMoney(platformFeeCents);
  const employerCharge = centsToMoney(employerChargeCents);
  const providerPayout = centsToMoney(providerPayoutCents);
  return {
    policyVersion: FEE_POLICY_VERSION,
    kind: normalizedKind,
    baseAmount: roundMoney(amount),
    employerFeeRate,
    workerFeeRate,
    employerFee,
    workerFee,
    platformFee,
    employerCharge,
    providerPayout,
    currency: normalizedCurrency,
  };
}

export function assertBalanced(entries) {
  const exactInteger = entries.every((e) => {
    for (const value of [e.debit ?? 0, e.credit ?? 0]) {
      if (typeof value === 'bigint') continue;
      if (typeof value === 'string' && /^\d+$/.test(value.trim())) continue;
      if (typeof value === 'number' && Number.isInteger(value) && Number.isSafeInteger(value)) continue;
      return false;
    }
    return true;
  });
  if (exactInteger) {
    const debit = entries.reduce((sum, e) => sum + BigInt(String(e.debit ?? 0)), 0n);
    const credit = entries.reduce((sum, e) => sum + BigInt(String(e.credit ?? 0)), 0n);
    if (debit !== credit) throw new Error(`UNBALANCED_JOURNAL:${debit}:${credit}`);
    return true;
  }
  const debit = roundMoney(entries.reduce((sum, e) => sum + Number(e.debit || 0), 0));
  const credit = roundMoney(entries.reduce((sum, e) => sum + Number(e.credit || 0), 0));
  if (debit !== credit) throw new Error(`UNBALANCED_JOURNAL:${debit}:${credit}`);
  return true;
}

export function fundingJournal(breakdown) {
  const entries = [
    { account: ACCOUNT.PLATFORM_CASH, debit: breakdown.employerCharge, credit: 0 },
    { account: ACCOUNT.ESCROW_LIABILITY, debit: 0, credit: breakdown.providerPayout },
    { account: ACCOUNT.PLATFORM_FEE_REVENUE, debit: 0, credit: breakdown.platformFee },
  ];
  assertBalanced(entries);
  return entries;
}

export function releaseJournal(breakdown) {
  const entries = [
    { account: ACCOUNT.ESCROW_LIABILITY, debit: breakdown.providerPayout, credit: 0 },
    { account: ACCOUNT.USER_PAYABLE, debit: 0, credit: breakdown.providerPayout },
  ];
  assertBalanced(entries);
  return entries;
}

export function payoutJournal(breakdown) {
  const entries = [
    { account: ACCOUNT.USER_PAYABLE, debit: breakdown.providerPayout, credit: 0 },
    { account: ACCOUNT.PLATFORM_CASH, debit: 0, credit: breakdown.providerPayout },
  ];
  assertBalanced(entries);
  return entries;
}

export function refundJournal(breakdown) {
  const entries = [
    { account: ACCOUNT.ESCROW_LIABILITY, debit: breakdown.providerPayout, credit: 0 },
    { account: ACCOUNT.PLATFORM_FEE_REVENUE, debit: breakdown.platformFee, credit: 0 },
    { account: ACCOUNT.PLATFORM_CASH, debit: 0, credit: breakdown.employerCharge },
  ];
  assertBalanced(entries);
  return entries;
}
