const OPERATION_REFERENCE_EVENTS = new Set(['PAYMENT_RELEASED', 'PAYMENT_REFUNDED']);

/**
 * Release and refund webhooks carry the reference of that operation, not the
 * original hold. Reject a hold reference being replayed as a terminal operation
 * reference, while allowing legitimate distinct releaseRef/refundRef values.
 */
export function operationProviderRefMismatch(eventType, providerRef, holdProviderRef) {
  if (!OPERATION_REFERENCE_EVENTS.has(String(eventType || '').trim().toUpperCase())) return false;
  if (providerRef == null || holdProviderRef == null || String(holdProviderRef).trim() === '') return false;
  return String(providerRef).trim() === String(holdProviderRef).trim();
}
