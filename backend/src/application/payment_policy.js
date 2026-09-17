import { HttpError } from '../api/http_error.js';

const IDEMPOTENCY_KEY_RE = /^[A-Za-z0-9._~:-]+$/;

export function validateIdempotencyPair({ headerKey = '', bodyKey = '', maxLength }) {
  const header = String(headerKey || '').trim();
  const body = String(bodyKey || '').trim();
  if (body && body.length > maxLength) {
    throw new HttpError(400, 'INVALID_IDEMPOTENCY_KEY', 'Idempotency-Key is too long');
  }
  if (body && !IDEMPOTENCY_KEY_RE.test(body)) {
    throw new HttpError(400, 'INVALID_IDEMPOTENCY_KEY', 'Idempotency-Key contains unsupported characters');
  }
  if (header && body && header !== body) {
    throw new HttpError(400, 'INVALID_IDEMPOTENCY_KEY', 'Header and body idempotency keys must match');
  }
  return header || body;
}

export function paymentAmountForJob(job) {
  const candidate = job.kind === 'JOB'
    ? (job.monthlySalary || job.budgetMax || job.budgetMin)
    : (job.budgetMax || job.budgetMin);
  const raw = String(candidate ?? '').trim();
  if (!/^\d+$/.test(raw) || raw === '0') {
    throw new HttpError(400, 'INVALID_AMOUNT', 'Job budget is invalid');
  }
  // TOMAN is integer-only and the financial core caps a single amount at
  // 9e15 so it remains representable by PostgreSQL BIGINT. Return the exact
  // decimal string; calculatePaymentBreakdown() performs BigInt arithmetic.
  try {
    const value = BigInt(raw);
    if (value > 9_000_000_000_000_000n) throw new Error('range');
    return value.toString();
  } catch {
    throw new HttpError(400, 'INVALID_AMOUNT', 'Job budget is invalid');
  }
}

export function mapPaymentMutationError(error) {
  switch (error?.code) {
    case 'PAYMENT_ALREADY_EXISTS':
      return new HttpError(409, 'PAYMENT_ALREADY_EXISTS', 'A payment already exists for this job');
    case 'IDEMPOTENCY_CONFLICT':
      return new HttpError(409, 'IDEMPOTENCY_CONFLICT', 'Idempotency key was already used for different payment parameters');
    case 'INVALID_OFFER_STATE':
      return new HttpError(409, 'INVALID_OFFER_STATE', 'The selected offer is no longer available');
    case 'INVALID_STATE':
      return new HttpError(409, 'INVALID_STATE', 'Job state changed while funding');
    case 'INVALID_PAYMENT_STATE':
      return new HttpError(409, 'INVALID_PAYMENT_STATE', 'Payment cannot be mutated from its current state');
    case 'PARTIAL_REFUND_UNSUPPORTED':
      return new HttpError(400, 'PARTIAL_REFUND_UNSUPPORTED', 'Only full refunds are currently supported');
    default:
      return error;
  }
}
