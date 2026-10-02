import test from 'node:test';
import assert from 'node:assert/strict';
import { refundablePaymentStateAllowed } from '../src/repository/payment_refunds.js';

test('dispute refund may transition an unreleased escrow payment to refund pending', () => {
  assert.equal(refundablePaymentStateAllowed('HELD', false), true);
  assert.equal(refundablePaymentStateAllowed('RELEASE_PENDING', false), false);
  assert.equal(refundablePaymentStateAllowed('RELEASE_PENDING', true), true);
  assert.equal(refundablePaymentStateAllowed('RELEASE_FAILED', true), true);
  assert.equal(refundablePaymentStateAllowed('RELEASED', true), false);
});