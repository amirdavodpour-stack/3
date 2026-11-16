import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const mobileRoot = path.resolve(import.meta.dirname, '../../');
const page = readFileSync(path.join(mobileRoot, 'lib/features/admin/admin_access_page.dart'), 'utf8');
const repository = readFileSync(path.join(mobileRoot, 'lib/core/admin/admin_repository.dart'), 'utf8');

test('mobile MFA flow can recover an unacknowledged delivery and only clears it after server ACK', () => {
  for (const token of [
    'recoveryCodesDeliveryPending', '_retrieveRecoveryCodes',
    'retrieveAdminMfaRecoveryCodes(code)', '_recoveryDeliveryId',
    '_acknowledgeRecoveryCodes', 'acknowledgeAdminMfaRecoveryDelivery(',
    "recoveryCodesDeliveryPending': false", 'I stored the codes and acknowledge receipt',
  ]) assert.ok(page.includes(token), `mobile page must include ${token}`);
  assert.ok(repository.includes('/admin/access/mfa/recovery-codes/retrieve'));
  assert.ok(repository.includes('/admin/access/mfa/recovery-codes/ack'));
});
