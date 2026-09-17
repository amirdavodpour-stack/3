import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const repo = fs.readFileSync(new URL('../src/repository/wallet.js', import.meta.url), 'utf8');
const routes = fs.readFileSync(new URL('../src/application/wallet_routes.js', import.meta.url), 'utf8');
const walletDart = fs.readFileSync(new URL('../../lib/core/transactions/wallet.dart', import.meta.url), 'utf8');
const walletRepoDart = fs.readFileSync(new URL('../../lib/core/transactions/wallet_repository.dart', import.meta.url), 'utf8');
const registry = fs.readFileSync(new URL('../../lib/core/application/application_registry.dart', import.meta.url), 'utf8');
const main = fs.readFileSync(new URL('../../lib/main.dart', import.meta.url), 'utf8');

test('wallet history is served from canonical immutable wallet_entries with cursor pagination', () => {
  assert.match(repo, /FROM wallet_entries e/);
  assert.match(repo, /\(e\.created_at,e\.id\) < \(\$3::timestamptz,\$4::uuid\)/);
  assert.match(repo, /ORDER BY e\.created_at DESC,e\.id DESC/);
  assert.match(repo, /nextCursor/);
  assert.match(repo, /base64url/);
  assert.match(routes, /searchParams\.get\('cursor'\)/);
  assert.match(routes, /INVALID_CURSOR/);
  assert.match(routes, /nextCursor: result\.nextCursor/);
});

test('wallet history mobile models expose canonical entry semantics and cursor page', () => {
  assert.match(walletDart, /entryType/);
  assert.match(walletDart, /direction/);
  assert.match(walletDart, /financialOperationId/);
  assert.match(walletDart, /balanceAfter/);
  assert.match(walletRepoDart, /class WalletTransactionsPage/);
  assert.match(walletRepoDart, /String\? cursor/);
  assert.match(walletRepoDart, /hasMore/);
  assert.match(walletRepoDart, /'\/wallet\/transactions'/);
});

test('wallet repository is registered in the application dependency graph', () => {
  assert.match(registry, /WalletRepository\? wallets/);
  assert.match(registry, /walletsOrThrow/);
  assert.match(main, /Provider<WalletRepository>/);
  assert.match(main, /wallets: context\.read<WalletRepository>\(\)/);
});

test('wallet API treats wallet id as the canonical transfer destination and exposes payout history', () => {
  assert.match(routes, /destinationWalletId/);
  assert.match(routes, /getWalletById\(destinationWalletId\)/);
  assert.match(routes, /parts\[1\] === 'payouts'/);
  assert.match(routes, /listPayoutsForUser/);
});
