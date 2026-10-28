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
      import('../src/repository/privacy.js'),
      import('../src/repository/storage.js'),
      import('../src/wallet_ledger.js'),
      import('../src/repository/payouts.js'),
      import('../src/config.js'),
      import('../src/repository/payment_webhooks.js'),
    ])
  : [];
const dbModule = modules[0];
const migration = modules[1]?.migration;
const { deleteUserPrivacyBundle } = modules[3] || {};
const { insertUpload, createUploadIntent, completeUploadAtomic } = modules[4] || {};
const { transferAvailable, creditWallet, getWalletByUserId, ensureWalletForUserPublic, postInternalPaymentHoldWithClient } = modules[5] || {};
const { requestPayoutAtomic } = modules[6] || {};
const { config: appConfig } = modules[7] || {};
const { applyPaymentWebhookAtomic } = modules[8] || {};
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

test('migration 034 scopes the message type constraint check to chat_messages', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const client = await pool.connect();
  let targetConstraintDropped = false;
  try {
    await client.query(`
      CREATE TEMP TABLE r05_constraint_name_collision (
        value TEXT CONSTRAINT chat_messages_message_type_check CHECK (value IS NOT NULL)
      )
    `);
    await client.query(
      'ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_message_type_check',
    );
    targetConstraintDropped = true;

    await migration.up(client);

    const { rows } = await client.query(`
      SELECT 1 FROM pg_constraint
      WHERE conrelid = 'chat_messages'::regclass
        AND conname = 'chat_messages_message_type_check'
    `);
    assert.equal(
      rows.length,
      1,
      'a same-named constraint on another relation must not suppress the chat_messages constraint',
    );
  } finally {
    if (targetConstraintDropped) {
      const { rows } = await client.query(`
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'chat_messages'::regclass
          AND conname = 'chat_messages_message_type_check'
      `).catch(() => ({rows: []}));
      if (!rows.length) {
        await client.query(`
          ALTER TABLE chat_messages
          ADD CONSTRAINT chat_messages_message_type_check
          CHECK (message_type IN ('TEXT','ATTACHMENT','VOICE'))
        `).catch(() => {});
      }
    }
    await client.query('DROP TABLE IF EXISTS pg_temp.r05_constraint_name_collision').catch(() => {});
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
  const makeUpload = async (userId, contentType, suffix, size = 24) => {
    const key = `r05/${suffix}/${Date.now()}-${Math.random().toString(16).slice(2)}`;
    const { rows } = await pool.query(`
      INSERT INTO uploads(id,storage_key,uploaded_by,content_type,size,created_at)
      VALUES(gen_random_uuid(),$1,$2,$3,$4,NOW())
      RETURNING id,storage_key
    `, [key, userId, contentType, size]);
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

  const payload = Buffer.from('R05 private attachment bytes', 'utf8');
  const fileUpload = await makeUpload(
    fixture.ownerId, 'application/pdf', 'download-file', payload.length,
  );
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
  assert.equal(response.headers['Content-Length'], String(payload.length));
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

test('account deletion preserves a concurrent chat attachment, retains cleanup tombstones and blocks further uploads', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const storageKey = `r05-race-${suffix}.pdf`;
  const { rows: uploads } = await pool.query(
    `INSERT INTO uploads(id,storage_key,uploaded_by,content_type,size,created_at)
     VALUES(gen_random_uuid(),$1,$2,'application/pdf',128,NOW()) RETURNING id`,
    [storageKey, fixture.workerId],
  );
  const uploadId = uploads[0].id;
  const pendingKey = `r05-pending-race-${suffix}.pdf`;
  await pool.query(
    `INSERT INTO upload_intents(id,storage_key,uploaded_by,content_type,expires_at,created_at)
     VALUES(gen_random_uuid(),$1,$2,'application/pdf',NOW()+INTERVAL '5 minutes',NOW())`,
    [pendingKey, fixture.workerId],
  );
  const holder = await pool.connect();
  let transactionOpen = false;
  let deletionPromise;
  try {
    await holder.query('BEGIN');
    transactionOpen = true;
    await holder.query('SELECT id FROM uploads WHERE id=$1 FOR UPDATE', [uploadId]);
    deletionPromise = deleteUserPrivacyBundle(fixture.workerId, {
      email: `deleted+${fixture.workerId}@invalid.local`,
      passwordHash: 'integration-only-deleted-account',
    });
    const deadline = Date.now() + 6000;
    let waiting = false;
    while (Date.now() < deadline) {
      const { rows } = await pool.query(`
        SELECT pid FROM pg_stat_activity
        WHERE datname=current_database() AND pid<>pg_backend_pid()
          AND wait_event_type='Lock'
          AND query ILIKE '%FROM uploads WHERE uploaded_by=$1 ORDER BY id FOR UPDATE%'
      `);
      if (rows.length) { waiting = true; break; }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    assert.equal(waiting, true, 'account deletion must wait on the owned upload row lock');
    const { rows: messages } = await holder.query(
      `INSERT INTO chat_messages(id,conversation_id,sender_id,body,message_type)
       VALUES(gen_random_uuid(),$1,$2,'Race attachment','ATTACHMENT') RETURNING id`,
      [fixture.conversationId, fixture.workerId],
    );
    await holder.query(
      `INSERT INTO chat_message_attachments(id,message_id,upload_id,storage_key,filename,content_type,size)
       VALUES(gen_random_uuid(),$1,$2,$3,'race.pdf','application/pdf',128)`,
      [messages[0].id, uploadId, storageKey],
    );
    await holder.query('COMMIT');
    transactionOpen = false;
  } finally {
    if (transactionOpen) await holder.query('ROLLBACK').catch(() => {});
    holder.release();
  }
  const deletion = await deletionPromise;
  assert.equal(deletion.deleted, true);
  assert.ok(deletion.pendingUploadIntentKeys.includes(pendingKey),
    'pending presigned keys must be returned for immediate best-effort deletion');
  const { rows: retainedIntent } = await pool.query(
    `SELECT id,uploaded_by FROM upload_intents WHERE storage_key=$1`, [pendingKey],
  );
  assert.equal(retainedIntent.length, 1, 'pending intent remains as a durable expiry/grace cleanup tombstone');
  assert.equal(retainedIntent[0].uploaded_by, fixture.workerId);
  assert.ok(!deletion.deletableUploadKeys.includes(storageKey),
    'the committed chat reference must exclude the blob from post-commit storage deletion');
  const { rows: associations } = await pool.query(
    `SELECT a.storage_key,u.uploaded_by
       FROM chat_message_attachments a JOIN uploads u ON u.id=a.upload_id
      WHERE a.upload_id=$1`,
    [uploadId],
  );
  assert.equal(associations.length, 1);
  assert.equal(associations[0].storage_key, storageKey);
  assert.equal(associations[0].uploaded_by, null);

  const inactiveAccount = (error) => error?.code === 'ACCOUNT_INACTIVE';
  await assert.rejects(() => createUploadIntent({
    id: '11111111-1111-4111-8111-111111111111',
    storageKey: `r05-after-delete-intent-${suffix}.pdf`,
    uploadedBy: fixture.workerId,
    contentType: 'application/pdf',
    expiresAt: new Date(Date.now() + 300_000).toISOString(),
    createdAt: new Date().toISOString(),
  }), inactiveAccount, 'deleted users cannot reserve new presigned uploads');
  await assert.rejects(() => insertUpload({
    id: '22222222-2222-4222-8222-222222222222',
    storageKey: `r05-after-delete-upload-${suffix}.pdf`,
    uploadedBy: fixture.workerId,
    contentType: 'application/pdf',
    size: 128,
    createdAt: new Date().toISOString(),
  }), inactiveAccount, 'deleted users cannot register new uploads');
  await assert.rejects(() => completeUploadAtomic({
    intentId: retainedIntent[0].id, key: pendingKey, userId: fixture.workerId,
    contentType: 'application/pdf', size: 128, createdAt: new Date().toISOString(),
  }), inactiveAccount, 'deleted users cannot complete a retained presigned intent');
});


test('account deletion serializes read receipts, presence and preferences before they can recreate user metadata', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const { rows: users } = await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES(gen_random_uuid(),$1,'r05-integration-only','R05 deletion race user','USER','ACTIVE',0,NOW())
     RETURNING id`,
    [`r05-delete-chat-race-${suffix}@example.test`],
  );
  const userId = users[0].id;
  const { rows: jobs } = await pool.query(
    `INSERT INTO jobs(
       id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
       budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
       created_at,updated_at
     )
     SELECT gen_random_uuid(),$1,$2,'R05 delete metadata race','Integration-only fixture',
       c.id,'FIXED','FIXED',100,100,1,'R05 integration fixture','IN_PROGRESS',
       'R05 test','MISSION','PUBLIC',NOW(),NOW()
     FROM categories c WHERE c.is_active=TRUE
     ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1
     RETURNING id`,
    [fixture.ownerId, userId],
  );
  assert.ok(jobs[0], 'race fixture requires an active category');
  const { rows: conversations } = await pool.query(
    `INSERT INTO chat_conversations(id,kind,job_id,status,title)
     VALUES(gen_random_uuid(),'JOB',$1,'OPEN','R05 delete metadata race')
     RETURNING id`,
    [jobs[0].id],
  );
  const conversationId = conversations[0].id;
  await pool.query(
    `INSERT INTO chat_messages(id,conversation_id,sender_id,body,message_type)
     VALUES(gen_random_uuid(),$1,$2,'Seed message for deletion race','TEXT')`,
    [conversationId, fixture.ownerId],
  );
  const { rows: auditRows } = await pool.query(
    `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
     VALUES(gen_random_uuid(),'R05_CHAT_DELETE_RACE',$1,'test',$2,'{}'::jsonb,NOW())
     RETURNING id`,
    [userId, jobs[0].id],
  );

  const holder = await pool.connect();
  let holderOpen = false;
  let deletionPromise;
  const outcomes = [null, null, null];
  let settledWriters = [];
  try {
    await holder.query('BEGIN');
    holderOpen = true;
    await holder.query('SELECT id FROM audit_logs WHERE id=$1 FOR UPDATE', [auditRows[0].id]);

    deletionPromise = deleteUserPrivacyBundle(userId, {
      email: `deleted+${userId}@invalid.local`,
      passwordHash: 'integration-only-deleted-account',
    });

    const deletionDeadline = Date.now() + 6000;
    let deletionBlockedAfterMetadataCleanup = false;
    while (Date.now() < deletionDeadline) {
      const { rows } = await pool.query(`
        SELECT pid FROM pg_stat_activity
        WHERE datname=current_database() AND pid<>pg_backend_pid()
          AND wait_event_type='Lock'
          AND query ILIKE '%UPDATE audit_logs SET actor_id=NULL WHERE actor_id=$1%'
      `);
      if (rows.length) { deletionBlockedAfterMetadataCleanup = true; break; }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    assert.equal(
      deletionBlockedAfterMetadataCleanup,
      true,
      'deletion must reach the post-chat-cleanup audit update before the metadata writers race',
    );

    const writers = [
      markChatConversationRead(conversationId, userId, 'USER'),
      updateChatPresence(conversationId, userId, 'USER', { online: true, typing: true }),
      updateChatConversationPreferences(conversationId, userId, 'USER', { isPinned: true, isImportant: true }),
    ];
    settledWriters = writers.map((writer, index) => writer.then(
      (value) => { outcomes[index] = { ok: true, value }; },
      (error) => { outcomes[index] = { ok: false, error }; },
    ));

    const writerDeadline = Date.now() + 6000;
    let allWritersSettledOrSerialized = false;
    while (Date.now() < writerDeadline) {
      const { rows } = await pool.query(`
        SELECT COUNT(*)::int AS count FROM pg_stat_activity
        WHERE datname=current_database() AND pid<>pg_backend_pid()
          AND wait_event_type='Lock'
          AND (
            query ILIKE '%lockActiveChatAccount%'
            OR query ILIKE '%INSERT INTO chat_message_reads%'
            OR query ILIKE '%INSERT INTO chat_presence%'
            OR query ILIKE '%INSERT INTO chat_conversation_preferences%'
          )
      `);
      const blockedOnAccount = Number(rows[0]?.count || 0);
      const settledCount = outcomes.filter(Boolean).length;
      if (settledCount + blockedOnAccount >= writers.length) {
        allWritersSettledOrSerialized = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    assert.equal(
      allWritersSettledOrSerialized,
      true,
      'each writer must either finish before deletion wins (regression) or wait on the account serialization lock',
    );
  } finally {
    if (holderOpen) await holder.query('COMMIT').catch(() => {});
    holder.release();
  }

  const deletion = await deletionPromise;
  assert.equal(deletion.deleted, true);
  await Promise.all(settledWriters);
  for (const outcome of outcomes) {
    assert.ok(outcome, 'every chat metadata writer must settle');
    assert.equal(outcome.ok, false, 'writers queued behind deletion must not recreate metadata');
    assert.equal(outcome.error?.code, 'ACCOUNT_INACTIVE');
  }

  const { rows: persisted } = await pool.query(
    `SELECT
       (SELECT COUNT(*)::int FROM chat_presence WHERE user_id=$1) AS presence,
       (SELECT COUNT(*)::int FROM chat_conversation_preferences WHERE user_id=$1) AS preferences,
       (SELECT COUNT(*)::int FROM chat_message_reads WHERE user_id=$1) AS reads`,
    [userId],
  );
  assert.equal(persisted[0].presence, 0);
  assert.equal(persisted[0].preferences, 0);
  assert.equal(persisted[0].reads, 0);
});



async function createTransferTestUser(pool, prefix) {
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const { rows } = await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES(gen_random_uuid(),$1,'test','Wallet transfer test','USER','ACTIVE',0,NOW())
     RETURNING id`,
    [`${prefix}-${suffix}@example.test`],
  );
  return rows[0].id;
}

test('wallet transfer rejects a deleted destination before creating its wallet', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const sourceId = await createTransferTestUser(pool, 'transfer-source');
  const destinationId = await createTransferTestUser(pool, 'transfer-deleted-destination');
  await creditWallet({
    userId: sourceId, amount: '1000', idempotencyKey: `wallet-seed-destination-${sourceId}`,
  });
  await pool.query(`UPDATE users SET status='DELETED' WHERE id=$1`, [destinationId]);

  await assert.rejects(
    transferAvailable({
      sourceUserId: sourceId, destinationUserId: destinationId,
      amount: '100', idempotencyKey: `transfer-to-deleted-${destinationId}`,
    }),
    (error) => error?.code === 'ACCOUNT_INACTIVE',
  );
  assert.equal(await getWalletByUserId(destinationId), null, 'a deleted destination must not get a new wallet as a side effect');
  assert.equal(String((await getWalletByUserId(sourceId)).available_balance), '1000', 'source funds must remain unchanged');
});

test('wallet transfer rejects a deleted source and preserves its remaining balance', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const sourceId = await createTransferTestUser(pool, 'transfer-deleted-source');
  const destinationId = await createTransferTestUser(pool, 'transfer-destination');
  await creditWallet({
    userId: sourceId, amount: '2500', idempotencyKey: `wallet-seed-deleted-source-${sourceId}`,
  });
  await pool.query(`UPDATE users SET status='DELETED' WHERE id=$1`, [sourceId]);

  await assert.rejects(
    transferAvailable({
      sourceUserId: sourceId, destinationUserId: destinationId,
      amount: '200', idempotencyKey: `transfer-from-deleted-${sourceId}`,
    }),
    (error) => error?.code === 'ACCOUNT_INACTIVE',
  );
  assert.equal(String((await getWalletByUserId(sourceId)).available_balance), '2500', 'deletion must not forfeit or move the retained balance');
  assert.equal(await getWalletByUserId(destinationId), null, 'the rejected transfer must not create a destination wallet');
});

test('wallet transfer serializes with account deletion and rejects after source becomes inactive', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const sourceId = await createTransferTestUser(pool, 'transfer-race-source');
  const destinationId = await createTransferTestUser(pool, 'transfer-race-destination');
  await creditWallet({
    userId: sourceId, amount: '3200', idempotencyKey: `wallet-seed-race-source-${sourceId}`,
  });
  await creditWallet({
    userId: destinationId, amount: '300', idempotencyKey: `wallet-seed-race-destination-${destinationId}`,
  });

  const holder = await pool.connect();
  let holderOpen = false;
  let outcome = null;
  let blockedOnAccountLock = false;
  try {
    await holder.query('BEGIN');
    holderOpen = true;
    await holder.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [sourceId]);

    const writer = transferAvailable({
      sourceUserId: sourceId, destinationUserId: destinationId,
      amount: '400', idempotencyKey: `transfer-race-${sourceId}`,
    }).then(
      (value) => { outcome = { ok: true, value }; },
      (error) => { outcome = { ok: false, error }; },
    );

    const deadline = Date.now() + 6000;
    while (Date.now() < deadline) {
      const { rows } = await pool.query(`
        SELECT pid FROM pg_stat_activity
        WHERE datname=current_database() AND pid<>pg_backend_pid()
          AND wait_event_type='Lock'
          AND query ILIKE '%lockActiveWalletUsers%'
      `);
      if (rows.length) { blockedOnAccountLock = true; break; }
      if (outcome) break;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    await holder.query(`UPDATE users SET status='DELETED' WHERE id=$1`, [sourceId]);
    await holder.query('COMMIT');
    holderOpen = false;
    await writer;
  } finally {
    if (holderOpen) await holder.query('ROLLBACK').catch(() => {});
    holder.release();
  }

  assert.equal(blockedOnAccountLock, true, 'wallet transfer must wait on the same account row lock as deletion');
  assert.equal(outcome?.ok, false, 'the transfer must fail after the account deletion transaction wins');
  assert.equal(outcome?.error?.code, 'ACCOUNT_INACTIVE');
  assert.equal(String((await getWalletByUserId(sourceId)).available_balance), '3200');
  assert.equal(String((await getWalletByUserId(destinationId)).available_balance), '300');
});


async function runWalletMutationTransaction(callback) {
  const client = await dbModule.getPool().connect();
  try {
    await client.query('BEGIN');
    const value = await callback(client);
    await client.query('COMMIT');
    return value;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

test('public wallet creation rejects deleted accounts without creating an orphan wallet', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'public-wallet-deleted-user');
  await pool.query("UPDATE users SET status='DELETED' WHERE id=$1", [userId]);

  await assert.rejects(
    ensureWalletForUserPublic(userId),
    (error) => error?.code === 'ACCOUNT_INACTIVE',
  );
  assert.equal(await getWalletByUserId(userId), null,
    'wallet creation must not bypass the account-deletion guard');
});

test('wallet credit rejects deleted targets before creating or crediting a wallet', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const emptyUserId = await createTransferTestUser(pool, 'credit-deleted-empty');
  await pool.query("UPDATE users SET status='DELETED' WHERE id=$1", [emptyUserId]);

  await assert.rejects(
    creditWallet({
      userId: emptyUserId,
      amount: '500',
      idempotencyKey: `credit-deleted-empty-${emptyUserId}`,
    }),
    (error) => error?.code === 'ACCOUNT_INACTIVE',
  );
  assert.equal(await getWalletByUserId(emptyUserId), null);

  const fundedUserId = await createTransferTestUser(pool, 'credit-deleted-funded');
  await creditWallet({
    userId: fundedUserId,
    amount: '1400',
    idempotencyKey: `credit-seed-deleted-funded-${fundedUserId}`,
  });
  await pool.query("UPDATE users SET status='DELETED' WHERE id=$1", [fundedUserId]);

  await assert.rejects(
    creditWallet({
      userId: fundedUserId,
      amount: '500',
      idempotencyKey: `credit-after-delete-${fundedUserId}`,
    }),
    (error) => error?.code === 'ACCOUNT_INACTIVE',
  );
  assert.equal(String((await getWalletByUserId(fundedUserId)).available_balance), '1400');
});

test('internal payment hold rejects a deleted payer before reserving funds', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const payerId = await createTransferTestUser(pool, 'hold-deleted-payer');
  await creditWallet({
    userId: payerId,
    amount: '2600',
    idempotencyKey: `hold-seed-deleted-payer-${payerId}`,
  });
  await pool.query("UPDATE users SET status='DELETED' WHERE id=$1", [payerId]);
  const paymentId = crypto.randomUUID();

  await assert.rejects(
    runWalletMutationTransaction((client) => postInternalPaymentHoldWithClient(client, {
      paymentId,
      payerId,
      employerCharge: '1100',
      providerPayout: '1000',
      platformFee: '100',
      idempotencyKey: `hold-deleted-payer-${paymentId}`,
    })),
    (error) => error?.code === 'ACCOUNT_INACTIVE',
  );

  const wallet = await getWalletByUserId(payerId);
  assert.equal(String(wallet.available_balance), '2600');
  assert.equal(String(wallet.locked_balance), '0');
  const { rows: holds } = await pool.query(
    "SELECT id FROM wallet_holds WHERE reference_id=$1 AND hold_type='JOB_PAYMENT'",
    [paymentId],
  );
  assert.equal(holds.length, 0);
});

test('payout reservation rejects a deleted account and does not move its available balance', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'payout-deleted-user');
  await creditWallet({
    userId,
    amount: '1900',
    idempotencyKey: `payout-seed-deleted-user-${userId}`,
  });
  await pool.query("UPDATE users SET status='DELETED' WHERE id=$1", [userId]);

  const previousProvider = appConfig.paymentProvider;
  appConfig.paymentProvider = 'internal';
  try {
    await assert.rejects(
      requestPayoutAtomic({
        userId,
        amount: '600',
        idempotencyKey: `payout-after-delete-${userId}`,
      }),
      (error) => error?.code === 'ACCOUNT_INACTIVE',
    );
  } finally {
    appConfig.paymentProvider = previousProvider;
  }

  const wallet = await getWalletByUserId(userId);
  assert.equal(String(wallet.available_balance), '1900');
  assert.equal(String(wallet.locked_balance), '0');
  const { rows: payouts } = await pool.query('SELECT id FROM payouts WHERE user_id=$1', [userId]);
  assert.equal(payouts.length, 0);
});


async function createWebhookMismatchPayment(status, label) {
  const pool = dbModule.getPool();
  const suffix = `${label}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const { rows: jobs } = await pool.query(
    `INSERT INTO jobs(
       id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
       budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
       created_at,updated_at
     )
     SELECT gen_random_uuid(),$1,$2,$3,'Webhook state mismatch integration fixture',
       c.id,'FIXED','FIXED',100,100,1,'R05 webhook fixture','IN_PROGRESS',
       'R05 test','MISSION','PUBLIC',NOW(),NOW()
     FROM categories c WHERE c.is_active=TRUE
     ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1
     RETURNING id`,
    [fixture.ownerId, fixture.workerId, `R05 webhook ${suffix}`],
  );
  assert.ok(jobs[0], 'webhook fixture requires an active category');
  const paymentId = crypto.randomUUID();
  const providerRef = `provider-ref-${suffix}`;
  await pool.query(
    `INSERT INTO payments(
       id,job_id,payer_id,payee_id,amount,status,provider_ref,currency,
       base_amount,employer_charge,provider_payout,platform_fee,created_at,updated_at
     ) VALUES($1,$2,$3,$4,100,$5,$6,'TOMAN',100,100,100,0,NOW(),NOW())`,
    [paymentId,jobs[0].id,fixture.ownerId,fixture.workerId,status,providerRef],
  );
  return { paymentId, providerRef };
}

test('mismatched payment-held callback is ignored and opens reconciliation when payment hold had failed', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const { paymentId, providerRef } = await createWebhookMismatchPayment('HOLD_FAILED', 'hold-failed');
  const eventId = `R05-webhook-state-conflict-${paymentId}`;
  const result = await applyPaymentWebhookAtomic({
    eventId,
    eventType: 'PAYMENT_HELD',
    paymentId,
    providerRef,
    payload: { eventId, eventType: 'PAYMENT_HELD', paymentId, providerRef },
  });

  assert.equal(result.processed, true, 'a signed mismatch is acknowledged so the provider does not retry it forever');
  assert.equal(result.ignored, true);
  assert.equal(result.reason, 'PAYMENT_STATE_MISMATCH');
  const { rows: paymentRows } = await pool.query('SELECT status FROM payments WHERE id=$1', [paymentId]);
  assert.equal(paymentRows[0].status, 'HOLD_FAILED', 'the mismatched event must not silently move the payment to HELD');
  const { rows: providerRows } = await pool.query(
    'SELECT status FROM provider_events WHERE provider=$1 AND provider_event_id=$2',
    [appConfig.paymentProvider, eventId],
  );
  assert.equal(providerRows[0].status, 'IGNORED');
  const { rows: cases } = await pool.query(
    `SELECT case_type,severity,expected,observed FROM reconciliation_cases
      WHERE case_type='PAYMENT_WEBHOOK_STATE_MISMATCH' AND resource_type='payment' AND resource_id=$1
        AND status IN ('OPEN','INVESTIGATING')`,
    [paymentId],
  );
  assert.equal(cases.length, 1);
  assert.equal(cases[0].severity, 'CRITICAL');
  assert.equal(cases[0].expected.allowedPaymentStatus, 'HOLD_PENDING');
  assert.equal(cases[0].observed.paymentStatus, 'HOLD_FAILED');
  const { rows: journalRows } = await pool.query(
    `SELECT id FROM financial_operations WHERE idempotency_key=$1`,
    [`internal:webhook:hold:${eventId}`],
  );
  assert.equal(journalRows.length, 0, 'no wallet hold may be posted from a state-mismatched event');
});

test('duplicate state callback after the transition is already reflected is ignored without a new reconciliation case', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const { paymentId, providerRef } = await createWebhookMismatchPayment('HELD', 'already-held');
  const eventId = `R05-webhook-stale-held-${paymentId}`;
  const result = await applyPaymentWebhookAtomic({
    eventId,
    eventType: 'PAYMENT_HELD',
    paymentId,
    providerRef,
    payload: { eventId, eventType: 'PAYMENT_HELD', paymentId, providerRef },
  });

  assert.equal(result.processed, true);
  assert.equal(result.ignored, true);
  assert.equal(result.reason, 'ALREADY_APPLIED');
  const { rows: providerRows } = await pool.query(
    'SELECT status FROM provider_events WHERE provider=$1 AND provider_event_id=$2',
    [appConfig.paymentProvider, eventId],
  );
  assert.equal(providerRows[0].status, 'IGNORED');
  const { rows: cases } = await pool.query(
    `SELECT id FROM reconciliation_cases
      WHERE case_type='PAYMENT_WEBHOOK_STATE_MISMATCH' AND resource_type='payment' AND resource_id=$1
        AND status IN ('OPEN','INVESTIGATING')`,
    [paymentId],
  );
  assert.equal(cases.length, 0);
});

test('direct payment-release webhook closes job chat in the same settlement transaction', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const { paymentId, providerRef } = await createWebhookMismatchPayment('RELEASE_PENDING', 'release-closes-chat');
  const { rows: payments } = await pool.query(
    'SELECT job_id,payer_id,payee_id FROM payments WHERE id=$1',
    [paymentId],
  );
  const payment = payments[0];
  assert.ok(payment?.job_id);
  await pool.query('UPDATE payments SET provider_payout=99,platform_fee=1,employer_charge=100 WHERE id=$1', [paymentId]);
  await pool.query("UPDATE jobs SET status='DELIVERED' WHERE id=$1", [payment.job_id]);
  await pool.query("UPDATE jobs SET status='COMPLETED' WHERE id=$1", [payment.job_id]);
  const { rows: conversations } = await pool.query(
    "INSERT INTO chat_conversations(id,kind,job_id,status,title) VALUES(gen_random_uuid(),'JOB',$1,'OPEN','R05 webhook settlement chat') RETURNING id",
    [payment.job_id],
  );
  await creditWallet({
    userId: payment.payer_id,
    amount: '1000',
    idempotencyKey: 'seed-release-chat-close-' + paymentId,
  });
  await runWalletMutationTransaction((client) => postInternalPaymentHoldWithClient(client, {
    paymentId,
    payerId: payment.payer_id,
    employerCharge: '100',
    providerPayout: '99',
    platformFee: '1',
    idempotencyKey: 'seed-release-hold-' + paymentId,
  }));

  const previousProvider = appConfig.paymentProvider;
  appConfig.paymentProvider = 'internal';
  try {
    const eventId = 'R05-webhook-release-close-' + paymentId;
    const releaseRef = providerRef + '-release';
    const result = await applyPaymentWebhookAtomic({
      eventId,
      eventType: 'PAYMENT_RELEASED',
      paymentId,
      providerRef: releaseRef,
      payload: { eventId, eventType: 'PAYMENT_RELEASED', paymentId, providerRef: releaseRef },
    });
    assert.equal(result.processed, true);
    assert.equal(result.ignored, undefined);
    const { rows: settledJobs } = await pool.query('SELECT status FROM jobs WHERE id=$1', [payment.job_id]);
    assert.equal(settledJobs[0].status, 'SETTLED');
    const { rows: settledPayments } = await pool.query('SELECT status FROM payments WHERE id=$1', [paymentId]);
    assert.equal(settledPayments[0].status, 'RELEASED');
    const { rows: chats } = await pool.query('SELECT status FROM chat_conversations WHERE id=$1', [conversations[0].id]);
    assert.equal(chats[0].status, 'CLOSED',
      'direct webhook settlement must preserve the same close-chat invariant as the outbox path');
  } finally {
    appConfig.paymentProvider = previousProvider;
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
