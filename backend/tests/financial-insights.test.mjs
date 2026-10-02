import test from 'node:test';
import assert from 'node:assert/strict';

import { buildFinancialInsights } from '../src/services/financial_insights.js';

test('financial insights produce balance, cash-flow, source and reservation series from wallet entries', () => {
  const result = buildFinancialInsights({
    wallet: { availableBalance: '1100000', lockedBalance: '200000' },
    entries: [
      { direction:'CREDIT', amount:'1000000', referenceType:'PAYMENT_RELEASE', createdAt:'2026-08-01T10:00:00.000Z', balanceAfter:'1000000' },
      { direction:'DEBIT', amount:'200000', referenceType:'WALLET_TRANSFER', createdAt:'2026-08-03T10:00:00.000Z', balanceAfter:'800000' },
      { direction:'CREDIT', amount:'500000', referenceType:'WALLET_TOP_UP', createdAt:'2026-09-02T10:00:00.000Z', balanceAfter:'1300000' },
      { direction:'DEBIT', amount:'200000', referenceType:'HOLD', createdAt:'2026-09-05T10:00:00.000Z', balanceAfter:'1100000' },
    ],
    months: 3,
    now: '2026-09-30T12:00:00.000Z',
  });

  assert.equal(result.currency, 'TOMAN');
  assert.equal(result.summary.availableBalance, '1100000');
  assert.equal(result.summary.lockedBalance, '200000');
  assert.equal(result.summary.totalInflow, '1500000');
  assert.equal(result.summary.totalOutflow, '200000');
  assert.equal(result.summary.totalReserved, '200000');
  assert.equal(result.monthlyCashFlow.at(-1).inflow, '500000');
  assert.equal(result.monthlyCashFlow.at(-1).reserved, '200000');
  assert.ok(result.balanceTrend.some((point) => point.balance === '800000'));
  assert.ok(result.bySource.some((item) => item.source === 'PAYMENT_RELEASE' && item.amount === '1000000'));
});

test('financial insights never treat HOLD as spending and tolerate malformed entries', () => {
  const result = buildFinancialInsights({
    wallet: { availableBalance: '0', lockedBalance: '0' },
    entries: [
      null,
      { direction:'SIDEWAYS', amount:'-10', referenceType:'X', createdAt:'not-a-date' },
      { direction:'DEBIT', amount:'300', referenceType:'HOLD', createdAt:'2026-09-01T00:00:00.000Z', balanceAfter:'0' },
    ],
    months: 1,
    now: '2026-09-30T12:00:00.000Z',
  });
  assert.equal(result.summary.totalOutflow, '0');
  assert.equal(result.summary.totalReserved, '300');
});
