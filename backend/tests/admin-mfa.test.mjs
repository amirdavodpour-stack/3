import test from 'node:test';
import assert from 'node:assert/strict';
import {
  encodeBase32,
  decodeBase32,
  generateTotpSecret,
  generateTotpCode,
  verifyTotpCode,
  encryptTotpSecret,
  decryptTotpSecret,
  generateRecoveryCodes,
  encryptRecoveryCodes,
  decryptRecoveryCodes,
  hashRecoveryCode,
  buildTotpUri,
} from '../src/security/admin_mfa.js';

test('Base32 encoding and decoding preserve exact secret bytes', () => {
  const source = Buffer.from('HOPEv2 administrator MFA');
  assert.deepEqual(decodeBase32(encodeBase32(source)), source);
});

test('TOTP generation matches RFC 6238 SHA-1 vectors with eight digits', () => {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  assert.equal(generateTotpCode(secret, 59000, { digits: 8 }), '94287082');
  assert.equal(generateTotpCode(secret, 1111111109000, { digits: 8 }), '07081804');
  assert.equal(generateTotpCode(secret, 1111111111000, { digits: 8 }), '14050471');
  assert.equal(generateTotpCode(secret, 1234567890000, { digits: 8 }), '89005924');
});

test('generated administrator TOTP secrets are high entropy and Base32 compatible', () => {
  const secret = generateTotpSecret();
  assert.equal(secret.length, 32);
  assert.match(secret, /^[A-Z2-7]+$/);
  assert.equal(decodeBase32(secret).length, 20);
});

test('TOTP verification accepts only the narrow time window and rejects malformed codes', () => {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  const now = 1710000000000;
  const code = generateTotpCode(secret, now);
  const accepted = verifyTotpCode(secret, code, now + 1000);
  assert.equal(accepted.valid, true);
  assert.ok(Number.isInteger(accepted.counter));
  assert.equal(verifyTotpCode(secret, 'abcdef', now).valid, false);
  assert.equal(verifyTotpCode(secret, '123', now).valid, false);
  assert.equal(verifyTotpCode(secret, '000000', now + 120000).valid, false);
});

test('TOTP verification rejects a counter that has already been accepted', () => {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  const now = 1710000000000;
  const code = generateTotpCode(secret, now);
  const first = verifyTotpCode(secret, code, now);
  assert.equal(first.valid, true);
  assert.equal(
    verifyTotpCode(secret, code, now, { lastAcceptedCounter: first.counter }).valid,
    false,
  );
});

test('TOTP secret encryption authenticates ciphertext and rejects a wrong key', () => {
  const secret = generateTotpSecret();
  const key = 'hope-admin-mfa-encryption-key-with-adequate-entropy';
  const encrypted = encryptTotpSecret(secret, key);
  assert.notEqual(encrypted, secret);
  assert.equal(decryptTotpSecret(encrypted, key), secret);
  assert.throws(() => decryptTotpSecret(encrypted, 'wrong-key-with-adequate-length'));
  assert.throws(() => encryptTotpSecret(secret, 'short'));
});

test('recovery codes are unique, high entropy and stored only as one-way hashes', () => {
  const { codes, hashes } = generateRecoveryCodes(10);
  assert.equal(codes.length, 10);
  assert.equal(hashes.length, 10);
  assert.equal(new Set(codes).size, 10);
  assert.equal(new Set(hashes).size, 10);
  for (let i = 0; i < codes.length; i += 1) {
    assert.match(codes[i], /^[A-F0-9]{32}$/);
    assert.equal(hashes[i], hashRecoveryCode(codes[i]));
    assert.notEqual(hashes[i], codes[i]);
  }
  assert.equal(hashRecoveryCode(codes[0].toLowerCase()), hashes[0]);
  assert.notEqual(hashRecoveryCode(codes[1]), hashes[0]);
});

test('TOTP URI labels the HOPEv2 administrator and encodes issuer/account values', () => {
  const uri = buildTotpUri({
    secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
    email: 'admin+hope@example.test',
  });
  assert.ok(uri.startsWith('otpauth://totp/'));
  assert.match(uri, /issuer=HOPEv2/);
  assert.match(uri, /admin%2Bhope%40example.test/);
  assert.match(uri, /secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ/);
});


test('recovery-code delivery payload is authenticated-encrypted and can be retried without storing plaintext', () => {
  const codes = generateRecoveryCodes(10).codes;
  const ciphertext = encryptRecoveryCodes(codes, 'hope-admin-mfa-test-encryption-key-with-entropy');
  assert.notEqual(ciphertext, JSON.stringify(codes));
  assert.deepEqual(decryptRecoveryCodes(ciphertext, 'hope-admin-mfa-test-encryption-key-with-entropy'), codes);
  assert.throws(() => decryptRecoveryCodes(ciphertext, 'wrong-encryption-key-with-sufficient-entropy'));
  assert.throws(() => encryptRecoveryCodes(['not-a-recovery-code'], 'hope-admin-mfa-test-encryption-key-with-entropy'));
});

test('recovery delivery ciphertext is purpose-bound, contains exactly ten unique codes, and rejects substitution', () => {
  const secret = generateTotpSecret();
  const totpCiphertext = encryptTotpSecret(secret, 'hope-admin-mfa-test-encryption-key-with-entropy');
  assert.throws(() => decryptRecoveryCodes(totpCiphertext, 'hope-admin-mfa-test-encryption-key-with-entropy'));
  const codes = generateRecoveryCodes(10).codes;
  assert.throws(() => encryptRecoveryCodes(codes.slice(1), 'hope-admin-mfa-test-encryption-key-with-entropy'));
  assert.throws(() => encryptRecoveryCodes([...codes.slice(0, 9), codes[0]], 'hope-admin-mfa-test-encryption-key-with-entropy'));
});