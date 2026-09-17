import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const route = fs.readFileSync(new URL('../src/application/wallet_routes.js', import.meta.url), 'utf8');
const dart = fs.readFileSync(new URL('../../lib/core/transactions/wallet_repository.dart', import.meta.url), 'utf8');
const walletPage = fs.readFileSync(new URL('../../lib/features/wallet/wallet_page.dart', import.meta.url), 'utf8');
const docs = fs.readFileSync(new URL('../../docs/CONFIGURATION-CONTRACT.md', import.meta.url), 'utf8');

test('Flutter top-up route matches the staging-only backend contract', () => {
  assert.match(dart, /Future<Map<String, dynamic>> topUp/);
  assert.match(dart, /['\"]POST['\"],\s*['\"]\/wallet\/top-up['\"]/s);
  assert.doesNotMatch(dart, /sandbox-topup/);
  assert.match(route, /parts\[1\] === 'top-up'/);
  assert.match(route, /NODE_ENV !== 'production'/);
  assert.match(route, /config\.internalWalletUserTopUpEnabled/);
  assert.match(route, /creditWallet/);
});

test('production cannot accidentally expose user top-up', () => {
  assert.match(route, /config\.paymentProvider !== 'internal' \|\| !enabled/);
  assert.match(docs, /wallet\/top-up.*disabled in production/i);
  assert.match(docs, /INTERNAL_WALLET_USER_TOPUP_ENABLED=true/);
});


test('Wallet mobile surface preserves retry-safe idempotency and financial state UX contracts', () => {
  assert.match(walletPage, /SharedPreferences/);
  assert.match(walletPage, /pending-idempotency/);
  assert.match(walletPage, /operationFingerprint/);
  assert.match(walletPage, /IDEMPOTENCY_CONFLICT/);
  assert.match(walletPage, /UNKNOWN/);
  assert.match(walletPage, /Wallet ID/);
  assert.match(walletPage, /listPayouts/);
  assert.match(walletPage, /isActive/);
});
