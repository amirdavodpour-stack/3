import test from 'node:test';
import assert from 'node:assert/strict';
import { reconcileSettlement, reconcileBatch } from '../src/financial_reconciliation.js';

test('reconcileSettlement matches monetary values at cent precision', () => {
  assert.deepEqual(reconcileSettlement({paymentId:'p1',amount:'100.005',currency:'USD',status:'RELEASED',providerRef:'r1'}, {paymentId:'p1',amount:100.01,currency:'USD',status:'released',providerRef:'r1'}), {status:'MATCH',issues:[]});
});

test('reconcileSettlement compares TOMAN amounts exactly above JS safe integer range', () => {
  assert.deepEqual(reconcileSettlement({paymentId:'p-toman',amount:'9007199254740993',currency:'TOMAN',status:'RELEASED'}, {paymentId:'p-toman',amount:'9007199254740993',currency:'TOMAN',status:'RELEASED'}), {status:'MATCH',issues:[]});
  assert.deepEqual(reconcileSettlement({paymentId:'p-toman',amount:'9007199254740993',currency:'TOMAN',status:'RELEASED'}, {paymentId:'p-toman',amount:'9007199254740992',currency:'TOMAN',status:'RELEASED'}), {status:'MISMATCH',issues:['AMOUNT_MISMATCH']});
});

test('reconcileSettlement reports critical divergence', () => {
  const result = reconcileSettlement({paymentId:'p1',amount:100,currency:'USD',status:'RELEASED',providerRef:'r1'}, {paymentId:'p1',amount:90,currency:'EUR',status:'FAILED',providerRef:'r2'});
  assert.equal(result.status,'MISMATCH');
  assert.deepEqual(result.issues,['AMOUNT_MISMATCH','CURRENCY_MISMATCH','STATUS_MISMATCH','PROVIDER_REF_MISMATCH']);
});

test('reconcileBatch detects missing records on either side', () => {
  const result = reconcileBatch([{paymentId:'p1',amount:10,currency:'USD',status:'RELEASED'}, {paymentId:'p2',amount:20,currency:'USD',status:'RELEASED'}], [{paymentId:'p1',amount:10,currency:'USD',status:'RELEASED'}, {paymentId:'p3',amount:30,currency:'USD',status:'RELEASED'}]);
  assert.equal(result.total,3);
  assert.equal(result.matched,1);
  assert.equal(result.mismatches.length,2);
  assert.deepEqual(result.mismatches.map(x=>x.status).sort(), ['MISSING_INTERNAL','MISSING_PROVIDER']);
});


test('reconcileBatch detects duplicate payment IDs instead of silently overwriting rows', () => {
  const result = reconcileBatch(
    [
      {paymentId:'p1',amount:10,currency:'USD',status:'RELEASED'},
      {paymentId:'p1',amount:10,currency:'USD',status:'RELEASED'},
    ],
    [
      {paymentId:'p1',amount:10,currency:'USD',status:'RELEASED'},
      {paymentId:'p2',amount:20,currency:'USD',status:'RELEASED'},
      {paymentId:'p2',amount:20,currency:'USD',status:'RELEASED'},
    ],
  );
  assert.equal(result.total, 2);
  assert.equal(result.matched, 0);
  assert.deepEqual(result.mismatches.map(x => [x.paymentId, x.issues]).sort(),
    [['p1', ['DUPLICATE_INTERNAL']], ['p2', ['INTERNAL_SETTLEMENT_MISSING', 'DUPLICATE_PROVIDER']]]);
});
