import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { Readable, Writable } from 'node:stream';
import { createHumanChatRoutes } from '../src/routes/human_chat_routes.js';

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
const {
  closeJobChatForJob,
  postChatMessage,
  getChatConversationForUser,
  listChatMessages,
  markChatConversationRead,
  updateChatPresence,
  listChatPresence,
  updateChatConversationPreferences,
  getChatAttachmentForUser,
} = modules[2] || {};

let fixture = null;
if (enabled) {
  await dbModule.initDatabase();
  const pool = dbModule.getPool();
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const { rows: owners } = await pool.query(`
    INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
    VALUES(gen_random_uuid(),$1,'r05-integration-only','R05 chat owner','USER','ACTIVE',0,NOW())
    RETURNING id
  `, [`r05-owner-${suffix}@example.test`]);
  const { rows: workers } = await pool.query(`
    INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
    VALUES(gen_random_uuid(),$1,'r05-integration-only','R05 chat worker','USER','ACTIVE',0,NOW())
    RETURNING id
  `, [`r05-worker-${suffix}@example.test`]);
  const { rows: outsiders } = await pool.query(`
    INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
    VALUES(gen_random_uuid(),$1,'r05-integration-only','R05 chat outsider','USER','ACTIVE',0,NOW())
    RETURNING id
  `, [`r05-outsider-${suffix}@example.test`]);
  const { rows: admins } = await pool.query(`
    INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
    VALUES(gen_random_uuid(),$1,'r05-integration-only','R05 chat admin','ADMIN','ACTIVE',0,NOW())
    RETURNING id
  `, [`r05-admin-${suffix}@example.test`]);
  const { rows: categories } = await pool.query(`
    SELECT id FROM categories WHERE is_active=TRUE ORDER BY created_at NULLS FIRST,id LIMIT 1
  `);
  if (!categories[0]) throw new Error('R05 fixture requires at least one active category');
  const { rows: jobs } = await pool.query(`
    INSERT INTO jobs(
      id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
      budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
      created_at,updated_at
    )
    VALUES(
      gen_random_uuid(),$1,$2,'R05 PostgreSQL chat fixture','Integration-only fixture',
      $3,'FIXED','FIXED',100,100,1,'R05 integration fixture','IN_PROGRESS',
      'R05 test','MISSION','PUBLIC',NOW(),NOW()
    )
    RETURNING id
  `, [owners[0].id, workers[0].id, categories[0].id]);
  const { rows: conversations } = await pool.query(`
    INSERT INTO chat_conversations(id,kind,job_id,status,title)
    VALUES(gen_random_uuid(),'JOB',$1,'OPEN','R05 PostgreSQL chat fixture')
    RETURNING id
  `, [jobs[0].id]);
  const { rows: adminConversations } = await pool.query(`
    INSERT INTO chat_conversations(id,kind,job_id,status,title)
    VALUES(gen_random_uuid(),'ADMIN',NULL,'OPEN','R05 PostgreSQL admin fixture')
    RETURNING id
  `);
  fixture = {
    ownerId: owners[0].id,
    workerId: workers[0].id,
    outsiderId: outsiders[0].id,
    adminId: admins[0].id,
    jobId: jobs[0].id,
    conversationId: conversations[0].id,
    adminConversationId: adminConversations[0].id,
  };
}

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
  const conversation = {
    id: fixture.conversationId,
    owner_id: fixture.ownerId,
    job_id: fixture.jobId,
  };

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
      cleanup: 'DELETE FROM chat_message_reads WHERE message_id=$1 AND user_id=$2',
      values: [messageId, conversation.owner_id],
    },
    {
      table: 'chat_presence',
      insert: 'INSERT INTO chat_presence(conversation_id, user_id) VALUES($1, $2)',
      cleanup: 'DELETE FROM chat_presence WHERE conversation_id=$1 AND user_id=$2',
      values: [conversation.id, conversation.owner_id],
    },
    {
      table: 'chat_conversation_preferences',
      insert: 'INSERT INTO chat_conversation_preferences(conversation_id, user_id, is_pinned) VALUES($1, $2, TRUE)',
      cleanup: 'DELETE FROM chat_conversation_preferences WHERE conversation_id=$1 AND user_id=$2',
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
    await pool.query(item.cleanup, item.values);
  }
});

test('chat participants, read receipts, presence and preferences enforce PostgreSQL authorization', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const conversationId = fixture.conversationId;

  assert.ok(await getChatConversationForUser(conversationId, fixture.ownerId, 'USER'));
  assert.ok(await getChatConversationForUser(conversationId, fixture.workerId, 'USER'));
  assert.equal(await getChatConversationForUser(conversationId, fixture.outsiderId, 'USER'), null);
  assert.equal(await getChatConversationForUser(conversationId, fixture.adminId, 'ADMIN'), null);
  assert.ok(await getChatConversationForUser(fixture.adminConversationId, fixture.adminId, 'ADMIN'));
  assert.equal(await getChatConversationForUser(fixture.adminConversationId, fixture.outsiderId, 'USER'), null);

  const workerMessage = await postChatMessage(
    conversationId, fixture.workerId, 'USER', 'R05 unread message',
  );
  const firstRead = await markChatConversationRead(conversationId, fixture.ownerId, 'USER');
  const repeatedRead = await markChatConversationRead(conversationId, fixture.ownerId, 'USER');
  assert.equal(firstRead.readCount, 1);
  assert.equal(repeatedRead.readCount, 0);

  const listed = await listChatMessages(conversationId, fixture.ownerId, 'USER');
  const readMessage = listed.messages.find((message) => message.id === workerMessage.id);
  assert.ok(readMessage);
  assert.ok(readMessage.readReceipts.some((receipt) => receipt.userId === fixture.ownerId));

  const presence = await updateChatPresence(
    conversationId, fixture.ownerId, 'USER', { online: true, typing: true },
  );
  assert.equal(presence.online, true);
  const visiblePresence = await listChatPresence(conversationId, fixture.workerId, 'USER');
  assert.ok(visiblePresence.some((entry) => entry.userId === fixture.ownerId));
  assert.equal(
    await updateChatPresence(conversationId, fixture.outsiderId, 'USER', { online: true }),
    null,
  );
  assert.equal(await listChatPresence(conversationId, fixture.outsiderId, 'USER'), null);

  const preferences = await updateChatConversationPreferences(
    conversationId, fixture.ownerId, 'USER', { isPinned: true, isImportant: true },
  );
  assert.equal(preferences.isPinned, true);
  assert.equal(preferences.isImportant, true);
  assert.equal(
    await updateChatConversationPreferences(
      conversationId, fixture.outsiderId, 'USER', { isPinned: true },
    ),
    null,
  );
  const { rows: outsiderPreferences } = await pool.query(
    'SELECT 1 FROM chat_conversation_preferences WHERE conversation_id=$1 AND user_id=$2',
    [conversationId, fixture.outsiderId],
  );
  assert.equal(outsiderPreferences.length, 0);
});

test('attachment ownership, voice consumption and private download are enforced by PostgreSQL-backed chat', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const makeUpload = async (userId, contentType, suffix) => {
    const key = `r05/${suffix}/${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const { rows } = await pool.query(`
      INSERT INTO uploads(id,storage_key,uploaded_by,content_type,size,created_at)
      VALUES(gen_random_uuid(),$1,$2,$3,24,NOW())
      RETURNING id,storage_key
    `, [key, userId, contentType]);
    return rows[0];
  };

  const ownerUpload = await makeUpload(fixture.ownerId, 'application/pdf', 'owner-file');
  await assert.rejects(
    postChatMessage(fixture.conversationId, fixture.workerId, 'USER', '', {
      messageType: 'ATTACHMENT',
      attachments: [{ key: ownerUpload.storage_key, filename: 'owner.pdf' }],
    }),
    (error) => error.code === 'CHAT_ATTACHMENT_UPLOAD_NOT_FOUND',
  );

  const fileUpload = await makeUpload(fixture.ownerId, 'application/pdf', 'download-file');
  const fileBody = `R05 attachment one-shot ${Date.now()}`;
  const fileResults = await Promise.allSettled([
    postChatMessage(fixture.conversationId, fixture.ownerId, 'USER', fileBody, {
      messageType: 'ATTACHMENT',
      attachments: [{ key: fileUpload.storage_key, filename: 'quarterly report.pdf' }],
    }),
    postChatMessage(fixture.conversationId, fixture.ownerId, 'USER', fileBody, {
      messageType: 'ATTACHMENT',
      attachments: [{ key: fileUpload.storage_key, filename: 'quarterly report.pdf' }],
    }),
  ]);
  const acceptedFiles = fileResults.filter((result) => result.status === 'fulfilled');
  const rejectedFiles = fileResults.filter((result) => result.status === 'rejected');
  assert.equal(acceptedFiles.length, 1);
  assert.equal(rejectedFiles.length, 1);
  assert.equal(rejectedFiles[0].reason.code, 'CHAT_ATTACHMENT_ALREADY_USED');
  assert.equal(acceptedFiles[0].value.attachments.length, 1);

  const attachmentId = acceptedFiles[0].value.attachments[0].id;
  const ownerMetadata = await getChatAttachmentForUser(attachmentId, fixture.ownerId, 'USER');
  assert.ok(ownerMetadata);
  assert.equal(ownerMetadata.filename, 'quarterly report.pdf');
  assert.ok(await getChatAttachmentForUser(attachmentId, fixture.workerId, 'USER'));
  assert.equal(await getChatAttachmentForUser(attachmentId, fixture.outsiderId, 'USER'), null);
  assert.equal(await getChatAttachmentForUser(attachmentId, fixture.adminId, 'ADMIN'), null);

  const payload = Buffer.from('R05 private attachment bytes', 'utf8');
  let storageReads = 0;
  let viewer = { id: fixture.ownerId, role: 'USER' };
  const route = createHumanChatRoutes({
    authUser: async () => viewer,
    sendJson: (res, status, body) => {
      res.statusCode = status;
      res.payload = body;
      return body;
    },
    readBody: async () => ({}),
    HttpError: class TestHttpError extends Error {
      constructor(status, code, message) {
        super(message);
        this.status = status;
        this.code = code;
      }
    },
    repo: { getChatAttachmentForUser },
    storage: {
      get: async ({ key }) => {
        storageReads += 1;
        assert.equal(key, fileUpload.storage_key);
        return { size: payload.length, body: Readable.from([payload]) };
      },
    },
  });

  const responseChunks = [];
  const response = new Writable({
    write(chunk, encoding, callback) {
      responseChunks.push(Buffer.from(chunk));
      callback();
    },
  });
  response.writeHead = (status, headers) => {
    response.statusCode = status;
    response.headers = headers;
    return response;
  };
  const finished = once(response, 'finish');
  await route(
    { method: 'GET' },
    response,
    ['messaging', 'attachments', attachmentId, 'content'],
  );
  await finished;
  assert.equal(response.statusCode, 200);
  assert.equal(Buffer.concat(responseChunks).toString('utf8'), payload.toString('utf8'));
  assert.equal(response.headers['Cache-Control'], 'private, no-store');
  assert.equal(response.headers['X-Content-Type-Options'], 'nosniff');
  assert.match(response.headers['Content-Disposition'], /quarterly%20report.pdf/);

  viewer = { id: fixture.outsiderId, role: 'USER' };
  await assert.rejects(
    route({ method: 'GET' }, new Writable({ write(chunk, encoding, callback) { callback(); } }),
      ['messaging', 'attachments', attachmentId, 'content']),
    (error) => error.status === 404 && error.code === 'CHAT_ATTACHMENT_NOT_FOUND',
  );
  assert.equal(storageReads, 1, 'unauthorized download must not read from storage');

  const voiceUpload = await makeUpload(fixture.ownerId, 'audio/mpeg', 'voice-note');
  const voiceBody = `R05 concurrent voice ${Date.now()}`;
  const voiceResults = await Promise.allSettled([
    postChatMessage(fixture.conversationId, fixture.ownerId, 'USER', '', {
      messageType: 'VOICE',
      attachments: [{ key: voiceUpload.storage_key, filename: 'voice-note.mp3' }],
    }),
    postChatMessage(fixture.conversationId, fixture.ownerId, 'USER', '', {
      messageType: 'VOICE',
      attachments: [{ key: voiceUpload.storage_key, filename: 'voice-note.mp3' }],
    }),
  ]);
  const acceptedVoice = voiceResults.filter((result) => result.status === 'fulfilled');
  const rejectedVoice = voiceResults.filter((result) => result.status === 'rejected');
  assert.equal(acceptedVoice.length, 1);
  assert.equal(rejectedVoice.length, 1);
  assert.equal(rejectedVoice[0].reason.code, 'CHAT_ATTACHMENT_ALREADY_USED');
  assert.equal(acceptedVoice[0].value.messageType, 'VOICE');
  assert.equal(acceptedVoice[0].value.attachments.length, 1);

  const { rows: voiceRows } = await pool.query(
    `SELECT COUNT(*)::int AS messages
     FROM chat_messages WHERE conversation_id=$1 AND message_type='VOICE' AND body='Voice message'`,
    [fixture.conversationId],
  );
  assert.equal(voiceRows[0].messages, 1, 'voice message and attachment must commit once, atomically');
});

test('send waits for an in-flight close and rejects when CLOSED commits first', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const conversation = {
    conversation_id: fixture.conversationId,
    job_id: fixture.jobId,
    owner_id: fixture.ownerId,
  };

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
