import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-email-verification-postgres-integration.json';

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository/auth.js'),
    ])
  : [];
const dbModule = modules[0];
const {
  insertEmailVerificationToken,
  consumeEmailVerificationToken,
} = modules[1] || {};

if (enabled) await dbModule.initDatabase();

const pool = enabled ? dbModule.getPool() : null;

async function createPendingUser(label) {
  const id = crypto.randomUUID();
  const email = `email-verification-${label}-${crypto.randomUUID()}@example.test`;
  await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,created_at
     ) VALUES($1,$2,'integration-test-hash','Email verification test','USER',
       'PENDING_EMAIL_VERIFICATION',0,NOW())`,
    [id,email],
  );
  return { id,email };
}

function tokenDraft(userId, rawToken, expiresAt = new Date(Date.now() + 60_000)) {
  return {
    id: crypto.randomUUID(),
    userId,
    tokenHash: crypto.createHash('sha256').update(rawToken).digest('hex'),
    expiresAt: expiresAt.toISOString(),
    usedAt: null,
    createdAt: new Date().toISOString(),
  };
}

test('resend locks the user before invalidating and replacing active verification tokens', {
  skip: !enabled,
  timeout: 20_000,
}, async () => {
  const user = await createPendingUser('resend-lock');
  const previous = tokenDraft(user.id, crypto.randomBytes(32).toString('hex'));
  const replacement = tokenDraft(user.id, crypto.randomBytes(32).toString('hex'));
  const blocker = await pool.connect();

  try {
    await insertEmailVerificationToken(previous);
    await blocker.query('BEGIN');
    await blocker.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [user.id]);

    let replacementSettled = false;
    const replacementWork = insertEmailVerificationToken(replacement).then((value) => {
      replacementSettled = true;
      return value;
    });

    await new Promise((resolve) => setTimeout(resolve, 250));
    const completedWhileUserRowWasLocked = replacementSettled;

    await blocker.query('ROLLBACK');
    await replacementWork;

    assert.equal(
      completedWhileUserRowWasLocked,
      false,
      'a resend must wait on the account row before touching that account\'s active tokens',
    );

    const { rows } = await pool.query(
      `SELECT token_hash,used_at FROM email_verification_tokens
        WHERE user_id=$1 ORDER BY created_at,id`,
      [user.id],
    );
    assert.equal(rows.length, 2);
    assert.ok(rows.find((row) => row.token_hash === previous.tokenHash)?.used_at);
    assert.equal(rows.find((row) => row.token_hash === replacement.tokenHash)?.used_at, null);

    const stale = await consumeEmailVerificationToken(previous.tokenHash);
    assert.equal(stale, null, 'the superseded verification code must no longer activate the account');
  } finally {
    await blocker.query('ROLLBACK').catch(() => {});
    blocker.release();
    await pool.query('DELETE FROM users WHERE id=$1', [user.id]).catch(() => {});
  }
});

test('concurrent verification attempts can activate an account only once', {
  skip: !enabled,
  timeout: 20_000,
}, async () => {
  const user = await createPendingUser('consume-race');
  const token = tokenDraft(user.id, crypto.randomBytes(32).toString('hex'));

  try {
    await insertEmailVerificationToken(token);
    const results = await Promise.all([
      consumeEmailVerificationToken(token.tokenHash),
      consumeEmailVerificationToken(token.tokenHash),
    ]);

    assert.equal(results.filter(Boolean).length, 1);
    const { rows: users } = await pool.query(
      'SELECT status FROM users WHERE id=$1',
      [user.id],
    );
    assert.equal(users[0]?.status, 'ACTIVE');
    const { rows: tokens } = await pool.query(
      'SELECT used_at FROM email_verification_tokens WHERE token_hash=$1',
      [token.tokenHash],
    );
    assert.ok(tokens[0]?.used_at);
  } finally {
    await pool.query('DELETE FROM users WHERE id=$1', [user.id]).catch(() => {});
  }
});

test('expired verification token cannot activate a pending account', {
  skip: !enabled,
}, async () => {
  const user = await createPendingUser('expired');
  const token = tokenDraft(
    user.id,
    crypto.randomBytes(32).toString('hex'),
    new Date(Date.now() - 60_000),
  );

  try {
    await insertEmailVerificationToken(token);
    assert.equal(await consumeEmailVerificationToken(token.tokenHash), null);
    const { rows } = await pool.query(
      'SELECT status FROM users WHERE id=$1',
      [user.id],
    );
    assert.equal(rows[0]?.status, 'PENDING_EMAIL_VERIFICATION');
  } finally {
    await pool.query('DELETE FROM users WHERE id=$1', [user.id]).catch(() => {});
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
