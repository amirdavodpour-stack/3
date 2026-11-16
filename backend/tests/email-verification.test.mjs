import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

function block(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = endMarker ? source.indexOf(endMarker, start) : source.length;
  assert.ok(start >= 0 && end > start, `Expected source block: ${startMarker}`);
  return source.slice(start, end);
}

test('password registration creates a pending account without issuing a session', () => {
  const route = read('backend/src/routes/auth_routes.js');
  const registration = block(
    route,
    "if (req.method === 'POST' && route === 'register')",
    "if (req.method === 'POST' && route === 'email/verification/resend')",
  );
  assert.match(registration, /status:\s*'PENDING_EMAIL_VERIFICATION'/);
  assert.match(registration, /sendJson\(res,\s*202/);
  assert.match(registration, /verificationRequired:\s*true/);
  assert.match(registration, /issueEmailVerification\(user\)/);
  assert.doesNotMatch(registration, /issueSession\(user\)/);
});

test('email verification consumes a hashed token and issues the first session only after activation', () => {
  const route = read('backend/src/routes/auth_routes.js');
  const verification = block(
    route,
    "if (req.method === 'POST' && route === 'email/verify')",
    "if (req.method === 'POST' && route === 'google/link')",
  );
  assert.match(verification, /sha256\(code\)/);
  assert.match(verification, /repo\.consumeEmailVerificationToken/);
  assert.match(verification, /legacy\.consumeEmailVerificationToken/);
  assert.match(verification, /EMAIL_VERIFICATION_INVALID/);
  assert.match(verification, /issueSession\(user\)/);
  assert.match(verification, /AUTH_EMAIL_VERIFIED/);
});

test('verification tokens are single-use, expiry-checked and row-locked in PostgreSQL', () => {
  const repository = read('backend/src/repository/auth.js');
  const insert = block(
    repository,
    'export async function insertEmailVerificationToken',
    'export async function invalidateEmailVerificationToken',
  );
  const consume = block(
    repository,
    'export async function consumeEmailVerificationToken',
  );
  assert.match(insert, /FOR NO KEY UPDATE/);
  assert.match(insert, /UPDATE email_verification_tokens/);
  assert.match(insert, /token_hash/);
  assert.match(consume, /SELECT user_id FROM email_verification_tokens/);
  assert.match(consume, /FOR NO KEY UPDATE/);
  assert.match(consume, /FOR UPDATE/);
  assert.match(consume, /expires_at/);
  assert.match(consume, /status='PENDING_EMAIL_VERIFICATION'/);
  assert.match(consume, /used_at=NOW\(\)/);
});

test('verification codes are stored as hashes and delivery sends codes through signed webhook only', () => {
  const migration = read('backend/src/db/migrations/042_email_verification_tokens.js');
  const delivery = read('backend/src/services/session.js');
  const route = read('backend/src/routes/auth_routes.js');
  assert.match(migration, /token_hash TEXT NOT NULL UNIQUE/);
  assert.match(migration, /expires_at TIMESTAMPTZ NOT NULL/);
  assert.match(delivery, /type, userId: user.id, email: user.email, code, expiresInSeconds/);
  assert.match(delivery, /createHmac\('sha256'/);
  assert.match(delivery, /'EMAIL_VERIFICATION_DELIVERY'/);
  assert.match(route, /exposeEmailVerificationCodeInDevelopment/);
  assert.match(route, /process\.env\.NODE_ENV !== 'production'/);
  assert.doesNotMatch(route, /createAudit\([^\n]*code/);
});
