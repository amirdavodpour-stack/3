const SAFE_ERROR_CODES = new Set([
  'PAYOUT_PROVIDER_NOT_ENABLED',
  'PAYOUT_PROVIDER_FAILED',
  'PAYOUT_PROVIDER_UNCONFIRMED',
  'PAYMENT_PROVIDER_UNCONFIRMED',
  'PAYMENT_PROVIDER_REFUND_UNCONFIRMED',
  'PAYMENT_PROVIDER_INVALID_JSON',
  'PAYMENT_PROVIDER_INVALID_RESPONSE',
  'PAYMENT_PROVIDER_INVALID_CREATE_RESPONSE',
  'PAYMENT_PROVIDER_INVALID_RELEASE_RESPONSE',
  'PAYMENT_PROVIDER_INVALID_REFUND_RESPONSE',
  'PAYMENT_PROVIDER_PAYOUT_STATUS_NOT_CONFIGURED',
  'NOTIFICATION_PROVIDER_URL_REQUIRED',
  'NOTIFICATION_PROVIDER_HTTPS_REQUIRED',
  'NOTIFICATION_PROVIDER_URL_INVALID',
  'NOTIFICATION_PROVIDER_RETRY_EXHAUSTED',
  'SECURITY_ALERT_NOT_DISPATCHED',
  'SECURITY_ALERT_TERMINAL_SIGNAL_INVALID',
  'ACCOUNT_ERASED',
  'NOTIFICATION_MISSING',
  'EMAIL_RECIPIENT_INVALIDATED',
  'RECIPIENT_ERASED',
  'SUPERSEDED_BY_REFUND',
  'CANCELLED_BY_ADMIN_DISPUTE_HOLD',
]);

const HTTP_ERROR_PATTERN = /^(PAYMENT_PROVIDER|NOTIFICATION_PROVIDER)_HTTP_(\d{3})$/;

function failureCategory(eventType, payload = {}) {
  const type = String(eventType || '').toUpperCase();
  if (type === 'PAYOUT_EXECUTE') return 'payout';
  if (type.startsWith('PAYMENT_')) return 'payment';
  if (type === 'AUTH_REFRESH_REUSE_ALERT' || type === 'SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL') return 'security';
  if (type === 'NOTIFICATION_DISPATCH') {
    const channel = String(payload?.channel || '').toUpperCase();
    if (channel === 'PUSH') return 'push';
    if (channel === 'EMAIL') return 'email';
    return 'notification';
  }
  return 'system';
}

/**
 * Convert untrusted provider/worker errors to a small allowlisted diagnostic.
 * Raw messages, response bodies, headers, URLs, and arbitrary error properties
 * are deliberately never returned or persisted.
 */
export function normalizeOutboxFailureMetadata({ eventType, payload = {}, error, retryable = false } = {}) {
  const type = String(eventType || '').toUpperCase();
  const category = failureCategory(type, payload);
  const message = typeof error === 'string'
    ? error
    : (error && typeof error.message === 'string' ? error.message : '');
  const candidate = error && typeof error.code === 'string' ? error.code : message;
  const httpMatch = HTTP_ERROR_PATTERN.exec(message);
  let httpStatus = null;
  let code = null;

  if (httpMatch) {
    const parsedStatus = Number(httpMatch[2]);
    if (parsedStatus >= 100 && parsedStatus <= 599) {
      httpStatus = parsedStatus;
      code = type === 'PAYOUT_EXECUTE'
        ? 'PAYOUT_PROVIDER_HTTP_ERROR'
        : httpMatch[1] + '_HTTP_ERROR';
    }
  }

  if (!code) {
    if (SAFE_ERROR_CODES.has(candidate)) code = candidate;
    else if (SAFE_ERROR_CODES.has(message)) code = message;
    else code = type === 'PAYOUT_EXECUTE' ? 'PAYOUT_PROVIDER_FAILED' : 'OUTBOX_PROCESSING_FAILED';
  }

  return {
    code,
    category,
    retryable: Boolean(retryable),
    httpStatus,
  };
}
