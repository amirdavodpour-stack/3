import test, { after } from 'node:test';
import assert from 'node:assert/strict';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-human-chat-postgres-integration.json';

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/db/migrations/034_chat_capabilities.js'),
      import('../src/repository/human_chat.js'),
    ])
  : [];
const dbModule = modules[0];
const migration = modules[1]?.migration;
const { closeJobChatForJob, postChatMessage } = modules[2] || {};

if (enabled) await dbModule.initDatabase();

async function waitForConversationRowLock(pool, timeoutMs = 6000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const { rows } = await pool.query(`
      SELECT pid
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND pid <> pg_backend_pid()
        AND wait_event_type = 'Lock'
        AND query ILIKE '%FOR UPDATE OF c%'
    `);
    if (rows.length) return;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(
    'postChatMessage did not wait for the conversation row lock; close-vs-send serialization is missing',
  );
}

test('migration 034 up is idempotent against real PostgreSQL', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const client = await pool.connect();
  try {
    await migration.up(client);
    await migration.up(client);

    const { rows: tables } = await client.query(`
      SELECT table_name FROM information_schema.tables
      WHERE table_schema = current_schema()
        AND table_name = ANY($1::text[])
    `, [[
      'chat_message_attachments',
      'chat_message_reads',
      'chat_presence',
      'chat_conversation_preferences',
    ]]);
    assert.equal(tables.length, 4);

    const { rows: constraint } = await client.query(`
      SELECT 1 FROM pg_constraint
      WHERE conrelid = 'chat_messages'::regclass
        AND conname = 'chat_messages_message_type_check'
    `);
    assert.equal(constraint.length, 1);
  } finally {
    client.release();
  }
});

test('migration 034 downgrade preserves retained read, presence and preference data', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const { rows: conversations } = await pool.query(`
    SELECT c.id, j.owner_id
    FROM chat_conversations c
    JOIN jobs j ON j.id = c.job_id
    ORDER BY c.created_at DESC
    LIMIT 1
  `);
  assert.ok(conversations[0], 'postgres repository e2e fixture must provide a job conversation');
  const conversation = conversations[0];

  const { rows: messages } = await pool.query(`
    INSERT INTO chat_messages(id, conversation_id, sender_id, body, message_type)
    VALUES(gen_random_uuid(), $1, $2, 'R05 rollback guard fixture', 'TEXT')
    RETURNING id
  `, [conversation.id, conversation.owner_id]);
  const messageId = messages[0].id;

  const cases = [
    {
      table: 'chat_message_reads',
      insert: 'INSERT INTO chat_message_reads(message_id, user_id) VALUES($1, $2)',
      values: [messageId, conversation.owner_id],
    },
    {
      table: 'chat_presence',
      insert: 'INSERT INTO chat_presence(conversation_id, user_id) VALUES($1, $2)',
      values: [conversation.id, conversation.owner_id],
    },
    {
      table: 'chat_conversation_preferences',
      insert: 'INSERT INTO chat_conversation_preferences(conversation_id, user_id, is_pinned) VALUES($1, $2, TRUE)',
      values: [conversation.id, conversation.owner_id],
    },
  ];

  for (const item of cases) {
    const client = await pool.connect();
    let inTransaction = false;
    let downgradeError;
    try {
      await client.query('BEGIN');
      inTransaction = true;
      // The capability row exists before the rollback attempt, so rollback to
      // the savepoint restores the schema but retains the pre-existing data.
      await client.query(item.insert, item.values);
      await client.query('SAVEPOINT before_downgrade');

      try {
        await migration.down(client);
      } catch (error) {
        downgradeError = error;
      }

      await client.query('ROLLBACK TO SAVEPOINT before_downgrade');
      await client.query('COMMIT');
      inTransaction = false;
    } finally {
      if (inTransaction) await client.query('ROLLBACK').catch(() => {});
      client.release();
    }

    assert.ok(
      downgradeError,
      `migration 034 down must refuse to drop ${item.table} data`,
    );
    assert.match(downgradeError.message, /Cannot rollback chat_capabilities/);
    const { rows: remains } = await pool.query(
      'SELECT 1 FROM information_schema.tables WHERE table_schema = current_schema() AND table_name = $1',
      [item.table],
    );
    assert.equal(remains.length, 1, `${item.table} must remain after rejected downgrade`);
    const { rows: retainedRows } = await pool.query(
      `SELECT 1 FROM ${item.table} LIMIT 1`,
    );
    assert.equal(retainedRows.length, 1, `${item.table} records must survive a rejected downgrade`);
  }
});

test('send waits for an in-flight close and rejects when CLOSED commits first', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const { rows } = await pool.query(`
    SELECT c.id AS conversation_id, c.job_id, j.owner_id
    FROM chat_conversations c
    JOIN jobs j ON j.id = c.job_id
    WHERE c.kind = 'JOB'
    ORDER BY c.created_at DESC
    LIMIT 1
  `);
  assert.ok(rows[0], 'postgres repository e2e fixture must provide a job conversation');
  const conversation = rows[0];

  // Re-open only this disposable integration fixture so the close transaction
  // and send can race from a known OPEN state.
  await pool.query(
    "UPDATE chat_conversations SET status = 'OPEN', closed_at = NULL WHERE id = $1",
    [conversation.conversation_id],
  );

  const closeClient = await pool.connect();
  let closeTransactionOpen = false;
  let waitError;
  const body = `R05 concurrent close/send ${Date.now()}`;
  let sendOutcome;

  try {
    await closeClient.query('BEGIN');
    closeTransactionOpen = true;
    const closed = await closeJobChatForJob(conversation.job_id, closeClient);
    assert.equal(closed, true);

    // Launch only after the close UPDATE owns the conversation row lock.
    // Under READ COMMITTED, the sender's initial non-locking precheck can
    // still observe OPEN; its in-transaction FOR UPDATE must wait and then
    // reject after this close commits.
    sendOutcome = postChatMessage(
      conversation.conversation_id,
      conversation.owner_id,
      'USER',
      body,
    ).then(
      (message) => ({ outcome: 'fulfilled', message }),
      (error) => ({ outcome: 'rejected', error }),
    );

    try {
      await waitForConversationRowLock(pool);
    } catch (error) {
      waitError = error;
    }

    await closeClient.query('COMMIT');
    closeTransactionOpen = false;
  } finally {
    if (closeTransactionOpen) await closeClient.query('ROLLBACK').catch(() => {});
    closeClient.release();
  }

  const outcome = await sendOutcome;
  assert.ifError(waitError);
  assert.equal(outcome.outcome, 'rejected');
  assert.equal(outcome.error?.code, 'CHAT_CLOSED_OR_FORBIDDEN');

  const { rows: persisted } = await pool.query(
    'SELECT id FROM chat_messages WHERE conversation_id = $1 AND body = $2',
    [conversation.conversation_id, body],
  );
  assert.equal(persisted.length, 0, 'message must not persist after CLOSED wins the row-lock race');
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
