import crypto from 'node:crypto';

const MAINTENANCE_PATH = '/api/v1/internal/maintenance';
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256_HEX = /^[0-9a-f]{64}$/i;

export function verifyMaintenanceSignature({
  method,
  pathname,
  timestamp,
  requestId,
  signature,
  secret,
  nowSeconds = Math.floor(Date.now() / 1000),
  maxAgeSeconds = 300,
} = {}) {
  if (String(method || '').toUpperCase() !== 'POST' || pathname !== MAINTENANCE_PATH) {
    return { valid: false, reason: 'REQUEST_TARGET_INVALID' };
  }
  if (typeof secret !== 'string' || Buffer.byteLength(secret, 'utf8') < 32) {
    return { valid: false, reason: 'MAINTENANCE_SECRET_UNAVAILABLE' };
  }
  if (!Number.isSafeInteger(nowSeconds) || !Number.isSafeInteger(maxAgeSeconds) || maxAgeSeconds < 30 || maxAgeSeconds > 600) {
    return { valid: false, reason: 'MAINTENANCE_CLOCK_INVALID' };
  }
  if (typeof timestamp !== 'string' || !/^\d{10}$/.test(timestamp)) {
    return { valid: false, reason: 'TIMESTAMP_INVALID' };
  }
  const timestampSeconds = Number(timestamp);
  if (!Number.isSafeInteger(timestampSeconds) || Math.abs(nowSeconds - timestampSeconds) > maxAgeSeconds) {
    return { valid: false, reason: 'TIMESTAMP_EXPIRED' };
  }
  if (typeof requestId !== 'string' || !UUID_V4.test(requestId)) {
    return { valid: false, reason: 'REQUEST_ID_INVALID' };
  }
  if (typeof signature !== 'string' || !SHA256_HEX.test(signature)) {
    return { valid: false, reason: 'SIGNATURE_INVALID' };
  }

  const canonical = `${timestamp}.${requestId}.POST.${MAINTENANCE_PATH}`;
  const expected = crypto.createHmac('sha256', secret).update(canonical, 'utf8').digest();
  const supplied = Buffer.from(signature, 'hex');
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(expected, supplied)) {
    return { valid: false, reason: 'SIGNATURE_INVALID' };
  }
  return { valid: true, requestId };
}

export { MAINTENANCE_PATH };
