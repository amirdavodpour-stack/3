import test, { after } from 'node:test';
import crypto from 'node:crypto';
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
      import('../src/repository/payment_funding.js'),
      import('../src/repository/outbox.js'),
      import('../src/outbox_handlers.js'),
      import('../src/payment_provider.js'),
      import('../src/repository/disputes.js'),
      import('../src/repository/auth.js'),
      import('../src/repository/admin.js'),
    ])
  : [];
const dbModule = modules[0];
const migration = modules[1]?.migration;
const { deleteUserPrivacyBundle, getUserPrivacyBundle } = modules[3] || {};
const { insertUpload, createUploadIntent, completeUploadAtomic } = modules[4] || {};
const { transferAvailable, creditWallet, getWalletByUserId, ensureWalletForUserPublic, postInternalPaymentHoldWithClient } = modules[5] || {};
const { requestPayoutAtomic, completePayoutOutbox, markPayoutUnknown, resolvePayoutUnknown, listUnknownPayouts } = modules[6] || {};
const { config: appConfig } = modules[7] || {};
const { applyPaymentWebhookAtomic } = modules[8] || {};
const { fundJobAtomic } = modules[9] || {};
const { completePaymentCreateHoldOutbox, failOutboxEvent, holdPaymentForDispute } = modules[10] || {};
const { processOutboxEvent } = modules[11] || {};
const { createPaymentProvider } = modules[12] || {};
const { claimJobDisputeResolution, completeJobDisputeResolution, updateJobDisputeAnalysis } = modules[13] || {};
const { setAdminPanelVerified, isAdminPanelVerified } = modules[13] || {};
const { bumpUserSessionVersion, insertResetToken, consumeResetTokenAndChangePassword } = modules[14] || {};
const { setUserStatus, revokeUserSessions } = modules[15] || {};
const {
  closeJobChatForJob,
  ensureJobChat,
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

test('admin dispute resolution atomically admits one decision and recovers its expired claim', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const disputeId = crypto.randomUUID();
  await pool.query(
    "INSERT INTO job_disputes(id,job_id,opened_by,trigger_type,status) VALUES($1,$2,$3,'ADMIN','ADMIN_REVIEW')",
    [disputeId,fixture.jobId,fixture.adminId],
  );

  const attempts = await Promise.all([
    claimJobDisputeResolution(disputeId,{
      resolution:'HOLD',
      reason:'first administrator decision',
      adminId:fixture.adminId,
    }),
    claimJobDisputeResolution(disputeId,{
      resolution:'REFUND',
      reason:'competing administrator decision',
      adminId:fixture.outsiderId,
    }),
  ]);
  const winner = attempts.find((attempt) => attempt?.claimed === true);
  const loser = attempts.find((attempt) => attempt?.conflict === true);
  assert.ok(winner,'exactly one concurrent administrator decision must acquire the durable claim');
  assert.ok(loser,'the competing, different decision must be rejected while a claim is active');

  const lateAnalysis = await updateJobDisputeAnalysis(disputeId,{
    decision:'RELEASE',
    confidence:1,
    report:{summary:'late participant analysis must not overwrite resolving'},
    rulesetVersion:'R05-test',
    manualReview:false,
  });
  assert.equal(lateAnalysis,null,'participant/AI analysis cannot overwrite an active admin resolution claim');
  const { rows: claimedState } = await pool.query(
    'SELECT status,resolution FROM job_disputes WHERE id=$1',
    [disputeId],
  );
  assert.equal(claimedState[0]?.status,'RESOLVING');
  assert.ok(['HOLD','REFUND'].includes(claimedState[0]?.resolution));
  assert.equal(attempts.filter((attempt) => attempt?.claimed === true).length,1);
  assert.equal(loser.code,'DISPUTE_RESOLUTION_IN_PROGRESS');

  const sameDecision = await claimJobDisputeResolution(disputeId,{
    resolution:winner.resolution,
    reason:'retry while the first worker still owns the lease',
    adminId:fixture.adminId,
  });
  assert.equal(sameDecision.inProgress,true,
    'same-decision retry must not execute the financial action concurrently');

  await pool.query(
    "UPDATE job_disputes SET resolution_lease_until=NOW()-INTERVAL '1 second' WHERE id=$1",
    [disputeId],
  );
  const expiredBeforeTakeover = await completeJobDisputeResolution(disputeId,{
    resolution:winner.resolution,
    token:winner.token,
  });
  assert.equal(expiredBeforeTakeover?.stale,true,
    'an expired lease cannot finalize even before another administrator reclaims it');

  const resumed = await claimJobDisputeResolution(disputeId,{
    resolution:winner.resolution,
    reason:'resume the same decision after lease expiry',
    adminId:fixture.adminId,
  });
  assert.equal(resumed.claimed,true);
  assert.equal(resumed.resumed,true);
  assert.notEqual(resumed.token,winner.token,'expired claim must receive a new fencing token');

  const stale = await completeJobDisputeResolution(disputeId,{
    resolution:winner.resolution,
    token:winner.token,
  });
  assert.equal(stale?.stale,true,'an expired worker must not finalize after a newer claim takes over');

  const completed = await completeJobDisputeResolution(disputeId,{
    resolution:winner.resolution,
    token:resumed.token,
  });
  assert.equal(completed?.status,'RESOLVED');
  assert.equal(completed?.resolution,winner.resolution);

  const { rows } = await pool.query(
    'SELECT status,resolution,resolution_lease_token,resolution_lease_until FROM job_disputes WHERE id=$1',
    [disputeId],
  );
  assert.equal(rows[0]?.status,'RESOLVED');
  assert.equal(rows[0]?.resolution,winner.resolution);
  assert.equal(rows[0]?.resolution_lease_token,null);
  assert.equal(rows[0]?.resolution_lease_until,null);
});

test('admin dispute HOLD cancels pending release events but refuses a provider operation already in progress', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const pendingPaymentId = crypto.randomUUID();
  const pendingEventId = crypto.randomUUID();
  const processingPaymentId = pendingPaymentId;
  const processingEventId = crypto.randomUUID();
  const suffix = crypto.randomBytes(6).toString('hex');
  const { rows: jobs } = await pool.query(
    'INSERT INTO jobs(' +
      'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
      'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
      'created_at,updated_at) ' +
      "SELECT gen_random_uuid(),$1,$2,'R05 dispute HOLD fixture'," +
      "'PostgreSQL dispute HOLD release-event fixture',c.id,'FIXED','FIXED'," +
      "100,130,1,'R05 dispute HOLD fixture','COMPLETED'," +
      "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
      'FROM categories c WHERE c.is_active=TRUE ' +
      'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
    [fixture.ownerId,fixture.workerId],
  );
  assert.ok(jobs[0],'dispute HOLD fixture requires an active category');
  const holdJobId = jobs[0].id;

  const insertPayment = async (paymentId, status, key) => pool.query(
    'INSERT INTO payments(' +
      'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
      'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
      'fee_policy_version,currency,created_at,updated_at) ' +
      "VALUES($1,$2,$3,$4,100,$5,$6,$7,100,30,0,30,130,100,'R05-test','TOMAN',NOW(),NOW())",
    [paymentId,holdJobId,fixture.ownerId,fixture.workerId,status,'hold-ref-'+suffix,key],
  );

  const insertEvent = async (eventId, paymentId, status, attempts, leaseToken) => pool.query(
    'INSERT INTO outbox_events(' +
      'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
      'available_at,locked_at,lease_token,created_at) ' +
      "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,$5,$6,NOW(),$7,$8,NOW())",
    [eventId,paymentId,'dispute-hold-release-'+eventId,JSON.stringify({jobId:holdJobId,paymentId}),status,attempts,status==='PROCESSING'?new Date():null,leaseToken],
  );

  try {
    await insertPayment(pendingPaymentId,'RELEASE_PENDING','dispute-hold-pending-'+suffix);
    await insertEvent(pendingEventId,pendingPaymentId,'PENDING',0,null);
    const held = await holdPaymentForDispute({jobId:holdJobId,paymentId:pendingPaymentId});
    assert.equal(held?.held,true);
    assert.equal(held?.paymentStatus,'HELD');
    assert.equal(held?.cancelledReleaseEvents,1);

    const { rows: pendingState } = await pool.query(
      'SELECT p.status AS payment_status,o.status AS outbox_status,o.last_error ' +
        'FROM payments p JOIN outbox_events o ON o.id=$2 WHERE p.id=$1',
      [pendingPaymentId,pendingEventId],
    );
    assert.equal(pendingState[0]?.payment_status,'HELD');
    assert.equal(pendingState[0]?.outbox_status,'DONE');
    assert.equal(pendingState[0]?.last_error,'CANCELLED_BY_ADMIN_DISPUTE_HOLD');

    const leaseToken = crypto.randomUUID();
    await pool.query(
      "UPDATE payments SET status='RELEASE_PENDING',updated_at=NOW() WHERE id=$1",
      [processingPaymentId],
    );
    await insertEvent(processingEventId,processingPaymentId,'PROCESSING',1,leaseToken);
    const refused = await holdPaymentForDispute({jobId:holdJobId,paymentId:processingPaymentId});
    assert.equal(refused?.held,false);
    assert.equal(refused?.reason,'PAYMENT_RELEASE_IN_PROGRESS');

    const { rows: processingState } = await pool.query(
      'SELECT p.status AS payment_status,o.status AS outbox_status ' +
        'FROM payments p JOIN outbox_events o ON o.id=$2 WHERE p.id=$1',
      [processingPaymentId,processingEventId],
    );
    assert.equal(processingState[0]?.payment_status,'RELEASE_PENDING');
    assert.equal(processingState[0]?.outbox_status,'PROCESSING');
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE id=ANY($1::uuid[])',[[pendingEventId,processingEventId]]);
    await pool.query('DELETE FROM payments WHERE id=$1',[pendingPaymentId]);
    await pool.query('DELETE FROM jobs WHERE id=$1',[holdJobId]);
  }
});

test('outbox event identity and payload are immutable after insertion', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const id = crypto.randomUUID();
  const aggregateId = crypto.randomUUID();
  const dedupeKey = 'outbox-identity-immutable-' + crypto.randomBytes(8).toString('hex');
  await pool.query(
    'INSERT INTO outbox_events(' +
      'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at) ' +
      "VALUES($1,'TEST_IMMUTABLE','test_aggregate',$2,$3,$4::jsonb,'PENDING',0,NOW(),NOW())",
    [id,aggregateId,dedupeKey,JSON.stringify({immutable:true})],
  );

  try {
    const mutations = [
      ["UPDATE outbox_events SET event_type='OTHER_EVENT' WHERE id=$1",[id]],
      ["UPDATE outbox_events SET aggregate_type='other_aggregate' WHERE id=$1",[id]],
      ["UPDATE outbox_events SET aggregate_id=$2 WHERE id=$1",[id,crypto.randomUUID()]],
      ["UPDATE outbox_events SET dedupe_key=$2 WHERE id=$1",[id,dedupeKey+'-changed']],
      ["UPDATE outbox_events SET payload=$2::jsonb WHERE id=$1",[id,JSON.stringify({changed:true})]],
      ["UPDATE outbox_events SET id=$2 WHERE id=$1",[id,crypto.randomUUID()]],
      ["UPDATE outbox_events SET created_at=NOW()+INTERVAL '1 day' WHERE id=$1",[id]],
    ];
    for (const [sql,args] of mutations) {
      await assert.rejects(
        pool.query(sql,args),
        (error) => error?.code === '55000' && /identity|immutable/i.test(error.message),
        'outbox identity mutation must be rejected by PostgreSQL',
      );
    }

    const { rows } = await pool.query(
      'SELECT id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status ' +
        'FROM outbox_events WHERE id=$1',
      [id],
    );
    assert.equal(rows.length,1);
    assert.equal(rows[0].event_type,'TEST_IMMUTABLE');
    assert.equal(rows[0].aggregate_type,'test_aggregate');
    assert.equal(String(rows[0].aggregate_id),String(aggregateId));
    assert.equal(rows[0].dedupe_key,dedupeKey);
    assert.deepEqual(rows[0].payload,{immutable:true});
    assert.equal(rows[0].status,'PENDING');
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[id]);
  }
});

test('PostgreSQL privacy export reads financial collections from a repeatable-read snapshot', { skip: !enabled }, async () => {
  await ensureWalletForUserPublic(fixture.ownerId);
  const bundle = await getUserPrivacyBundle(fixture.ownerId);

  assert.equal(bundle.user.id, fixture.ownerId);
  assert.ok(bundle.walletAccounts.some((wallet) => wallet.currency === 'TOMAN'));
  assert.ok(Array.isArray(bundle.walletEntries));
  assert.ok(Array.isArray(bundle.walletHolds));
  assert.ok(Array.isArray(bundle.payouts));
  assert.ok(Array.isArray(bundle.refunds));
  assert.ok(Array.isArray(bundle.settlements));
});

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


test('migration 035 canonicalizes a balanced legacy ledger group before enforcing the journal foreign key', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const schema = `r035_${crypto.randomBytes(6).toString('hex')}`;
  const quotedSchema = `"${schema}"`;
  const journalId = crypto.randomUUID();
  const referenceId = crypto.randomUUID();
  const { migration: migration035 } = await import('../src/db/migrations/035_external_ledger_journals_and_currency_precision.js');
  const client = await pool.connect();
  let schemaCreated = false;
  let transactionOpen = false;
  try {
    await client.query(`CREATE SCHEMA ${quotedSchema}`);
    schemaCreated = true;
    await client.query('BEGIN');
    transactionOpen = true;
    await client.query(`SET LOCAL search_path TO ${quotedSchema}, public`);
    await client.query(`
      CREATE TABLE financial_operations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        operation_type TEXT NOT NULL CHECK (operation_type IN ('TOP_UP','TRANSFER','HOLD','RELEASE','REFUND','PAYOUT','ADJUSTMENT')),
        actor_type TEXT NOT NULL CHECK (actor_type IN ('USER','ADMIN','SYSTEM','PROVIDER')),
        actor_id UUID NULL,
        status TEXT NOT NULL CHECK (status IN ('PENDING','PROCESSING','SUCCEEDED','FAILED','UNKNOWN','CANCELLED')),
        idempotency_key TEXT NULL,
        request_hash TEXT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        completed_at TIMESTAMPTZ NULL,
        CHECK ((status IN ('SUCCEEDED','FAILED','CANCELLED') AND completed_at IS NOT NULL) OR
               (status IN ('PENDING','PROCESSING','UNKNOWN') AND completed_at IS NULL))
      );
      CREATE TABLE journals (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        operation_id UUID NOT NULL REFERENCES financial_operations(id) ON DELETE RESTRICT,
        journal_type TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'TOMAN' CONSTRAINT journals_currency_check CHECK (currency='TOMAN'),
        status TEXT NOT NULL DEFAULT 'CREATED' CHECK (status IN ('CREATED','POSTED','FAILED')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        posted_at TIMESTAMPTZ NULL,
        UNIQUE(operation_id,journal_type)
      );
      CREATE TABLE ledger_entries (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        journal_id UUID NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id UUID NULL,
        account TEXT NOT NULL,
        debit BIGINT NOT NULL DEFAULT 0 CHECK (debit >= 0),
        credit BIGINT NOT NULL DEFAULT 0 CHECK (credit >= 0),
        currency TEXT NOT NULL DEFAULT 'USD',
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CHECK ((debit=0 AND credit>0) OR (credit=0 AND debit>0)),
        CONSTRAINT ledger_entries_amount_max_chk CHECK (debit <= 9000000000000000 AND credit <= 9000000000000000)
      );
      CREATE OR REPLACE FUNCTION hope_assert_ledger_journal_balanced() RETURNS trigger
      LANGUAGE plpgsql AS $fn$
      DECLARE debit_total NUMERIC; credit_total NUMERIC; journal_uuid UUID;
      BEGIN
        journal_uuid := COALESCE(NEW.journal_id,OLD.journal_id);
        SELECT COALESCE(SUM(debit),0),COALESCE(SUM(credit),0)
          INTO debit_total,credit_total FROM ledger_entries WHERE journal_id=journal_uuid;
        IF debit_total <> credit_total THEN
          RAISE EXCEPTION 'legacy journal % is unbalanced', journal_uuid USING ERRCODE='23514';
        END IF;
        RETURN COALESCE(NEW,OLD);
      END;
      $fn$;
      CREATE CONSTRAINT TRIGGER ledger_journal_balance_deferred
        AFTER INSERT OR UPDATE OF debit,credit,journal_id OR DELETE ON ledger_entries
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION hope_assert_ledger_journal_balanced();
      CREATE OR REPLACE FUNCTION hope_validate_posted_journal_balance() RETURNS trigger
      LANGUAGE plpgsql AS $fn$
      DECLARE debit_total NUMERIC; credit_total NUMERIC; entry_count BIGINT;
      BEGIN
        IF NEW.status='POSTED' AND (TG_OP='INSERT' OR OLD.status IS DISTINCT FROM 'POSTED') THEN
          SELECT COUNT(*),COALESCE(SUM(debit),0),COALESCE(SUM(credit),0)
            INTO entry_count,debit_total,credit_total FROM ledger_entries WHERE journal_id=NEW.id;
          IF entry_count=0 OR debit_total<>credit_total OR debit_total<=0 THEN
            RAISE EXCEPTION 'posted journal must be balanced and non-empty' USING ERRCODE='55000';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $fn$;
      CREATE CONSTRAINT TRIGGER journals_posted_balance_trigger
        AFTER INSERT OR UPDATE OF status ON journals
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION hope_validate_posted_journal_balance();
    `);
    await client.query(
      `INSERT INTO ledger_entries(journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
       VALUES($1,'LEGACY_TEST',$2,'PLATFORM_CASH',130,0,'USD',NOW()),
             ($1,'LEGACY_TEST',$2,'ESCROW_LIABILITY',0,100,'USD',NOW()),
             ($1,'LEGACY_TEST',$2,'PLATFORM_FEE_REVENUE',0,30,'USD',NOW())`,
      [journalId,referenceId],
    );
    const { rows: preMigration } = await client.query('SELECT id FROM journals WHERE id=$1', [journalId]);
    assert.equal(preMigration.length, 0, 'fixture must model a legacy orphan journal group');
    await client.query('COMMIT');
    transactionOpen = false;

    await client.query('BEGIN');
    transactionOpen = true;
    await client.query(`SET LOCAL search_path TO ${quotedSchema}, public`);
    await migration035.up(client);
    await client.query('COMMIT');
    transactionOpen = false;

    const { rows: canonical } = await client.query(
      `SELECT j.id,j.currency,j.status,j.journal_type,
              fo.operation_type,fo.actor_type,fo.status AS operation_status,fo.idempotency_key,
              COUNT(le.id)::int AS entry_count,SUM(le.debit)::numeric AS debits,SUM(le.credit)::numeric AS credits,
              MIN(le.currency) AS entry_currency
         FROM ${quotedSchema}.journals j
         JOIN ${quotedSchema}.financial_operations fo ON fo.id=j.operation_id
         JOIN ${quotedSchema}.ledger_entries le ON le.journal_id=j.id
        WHERE j.id=$1
        GROUP BY j.id,fo.id`,
      [journalId],
    );
    assert.equal(canonical.length, 1);
    assert.equal(canonical[0].currency, 'USD');
    assert.equal(canonical[0].entry_currency, 'USD');
    assert.equal(canonical[0].status, 'POSTED');
    assert.equal(canonical[0].journal_type, 'LEGACY_IMPORT');
    assert.equal(canonical[0].operation_type, 'ADJUSTMENT');
    assert.equal(canonical[0].actor_type, 'SYSTEM');
    assert.equal(canonical[0].operation_status, 'SUCCEEDED');
    assert.equal(canonical[0].idempotency_key, `migration-035:legacy-ledger:${journalId}`);
    assert.equal(canonical[0].entry_count, 3);
    assert.equal(Number(canonical[0].debits), 130);
    assert.equal(Number(canonical[0].credits), 130);
    const { rows: foreignKeys } = await client.query(
      `SELECT convalidated FROM pg_constraint
        WHERE conname='ledger_entries_journal_id_fk'
          AND connamespace=(SELECT oid FROM pg_namespace WHERE nspname=$1)`,
      [schema],
    );
    assert.equal(foreignKeys.length, 1);
    assert.equal(foreignKeys[0].convalidated, true);
  } catch (error) {
    if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    if (transactionOpen) await client.query('ROLLBACK').catch(() => {});
    if (schemaCreated) await client.query(`DROP SCHEMA IF EXISTS ${quotedSchema} CASCADE`).catch(() => {});
    client.release();
  }
});

test('PostgreSQL enforces parent-ledger currency consistency and journal currency immutability', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const client = await pool.connect();
  const operationId = crypto.randomUUID();
  const journalId = crypto.randomUUID();
  try {
    await client.query('BEGIN');
    await client.query(
      `INSERT INTO financial_operations(id,operation_type,actor_type,actor_id,status,created_at)
       VALUES($1,'ADJUSTMENT','SYSTEM',NULL,'PROCESSING',NOW())`,
      [operationId],
    );
    await client.query(
      `INSERT INTO journals(id,operation_id,journal_type,currency,status,created_at)
       VALUES($1,$2,'CURRENCY_GUARD_TEST','USD','CREATED',NOW())`,
      [journalId,operationId],
    );
    await client.query(
      `INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
       VALUES(gen_random_uuid(),$1,'CURRENCY_GUARD_TEST',$2,'TEST_DEBIT',1,0,'USD',NOW()),
             (gen_random_uuid(),$1,'CURRENCY_GUARD_TEST',$2,'TEST_CREDIT',0,1,'USD',NOW())`,
      [journalId,operationId],
    );
    await client.query('SAVEPOINT mismatch_entry');
    await assert.rejects(
      client.query(
        `INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
         VALUES(gen_random_uuid(),$1,'CURRENCY_GUARD_TEST',$2,'TEST_ACCOUNT',1,0,'EUR',NOW())`,
        [journalId,operationId],
      ),
      (error) => error?.code === '23514' && /currency must match/i.test(error.message),
    );
    await client.query('ROLLBACK TO SAVEPOINT mismatch_entry');
    await client.query('SAVEPOINT mutate_journal_currency');
    await assert.rejects(
      client.query(`UPDATE journals SET currency='EUR' WHERE id=$1`, [journalId]),
      (error) => error?.code === '23514' && /currency is immutable/i.test(error.message),
    );
    await client.query('ROLLBACK TO SAVEPOINT mutate_journal_currency');
    await client.query('ROLLBACK');
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
});

test('external payment-refund webhook preserves fractional USD in one canonical immutable journal', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const suffix = `external-refund-journal-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const eventId = `r05-${suffix}`;
  const paymentId = crypto.randomUUID();
  const providerRef = `hold-ref-${suffix}`;
  const refundRef = `refund-ref-${suffix}`;
  const previousProvider = appConfig.paymentProvider;
  let jobId;

  try {
    const { rows: jobs } = await pool.query(
      `INSERT INTO jobs(
         id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
         budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
         created_at,updated_at
       )
       SELECT gen_random_uuid(),$1,$3,$2,'External refund journal integration fixture',
         c.id,'FIXED','FIXED',100,130,1,'R05 external refund fixture','FUNDED',
         'R05 test','MISSION','PUBLIC',NOW(),NOW()
       FROM categories c WHERE c.is_active=TRUE
       ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1
       RETURNING id`,
      [fixture.ownerId, `R05 external refund ${suffix}`, fixture.workerId],
    );
    assert.ok(jobs[0], 'external refund fixture requires an active category');
    jobId = jobs[0].id;
    const conversation = await ensureJobChat(jobId);
    assert.ok(conversation, 'external refund fixture must have an active worker chat before refund');

    await pool.query(
      `INSERT INTO payments(
         id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,
         base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,
         fee_policy_version,currency,created_at,updated_at
       )
       VALUES($1,$2,$3,$4,100.25,'REFUND_PENDING',$5,$6,100.25,30.08,0,30.08,130.33,100.25,'R05-test','USD',NOW(),NOW())`,
      [paymentId,jobId,fixture.ownerId,fixture.workerId,providerRef,`idempotency-${suffix}`],
    );
    await pool.query(
      `INSERT INTO refunds(id,payment_id,amount,status,provider_ref,idempotency_key,created_at,updated_at)
       VALUES(gen_random_uuid(),$1,130.33,'PENDING',NULL,$2,NOW(),NOW())`,
      [paymentId, `refund-idempotency-${suffix}`],
    );

    appConfig.paymentProvider = 'webhook';
    const result = await applyPaymentWebhookAtomic({
      eventId,
      eventType: 'PAYMENT_REFUNDED',
      paymentId,
      providerRef: refundRef,
      payload: { eventId, eventType: 'PAYMENT_REFUNDED', paymentId, providerRef: refundRef },
    });

    assert.equal(result.processed, true);
    const { rows: paymentRows } = await pool.query(
      'SELECT status FROM payments WHERE id=$1', [paymentId],
    );
    assert.equal(paymentRows[0].status, 'REFUNDED');
    const { rows: refundRows } = await pool.query(
      'SELECT status,provider_ref FROM refunds WHERE payment_id=$1', [paymentId],
    );
    assert.equal(refundRows.length, 1);
    assert.equal(refundRows[0].status, 'REFUNDED');
    assert.equal(refundRows[0].provider_ref, refundRef);

    const { rows: conversations } = await pool.query(
      `SELECT status,closed_at FROM chat_conversations WHERE kind='JOB' AND job_id=$1`,
      [jobId],
    );
    assert.equal(conversations.length, 1);
    assert.equal(conversations[0].status, 'CLOSED');
    assert.ok(conversations[0].closed_at, 'webhook refund must close the active job chat atomically');

    const { rows: journals } = await pool.query(
      `SELECT journal_id,COUNT(*)::int AS entries,
              SUM(debit)::numeric AS debits,SUM(credit)::numeric AS credits
         FROM ledger_entries
        WHERE reference_type='PAYMENT_REFUND' AND reference_id=$1
        GROUP BY journal_id`,
      [paymentId],
    );
    assert.equal(journals.length, 1, 'all refund entries must share one journal identifier');
    assert.equal(journals[0].entries, 3);
    assert.equal(Number(journals[0].debits), Number(journals[0].credits));
    const { rows: canonical } = await pool.query(
      `SELECT j.id,j.status,j.currency,fo.operation_type,fo.status AS operation_status
         FROM journals j JOIN financial_operations fo ON fo.id=j.operation_id
        WHERE j.id=$1`,
      [journals[0].journal_id],
    );
    assert.equal(canonical.length, 1, 'every external ledger group must have a canonical journal and operation');
    assert.equal(canonical[0].status, 'POSTED');
    assert.equal(canonical[0].currency, 'USD');
    assert.equal(canonical[0].operation_type, 'REFUND');
    assert.equal(canonical[0].operation_status, 'SUCCEEDED');
    await assert.rejects(
      pool.query('UPDATE ledger_entries SET account=account WHERE journal_id=$1', [journals[0].journal_id]),
      (error) => error?.code === '55000',
      'ledger entries in a posted canonical journal must be immutable',
    );
  } finally {
    appConfig.paymentProvider = previousProvider;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows: canonicalRows } = await client.query(
        `SELECT j.id FROM journals j JOIN ledger_entries le ON le.journal_id=j.id
          WHERE le.reference_type='PAYMENT_REFUND' AND le.reference_id=$1 AND j.status='POSTED' LIMIT 1`,
        [paymentId],
      );
      if (!canonicalRows.length) {
        await client.query(
          `DELETE FROM ledger_entries WHERE reference_type='PAYMENT_REFUND' AND reference_id=$1`,
          [paymentId],
        );
        await client.query('DELETE FROM payment_webhook_events WHERE event_id=$1', [eventId]);
        await client.query(
          'DELETE FROM provider_events WHERE provider=$1 AND provider_event_id=$2',
          ['webhook',eventId],
        );
        await client.query('DELETE FROM payments WHERE id=$1', [paymentId]);
        if (jobId) await client.query('DELETE FROM jobs WHERE id=$1', [jobId]);
      }
      // Keep successfully posted accounting rows immutable in the disposable database.
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK').catch(() => {});
      throw error;
    } finally {
      client.release();
    }
  }
});


test('refund supersedes every pending or failed release event and transitions payment to REFUND_PENDING', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const suffix = crypto.randomBytes(7).toString('hex');
  const jobId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const pendingEventId = crypto.randomUUID();
  const failedEventId = crypto.randomUUID();
  const refundId = crypto.randomUUID();
  const { rows: jobs } = await pool.query(
    'INSERT INTO jobs(' +
      'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
      'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
      'created_at,updated_at) ' +
      "SELECT $1,$2,$3,'R05 pending release refund fixture'," +
      "'PostgreSQL pending release refund supersession fixture',c.id,'FIXED','FIXED'," +
      "100,130,1,'R05 pending release refund fixture','COMPLETED'," +
      "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
      'FROM categories c WHERE c.is_active=TRUE ' +
      'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
    [jobId,fixture.ownerId,fixture.workerId],
  );
  assert.ok(jobs[0],'pending release refund fixture requires an active category');

  try {
    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'RELEASE_PENDING',$5,$6,100,30,0,30,130,100,'R05-test','TOMAN',NOW(),NOW())",
      [paymentId,jobId,fixture.ownerId,fixture.workerId,'provider-hold-'+suffix,'pending-release-refund-'+suffix],
    );

    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'PENDING',0,NOW(),NULL,NULL,NOW()-INTERVAL '2 minutes')",
      [pendingEventId,paymentId,'pending-release-before-refund-'+suffix,JSON.stringify({jobId,paymentId})],
    );
    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'FAILED',1,NOW(),NULL,NULL,NOW()-INTERVAL '1 minute')",
      [failedEventId,paymentId,'failed-release-before-refund-'+suffix,JSON.stringify({jobId,paymentId})],
    );

    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    const refund = await createRefundAtomic({
      jobId,
      paymentId,
      ownerId:fixture.ownerId,
      amount:100,
      id:refundId,
      idempotencyKey:'pending-release-refund-request-'+suffix,
      createdAt:new Date(),
      allowPendingRelease:true,
    });
    assert.equal(refund?.refund?.id,refundId);
    assert.equal(refund?.payment?.status,'REFUND_PENDING');

    const { rows: persisted } = await pool.query(
      'SELECT p.status AS payment_status,r.status AS refund_status,' +
        "COUNT(o.id) FILTER (WHERE o.event_type='PAYMENT_RELEASE' AND o.status='DONE')::int AS release_done_count," +
        "COUNT(o.id) FILTER (WHERE o.event_type='PAYMENT_REFUND' AND o.status='PENDING')::int AS refund_pending_count," +
        "COUNT(o.id) FILTER (WHERE o.last_error='SUPERSEDED_BY_REFUND')::int AS superseded_count " +
        'FROM payments p LEFT JOIN refunds r ON r.payment_id=p.id ' +
        'LEFT JOIN outbox_events o ON o.aggregate_id=p.id ' +
        'WHERE p.id=$1 GROUP BY p.id,r.id',
      [paymentId],
    );
    assert.equal(persisted.length,1);
    assert.equal(persisted[0].payment_status,'REFUND_PENDING');
    assert.equal(persisted[0].refund_status,'PENDING');
    assert.equal(persisted[0].release_done_count,2);
    assert.equal(persisted[0].refund_pending_count,1);
    assert.equal(persisted[0].superseded_count,2);
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE aggregate_id=$1',[paymentId]);
    await pool.query('DELETE FROM refunds WHERE payment_id=$1',[paymentId]);
    await pool.query('DELETE FROM payments WHERE id=$1',[paymentId]);
    await pool.query('DELETE FROM jobs WHERE id=$1',[jobId]);
  }
});

test('refund request and refund webhook serialize job/payment locks without a deadlock', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const ownerId = await createTransferTestUser(pool, 'refund-lock-owner');
  const workerId = await createTransferTestUser(pool, 'refund-lock-worker');
  const suffix = crypto.randomBytes(8).toString('hex');
  const eventId = 'r05-refund-lock-' + suffix;
  const paymentId = crypto.randomUUID();
  const providerRef = 'refund-lock-hold-' + suffix;
  const refundRef = 'refund-lock-operation-' + suffix;
  const idempotencyKey = 'refund-lock-request-' + suffix;
  const previousProvider = appConfig.paymentProvider;
  let jobId = null;
  let observer = null;
  let originalPoolConnect = null;
  let requestPromise = null;
  let webhookPromise = null;
  const requestGate = deferredGate();
  const webhookPaymentGate = deferredGate();
  const requestJobLocked = deferredGate();
  const webhookPaymentLocked = deferredGate();
  const webhookJobLockAttempted = deferredGate();
  let patchedConnect = false;

  function deferredGate() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
  }

  const waitForBlockedQuery = async (client, pattern, description, timeoutMs = 7000) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const { rows } = await client.query(
        'SELECT pid,query,wait_event_type,wait_event FROM pg_stat_activity ' +
          'WHERE datname=current_database() AND pid<>pg_backend_pid() ' +
          "AND wait_event_type='Lock' AND query ILIKE $1",
        [pattern],
      );
      if (rows.length) return rows[0];
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(description + ' did not reach the expected PostgreSQL lock wait');
  };

  const waitForSignal = async (signal, description, timeoutMs = 7000) => {
    let timeout;
    try {
      await Promise.race([
        signal.promise,
        new Promise((_, reject) => {
          timeout = setTimeout(() => reject(new Error(description + ' timed out')), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  try {
    const jobInsert = [
      'INSERT INTO jobs(',
      ' id,owner_id,provider_id,title,description,category_id,job_type,budget_type,',
      ' budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,',
      ' created_at,updated_at)',
      " SELECT gen_random_uuid(),$1,$2,'R05 refund lock-order fixture',",
      " 'PostgreSQL concurrency regression fixture',c.id,'FIXED','FIXED',",
      " 100,100,1,'R05 refund lock-order fixture','ASSIGNED',",
      " 'R05 test','MISSION','PUBLIC',NOW(),NOW()",
      ' FROM categories c WHERE c.is_active=TRUE',
      ' ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1',
      ' RETURNING id',
    ].join('\n');
    const { rows: jobs } = await pool.query(jobInsert, [
      ownerId, workerId,
    ]);
    assert.ok(jobs[0], 'refund lock-order fixture requires an active category');
    jobId = jobs[0].id;

    await pool.query(
      'INSERT INTO payments(id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'REFUND_PENDING',$5,$6,100,30,0,30,130,100,'R05-test','USD',NOW(),NOW())",
      [paymentId,jobId,ownerId,workerId,providerRef,'refund-lock-payment-' + suffix],
    );
    await pool.query(
      "INSERT INTO refunds(id,payment_id,amount,currency,status,provider_ref,idempotency_key,created_at,updated_at) " +
        "VALUES(gen_random_uuid(),$1,130,'USD','PENDING',NULL,$2,NOW(),NOW())",
      [paymentId,idempotencyKey],
    );

    observer = await pool.connect();
    originalPoolConnect = pool.connect;
    const connect = pool.connect.bind(pool);
    let serviceConnection = 0;
    pool.connect = async (...args) => {
      const client = await connect(...args);
      serviceConnection += 1;
      const role = serviceConnection;
      const originalQuery = client.query.bind(client);
      client.query = async (queryText, ...queryArgs) => {
        const sql = typeof queryText === 'string' ? queryText : String(queryText?.text || '');
        const normalized = sql.replace(/\s+/g, ' ').toUpperCase();
        const isJobLock = normalized.includes('FROM JOBS WHERE ID=$1 FOR UPDATE');
        const isPaymentLock = normalized.includes('FROM PAYMENTS WHERE ID=$1') && normalized.includes('FOR UPDATE');

        if (role === 2 && isJobLock) webhookJobLockAttempted.resolve();

        const result = await originalQuery(queryText, ...queryArgs);

        if (role === 1 && isJobLock) {
          requestJobLocked.resolve();
          await requestGate.promise;
        }
        if (role === 2 && isPaymentLock) {
          webhookPaymentLocked.resolve();
          await webhookPaymentGate.promise;
        }
        return result;
      };
      return client;
    };
    patchedConnect = true;

    appConfig.paymentProvider = 'webhook';
    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');

    requestPromise = createRefundAtomic({
      jobId,
      paymentId,
      ownerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey,
      createdAt:new Date(),
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    await waitForSignal(requestJobLocked, 'refund request job lock');

    webhookPromise = applyPaymentWebhookAtomic({
      eventId,
      eventType:'PAYMENT_REFUNDED',
      paymentId,
      providerRef:refundRef,
      payload:{eventId,eventType:'PAYMENT_REFUNDED',paymentId,providerRef:refundRef},
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    const firstWebhookLock = await Promise.race([
      webhookPaymentLocked.promise.then(() => 'payment-first'),
      webhookJobLockAttempted.promise.then(() => 'job-first'),
    ]);

    if (firstWebhookLock === 'payment-first') {
      // Current implementation: webhook owns payment while request owns job.
      // Let the request reach its payment lock, then release the webhook so
      // PostgreSQL sees the real job <-> payment wait cycle.
      requestGate.resolve();
      await waitForBlockedQuery(
        observer,
        '%FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE%',
        'duplicate refund request payment lock',
      );
      webhookPaymentGate.resolve();
    } else {
      // Correct job-first implementation: webhook waits for the request's job
      // lock before it can acquire payment. Let the request reject the already
      // pending refund, release job, then allow the webhook to finish.
      await waitForBlockedQuery(
        observer,
        '%FROM jobs%FOR UPDATE%',
        'refund webhook job-first lock',
      );
      requestGate.resolve();
      await waitForSignal(webhookPaymentLocked, 'refund webhook payment lock after job serialization');
      webhookPaymentGate.resolve();
    }

    const [requestOutcome, webhookOutcome] = await Promise.all([requestPromise, webhookPromise]);
    assert.equal(
      requestOutcome.error?.code,
      'INVALID_PAYMENT_STATE',
      'the duplicate refund request should observe the already-pending refund after lock serialization',
    );
    assert.equal(
      webhookOutcome.ok,
      true,
      'the provider refund webhook must complete without a PostgreSQL deadlock; observed ' +
        (webhookOutcome.error?.code || webhookOutcome.error?.message || 'unknown outcome'),
    );
    assert.equal(webhookOutcome.value.processed, true);

    const { rows: persisted } = await observer.query(
      'SELECT p.status AS payment_status,r.status AS refund_status,j.status AS job_status ' +
        'FROM payments p JOIN refunds r ON r.payment_id=p.id JOIN jobs j ON j.id=p.job_id ' +
        'WHERE p.id=$1',
      [paymentId],
    );
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].payment_status, 'REFUNDED');
    assert.equal(persisted[0].refund_status, 'REFUNDED');
    assert.equal(persisted[0].job_status, 'ASSIGNED');
  } finally {
    requestGate.resolve();
    webhookPaymentGate.resolve();
    if (requestPromise || webhookPromise) {
      await Promise.allSettled([requestPromise, webhookPromise].filter(Boolean));
    }
    if (patchedConnect) pool.connect = originalPoolConnect;
    appConfig.paymentProvider = previousProvider;

    if (observer) {
      try {
        if (paymentId) {
          const { rows: posted } = await observer.query(
            'SELECT j.id FROM journals j JOIN ledger_entries le ON le.journal_id=j.id ' +
              "WHERE le.reference_type='PAYMENT_REFUND' AND le.reference_id=$1 " +
              "AND j.status='POSTED' LIMIT 1",
            [paymentId],
          );
          if (!posted.length) {
            await observer.query('BEGIN');
            await observer.query('DELETE FROM payment_webhook_events WHERE event_id=$1', [eventId]);
            await observer.query(
              'DELETE FROM provider_events WHERE provider=$1 AND provider_event_id=$2',
              ['webhook',eventId],
            );
            await observer.query('DELETE FROM refunds WHERE payment_id=$1', [paymentId]);
            await observer.query('DELETE FROM payments WHERE id=$1', [paymentId]);
            if (jobId) await observer.query('DELETE FROM jobs WHERE id=$1', [jobId]);
            await observer.query('COMMIT');
          }
        }
      } catch (error) {
        await observer.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        observer.release();
      }
    }
  }
});




test('internal PAYMENT_HELD webhook acquires participant locks before payment while funding replay races', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const ownerId = await createTransferTestUser(pool, 'held-lock-owner');
  const workerId = await createTransferTestUser(pool, 'held-lock-worker');
  const suffix = crypto.randomBytes(8).toString('hex');
  const eventId = 'r05-held-lock-' + suffix;
  const paymentId = crypto.randomUUID();
  const holdRef = 'held-lock-provider-' + suffix;
  const idempotencyKey = 'held-lock-funding-' + suffix;
  const previousProvider = appConfig.paymentProvider;
  let jobId = null;
  let observer = null;
  let originalPoolConnect = null;
  let fundingPromise = null;
  let webhookPromise = null;
  let patchedConnect = false;

  const fundingUserGate = deferredGate();
  const fundingUsersLocked = deferredGate();
  const webhookUsersLockAttempted = deferredGate();
  const webhookPaymentLocked = deferredGate();

  function deferredGate() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
  }

  const waitForSignal = async (signal, description, timeoutMs = 7000) => {
    let timeout;
    try {
      await Promise.race([
        signal.promise,
        new Promise((_, reject) => {
          timeout = setTimeout(() => reject(new Error(description + ' timed out')), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  const waitForBlockedQuery = async (client, pattern, description, timeoutMs = 7000) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const { rows } = await client.query(
        'SELECT pid,query,wait_event_type,wait_event FROM pg_stat_activity ' +
          'WHERE datname=current_database() AND pid<>pg_backend_pid() ' +
          "AND wait_event_type='Lock' AND query ILIKE $1",
        [pattern],
      );
      if (rows.length) return rows[0];
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(description + ' did not reach the expected PostgreSQL lock wait');
  };

  try {
    await creditWallet({
      userId:ownerId,
      amount:'1000',
      idempotencyKey:'seed-held-lock-wallet-' + suffix,
    });

    const { rows: jobs } = await pool.query(
      'INSERT INTO jobs(' +
        'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
        'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
        'created_at,updated_at) ' +
        "SELECT gen_random_uuid(),$1,$2,'R05 held lock-order fixture'," +
        "'PostgreSQL internal hold/funding concurrency fixture',c.id,'FIXED','FIXED'," +
        "100,100,1,'R05 held lock-order fixture','FUNDED'," +
        "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
        'FROM categories c WHERE c.is_active=TRUE ' +
        'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
      [ownerId,workerId],
    );
    assert.ok(jobs[0], 'internal hold lock-order fixture requires an active category');
    jobId = jobs[0].id;

    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'HOLD_PENDING',$5,$6,100,0,0,1,101,100,'R05-test','TOMAN',NOW(),NOW())",
      [paymentId,jobId,ownerId,workerId,holdRef,idempotencyKey],
    );

    observer = await pool.connect();
    originalPoolConnect = pool.connect;
    const connect = pool.connect.bind(pool);
    let serviceConnection = 0;
    pool.connect = async (...args) => {
      const client = await connect(...args);
      serviceConnection += 1;
      const role = serviceConnection;
      const originalQuery = client.query.bind(client);
      client.query = async (queryText, ...queryArgs) => {
        const sql = typeof queryText === 'string' ? queryText : String(queryText?.text || '');
        const normalized = sql.replace(/\s+/g, ' ').toUpperCase();
        const isUsersLock = normalized.includes('FROM USERS') && normalized.includes('FOR NO KEY UPDATE');
        const isPaymentLock = normalized.includes('FROM PAYMENTS WHERE ID=$1 FOR UPDATE');

        if (role === 2 && isUsersLock) webhookUsersLockAttempted.resolve();

        const result = await originalQuery(queryText, ...queryArgs);

        if (role === 1 && isUsersLock) {
          fundingUsersLocked.resolve();
          await fundingUserGate.promise;
        }
        if (role === 2 && isPaymentLock) webhookPaymentLocked.resolve();
        return result;
      };
      return client;
    };
    patchedConnect = true;

    appConfig.paymentProvider = 'internal';
    const { fundJobAtomic } = await import('../src/repository/payment_funding.js');

    fundingPromise = fundJobAtomic({
      jobId,
      payerId:ownerId,
      payeeId:workerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey,
      createdAt:new Date(),
      breakdown:{
        currency:'TOMAN',
        baseAmount:'100',
        employerFee:'0',
        workerFee:'0',
        platformFee:'1',
        employerCharge:'101',
        providerPayout:'100',
        policyVersion:'R05-test',
      },
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    await waitForSignal(fundingUsersLocked, 'funding participant locks');

    webhookPromise = applyPaymentWebhookAtomic({
      eventId,
      eventType:'PAYMENT_HELD',
      paymentId,
      providerRef:holdRef,
      payload:{eventId,eventType:'PAYMENT_HELD',paymentId,providerRef:holdRef},
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    const firstWebhookLock = await Promise.race([
      webhookUsersLockAttempted.promise.then(() => 'users-first'),
      webhookPaymentLocked.promise.then(() => 'payment-first'),
    ]);

    if (firstWebhookLock === 'payment-first') {
      // Old ordering: webhook owns payment while funding owns both participant
      // rows. Let the callback reach its wallet-user lock, then let funding
      // proceed until it needs the payment row: PostgreSQL detects the cycle.
      await waitForSignal(webhookUsersLockAttempted, 'webhook wallet-user lock');
      await waitForBlockedQuery(observer, '%FROM users%FOR NO KEY UPDATE%', 'webhook participant lock');
      fundingUserGate.resolve();
      await waitForBlockedQuery(
        observer,
        '%FROM payments WHERE job_id=$1 FOR UPDATE%',
        'funding replay payment lock',
      );
    } else {
      // Correct ordering: callback waits for participants before touching
      // payment. Funding replay can complete, after which the callback posts
      // exactly one internal escrow hold.
      await waitForBlockedQuery(observer, '%FROM users%FOR NO KEY UPDATE%', 'webhook participant lock');
      fundingUserGate.resolve();
    }

    const [fundingOutcome, webhookOutcome] = await Promise.all([fundingPromise, webhookPromise]);
    assert.equal(fundingOutcome.ok, true,
      'funding replay must finish without deadlock; observed ' +
        (fundingOutcome.error?.code || fundingOutcome.error?.message || 'unknown outcome'));
    assert.equal(fundingOutcome.value.created, false);
    assert.equal(webhookOutcome.ok, true,
      'internal hold webhook must finish without deadlock; observed ' +
        (webhookOutcome.error?.code || webhookOutcome.error?.message || 'unknown outcome'));
    assert.equal(webhookOutcome.value.processed, true);

    const { rows: persisted } = await observer.query(
      'SELECT p.status AS payment_status,w.available_balance,w.locked_balance,' +
        '(SELECT COUNT(*)::int FROM wallet_holds h WHERE h.reference_type=$2 AND h.reference_id=$1 AND h.status=$3) AS active_holds ' +
        'FROM payments p JOIN wallet_accounts w ON w.user_id=p.payer_id AND w.currency=$4 ' +
        'WHERE p.id=$1',
      [paymentId,'PAYMENT','ACTIVE','TOMAN'],
    );
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].payment_status, 'HELD');
    assert.equal(String(persisted[0].available_balance), '899');
    assert.equal(String(persisted[0].locked_balance), '100');
    assert.equal(persisted[0].active_holds, 1, 'concurrent replay and callback must create exactly one active escrow hold');
  } finally {
    fundingUserGate.resolve();
    if (fundingPromise || webhookPromise) {
      await Promise.allSettled([fundingPromise, webhookPromise].filter(Boolean));
    }
    if (patchedConnect) pool.connect = originalPoolConnect;
    appConfig.paymentProvider = previousProvider;

    if (observer) {
      try {
        const { rows: holds } = await observer.query(
          'SELECT id FROM wallet_holds WHERE reference_type=$1 AND reference_id=$2 LIMIT 1',
          ['PAYMENT',paymentId],
        );
        if (!holds.length) {
          await observer.query('BEGIN');
          await observer.query('DELETE FROM payment_webhook_events WHERE event_id=$1', [eventId]);
          await observer.query('DELETE FROM provider_events WHERE provider=$1 AND provider_event_id=$2', ['internal',eventId]);
          await observer.query('DELETE FROM payments WHERE id=$1', [paymentId]);
          if (jobId) await observer.query('DELETE FROM jobs WHERE id=$1', [jobId]);
          await observer.query('COMMIT');
        }
      } catch (error) {
        await observer.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        observer.release();
      }
    }
  }
});


test('refund refuses when any release outbox event is processing, even if a newer event is pending', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const suffix = crypto.randomBytes(7).toString('hex');
  const jobId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const processingEventId = crypto.randomUUID();
  const pendingEventId = crypto.randomUUID();
  const processingLease = crypto.randomUUID();
  const refundId = crypto.randomUUID();
  const { rows: jobs } = await pool.query(
    'INSERT INTO jobs(' +
      'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
      'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
      'created_at,updated_at) ' +
      "SELECT $1,$2,$3,'R05 multiple release-event fixture'," +
      "'PostgreSQL multiple release event/refund fixture',c.id,'FIXED','FIXED'," +
      "100,130,1,'R05 multiple release-event fixture','COMPLETED'," +
      "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
      'FROM categories c WHERE c.is_active=TRUE ' +
      'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
    [jobId,fixture.ownerId,fixture.workerId],
  );
  assert.ok(jobs[0],'multiple release-event fixture requires an active category');

  try {
    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'RELEASE_PENDING',$5,$6,100,30,0,30,130,100,'R05-test','TOMAN',NOW(),NOW())",
      [paymentId,jobId,fixture.ownerId,fixture.workerId,'provider-hold-'+suffix,'multi-release-refund-'+suffix],
    );

    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW()-INTERVAL '1 minute')",
      [processingEventId,paymentId,'old-processing-release-'+suffix,JSON.stringify({jobId,paymentId}),processingLease],
    );
    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'PENDING',0,NOW(),NULL,NULL,NOW())",
      [pendingEventId,paymentId,'new-pending-release-'+suffix,JSON.stringify({jobId,paymentId})],
    );

    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    await assert.rejects(
      createRefundAtomic({
        jobId,
        paymentId,
        ownerId:fixture.ownerId,
        amount:100,
        id:refundId,
        idempotencyKey:'multi-release-refund-request-'+suffix,
        createdAt:new Date(),
        allowPendingRelease:true,
      }),
      (error) => error?.code === 'PAYMENT_RELEASE_IN_PROGRESS',
      'an older PROCESSING release event must block refund even when a newer event is PENDING',
    );

    const { rows: persisted } = await pool.query(
      'SELECT p.status AS payment_status,' +
        'old.status AS old_event_status,newer.status AS newer_event_status,' +
        'COUNT(r.id)::int AS refund_count ' +
        'FROM payments p ' +
        'JOIN outbox_events old ON old.id=$2 ' +
        'JOIN outbox_events newer ON newer.id=$3 ' +
        'LEFT JOIN refunds r ON r.payment_id=p.id ' +
        'WHERE p.id=$1 ' +
        'GROUP BY p.id,old.status,newer.status',
      [paymentId,processingEventId,pendingEventId],
    );
    assert.equal(persisted.length,1);
    assert.equal(persisted[0].payment_status,'RELEASE_PENDING');
    assert.equal(persisted[0].old_event_status,'PROCESSING');
    assert.equal(persisted[0].newer_event_status,'PENDING');
    assert.equal(persisted[0].refund_count,0);
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE aggregate_id=$1',[paymentId]);
    await pool.query('DELETE FROM refunds WHERE payment_id=$1',[paymentId]);
    await pool.query('DELETE FROM payments WHERE id=$1',[paymentId]);
    await pool.query('DELETE FROM jobs WHERE id=$1',[jobId]);
  }
});

test('release outbox completion serializes with a refund that supersedes a pending release', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const ownerId = await createTransferTestUser(pool, 'release-lock-owner');
  const workerId = await createTransferTestUser(pool, 'release-lock-worker');
  const suffix = crypto.randomBytes(8).toString('hex');
  const eventId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const leaseToken = crypto.randomUUID();
  const holdRef = 'release-lock-hold-' + suffix;
  const releaseRef = 'release-lock-settlement-' + suffix;
  const previousProvider = appConfig.paymentProvider;
  let jobId = null;
  let observer = null;
  let originalPoolConnect = null;
  let requestPromise = null;
  let workerPromise = null;
  let patchedConnect = false;

  const requestJobGate = deferredGate();
  const requestPaymentGate = deferredGate();
  const requestEventGate = deferredGate();
  const requestJobLocked = deferredGate();
  const requestPaymentLocked = deferredGate();
  const requestEventLocked = deferredGate();
  const requestEventLockAttempted = deferredGate();
  const workerJobLockAttempted = deferredGate();
  const workerEventLocked = deferredGate();
  const workerEventGate = deferredGate();

  function deferredGate() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
  }

  const waitForSignal = async (signal, description, timeoutMs = 7000) => {
    let timeout;
    try {
      await Promise.race([
        signal.promise,
        new Promise((_, reject) => {
          timeout = setTimeout(() => reject(new Error(description + ' timed out')), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  const waitForBlockedQuery = async (client, pattern, description, timeoutMs = 7000) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const { rows } = await client.query(
        'SELECT pid,query,wait_event_type,wait_event FROM pg_stat_activity ' +
          'WHERE datname=current_database() AND pid<>pg_backend_pid() ' +
          "AND wait_event_type='Lock' AND query ILIKE $1",
        [pattern],
      );
      if (rows.length) return rows[0];
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(description + ' did not reach the expected PostgreSQL lock wait');
  };

  try {
    const { rows: jobs } = await pool.query(
      'INSERT INTO jobs(' +
        'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
        'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
        'created_at,updated_at) ' +
        "SELECT gen_random_uuid(),$1,$2,'R05 release lock-order fixture'," +
        "'PostgreSQL release/refund concurrency fixture',c.id,'FIXED','FIXED'," +
        "100,130,1,'R05 release lock-order fixture','COMPLETED'," +
        "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
        'FROM categories c WHERE c.is_active=TRUE ' +
        'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
      [ownerId,workerId],
    );
    assert.ok(jobs[0], 'release lock-order fixture requires an active category');
    jobId = jobs[0].id;

    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'RELEASE_PENDING',$5,$6,100,30,0,30,130,100,'R05-test','USD',NOW(),NOW())",
      [paymentId,jobId,ownerId,workerId,holdRef,'release-lock-payment-' + suffix],
    );
    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())",
      [eventId,paymentId,'release-lock-event-' + suffix,JSON.stringify({jobId,paymentId}),leaseToken],
    );

    observer = await pool.connect();
    originalPoolConnect = pool.connect;
    const connect = pool.connect.bind(pool);
    let serviceConnection = 0;
    pool.connect = async (...args) => {
      const client = await connect(...args);
      serviceConnection += 1;
      const role = serviceConnection;
      const originalQuery = client.query.bind(client);
      client.query = async (queryText, ...queryArgs) => {
        const sql = typeof queryText === 'string' ? queryText : String(queryText?.text || '');
        const normalized = sql.replace(/\s+/g, ' ').toUpperCase();
        const isJobLock = normalized.includes('FROM JOBS WHERE ID=$1 FOR UPDATE');
        const isPaymentLock = normalized.includes('FROM PAYMENTS WHERE ID=$1 AND JOB_ID=$2 FOR UPDATE');
        const isRequestReleaseEventLock = role === 1 &&
          normalized.includes('FROM OUTBOX_EVENTS') &&
          normalized.includes('AGGREGATE_ID=$1') && normalized.includes('FOR UPDATE');
        const isOutboxLock = normalized.includes('FROM OUTBOX_EVENTS WHERE ID=$1 FOR UPDATE');

        if (isRequestReleaseEventLock) requestEventLockAttempted.resolve();
        if (role === 2 && isJobLock) workerJobLockAttempted.resolve();

        const result = await originalQuery(queryText, ...queryArgs);

        if (role === 1 && isJobLock) {
          requestJobLocked.resolve();
          await requestJobGate.promise;
        }
        if (role === 1 && isRequestReleaseEventLock) {
          requestEventLocked.resolve();
          await requestEventGate.promise;
        }
        if (role === 1 && isPaymentLock) {
          requestPaymentLocked.resolve();
          await requestPaymentGate.promise;
        }
        if (role === 2 && isOutboxLock) {
          workerEventLocked.resolve();
          await workerEventGate.promise;
        }
        return result;
      };
      return client;
    };
    patchedConnect = true;

    appConfig.paymentProvider = 'webhook';
    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    const { completePaymentReleaseOutbox } = await import('../src/repository/outbox.js');

    requestPromise = createRefundAtomic({
      jobId,
      paymentId,
      ownerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey:'refund-for-pending-release-' + suffix,
      createdAt:new Date(),
      allowPendingRelease:true,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    await waitForSignal(requestJobLocked, 'refund request job lock');

    workerPromise = completePaymentReleaseOutbox({
      eventId,
      jobId,
      paymentId,
      actorId:ownerId,
      leaseToken,
      providerReleaseRef:releaseRef,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    const firstWorkerLock = await Promise.race([
      workerJobLockAttempted.promise.then(() => 'job-first'),
      workerEventLocked.promise.then(() => 'event-first'),
    ]);

    if (firstWorkerLock === 'event-first') {
      // Old lock ordering: worker owns the event; request owns the job.
      // Let the request lock payment and wait for the event, then let worker
      // continue until it waits for payment, creating a deterministic cycle.
      requestJobGate.resolve();
      await waitForSignal(requestPaymentLocked, 'refund request payment lock');
      requestPaymentGate.resolve();
      await waitForSignal(requestEventLockAttempted, 'refund request outbox lock attempt');
      await waitForBlockedQuery(observer, '%FROM outbox_events%FOR UPDATE%', 'refund request outbox lock');
      workerEventGate.resolve();
    } else {
      // Correct job-first order: the worker cannot own the event while the
      // request holds the job. The request sees PROCESSING, rejects safely,
      // and releases the aggregate for the worker to complete the settlement.
      await waitForBlockedQuery(observer, '%FROM jobs WHERE id=$1 FOR UPDATE%', 'release worker job lock');
      requestJobGate.resolve();
      await waitForSignal(requestEventLocked, 'refund request release-event lock');
      requestEventGate.resolve();
      const requestOutcome = await requestPromise;
      assert.equal(requestOutcome.error?.code, 'PAYMENT_RELEASE_IN_PROGRESS');
      await waitForSignal(workerEventLocked, 'release worker outbox event lock');
      workerEventGate.resolve();
    }

    const [requestOutcome, workerOutcome] = await Promise.all([requestPromise, workerPromise]);
    assert.equal(
      requestOutcome.error?.code,
      'PAYMENT_RELEASE_IN_PROGRESS',
      'refund must reject while the provider release is already processing',
    );
    assert.equal(
      workerOutcome.ok,
      true,
      'release outbox completion must proceed without a lock-order deadlock; observed ' +
        (workerOutcome.error?.code || workerOutcome.error?.message || 'unknown outcome'),
    );
    assert.equal(workerOutcome.value.completed, true);

    const { rows: persisted } = await observer.query(
      'SELECT p.status AS payment_status,j.status AS job_status,o.status AS outbox_status ' +
        'FROM payments p JOIN jobs j ON j.id=p.job_id JOIN outbox_events o ON o.id=$2 ' +
        'WHERE p.id=$1',
      [paymentId,eventId],
    );
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].payment_status, 'RELEASED');
    assert.equal(persisted[0].job_status, 'SETTLED');
    assert.equal(persisted[0].outbox_status, 'DONE');
  } finally {
    requestJobGate.resolve();
    requestPaymentGate.resolve();
    requestEventGate.resolve();
    workerEventGate.resolve();
    if (requestPromise || workerPromise) {
      await Promise.allSettled([requestPromise, workerPromise].filter(Boolean));
    }
    if (patchedConnect) pool.connect = originalPoolConnect;
    appConfig.paymentProvider = previousProvider;

    if (observer) {
      try {
        const { rows: posted } = await observer.query(
          'SELECT j.id FROM journals j JOIN ledger_entries le ON le.journal_id=j.id ' +
            "WHERE le.reference_type IN ('PAYMENT_RELEASE','PAYMENT_PAYOUT') " +
            "AND le.reference_id=$1 AND j.status='POSTED' LIMIT 1",
          [paymentId],
        );
        if (!posted.length) {
          await observer.query('BEGIN');
          await observer.query('DELETE FROM audit_logs WHERE entity_type=$1 AND entity_id=$2', ['payment',paymentId]);
          await observer.query('DELETE FROM settlements WHERE payment_id=$1', [paymentId]);
          await observer.query('DELETE FROM outbox_events WHERE id=$1', [eventId]);
          await observer.query('DELETE FROM payments WHERE id=$1', [paymentId]);
          if (jobId) await observer.query('DELETE FROM jobs WHERE id=$1', [jobId]);
          await observer.query('COMMIT');
        }
      } catch (error) {
        await observer.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        observer.release();
      }
    }
  }
});




test('terminal hold failure serializes with provider hold completion without a deadlock', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const ownerId = await createTransferTestUser(pool, 'hold-failure-lock-owner');
  const workerId = await createTransferTestUser(pool, 'hold-failure-lock-worker');
  const suffix = crypto.randomBytes(8).toString('hex');
  const eventId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const leaseToken = crypto.randomUUID();
  const holdRef = 'hold-failure-provider-' + suffix;
  const previousProvider = appConfig.paymentProvider;
  let jobId = null;
  let observer = null;
  let originalPoolConnect = null;
  let completionPromise = null;
  let failurePromise = null;
  let patchedConnect = false;

  const completionPaymentGate = deferredGate();
  const completionEventGate = deferredGate();
  const failureEventGate = deferredGate();
  const completionPaymentLocked = deferredGate();
  const completionEventLocked = deferredGate();
  const completionEventLockAttempted = deferredGate();
  const failureJobLockAttempted = deferredGate();
  const failureEventLocked = deferredGate();

  function deferredGate() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
  }

  const waitForSignal = async (signal, description, timeoutMs = 7000) => {
    let timeout;
    try {
      await Promise.race([
        signal.promise,
        new Promise((_, reject) => {
          timeout = setTimeout(() => reject(new Error(description + ' timed out')), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  const waitForBlockedQuery = async (client, pattern, description, timeoutMs = 7000) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const { rows } = await client.query(
        'SELECT pid,query,wait_event_type,wait_event FROM pg_stat_activity ' +
          'WHERE datname=current_database() AND pid<>pg_backend_pid() ' +
          "AND wait_event_type='Lock' AND query ILIKE $1",
        [pattern],
      );
      if (rows.length) return rows[0];
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(description + ' did not reach the expected PostgreSQL lock wait');
  };

  try {
    const { rows: jobs } = await pool.query(
      'INSERT INTO jobs(' +
        'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
        'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
        'created_at,updated_at) ' +
        "SELECT gen_random_uuid(),$1,$2,'R05 hold failure lock-order fixture'," +
        "'PostgreSQL hold failure/completion concurrency fixture',c.id,'FIXED','FIXED'," +
        "100,130,1,'R05 hold failure lock-order fixture','FUNDED'," +
        "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
        'FROM categories c WHERE c.is_active=TRUE ' +
        'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
      [ownerId,workerId],
    );
    assert.ok(jobs[0], 'hold failure lock-order fixture requires an active category');
    jobId = jobs[0].id;

    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,funding_previous_job_status,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'HOLD_PENDING',$5,$6,100,30,0,30,130,100,'R05-test','USD','ASSIGNED',NOW(),NOW())",
      [paymentId,jobId,ownerId,workerId,'PENDING:'+paymentId,'hold-failure-payment-' + suffix],
    );
    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_CREATE_HOLD','payment',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())",
      [eventId,paymentId,'hold-failure-event-' + suffix,JSON.stringify({jobId,ownerId,paymentId}),leaseToken],
    );

    observer = await pool.connect();
    originalPoolConnect = pool.connect;
    const connect = pool.connect.bind(pool);
    let serviceConnection = 0;
    pool.connect = async (...args) => {
      const client = await connect(...args);
      serviceConnection += 1;
      const role = serviceConnection;
      const originalQuery = client.query.bind(client);
      client.query = async (queryText, ...queryArgs) => {
        const sql = typeof queryText === 'string' ? queryText : String(queryText?.text || '');
        const normalized = sql.replace(/\s+/g, ' ').toUpperCase();
        const isCompletionPaymentLock = role === 1 &&
          normalized.includes('FROM PAYMENTS WHERE ID=$1 AND JOB_ID=$2 FOR UPDATE');
        const isCompletionEventLock = role === 1 &&
          normalized.includes('FROM OUTBOX_EVENTS WHERE ID=$1 FOR UPDATE');
        const isFailureJobLock = role === 2 &&
          normalized.includes('FROM JOBS WHERE ID=$1 FOR UPDATE');
        const isFailureEventLock = role === 2 &&
          normalized.includes('FROM OUTBOX_EVENTS WHERE ID=$1 FOR UPDATE');

        if (isCompletionEventLock) completionEventLockAttempted.resolve();
        if (isFailureJobLock) failureJobLockAttempted.resolve();

        const result = await originalQuery(queryText, ...queryArgs);

        if (isCompletionPaymentLock) {
          completionPaymentLocked.resolve();
          await completionPaymentGate.promise;
        }
        if (isCompletionEventLock) {
          completionEventLocked.resolve();
          await completionEventGate.promise;
        }
        if (isFailureEventLock) {
          failureEventLocked.resolve();
          await failureEventGate.promise;
        }
        return result;
      };
      return client;
    };
    patchedConnect = true;

    appConfig.paymentProvider = 'webhook';
    const { completePaymentCreateHoldOutbox } = await import('../src/repository/outbox.js');

    completionPromise = completePaymentCreateHoldOutbox({
      eventId,
      jobId,
      paymentId,
      providerRef:holdRef,
      actorId:ownerId,
      leaseToken,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    await waitForSignal(completionPaymentLocked, 'provider hold completion payment lock');

    failurePromise = failOutboxEvent({
      eventId,
      error:'R05 terminal provider hold failure',
      maxAttempts:1,
      leaseToken,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    const firstFailureLock = await Promise.race([
      failureEventLocked.promise.then(() => 'event-first'),
      failureJobLockAttempted.promise.then(() => 'job-first'),
    ]);

    if (firstFailureLock === 'event-first') {
      // Old ordering: failure owns outbox while provider completion owns payment.
      completionPaymentGate.resolve();
      await waitForSignal(completionEventLockAttempted, 'provider completion outbox lock attempt');
      await waitForBlockedQuery(observer, '%FROM outbox_events WHERE id=$1 FOR UPDATE%', 'provider completion outbox lock');
      failureEventGate.resolve();
    } else {
      // Correct aggregate ordering: failure waits for the job before outbox.
      await waitForBlockedQuery(observer, '%FROM jobs WHERE id=$1 FOR UPDATE%', 'terminal hold failure job lock');
      completionPaymentGate.resolve();
      await waitForSignal(completionEventLocked, 'provider completion outbox lock');
      completionEventGate.resolve();
      const completionOutcome = await completionPromise;
      assert.equal(completionOutcome.ok, true,
        'provider hold completion must win without deadlock; observed ' +
          (completionOutcome.error?.code || completionOutcome.error?.message || 'unknown outcome'));
      assert.equal(completionOutcome.value.completed, true);
      await waitForSignal(failureEventLocked, 'terminal failure outbox lock after completion');
      failureEventGate.resolve();
    }

    const [completionOutcome,failureOutcome] = await Promise.all([completionPromise,failurePromise]);
    assert.equal(
      completionOutcome.ok,
      true,
      'provider hold completion must finish without PostgreSQL deadlock; observed ' +
        (completionOutcome.error?.code || completionOutcome.error?.message || 'unknown outcome'),
    );
    assert.equal(completionOutcome.value.completed, true);
    assert.equal(
      failureOutcome.ok,
      true,
      'terminal hold failure must serialize with provider completion; observed ' +
        (failureOutcome.error?.code || failureOutcome.error?.message || 'unknown outcome'),
    );
    assert.equal(failureOutcome.value.alreadyDone, true);

    const { rows: persisted } = await observer.query(
      'SELECT p.status AS payment_status,o.status AS outbox_status ' +
        'FROM payments p JOIN outbox_events o ON o.id=$2 WHERE p.id=$1',
      [paymentId,eventId],
    );
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].payment_status, 'HELD');
    assert.equal(persisted[0].outbox_status, 'DONE');
  } finally {
    completionPaymentGate.resolve();
    completionEventGate.resolve();
    failureEventGate.resolve();
    if (completionPromise || failurePromise) {
      await Promise.allSettled([completionPromise,failurePromise].filter(Boolean));
    }
    if (patchedConnect) pool.connect = originalPoolConnect;
    appConfig.paymentProvider = previousProvider;

    if (observer) {
      try {
        const { rows: posted } = await observer.query(
          "SELECT j.id FROM journals j JOIN ledger_entries le ON le.journal_id=j.id " +
            "WHERE le.reference_type='PAYMENT_FUND' AND le.reference_id=$1 " +
            "AND j.journal_type='EXTERNAL_FUNDING' AND j.status='POSTED' LIMIT 1",
          [paymentId],
        );
        if (!posted.length) {
          await observer.query('BEGIN');
          await observer.query('DELETE FROM audit_logs WHERE entity_type=$1 AND entity_id=$2', ['payment',paymentId]);
          await observer.query('DELETE FROM outbox_events WHERE id=$1', [eventId]);
          await observer.query('DELETE FROM payments WHERE id=$1', [paymentId]);
          if (jobId) await observer.query('DELETE FROM jobs WHERE id=$1', [jobId]);
          await observer.query('COMMIT');
        }
      } catch (error) {
        await observer.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        observer.release();
      }
    }
  }
});


test('terminal release failure serializes with refund supersession without a deadlock', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const ownerId = await createTransferTestUser(pool, 'release-failure-lock-owner');
  const workerId = await createTransferTestUser(pool, 'release-failure-lock-worker');
  const suffix = crypto.randomBytes(8).toString('hex');
  const eventId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const leaseToken = crypto.randomUUID();
  const holdRef = 'release-failure-lock-hold-' + suffix;
  const previousProvider = appConfig.paymentProvider;
  let jobId = null;
  let observer = null;
  let originalPoolConnect = null;
  let requestPromise = null;
  let failurePromise = null;
  let patchedConnect = false;

  const requestPaymentGate = deferredGate();
  const requestEventGate = deferredGate();
  const failureEventGate = deferredGate();
  const requestPaymentLocked = deferredGate();
  const requestEventLocked = deferredGate();
  const requestEventLockAttempted = deferredGate();
  const failureJobLockAttempted = deferredGate();
  const failureEventLocked = deferredGate();

  function deferredGate() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
  }

  const waitForSignal = async (signal, description, timeoutMs = 7000) => {
    let timeout;
    try {
      await Promise.race([
        signal.promise,
        new Promise((_, reject) => {
          timeout = setTimeout(() => reject(new Error(description + ' timed out')), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  const waitForBlockedQuery = async (client, pattern, description, timeoutMs = 7000) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const { rows } = await client.query(
        'SELECT pid,query,wait_event_type,wait_event FROM pg_stat_activity ' +
          'WHERE datname=current_database() AND pid<>pg_backend_pid() ' +
          "AND wait_event_type='Lock' AND query ILIKE $1",
        [pattern],
      );
      if (rows.length) return rows[0];
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(description + ' did not reach the expected PostgreSQL lock wait');
  };

  try {
    const { rows: jobs } = await pool.query(
      'INSERT INTO jobs(' +
        'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
        'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
        'created_at,updated_at) ' +
        "SELECT gen_random_uuid(),$1,$2,'R05 release failure lock-order fixture'," +
        "'PostgreSQL release failure/refund concurrency fixture',c.id,'FIXED','FIXED'," +
        "100,130,1,'R05 release failure lock-order fixture','COMPLETED'," +
        "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
        'FROM categories c WHERE c.is_active=TRUE ' +
        'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
      [ownerId,workerId],
    );
    assert.ok(jobs[0], 'release failure lock-order fixture requires an active category');
    jobId = jobs[0].id;

    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'RELEASE_PENDING',$5,$6,100,30,0,30,130,100,'R05-test','USD',NOW(),NOW())",
      [paymentId,jobId,ownerId,workerId,holdRef,'release-failure-lock-payment-' + suffix],
    );
    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())",
      [eventId,paymentId,'release-failure-lock-event-' + suffix,JSON.stringify({jobId,paymentId}),leaseToken],
    );

    observer = await pool.connect();
    originalPoolConnect = pool.connect;
    const connect = pool.connect.bind(pool);
    let serviceConnection = 0;
    pool.connect = async (...args) => {
      const client = await connect(...args);
      serviceConnection += 1;
      const role = serviceConnection;
      const originalQuery = client.query.bind(client);
      client.query = async (queryText, ...queryArgs) => {
        const sql = typeof queryText === 'string' ? queryText : String(queryText?.text || '');
        const normalized = sql.replace(/\s+/g, ' ').toUpperCase();
        const isRequestPaymentLock = role === 1 &&
          normalized.includes('FROM PAYMENTS WHERE ID=$1 AND JOB_ID=$2 FOR UPDATE');
        const isRequestReleaseEventLock = role === 1 &&
          normalized.includes('FROM OUTBOX_EVENTS') &&
          normalized.includes('AGGREGATE_ID=$1') && normalized.includes('FOR UPDATE');
        const isFailureJobLock = role === 2 &&
          normalized.includes('FROM JOBS WHERE ID=$1 FOR UPDATE');
        const isFailureEventLock = role === 2 &&
          normalized.includes('FROM OUTBOX_EVENTS WHERE ID=$1 FOR UPDATE');

        if (isRequestReleaseEventLock) requestEventLockAttempted.resolve();
        if (isFailureJobLock) failureJobLockAttempted.resolve();

        const result = await originalQuery(queryText, ...queryArgs);

        if (isRequestPaymentLock) {
          requestPaymentLocked.resolve();
          await requestPaymentGate.promise;
        }
        if (isRequestReleaseEventLock) {
          requestEventLocked.resolve();
          await requestEventGate.promise;
        }
        if (isFailureEventLock) {
          failureEventLocked.resolve();
          await failureEventGate.promise;
        }
        return result;
      };
      return client;
    };
    patchedConnect = true;

    appConfig.paymentProvider = 'webhook';
    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');

    requestPromise = createRefundAtomic({
      jobId,
      paymentId,
      ownerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey:'refund-after-release-failure-' + suffix,
      createdAt:new Date(),
      allowPendingRelease:true,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    const firstRequestLock = await Promise.race([
      requestPaymentLocked.promise.then(() => 'payment-first'),
      requestEventLocked.promise.then(() => 'event-first'),
    ]);

    failurePromise = failOutboxEvent({
      eventId,
      error:'R05 terminal release provider failure',
      maxAttempts:1,
      leaseToken,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    if (firstRequestLock === 'payment-first') {
      // Old ordering: refund owns payment; terminal failure owns outbox.
      await waitForSignal(failureEventLocked, 'terminal release failure outbox lock');
      requestPaymentGate.resolve();
      await waitForSignal(requestEventLockAttempted, 'refund release-event lock attempt');
      await waitForBlockedQuery(observer, '%FROM outbox_events%FOR UPDATE%', 'refund release-event lock');
      failureEventGate.resolve();
    } else {
      // Correct aggregate-first ordering: refund owns job -> release-event and
      // the failure worker must wait for the job before acquiring event/payment.
      await waitForSignal(failureJobLockAttempted, 'terminal release failure job lock attempt');
      await waitForBlockedQuery(observer, '%FROM jobs WHERE id=$1 FOR UPDATE%', 'terminal release failure job lock');
      requestEventGate.resolve();
      const requestOutcome = await requestPromise;
      assert.equal(requestOutcome.error?.code, 'PAYMENT_RELEASE_IN_PROGRESS');
      await waitForSignal(failureEventLocked, 'terminal release failure outbox lock after refund exits');
      failureEventGate.resolve();
    }

    const [requestOutcome, failureOutcome] = await Promise.all([requestPromise,failurePromise]);
    assert.equal(
      requestOutcome.error?.code,
      'PAYMENT_RELEASE_IN_PROGRESS',
      'refund must not race a release event already being processed',
    );
    assert.equal(
      failureOutcome.ok,
      true,
      'terminal release failure must complete without a PostgreSQL deadlock; observed ' +
        (failureOutcome.error?.code || failureOutcome.error?.message || 'unknown outcome'),
    );
    assert.equal(failureOutcome.value.terminal, true);

    const { rows: persisted } = await observer.query(
      'SELECT p.status AS payment_status,o.status AS outbox_status ' +
        'FROM payments p JOIN outbox_events o ON o.id=$2 WHERE p.id=$1',
      [paymentId,eventId],
    );
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].payment_status, 'RELEASE_FAILED');
    assert.equal(persisted[0].outbox_status, 'FAILED');
  } finally {
    requestPaymentGate.resolve();
    requestEventGate.resolve();
    failureEventGate.resolve();
    if (requestPromise || failurePromise) {
      await Promise.allSettled([requestPromise,failurePromise].filter(Boolean));
    }
    if (patchedConnect) pool.connect = originalPoolConnect;
    appConfig.paymentProvider = previousProvider;

    if (observer) {
      try {
        await observer.query('BEGIN');
        await observer.query('DELETE FROM audit_logs WHERE entity_type=$1 AND entity_id=$2', ['payment',paymentId]);
        await observer.query('DELETE FROM settlements WHERE payment_id=$1', [paymentId]);
        await observer.query('DELETE FROM refunds WHERE payment_id=$1', [paymentId]);
        await observer.query('DELETE FROM outbox_events WHERE id=$1', [eventId]);
        await observer.query('DELETE FROM payments WHERE id=$1', [paymentId]);
        if (jobId) await observer.query('DELETE FROM jobs WHERE id=$1', [jobId]);
        await observer.query('COMMIT');
      } catch (error) {
        await observer.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        observer.release();
      }
    }
  }
});


test('internal create-hold outbox completion follows participant/job/payment order during funding replay', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const ownerId = await createTransferTestUser(pool, 'hold-outbox-lock-owner');
  const workerId = await createTransferTestUser(pool, 'hold-outbox-lock-worker');
  const suffix = crypto.randomBytes(8).toString('hex');
  const eventId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const leaseToken = crypto.randomUUID();
  const holdRef = 'hold-outbox-provider-' + suffix;
  const idempotencyKey = 'hold-outbox-funding-' + suffix;
  const previousProvider = appConfig.paymentProvider;
  let jobId = null;
  let observer = null;
  let originalPoolConnect = null;
  let fundingPromise = null;
  let outboxPromise = null;
  let patchedConnect = false;

  const fundingUserGate = deferredGate();
  const fundingUsersLocked = deferredGate();
  const outboxUsersLockAttempted = deferredGate();
  const outboxPaymentLocked = deferredGate();

  function deferredGate() {
    let resolve;
    const promise = new Promise((done) => { resolve = done; });
    return { promise, resolve };
  }

  const waitForSignal = async (signal, description, timeoutMs = 7000) => {
    let timeout;
    try {
      await Promise.race([
        signal.promise,
        new Promise((_, reject) => {
          timeout = setTimeout(() => reject(new Error(description + ' timed out')), timeoutMs);
        }),
      ]);
    } finally {
      clearTimeout(timeout);
    }
  };

  const waitForBlockedQuery = async (client, pattern, description, timeoutMs = 7000) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      const { rows } = await client.query(
        'SELECT pid,query,wait_event_type,wait_event FROM pg_stat_activity ' +
          'WHERE datname=current_database() AND pid<>pg_backend_pid() ' +
          "AND wait_event_type='Lock' AND query ILIKE $1",
        [pattern],
      );
      if (rows.length) return rows[0];
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    throw new Error(description + ' did not reach the expected PostgreSQL lock wait');
  };

  try {
    await creditWallet({
      userId:ownerId,
      amount:'1000',
      idempotencyKey:'seed-hold-outbox-wallet-' + suffix,
    });

    const { rows: jobs } = await pool.query(
      'INSERT INTO jobs(' +
        'id,owner_id,provider_id,title,description,category_id,job_type,budget_type,' +
        'budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,' +
        'created_at,updated_at) ' +
        "SELECT gen_random_uuid(),$1,$2,'R05 hold outbox lock-order fixture'," +
        "'PostgreSQL internal hold outbox/funding concurrency fixture',c.id,'FIXED','FIXED'," +
        "100,100,1,'R05 hold outbox lock-order fixture','FUNDED'," +
        "'R05 test','MISSION','PUBLIC',NOW(),NOW() " +
        'FROM categories c WHERE c.is_active=TRUE ' +
        'ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
      [ownerId,workerId],
    );
    assert.ok(jobs[0], 'internal hold outbox fixture requires an active category');
    jobId = jobs[0].id;

    await pool.query(
      'INSERT INTO payments(' +
        'id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,' +
        'base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,' +
        'fee_policy_version,currency,created_at,updated_at) ' +
        "VALUES($1,$2,$3,$4,100,'HOLD_PENDING',$5,$6,100,0,0,1,101,100,'R05-test','TOMAN',NOW(),NOW())",
      [paymentId,jobId,ownerId,workerId,holdRef,idempotencyKey],
    );
    await pool.query(
      'INSERT INTO outbox_events(' +
        'id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,' +
        'available_at,locked_at,lease_token,created_at) ' +
        "VALUES($1,'PAYMENT_CREATE_HOLD','payment',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())",
      [eventId,paymentId,'PAYMENT_CREATE_HOLD:' + paymentId,JSON.stringify({jobId,ownerId,paymentId}),leaseToken],
    );

    observer = await pool.connect();
    originalPoolConnect = pool.connect;
    const connect = pool.connect.bind(pool);
    let serviceConnection = 0;
    pool.connect = async (...args) => {
      const client = await connect(...args);
      serviceConnection += 1;
      const role = serviceConnection;
      const originalQuery = client.query.bind(client);
      client.query = async (queryText, ...queryArgs) => {
        const sql = typeof queryText === 'string' ? queryText : String(queryText?.text || '');
        const normalized = sql.replace(/\s+/g, ' ').toUpperCase();
        const isUsersLock = normalized.includes('FROM USERS') && normalized.includes('FOR NO KEY UPDATE');
        const isPaymentLock = normalized.includes('FROM PAYMENTS WHERE ID=$1 AND JOB_ID=$2 FOR UPDATE');

        if (role === 2 && isUsersLock) outboxUsersLockAttempted.resolve();

        const result = await originalQuery(queryText, ...queryArgs);

        if (role === 1 && isUsersLock) {
          fundingUsersLocked.resolve();
          await fundingUserGate.promise;
        }
        if (role === 2 && isPaymentLock) outboxPaymentLocked.resolve();
        return result;
      };
      return client;
    };
    patchedConnect = true;

    appConfig.paymentProvider = 'internal';
    const { fundJobAtomic } = await import('../src/repository/payment_funding.js');
    const { completePaymentCreateHoldOutbox } = await import('../src/repository/outbox.js');

    fundingPromise = fundJobAtomic({
      jobId,
      payerId:ownerId,
      payeeId:workerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey,
      createdAt:new Date(),
      breakdown:{
        currency:'TOMAN',
        baseAmount:'100',
        employerFee:'0',
        workerFee:'0',
        platformFee:'1',
        employerCharge:'101',
        providerPayout:'100',
        policyVersion:'R05-test',
      },
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    await waitForSignal(fundingUsersLocked, 'funding participant locks');

    outboxPromise = completePaymentCreateHoldOutbox({
      eventId,
      jobId,
      paymentId,
      providerRef:holdRef,
      actorId:ownerId,
      leaseToken,
    }).then((value) => ({ ok:true,value }), (error) => ({ ok:false,error }));

    const firstOutboxLock = await Promise.race([
      outboxUsersLockAttempted.promise.then(() => 'users-first'),
      outboxPaymentLocked.promise.then(() => 'payment-first'),
    ]);

    if (firstOutboxLock === 'payment-first') {
      // Old ordering: worker owns payment and event before waiting on users;
      // funding owns users and then waits for the same payment row.
      await waitForSignal(outboxUsersLockAttempted, 'outbox internal participant lock');
      await waitForBlockedQuery(observer, '%FROM users%FOR NO KEY UPDATE%', 'outbox participant lock');
      fundingUserGate.resolve();
      await waitForBlockedQuery(
        observer,
        '%FROM payments WHERE job_id=$1 FOR UPDATE%',
        'funding replay payment lock',
      );
    } else {
      // Correct ordering: outbox worker waits for participant rows before
      // job/payment/event, allowing a funding replay to finish and release them.
      await waitForBlockedQuery(observer, '%FROM users%FOR NO KEY UPDATE%', 'outbox participant lock');
      fundingUserGate.resolve();
    }

    const [fundingOutcome, outboxOutcome] = await Promise.all([fundingPromise,outboxPromise]);
    assert.equal(fundingOutcome.ok, true,
      'funding replay must finish without deadlock; observed ' +
        (fundingOutcome.error?.code || fundingOutcome.error?.message || 'unknown outcome'));
    assert.equal(fundingOutcome.value.created, false);
    assert.equal(outboxOutcome.ok, true,
      'internal create-hold outbox completion must finish without deadlock; observed ' +
        (outboxOutcome.error?.code || outboxOutcome.error?.message || 'unknown outcome'));
    assert.equal(outboxOutcome.value.completed, true);

    const { rows: persisted } = await observer.query(
      'SELECT p.status AS payment_status,o.status AS outbox_status,w.available_balance,w.locked_balance,' +
        '(SELECT COUNT(*)::int FROM wallet_holds h WHERE h.reference_type=$2 AND h.reference_id=$1 AND h.status=$3) AS active_holds ' +
        'FROM payments p JOIN outbox_events o ON o.id=$4 ' +
        'JOIN wallet_accounts w ON w.user_id=p.payer_id AND w.currency=$5 WHERE p.id=$1',
      [paymentId,'PAYMENT','ACTIVE',eventId,'TOMAN'],
    );
    assert.equal(persisted.length, 1);
    assert.equal(persisted[0].payment_status, 'HELD');
    assert.equal(persisted[0].outbox_status, 'DONE');
    assert.equal(String(persisted[0].available_balance), '899');
    assert.equal(String(persisted[0].locked_balance), '100');
    assert.equal(persisted[0].active_holds, 1);
  } finally {
    fundingUserGate.resolve();
    if (fundingPromise || outboxPromise) {
      await Promise.allSettled([fundingPromise,outboxPromise].filter(Boolean));
    }
    if (patchedConnect) pool.connect = originalPoolConnect;
    appConfig.paymentProvider = previousProvider;

    if (observer) {
      try {
        const { rows: holds } = await observer.query(
          'SELECT id FROM wallet_holds WHERE reference_type=$1 AND reference_id=$2 LIMIT 1',
          ['PAYMENT',paymentId],
        );
        if (!holds.length) {
          await observer.query('BEGIN');
          await observer.query('DELETE FROM outbox_events WHERE id=$1', [eventId]);
          await observer.query('DELETE FROM payments WHERE id=$1', [paymentId]);
          if (jobId) await observer.query('DELETE FROM jobs WHERE id=$1', [jobId]);
          await observer.query('COMMIT');
        }
      } catch (error) {
        await observer.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        observer.release();
      }
    }
  }
});


async function createExternalFundingFixture(label) {
  const pool = dbModule.getPool();
  const suffix = `${label}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  // Earlier deletion tests intentionally mark fixture.workerId DELETED. Funding
  // must never reuse that global participant; isolate new funding scenarios with
  // distinct active users so the production account guard is tested, not bypassed.
  const payerId = await createTransferTestUser(pool, `external-funding-payer-${label}`);
  const payeeId = await createTransferTestUser(pool, `external-funding-payee-${label}`);
  const { rows: jobs } = await pool.query(
    `INSERT INTO jobs(
       id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
       budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
       created_at,updated_at
     )
     SELECT gen_random_uuid(),$1,$2,$3,'External funding journal integration fixture',
       c.id,'FIXED','FIXED',100,130,1,'R05 external funding fixture','ASSIGNED',
       'R05 test','MISSION','PUBLIC',NOW(),NOW()
     FROM categories c WHERE c.is_active=TRUE
     ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1
     RETURNING id`,
    [payerId, payeeId, `R05 external funding ${suffix}`],
  );
  assert.ok(jobs[0], 'external funding fixture requires an active category');
  const paymentId = crypto.randomUUID();
  const createdAt = new Date();
  const breakdown = {
    policyVersion: 'R05-test',
    currency: 'USD',
    baseAmount: 100,
    employerFee: 30,
    workerFee: 0,
    platformFee: 30,
    employerCharge: 130,
    providerPayout: 100,
  };
  const result = await fundJobAtomic({
    jobId: jobs[0].id,
    payerId,
    payeeId,
    amount: 100,
    id: paymentId,
    idempotencyKey: `R05-external-fund-${suffix}`,
    createdAt,
    breakdown,
  });
  assert.equal(result.created, true);
  assert.ok(result.outboxEvent?.id, 'external funding fixture must enqueue a hold request');
  return { jobId: jobs[0].id, payerId, payeeId, paymentId, eventId: result.outboxEvent.id, idempotencyKey: `R05-external-fund-${suffix}`, breakdown };
}

test('funding replay rejects the same idempotency key with a different amount or payee', { skip: !enabled }, async () => {
  const previousProvider = appConfig.paymentProvider;
  appConfig.paymentProvider = 'webhook';
  try {
    const amountFixture = await createExternalFundingFixture('funding-idempotency-amount');
    await assert.rejects(
      fundJobAtomic({
        jobId: amountFixture.jobId,
        payerId: amountFixture.payerId,
        payeeId: amountFixture.payeeId,
        amount: 101,
        id: crypto.randomUUID(),
        idempotencyKey: amountFixture.idempotencyKey,
        createdAt: new Date(),
        breakdown: { ...amountFixture.breakdown, baseAmount:101, employerCharge:131.3, platformFee:31.3 },
      }),
      (error) => error?.code === 'IDEMPOTENCY_CONFLICT',
      'the same funding key must not silently replay a payment for a different amount',
    );

    const payeeFixture = await createExternalFundingFixture('funding-idempotency-payee');
    const differentPayeeId = await createTransferTestUser(dbModule.getPool(), 'funding-idempotency-different-payee');
    await assert.rejects(
      fundJobAtomic({
        jobId: payeeFixture.jobId,
        payerId: payeeFixture.payerId,
        payeeId: differentPayeeId,
        amount:100,
        id: crypto.randomUUID(),
        idempotencyKey: payeeFixture.idempotencyKey,
        createdAt: new Date(),
        breakdown: payeeFixture.breakdown,
      }),
      (error) => error?.code === 'IDEMPOTENCY_CONFLICT',
      'the same funding key must not silently replay a payment for a different payee',
    );
  } finally {
    appConfig.paymentProvider = previousProvider;
  }
});

test('funding idempotency replay after settlement returns the original payment', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const previousProvider = appConfig.paymentProvider;
  appConfig.paymentProvider = 'webhook';
  try {
    const fixtureRows = await createExternalFundingFixture('funding-replay-after-settlement');
    await pool.query(`UPDATE payments SET status='HELD' WHERE id=$1`, [fixtureRows.paymentId]);
    await pool.query(`UPDATE payments SET status='RELEASE_PENDING' WHERE id=$1`, [fixtureRows.paymentId]);
    await pool.query(`UPDATE payments SET status='RELEASED' WHERE id=$1`, [fixtureRows.paymentId]);
    await pool.query(`UPDATE jobs SET status='IN_PROGRESS' WHERE id=$1`, [fixtureRows.jobId]);
    await pool.query(`UPDATE jobs SET status='DELIVERED' WHERE id=$1`, [fixtureRows.jobId]);
    await pool.query(`UPDATE jobs SET status='COMPLETED' WHERE id=$1`, [fixtureRows.jobId]);
    await pool.query(`UPDATE jobs SET status='SETTLED' WHERE id=$1`, [fixtureRows.jobId]);

    const replay = await fundJobAtomic({
      jobId: fixtureRows.jobId,
      payerId: fixtureRows.payerId,
      payeeId: fixtureRows.payeeId,
      amount:100,
      id: crypto.randomUUID(),
      idempotencyKey:fixtureRows.idempotencyKey,
      createdAt:new Date(),
      breakdown:fixtureRows.breakdown,
    });

    assert.equal(replay.created, false);
    assert.equal(replay.payment.id, fixtureRows.paymentId);
    assert.equal(replay.payment.status, 'RELEASED');
    assert.equal(replay.outboxEvent, null);
    const { rows: payments } = await pool.query(
      `SELECT COUNT(*)::int AS count FROM payments WHERE job_id=$1`,
      [fixtureRows.jobId],
    );
    assert.equal(payments[0].count, 1, 'replay after settlement must not create another payment');
  } finally {
    appConfig.paymentProvider = previousProvider;
  }
});

test('external funding ledger is posted only after the provider confirms its hold', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const previousProvider = appConfig.paymentProvider;
  let fixtureRows;
  let eventId;
  appConfig.paymentProvider = 'webhook';
  try {
    fixtureRows = await createExternalFundingFixture('external-funding-success');
    eventId = fixtureRows.eventId;

    const before = await pool.query(
      `SELECT COUNT(*)::int AS count FROM ledger_entries
        WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`,
      [fixtureRows.paymentId],
    );
    assert.equal(before.rows[0].count, 0,
      'external funding must not be journal-posted before provider hold confirmation');

    const confirmed = await completePaymentCreateHoldOutbox({
      eventId: fixtureRows.eventId,
      jobId: fixtureRows.jobId,
      paymentId: fixtureRows.paymentId,
      providerRef: `confirmed-hold-${fixtureRows.paymentId}`,
      actorId: fixture.ownerId,
    });
    assert.equal(confirmed.completed, true);

    const { rows: payments } = await pool.query(
      'SELECT status FROM payments WHERE id=$1', [fixtureRows.paymentId],
    );
    assert.equal(payments[0].status, 'HELD');

    const { rows: journals } = await pool.query(
      `SELECT journal_id,COUNT(*)::int AS entries,
              SUM(debit)::numeric AS debits,SUM(credit)::numeric AS credits
         FROM ledger_entries
        WHERE reference_type='PAYMENT_FUND' AND reference_id=$1
        GROUP BY journal_id`,
      [fixtureRows.paymentId],
    );
    assert.equal(journals.length, 1, 'confirmed hold must create one funding journal group');
    assert.equal(journals[0].entries, 3);
    assert.equal(Number(journals[0].debits), Number(journals[0].credits));
    const { rows: canonicalRows } = await pool.query(
      `SELECT j.id,j.status,j.currency,fo.operation_type,fo.status AS operation_status
         FROM journals j JOIN financial_operations fo ON fo.id=j.operation_id WHERE j.id=$1`,
      [journals[0].journal_id],
    );
    assert.equal(canonicalRows.length, 1);
    assert.equal(canonicalRows[0].status, 'POSTED');
    assert.equal(canonicalRows[0].currency, 'USD');
    assert.equal(canonicalRows[0].operation_type, 'HOLD');
    assert.equal(canonicalRows[0].operation_status, 'SUCCEEDED');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (fixtureRows) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const { rows: canonicalRows } = await client.query(
          `SELECT j.id FROM journals j JOIN ledger_entries le ON le.journal_id=j.id
            WHERE le.reference_type='PAYMENT_FUND' AND le.reference_id=$1 AND j.status='POSTED' LIMIT 1`,
          [fixtureRows.paymentId],
        );
        if (!canonicalRows.length) {
          await client.query(`DELETE FROM ledger_entries WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`, [fixtureRows.paymentId]);
          await client.query('DELETE FROM outbox_events WHERE id=$1', [fixtureRows.eventId]);
          await client.query('DELETE FROM audit_logs WHERE entity_type=$1 AND entity_id=$2', ['payment',fixtureRows.paymentId]);
          await client.query('DELETE FROM payments WHERE id=$1', [fixtureRows.paymentId]);
          await client.query('DELETE FROM jobs WHERE id=$1', [fixtureRows.jobId]);
        }
        // Keep successfully posted accounting rows immutable in the disposable database.
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        client.release();
      }
    }
  }
});

test('external PAYMENT_HELD callback before outbox completion posts exactly one funding journal', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const previousProvider = appConfig.paymentProvider;
  let fixtureRows;
  let webhookEventId;
  appConfig.paymentProvider = 'webhook';
  try {
    fixtureRows = await createExternalFundingFixture('external-funding-webhook-first');
    webhookEventId = `R05-external-held-webhook-first-${fixtureRows.paymentId}`;
    const providerRef = `confirmed-hold-${fixtureRows.paymentId}`;
    const callback = await applyPaymentWebhookAtomic({
      eventId: webhookEventId,
      eventType: 'PAYMENT_HELD',
      paymentId: fixtureRows.paymentId,
      providerRef,
      payload: { eventId: webhookEventId, eventType: 'PAYMENT_HELD', paymentId: fixtureRows.paymentId, providerRef },
    });
    assert.equal(callback.processed, true);

    const afterCallback = await pool.query(
      `SELECT COUNT(*)::int AS count FROM ledger_entries
        WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`,
      [fixtureRows.paymentId],
    );
    assert.equal(afterCallback.rows[0].count, 3,
      'a callback-first hold must post the balanced funding journal before the outbox can mark itself done');

    const outboxResult = await completePaymentCreateHoldOutbox({
      eventId: fixtureRows.eventId,
      jobId: fixtureRows.jobId,
      paymentId: fixtureRows.paymentId,
      providerRef,
      actorId: fixture.ownerId,
    });
    assert.equal(outboxResult.completed, true);

    const { rows: journalGroups } = await pool.query(
      `SELECT journal_id,COUNT(*)::int AS entries,
              SUM(debit)::numeric AS debits,SUM(credit)::numeric AS credits
         FROM ledger_entries
        WHERE reference_type='PAYMENT_FUND' AND reference_id=$1
        GROUP BY journal_id`,
      [fixtureRows.paymentId],
    );
    assert.equal(journalGroups.length, 1, 'callback/outbox ordering must never duplicate the funding journal');
    assert.equal(journalGroups[0].entries, 3);
    assert.equal(Number(journalGroups[0].debits), Number(journalGroups[0].credits));
    const { rows: canonicalRows } = await pool.query(
      `SELECT j.id,j.status,j.currency,fo.operation_type,fo.status AS operation_status
         FROM journals j JOIN financial_operations fo ON fo.id=j.operation_id WHERE j.id=$1`,
      [journalGroups[0].journal_id],
    );
    assert.equal(canonicalRows.length, 1);
    assert.equal(canonicalRows[0].status, 'POSTED');
    assert.equal(canonicalRows[0].currency, 'USD');
    assert.equal(canonicalRows[0].operation_type, 'HOLD');
    assert.equal(canonicalRows[0].operation_status, 'SUCCEEDED');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (fixtureRows) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const { rows: canonicalRows } = await client.query(
          `SELECT j.id FROM journals j JOIN ledger_entries le ON le.journal_id=j.id
            WHERE le.reference_type='PAYMENT_FUND' AND le.reference_id=$1 AND j.status='POSTED' LIMIT 1`,
          [fixtureRows.paymentId],
        );
        if (!canonicalRows.length) {
          if (webhookEventId) await client.query('DELETE FROM provider_events WHERE provider_event_id=$1', [webhookEventId]);
          await client.query(`DELETE FROM ledger_entries WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`, [fixtureRows.paymentId]);
          await client.query('DELETE FROM outbox_events WHERE id=$1', [fixtureRows.eventId]);
          await client.query('DELETE FROM audit_logs WHERE entity_type=$1 AND entity_id=$2', ['payment',fixtureRows.paymentId]);
          await client.query('DELETE FROM payments WHERE id=$1', [fixtureRows.paymentId]);
          await client.query('DELETE FROM jobs WHERE id=$1', [fixtureRows.jobId]);
        }
        // Keep successfully posted accounting rows immutable in the disposable database.
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        client.release();
      }
    }
  }
});

test('terminal external hold failure leaves no funding journal and restores the original assigned job state', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const previousProvider = appConfig.paymentProvider;
  let fixtureRows;
  appConfig.paymentProvider = 'webhook';
  try {
    fixtureRows = await createExternalFundingFixture('external-funding-failure');
    const before = await pool.query(
      `SELECT COUNT(*)::int AS count FROM ledger_entries
        WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`,
      [fixtureRows.paymentId],
    );
    // This assertion is evaluated after driving the terminal failure below, so
    // the same test records both pre-hold and post-failure ledger state.
    await pool.query('UPDATE outbox_events SET attempts=8 WHERE id=$1', [fixtureRows.eventId]);
    const failed = await failOutboxEvent({
      eventId: fixtureRows.eventId,
      error: 'R05 integration provider hold failure',
      maxAttempts: 8,
    });
    assert.equal(failed.terminal, true);

    const { rows: payments } = await pool.query(
      'SELECT status,funding_previous_job_status FROM payments WHERE id=$1',
      [fixtureRows.paymentId],
    );
    const { rows: jobs } = await pool.query(
      'SELECT status FROM jobs WHERE id=$1', [fixtureRows.jobId],
    );
    const { rows: entries } = await pool.query(
      `SELECT COUNT(*)::int AS count FROM ledger_entries
        WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`,
      [fixtureRows.paymentId],
    );

    assert.equal(before.rows[0].count, 0,
      'failed external hold must not have posted a funding journal before confirmation');
    assert.equal(payments[0].status, 'HOLD_FAILED');
    assert.equal(payments[0].funding_previous_job_status, 'ASSIGNED');
    assert.equal(jobs[0].status, 'ASSIGNED',
      'terminal hold failure must restore the job state recorded before funding');
    assert.equal(entries[0].count, 0,
      'terminal provider hold failure must leave no funding ledger rows');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (fixtureRows) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(
          `DELETE FROM ledger_entries WHERE reference_type='PAYMENT_FUND' AND reference_id=$1`,
          [fixtureRows.paymentId],
        );
        await client.query('DELETE FROM outbox_events WHERE id=$1', [fixtureRows.eventId]);
        await client.query('DELETE FROM audit_logs WHERE entity_type=$1 AND entity_id=$2', ['payment',fixtureRows.paymentId]);
        await client.query('DELETE FROM payments WHERE id=$1', [fixtureRows.paymentId]);
        await client.query('DELETE FROM jobs WHERE id=$1', [fixtureRows.jobId]);
        await client.query('COMMIT');
      } catch (error) {
        await client.query('ROLLBACK').catch(() => {});
        throw error;
      } finally {
        client.release();
      }
    }
  }
});


test('plain text chat send rejects after account deletion has committed', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const suffix = `deleted-text-send-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const { rows: users } = await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES(gen_random_uuid(),$1,'r05-integration-only','R05 deleted text sender','USER','ACTIVE',0,NOW())
     RETURNING id`,
    [`r05-${suffix}@example.test`],
  );
  const userId = users[0].id;
  let jobId;
  let conversationId;
  try {
    const { rows: jobs } = await pool.query(
      `INSERT INTO jobs(
         id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
         budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
         created_at,updated_at
       )
       SELECT gen_random_uuid(),$1,$2,$3,'Account deletion text-send regression fixture',
         c.id,'FIXED','FIXED',100,100,1,'R05 deletion text-send fixture','IN_PROGRESS',
         'R05 test','MISSION','PUBLIC',NOW(),NOW()
       FROM categories c WHERE c.is_active=TRUE
       ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1
       RETURNING id`,
      [userId, fixture.workerId, `R05 deleted text sender ${suffix}`],
    );
    assert.ok(jobs[0], 'text-send fixture requires an active category');
    jobId = jobs[0].id;
    const { rows: conversations } = await pool.query(
      `INSERT INTO chat_conversations(id,kind,job_id,status,title)
       VALUES(gen_random_uuid(),'JOB',$1,'OPEN','R05 deleted text sender') RETURNING id`,
      [jobId],
    );
    conversationId = conversations[0].id;

    const deletion = await deleteUserPrivacyBundle(userId, {
      email: `deleted+${userId}@invalid.local`,
      passwordHash: 'integration-only-deleted-account',
    });
    assert.equal(deletion.deleted, true);

    await assert.rejects(
      postChatMessage(conversationId, userId, 'USER', 'Must not persist after deletion'),
      (error) => error?.code === 'ACCOUNT_INACTIVE',
    );
    const { rows: messages } = await pool.query(
      'SELECT id FROM chat_messages WHERE conversation_id=$1 AND sender_id=$2',
      [conversationId,userId],
    );
    assert.equal(messages.length, 0,
      'a deleted account must not submit plain-text chat messages after deletion commits');
  } finally {
    if (conversationId) await pool.query('DELETE FROM chat_conversations WHERE id=$1', [conversationId]);
    if (jobId) await pool.query('DELETE FROM jobs WHERE id=$1', [jobId]);
    await pool.query('DELETE FROM users WHERE id=$1', [userId]);
  }
});


test('production disables synthetic internal cash-out before reserving wallet funds', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'production-internal-payout-block');
  const seedKey = `seed-production-payout-block-${userId}`;
  await creditWallet({ userId, amount: '1700', idempotencyKey: seedKey });

  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProjectId = process.env.RAILWAY_PROJECT_ID;
  const previousStageFlag = process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'production';
    process.env.RAILWAY_PROJECT_ID = 'b12b7c1e-4dcc-470e-b87a-c63035c6e342';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

    await assert.rejects(
      requestPayoutAtomic({
        userId,
        amount: '500',
        idempotencyKey: `production-payout-block-${userId}`,
      }),
      (error) => error?.code === 'PAYOUT_PROVIDER_NOT_ENABLED',
    );

    const wallet = await getWalletByUserId(userId);
    assert.equal(String(wallet.available_balance), '1700');
    assert.equal(String(wallet.locked_balance), '0');
    const { rows: payouts } = await pool.query(
      'SELECT id FROM payouts WHERE user_id=$1',
      [userId],
    );
    assert.equal(payouts.length, 0, 'no payout reservation or provider-success path may be created in real production');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousProjectId === undefined) delete process.env.RAILWAY_PROJECT_ID;
    else process.env.RAILWAY_PROJECT_ID = previousProjectId;
    if (previousStageFlag === undefined) delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    else process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT = previousStageFlag;
  }
});

test('production outbox refuses an already-reserved synthetic internal payout and restores wallet funds', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'stale-internal-payout');
  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProjectId = process.env.RAILWAY_PROJECT_ID;
  const previousPayoutFlag = process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
  let payoutId = null;
  let outboxEventId = null;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'test';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    await creditWallet({
      userId,
      amount: '1700',
      idempotencyKey: `stale-payout-wallet-seed-${userId}`,
    });

    const payout = await requestPayoutAtomic({
      userId,
      amount: '500',
      idempotencyKey: `stale-production-payout-${userId}`,
    });
    payoutId = payout.id;

    const { rows: events } = await pool.query(
      `UPDATE outbox_events
          SET status='PROCESSING',attempts=1,locked_at=NOW(),lease_token=gen_random_uuid()
        WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1
        RETURNING *`,
      [payoutId],
    );
    assert.equal(events.length, 1, 'fixture must create one durable payout event');
    outboxEventId = events[0].id;
    assert.equal(String(events[0].payload.amount), '500',
      'outbox payload must preserve the exact integer amount as a JSON string');

    process.env.NODE_ENV = 'production';
    process.env.RAILWAY_PROJECT_ID = 'b12b7c1e-4dcc-470e-b87a-c63035c6e342';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

    const internalProvider = createPaymentProvider('internal');
    await assert.rejects(
      internalProvider.createPayout({ payoutId, amount:'500', currency:'TOMAN', idempotencyKey:`direct-prod-payout-${userId}` }),
      (error) => error?.code === 'PAYOUT_PROVIDER_NOT_ENABLED',
    );
    await assert.rejects(
      internalProvider.getPayoutStatus({ payoutId, amount:'500', currency:'TOMAN', idempotencyKey:`direct-prod-payout-status-${userId}` }),
      (error) => error?.code === 'PAYOUT_PROVIDER_NOT_ENABLED',
    );

    const result = await processOutboxEvent(events[0]);
    assert.equal(result?.disabled, true, 'production must fail closed before invoking the synthetic payout adapter');

    const wallet = await getWalletByUserId(userId);
    assert.equal(String(wallet.available_balance), '1700');
    assert.equal(String(wallet.locked_balance), '0');

    const { rows: payoutRows } = await pool.query(
      'SELECT status,provider_ref,failure_code,failure_message FROM payouts WHERE id=$1',
      [payoutId],
    );
    assert.equal(payoutRows[0]?.status, 'FAILED');
    assert.equal(payoutRows[0]?.provider_ref, null, 'no synthetic provider reference may be issued in production');
    assert.equal(payoutRows[0]?.failure_code, 'PAYOUT_PROVIDER_NOT_ENABLED');

    const { rows: walletLedgerRows } = await pool.query(
      `SELECT entry_type,direction,amount,metadata
         FROM wallet_entries
        WHERE reference_type='PAYOUT' AND reference_id=$1
        ORDER BY created_at,id`,
      [payoutId],
    );
    assert.equal(walletLedgerRows.length, 2,
      'a failed payout must retain the original reservation debit and append one compensating credit');
    assert.ok(walletLedgerRows.some((entry) =>
      entry.entry_type === 'PAYOUT' && entry.direction === 'DEBIT' && String(entry.amount) === '500',
    ));
    const reversal = walletLedgerRows.find((entry) => entry.direction === 'CREDIT');
    assert.ok(reversal, 'failed payout must append a credit reversal; wallet entries are immutable');
    assert.equal(String(reversal.amount), '500');
    assert.equal(reversal.metadata?.state, 'REVERSED');
    assert.equal(reversal.metadata?.failureCode, 'PAYOUT_PROVIDER_NOT_ENABLED');

    const { rows: outboxRows } = await pool.query(
      'SELECT status,last_error FROM outbox_events WHERE id=$1',
      [outboxEventId],
    );
    assert.equal(outboxRows[0]?.status, 'FAILED');
    assert.match(outboxRows[0]?.last_error || '', /PAYOUT_PROVIDER_NOT_ENABLED/);
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousProjectId === undefined) delete process.env.RAILWAY_PROJECT_ID;
    else process.env.RAILWAY_PROJECT_ID = previousProjectId;
    if (previousPayoutFlag === undefined) delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    else process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT = previousPayoutFlag;

    // Preserve the payout and wallet-ledger fixture. wallet_entries are
    // deliberately immutable, and this isolated PostgreSQL database is discarded
    // after the job; deleting accounting history in teardown violates the ledger contract.
  }
});

test('manual failed resolution of an unknown payout appends a compensating wallet credit', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'unknown-payout-manual-failure');
  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProjectId = process.env.RAILWAY_PROJECT_ID;
  const previousPayoutFlag = process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'test';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    await creditWallet({
      userId,
      amount: '1700',
      idempotencyKey: `manual-unknown-payout-wallet-seed-${userId}`,
    });

    const payout = await requestPayoutAtomic({
      userId,
      amount: '500',
      idempotencyKey: `manual-unknown-payout-${userId}`,
    });
    const { rows: events } = await pool.query(
      "SELECT id FROM outbox_events WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1",
      [payout.id],
    );
    assert.equal(events.length, 1);

    const marked = await markPayoutUnknown({ eventId: events[0].id, payoutId: payout.id });
    assert.equal(marked?.marked, true);

    const { rows: unknownPayoutState } = await pool.query(
      `SELECT p.status AS payout_status,operation.status AS operation_status
         FROM payouts p
         JOIN wallet_holds hold
           ON hold.reference_id=p.id
          AND hold.hold_type='PAYOUT_RESERVATION'
          AND hold.status='ACTIVE'
         JOIN financial_operations operation
           ON operation.id=hold.financial_operation_id
        WHERE p.id=$1`,
      [payout.id],
    );
    assert.equal(unknownPayoutState[0]?.payout_status, 'UNKNOWN');
    assert.equal(
      unknownPayoutState[0]?.operation_status,
      'UNKNOWN',
      'provider UNKNOWN must transition the financial operation from PROCESSING to UNKNOWN',
    );

    const resolved = await resolvePayoutUnknown({
      payoutId: payout.id,
      decision: 'FAILED',
      reason: 'integration fixture: provider status confirmed no disbursement',
    });
    assert.equal(resolved?.status, 'FAILED');

    const wallet = await getWalletByUserId(userId);
    assert.equal(String(wallet.available_balance), '1700');
    assert.equal(String(wallet.locked_balance), '0');

    const { rows: entries } = await pool.query(
      `SELECT entry_type,direction,amount,metadata
         FROM wallet_entries
        WHERE reference_type='PAYOUT' AND reference_id=$1
        ORDER BY created_at,id`,
      [payout.id],
    );
    assert.equal(entries.length, 2,
      'manual failed resolution must preserve the reservation debit and append exactly one credit');
    assert.ok(entries.some((entry) => entry.direction === 'DEBIT' && String(entry.amount) === '500'));
    const reversal = entries.find((entry) => entry.direction === 'CREDIT');
    assert.ok(reversal, 'manual resolution must append, never mutate, wallet history');
    assert.equal(String(reversal.amount), '500');
    assert.equal(reversal.metadata?.state, 'REVERSED');
    assert.equal(reversal.metadata?.failureCode, 'UNKNOWN_RESOLVED_FAILED');

    const { rows: holds } = await pool.query(
      "SELECT status FROM wallet_holds WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION'",
      [payout.id],
    );
    assert.equal(holds[0]?.status, 'CANCELLED');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousProjectId === undefined) delete process.env.RAILWAY_PROJECT_ID;
    else process.env.RAILWAY_PROJECT_ID = previousProjectId;
    if (previousPayoutFlag === undefined) delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    else process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT = previousPayoutFlag;
    // This PostgreSQL database is disposable; preserve immutable wallet entries.
  }
});


test('manual payout resolution closes every active reconciliation case atomically', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'manual-payout-close-cases');
  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProjectId = process.env.RAILWAY_PROJECT_ID;
  const previousPayoutFlag = process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'test';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    await creditWallet({
      userId,
      amount: '1700',
      idempotencyKey: `manual-payout-close-cases-seed-${userId}`,
    });

    const payout = await requestPayoutAtomic({
      userId,
      amount: '500',
      idempotencyKey: `manual-payout-close-cases-${userId}`,
    });
    const { rows: events } = await pool.query(
      "SELECT id FROM outbox_events WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1",
      [payout.id],
    );
    assert.equal(events.length, 1);
    const marked = await markPayoutUnknown({ eventId: events[0].id, payoutId: payout.id });
    assert.equal(marked?.marked, true);

    await pool.query(
      `INSERT INTO reconciliation_cases(
         id,case_type,resource_type,resource_id,severity,expected,observed,status,created_at,updated_at
       ) VALUES
         (gen_random_uuid(),'PAYOUT_PROVIDER_PENDING','payout',$1,'HIGH','{"status":"SUCCEEDED|FAILED"}'::jsonb,'{"status":"UNKNOWN"}'::jsonb,'OPEN',NOW(),NOW()),
         (gen_random_uuid(),'PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY','payout',$1,'CRITICAL','{"activeReservationHold":true}'::jsonb,'{"reason":"manual-review"}'::jsonb,'INVESTIGATING',NOW(),NOW())`,
      [payout.id],
    );

    const resolved = await resolvePayoutUnknown({
      payoutId: payout.id,
      decision: 'FAILED',
      adminId: fixture.adminId,
      reason: 'admin confirmed provider did not disburse',
    });
    assert.equal(resolved?.status, 'FAILED');

    const { rows: cases } = await pool.query(
      `SELECT case_type,status,resolution_reference,resolved_at
         FROM reconciliation_cases
        WHERE resource_type='payout' AND resource_id=$1
        ORDER BY case_type`,
      [payout.id],
    );
    assert.equal(cases.length, 2);
    assert.ok(cases.every((item) => item.status === 'RESOLVED'),
      'manual payout resolution must close all OPEN and INVESTIGATING cases for the payout');
    assert.ok(cases.every((item) => item.resolved_at),
      'closed payout reconciliation cases must have resolved_at');
    assert.ok(cases.every((item) =>
      String(item.resolution_reference || '').includes(fixture.adminId)
        && String(item.resolution_reference || '').includes('FAILED'),
    ), 'case resolution reference must identify the admin and terminal decision');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousProjectId === undefined) delete process.env.RAILWAY_PROJECT_ID;
    else process.env.RAILWAY_PROJECT_ID = previousProjectId;
    if (previousPayoutFlag === undefined) delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    else process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT = previousPayoutFlag;
    // Keep immutable wallet ledger rows in the disposable PostgreSQL fixture.
  }
});


test('unknown payout admin read model includes active reconciliation case details', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'unknown-payout-admin-read-model');
  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProjectId = process.env.RAILWAY_PROJECT_ID;
  const previousPayoutFlag = process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'test';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    await creditWallet({
      userId,
      amount: '1700',
      idempotencyKey: `unknown-payout-admin-read-model-seed-${userId}`,
    });

    const payout = await requestPayoutAtomic({
      userId,
      amount: '500',
      idempotencyKey: `unknown-payout-admin-read-model-${userId}`,
    });
    const { rows: events } = await pool.query(
      "SELECT id FROM outbox_events WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1",
      [payout.id],
    );
    assert.equal(events.length, 1);
    const marked = await markPayoutUnknown({ eventId: events[0].id, payoutId: payout.id });
    assert.equal(marked?.marked, true);

    const { rows: insertedCases } = await pool.query(
      `INSERT INTO reconciliation_cases(
         id,case_type,resource_type,resource_id,severity,expected,observed,status,created_at,updated_at
       ) VALUES
         (gen_random_uuid(),'PAYOUT_PROVIDER_PENDING','payout',$1,'HIGH','{"status":"SUCCEEDED|FAILED"}'::jsonb,'{"status":"UNKNOWN","providerRef":null}'::jsonb,'OPEN',NOW(),NOW()),
         (gen_random_uuid(),'PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY','payout',$1,'CRITICAL','{"activeReservationHold":true}'::jsonb,'{"reason":"PAYOUT_OPERATION_MISMATCH"}'::jsonb,'INVESTIGATING',NOW(),NOW()),
         (gen_random_uuid(),'PAYOUT_OLD_RESOLVED_CASE','payout',$1,'LOW','{}'::jsonb,'{}'::jsonb,'RESOLVED',NOW(),NOW())
       RETURNING id`,
      [payout.id],
    );
    assert.equal(insertedCases.length, 3);

    const rows = await listUnknownPayouts({ limit: 100 });
    const item = rows.find((row) => row.id === payout.id);
    assert.ok(item, 'unknown payout must remain visible in admin read model');
    assert.equal(Array.isArray(item.reconciliationCases), true);
    assert.equal(item.reconciliationCases.length, 2,
      'admin payout listing must include every active case, excluding resolved history');
    const pending = item.reconciliationCases.find((entry) => entry.caseType === 'PAYOUT_PROVIDER_PENDING');
    const critical = item.reconciliationCases.find((entry) => entry.caseType === 'PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY');
    assert.equal(pending?.severity, 'HIGH');
    assert.equal(pending?.status, 'OPEN');
    assert.equal(pending?.observed?.status, 'UNKNOWN');
    assert.equal(critical?.severity, 'CRITICAL');
    assert.equal(critical?.status, 'INVESTIGATING');
    assert.equal(critical?.observed?.reason, 'PAYOUT_OPERATION_MISMATCH');
    assert.ok(pending?.id && critical?.id, 'case identifiers must be available for admin review');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousProjectId === undefined) delete process.env.RAILWAY_PROJECT_ID;
    else process.env.RAILWAY_PROJECT_ID = previousProjectId;
    if (previousPayoutFlag === undefined) delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    else process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT = previousPayoutFlag;
    // Keep immutable wallet ledger rows in the disposable PostgreSQL fixture.
  }
});


test('provider UNKNOWN without an active payout hold remains locked and opens critical reconciliation', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'unknown-payout-missing-hold');
  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousProjectId = process.env.RAILWAY_PROJECT_ID;
  const previousPayoutFlag = process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'test';
    delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    await creditWallet({
      userId,
      amount: '1700',
      idempotencyKey: `unknown-payout-missing-hold-seed-${userId}`,
    });

    const payout = await requestPayoutAtomic({
      userId,
      amount: '500',
      idempotencyKey: `unknown-payout-missing-hold-${userId}`,
    });
    const { rows: events } = await pool.query(
      `UPDATE outbox_events
          SET status='PROCESSING',attempts=1,locked_at=NOW(),lease_token=gen_random_uuid()
        WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1
        RETURNING id,lease_token`,
      [payout.id],
    );
    assert.equal(events.length, 1);

    await pool.query(
      `UPDATE wallet_holds
          SET status='CANCELLED',released_at=NOW()
        WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
      [payout.id],
    );

    const marked = await markPayoutUnknown({
      eventId: events[0].id,
      payoutId: payout.id,
      leaseToken: events[0].lease_token,
    });
    assert.equal(marked?.marked, true,
      'an ambiguous provider result must not fall into generic payout failure/retry handling');
    assert.equal(marked?.requiresReconciliation, true);

    const { rows: payoutRows } = await pool.query(
      'SELECT status FROM payouts WHERE id=$1',
      [payout.id],
    );
    assert.equal(payoutRows[0]?.status, 'UNKNOWN');

    const { rows: operationRows } = await pool.query(
      `SELECT operation.status
         FROM financial_operations operation
         JOIN wallet_entries entry ON entry.financial_operation_id=operation.id
        WHERE entry.reference_type='PAYOUT' AND entry.reference_id=$1
        ORDER BY entry.created_at,entry.id LIMIT 1`,
      [payout.id],
    );
    assert.equal(operationRows[0]?.status, 'PROCESSING',
      'missing reservation linkage must leave the operation untouched for manual repair');

    const wallet = await getWalletByUserId(userId);
    assert.equal(String(wallet.available_balance), '1200');
    assert.equal(String(wallet.locked_balance), '500',
      'ambiguous provider outcome must never auto-release the reserved funds');

    const { rows: outboxRows } = await pool.query(
      'SELECT status FROM outbox_events WHERE id=$1',
      [events[0].id],
    );
    assert.equal(outboxRows[0]?.status, 'DONE',
      'UNKNOWN provider response must not be retried as a definite payout failure');

    const { rows: cases } = await pool.query(
      `SELECT case_type,severity,status,observed
         FROM reconciliation_cases
        WHERE case_type='PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY'
          AND resource_type='payout' AND resource_id=$1
          AND status IN ('OPEN','INVESTIGATING')`,
      [payout.id],
    );
    assert.equal(cases.length, 1);
    assert.equal(cases[0].severity, 'CRITICAL');
    assert.equal(cases[0].status, 'OPEN');
    assert.equal(cases[0].observed.reason, 'PAYOUT_RESERVATION_NOT_FOUND');
  } finally {
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousProjectId === undefined) delete process.env.RAILWAY_PROJECT_ID;
    else process.env.RAILWAY_PROJECT_ID = previousProjectId;
    if (previousPayoutFlag === undefined) delete process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT;
    else process.env.STAGING_ALLOW_INTERNAL_WALLET_PAYOUT = previousPayoutFlag;
    // The test database is disposable; preserve immutable wallet ledger entries.
  }
});


test('account deletion refuses a non-zero internal wallet balance and preserves account state', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'delete-funded-wallet');
  await creditWallet({ userId, amount: '900', idempotencyKey: 'delete-funded-wallet-seed-' + userId });

  await assert.rejects(
    deleteUserPrivacyBundle(userId, {
      email: 'deleted+' + userId + '@invalid.local',
      passwordHash: 'integration-only-deleted-account',
    }),
    (error) => error?.code === 'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING',
  );

  const { rows: users } = await pool.query('SELECT status FROM users WHERE id=$1', [userId]);
  assert.equal(users[0]?.status, 'ACTIVE', 'rejected deletion must not anonymize or disable the account');
  assert.equal(String((await getWalletByUserId(userId)).available_balance), '900',
    'rejected deletion must preserve user-owned funds');
});

test('account deletion refuses a nonterminal payment even when no wallet balance exists', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'delete-pending-payment');
  const suffix = 'delete-pending-payment-' + Date.now() + '-' + Math.random().toString(16).slice(2);
  const jobInsert = [
    'INSERT INTO jobs(',
    ' id,owner_id,provider_id,title,description,category_id,job_type,budget_type,',
    ' budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,created_at,updated_at',
    ')',
    'SELECT gen_random_uuid(),$1,$2,$3,$4,c.id,\'FIXED\',\'FIXED\',100,100,1,$5,\'IN_PROGRESS\',',
    ' \'R05 test\',\'MISSION\',\'PUBLIC\',NOW(),NOW()',
    'FROM categories c WHERE c.is_active=TRUE ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
  ].join('\n');
  const { rows: jobs } = await pool.query(jobInsert, [
    userId, fixture.workerId, suffix, 'Account deletion pending payment fixture', 'R05 account deletion pending payment',
  ]);
  assert.ok(jobs[0], 'pending-payment fixture requires an active category');
  const paymentId = crypto.randomUUID();
  await pool.query(
    'INSERT INTO payments(id,job_id,payer_id,payee_id,amount,status,provider_ref,currency,base_amount,employer_charge,provider_payout,platform_fee,created_at,updated_at) VALUES($1,$2,$3,$4,100,\'HOLD_PENDING\',$5,\'TOMAN\',100,100,100,0,NOW(),NOW())',
    [paymentId, jobs[0].id, userId, fixture.workerId, 'pending-' + suffix],
  );

  await assert.rejects(
    deleteUserPrivacyBundle(userId, {
      email: 'deleted+' + userId + '@invalid.local',
      passwordHash: 'integration-only-deleted-account',
    }),
    (error) => error?.code === 'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING',
  );
  const { rows: users } = await pool.query('SELECT status FROM users WHERE id=$1', [userId]);
  assert.equal(users[0]?.status, 'ACTIVE');
});

test('account deletion refuses an unresolved payout even if wallet balances are zero', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'delete-unknown-payout');
  const wallet = await ensureWalletForUserPublic(userId);
  await pool.query(
    'INSERT INTO payouts(id,wallet_id,user_id,amount,currency,status,provider,provider_ref,idempotency_key,created_at,updated_at,completed_at) VALUES($1,$2,$3,100,\'TOMAN\',\'UNKNOWN\',\'internal\',NULL,$4,NOW(),NOW(),NULL)',
    [crypto.randomUUID(), wallet.id, userId, 'delete-unknown-payout-' + userId],
  );

  await assert.rejects(
    deleteUserPrivacyBundle(userId, {
      email: 'deleted+' + userId + '@invalid.local',
      passwordHash: 'integration-only-deleted-account',
    }),
    (error) => error?.code === 'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING',
  );
  const { rows: users } = await pool.query('SELECT status FROM users WHERE id=$1', [userId]);
  assert.equal(users[0]?.status, 'ACTIVE');
});

test('account deletion refuses an active wallet hold even if the balance row is zero', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'delete-active-hold');
  const wallet = await ensureWalletForUserPublic(userId);
  await pool.query(
    'INSERT INTO wallet_holds(wallet_id,hold_type,reference_type,reference_id,amount,status) VALUES($1,\'OTHER\',\'ACCOUNT_DELETE_TEST\',$2,100,\'ACTIVE\')',
    [wallet.id, crypto.randomUUID()],
  );

  await assert.rejects(
    deleteUserPrivacyBundle(userId, {
      email: 'deleted+' + userId + '@invalid.local',
      passwordHash: 'integration-only-deleted-account',
    }),
    (error) => error?.code === 'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING',
  );
  const { rows: users } = await pool.query('SELECT status FROM users WHERE id=$1', [userId]);
  assert.equal(users[0]?.status, 'ACTIVE');
});

test('job funding waits for the account lock and cannot create a payment after deletion wins', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createTransferTestUser(pool, 'funding-delete-race');
  const suffix = 'funding-delete-race-' + Date.now() + '-' + Math.random().toString(16).slice(2);
  const jobInsert = [
    'INSERT INTO jobs(',
    ' id,owner_id,provider_id,title,description,category_id,job_type,budget_type,',
    ' budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,created_at,updated_at',
    ')',
    'SELECT gen_random_uuid(),$1,$2,$3,$4,c.id,\'FIXED\',\'FIXED\',100,100,1,$5,\'PUBLISHED\',',
    ' \'R05 test\',\'MISSION\',\'PUBLIC\',NOW(),NOW()',
    'FROM categories c WHERE c.is_active=TRUE ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1 RETURNING id',
  ].join('\n');
  const { rows: jobs } = await pool.query(jobInsert, [
    userId, fixture.workerId, suffix, 'Funding deletion race fixture', 'R05 funding deletion race',
  ]);
  assert.ok(jobs[0], 'funding/deletion race fixture requires an active category');

  const holder = await pool.connect();
  let holderOpen = false;
  let outcome = null;
  let blockedOnAccountLock = false;
  let writer = null;
  try {
    await holder.query('BEGIN');
    holderOpen = true;
    await holder.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE', [userId]);
    await holder.query('UPDATE users SET status=\'DELETED\' WHERE id=$1', [userId]);

    writer = fundJobAtomic({
      jobId: jobs[0].id,
      payerId: userId,
      payeeId: fixture.workerId,
      amount: 100,
      id: crypto.randomUUID(),
      idempotencyKey: 'funding-delete-race-' + userId,
      createdAt: new Date(),
    }).then(
      (value) => { outcome = { ok: true, value }; },
      (error) => { outcome = { ok: false, error }; },
    );

    const deadline = Date.now() + 6000;
    while (Date.now() < deadline) {
      const { rows } = await pool.query(
        "SELECT pid FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND wait_event_type='Lock' AND query ILIKE '%lockActiveWalletUsers%'",
      );
      if (rows.length) { blockedOnAccountLock = true; break; }
      if (outcome) break;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }

    await holder.query('COMMIT');
    holderOpen = false;
    await writer;
  } finally {
    if (holderOpen) await holder.query('ROLLBACK').catch(() => {});
    holder.release();
  }

  assert.equal(blockedOnAccountLock, true, 'funding must take the same account lock as deletion before locking the job');
  assert.equal(outcome?.ok, false, 'funding must fail if deletion marks the payer inactive first');
  assert.equal(outcome?.error?.code, 'ACCOUNT_INACTIVE');
  const { rows: payments } = await pool.query('SELECT id FROM payments WHERE job_id=$1', [jobs[0].id]);
  assert.equal(payments.length, 0, 'no new payment obligation may be created after deletion wins');
});


async function seedFailedRefundRetryFixture(label) {
  const pool = dbModule.getPool();
  const { paymentId } = await createWebhookMismatchPayment('HELD', label);
  const { rows: payments } = await pool.query(
    'SELECT job_id FROM payments WHERE id=$1',
    [paymentId],
  );
  const jobId = payments[0].job_id;
  const refundId = crypto.randomUUID();
  const eventId = crypto.randomUUID();
  const idempotencyKey = 'refund-retry-' + label + '-' + crypto.randomUUID();

  await pool.query(
    `INSERT INTO refunds(id,payment_id,amount,status,provider_ref,idempotency_key,created_at,updated_at)
     VALUES($1,$2,100,'FAILED',NULL,$3,NOW()-INTERVAL '2 minutes',NOW()-INTERVAL '1 minute')`,
    [refundId,paymentId,idempotencyKey],
  );
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,
       available_at,locked_at,lease_token,last_error,created_at,processed_at
     )
     VALUES(
       $1,'PAYMENT_REFUND','payment',$2,$3,$4::jsonb,'FAILED',5,
       NOW(),NOW()-INTERVAL '1 minute',$5,'provider timed out after max attempts',
       NOW()-INTERVAL '3 minutes',NOW()-INTERVAL '1 minute'
     )`,
    [eventId,paymentId,`PAYMENT_REFUND:${paymentId}`,JSON.stringify({
      jobId, ownerId:fixture.ownerId, paymentId, refundId,
      providerRef:null, idempotencyKey,
    }),crypto.randomUUID()],
  );
  return { paymentId, jobId, refundId, eventId, idempotencyKey };
}

async function seedPendingRefundRetryFixture(label) {
  const pool = dbModule.getPool();
  const { paymentId } = await createWebhookMismatchPayment('HELD', label);
  const { rows: payments } = await pool.query(
    'SELECT job_id FROM payments WHERE id=$1',
    [paymentId],
  );
  const jobId = payments[0].job_id;
  const refundId = crypto.randomUUID();
  const eventId = crypto.randomUUID();
  const idempotencyKey = 'refund-pending-' + label + '-' + crypto.randomUUID();

  await pool.query(
    `INSERT INTO refunds(id,payment_id,amount,status,provider_ref,idempotency_key,created_at,updated_at)
     VALUES($1,$2,100,'PENDING',NULL,$3,NOW(),NOW())`,
    [refundId,paymentId,idempotencyKey],
  );
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,
       available_at,created_at
     )
     VALUES($1,'PAYMENT_REFUND','payment',$2,$3,$4::jsonb,'PENDING',0,NOW(),NOW())`,
    [eventId,paymentId,`PAYMENT_REFUND:${paymentId}`,JSON.stringify({
      jobId, ownerId:fixture.ownerId, paymentId, refundId,
      providerRef:null, idempotencyKey,
    })],
  );
  return { paymentId, jobId, refundId, eventId, idempotencyKey };
}

async function cleanupFailedRefundRetryFixture({ paymentId, jobId }) {
  const pool = dbModule.getPool();
  await pool.query('DELETE FROM outbox_events WHERE aggregate_id=$1', [paymentId]);
  await pool.query('DELETE FROM refunds WHERE payment_id=$1', [paymentId]);
  await pool.query('DELETE FROM payments WHERE id=$1', [paymentId]);
  await pool.query('DELETE FROM jobs WHERE id=$1', [jobId]);
}

test('same-key refund retry resets terminal outbox attempts and stale delivery metadata', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const seeded = await seedFailedRefundRetryFixture('same-key');
  try {
    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    const retried = await createRefundAtomic({
      jobId:seeded.jobId,
      paymentId:seeded.paymentId,
      ownerId:fixture.ownerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey:seeded.idempotencyKey,
      createdAt:new Date(),
    });

    assert.equal(retried.refund.id,seeded.refundId,
      'a semantic retry must reopen the original refund operation');
    const { rows: events } = await pool.query(
      `SELECT status,attempts,locked_at,lease_token,last_error,processed_at,
              payload->>'refundId' AS payload_refund_id
         FROM outbox_events WHERE id=$1`,
      [seeded.eventId],
    );
    assert.equal(events.length,1);
    assert.equal(events[0].status,'PENDING');
    assert.equal(events[0].attempts,0,
      'the retry must receive a fresh bounded delivery-attempt budget');
    assert.equal(events[0].locked_at,null);
    assert.equal(events[0].lease_token,null);
    assert.equal(events[0].last_error,null);
    assert.equal(events[0].processed_at,null);
    assert.equal(events[0].payload_refund_id,seeded.refundId,
      'the immutable outbox payload must still identify the reopened refund');
  } finally {
    await cleanupFailedRefundRetryFixture(seeded);
  }
});

test('failed refund cannot be retried with a different idempotency key against an immutable outbox payload', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const seeded = await seedFailedRefundRetryFixture('different-key');
  try {
    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    await assert.rejects(
      createRefundAtomic({
        jobId:seeded.jobId,
        paymentId:seeded.paymentId,
        ownerId:fixture.ownerId,
        amount:100,
        id:crypto.randomUUID(),
        idempotencyKey:seeded.idempotencyKey + '-different',
        createdAt:new Date(),
      }),
      (error) => error?.code === 'REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY',
    );

    const { rows: refunds } = await pool.query(
      'SELECT id,status,idempotency_key FROM refunds WHERE payment_id=$1 ORDER BY created_at,id',
      [seeded.paymentId],
    );
    assert.equal(refunds.length,1,
      'a second refund row must not be created behind an immutable outbox payload');
    assert.equal(refunds[0].id,seeded.refundId);
    assert.equal(refunds[0].status,'FAILED');
  } finally {
    await cleanupFailedRefundRetryFixture(seeded);
  }
});


test('pending refund with a different key cannot hide an earlier failed refund operation', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const seeded = await seedFailedRefundRetryFixture('pending-different-key');
  const pendingRefundId = crypto.randomUUID();
  const pendingKey = seeded.idempotencyKey + '-pending';
  try {
    await pool.query(
      `INSERT INTO refunds(id,payment_id,amount,status,provider_ref,idempotency_key,created_at,updated_at)
       VALUES($1,$2,100,'PENDING',NULL,$3,NOW(),NOW())`,
      [pendingRefundId,seeded.paymentId,pendingKey],
    );

    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    await assert.rejects(
      createRefundAtomic({
        jobId:seeded.jobId,
        paymentId:seeded.paymentId,
        ownerId:fixture.ownerId,
        amount:100,
        id:crypto.randomUUID(),
        idempotencyKey:pendingKey,
        createdAt:new Date(),
      }),
      (error) => error?.code === 'REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY',
    );

    const { rows: refunds } = await pool.query(
      'SELECT id,status FROM refunds WHERE payment_id=$1 ORDER BY created_at,id',
      [seeded.paymentId],
    );
    assert.equal(refunds.length,2);
    assert.equal(refunds.find((row) => row.id === seeded.refundId)?.status,'FAILED');
    assert.equal(refunds.find((row) => row.id === pendingRefundId)?.status,'PENDING');
  } finally {
    await cleanupFailedRefundRetryFixture(seeded);
  }
});

test('pending refund cannot be duplicated by a different or missing idempotency key', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const seeded = await seedPendingRefundRetryFixture('operation-key');
  try {
    const { createRefundAtomic } = await import('../src/repository/payment_refunds.js');
    const replay = await createRefundAtomic({
      jobId:seeded.jobId,
      paymentId:seeded.paymentId,
      ownerId:fixture.ownerId,
      amount:100,
      id:crypto.randomUUID(),
      idempotencyKey:seeded.idempotencyKey,
      createdAt:new Date(),
    });
    assert.equal(replay.refund.id,seeded.refundId,
      'same-key replay must return the existing pending refund');

    for (const idempotencyKey of [seeded.idempotencyKey + '-different', null]) {
      await assert.rejects(
        createRefundAtomic({
          jobId:seeded.jobId,
          paymentId:seeded.paymentId,
          ownerId:fixture.ownerId,
          amount:100,
          id:crypto.randomUUID(),
          idempotencyKey,
          createdAt:new Date(),
        }),
        (error) => error?.code === 'REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY',
      );
    }

    const { rows: refunds } = await pool.query(
      'SELECT id,status FROM refunds WHERE payment_id=$1',
      [seeded.paymentId],
    );
    assert.equal(refunds.length,1);
    assert.equal(refunds[0].id,seeded.refundId);
    assert.equal(refunds[0].status,'PENDING');
    const { rows: events } = await pool.query(
      `SELECT payload->>'refundId' AS payload_refund_id,status,attempts
         FROM outbox_events WHERE id=$1`,
      [seeded.eventId],
    );
    assert.equal(events.length,1);
    assert.equal(events[0].payload_refund_id,seeded.refundId);
    assert.equal(events[0].status,'PENDING');
    assert.equal(events[0].attempts,0);
  } finally {
    await cleanupFailedRefundRetryFixture(seeded);
  }
});





async function runAccountDeletionAgainstInternalPaymentWebhook({ eventType }) {
  const pool = dbModule.getPool();
  const suffix = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}`;
  const payerId = await createTransferTestUser(pool, `delete-webhook-payer-${suffix}`);
  const workerId = await createTransferTestUser(pool, `delete-webhook-worker-${suffix}`);
  const jobId = crypto.randomUUID();
  const paymentId = crypto.randomUUID();
  const holdRef = `delete-webhook-hold-${suffix}`;
  const eventId = `delete-webhook-${eventType.toLowerCase()}-${suffix}`;
  const isRelease = eventType === 'PAYMENT_RELEASED';
  const paymentStatus = isRelease ? 'RELEASE_PENDING' : 'REFUND_PENDING';
  const jobTitle = `Account deletion vs ${eventType} race ${suffix}`;
  const { rows: jobs } = await pool.query(
    `INSERT INTO jobs(
       id,owner_id,provider_id,title,description,category_id,job_type,budget_type,
       budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,
       created_at,updated_at
     )
     SELECT $1,$2,$3,$4,'Deterministic account-deletion/payment-webhook race fixture',
       c.id,'FIXED','FIXED',100,130,1,'Race fixture', $5,
       'R05 test','MISSION','PUBLIC',NOW(),NOW()
       FROM categories c WHERE c.is_active=TRUE
       ORDER BY c.created_at NULLS FIRST,c.id LIMIT 1
       RETURNING id`,
    [jobId,payerId,workerId,jobTitle,isRelease ? 'IN_PROGRESS' : 'ASSIGNED'],
  );
  assert.ok(jobs[0], 'account-deletion/webhook race requires an active category');
  if (isRelease) {
    await pool.query("UPDATE jobs SET status='DELIVERED' WHERE id=$1", [jobId]);
    await pool.query("UPDATE jobs SET status='COMPLETED' WHERE id=$1", [jobId]);
  }

  await pool.query(
    `INSERT INTO payments(
       id,job_id,payer_id,payee_id,amount,status,provider_ref,idempotency_key,
       base_amount,employer_fee,worker_fee,platform_fee,employer_charge,provider_payout,
       fee_policy_version,currency,created_at,updated_at
     )
     VALUES($1,$2,$3,$4,100,$5,$6,$7,100,0,0,1,100,99,'R05-race','TOMAN',NOW(),NOW())`,
    [paymentId,jobId,payerId,workerId,paymentStatus,holdRef,`delete-webhook-payment-${suffix}`],
  );

  await creditWallet({
    userId:payerId,
    amount:'1000',
    idempotencyKey:`delete-webhook-wallet-seed-${suffix}`,
  });
  await runWalletMutationTransaction((client) => postInternalPaymentHoldWithClient(client, {
    paymentId,
    payerId,
    employerCharge:'100',
    providerPayout:'99',
    platformFee:'1',
    idempotencyKey:`delete-webhook-hold-operation-${suffix}`,
  }));

  if (!isRelease) {
    await pool.query(
      `INSERT INTO refunds(
         id,payment_id,amount,status,provider_ref,idempotency_key,created_at,updated_at
       )
       VALUES($1,$2,100,'PENDING',NULL,$3,NOW(),NOW())`,
      [crypto.randomUUID(),paymentId,`delete-webhook-refund-${suffix}`],
    );
  }

  const wallet = await getWalletByUserId(payerId);
  assert.ok(wallet, 'race fixture must have a payer wallet');
  const holder = await pool.connect();
  let holderOpen = false;
  let deleteBlockedOnWallet = false;
  let webhookBlockedOnWallet = false;
  let deleteOutcome = null;
  let webhookOutcome = null;
  let webhookPromise = null;

  try {
    await holder.query('BEGIN');
    holderOpen = true;
    await holder.query('SELECT id FROM wallet_accounts WHERE id=$1 FOR UPDATE', [wallet.id]);

    const deletePromise = deleteUserPrivacyBundle(payerId, {
      email:`deleted+${payerId}@invalid.local`,
      passwordHash:'integration-only-deleted-account',
    }).then(
      (value) => { deleteOutcome = {ok:true,value}; return deleteOutcome; },
      (error) => { deleteOutcome = {ok:false,error}; return deleteOutcome; },
    );

    const deletionDeadline = Date.now() + 7000;
    while (Date.now() < deletionDeadline) {
      const { rows: waiters } = await pool.query(
        `SELECT pid,query FROM pg_stat_activity
          WHERE datname=current_database() AND pid<>pg_backend_pid()
            AND wait_event_type='Lock'
            AND query ILIKE '%FROM wallet_accounts%'
            AND query ILIKE '%WHERE user_id=$1%'`,
      );
      if (waiters.length) { deleteBlockedOnWallet = true; break; }
      if (deleteOutcome) break;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }

    const previousProvider = appConfig.paymentProvider;
    appConfig.paymentProvider = 'internal';
    try {
      const webhookRef = `${holdRef}-${isRelease ? 'release' : 'refund'}`;
      webhookPromise = applyPaymentWebhookAtomic({
        eventId,
        eventType,
        paymentId,
        providerRef:webhookRef,
        payload:{eventId,eventType,paymentId,providerRef:webhookRef},
      }).then(
        (value) => { webhookOutcome = {ok:true,value}; return webhookOutcome; },
        (error) => { webhookOutcome = {ok:false,error}; return webhookOutcome; },
      );

      const callbackDeadline = Date.now() + 7000;
      while (Date.now() < callbackDeadline) {
        const { rows: waiters } = await pool.query(
          `SELECT pid,query FROM pg_stat_activity
            WHERE datname=current_database() AND pid<>pg_backend_pid()
              AND wait_event_type='Lock'
              AND query ILIKE '%wallet_accounts%'
              AND (
                query ILIKE '%id = ANY%'
                OR query ILIKE '%INSERT INTO wallet_accounts%'
              )`,
        );
        if (waiters.length) { webhookBlockedOnWallet = true; break; }
        if (webhookOutcome) break;
        await new Promise((resolve) => setTimeout(resolve, 20));
      }
    } finally {
      appConfig.paymentProvider = previousProvider;
    }

    await holder.query('COMMIT');
    holderOpen = false;
    await Promise.all([deletePromise, webhookPromise]);
  } finally {
    if (holderOpen) await holder.query('ROLLBACK').catch(() => {});
    holder.release();
  }

  assert.equal(deleteBlockedOnWallet,true,
    'account deletion must acquire and wait for the wallet lock before evaluating outstanding obligations');
  assert.equal(webhookBlockedOnWallet,true,
    'the internal webhook must reach the wallet lock while holding its payment aggregate');
  assert.equal(deleteOutcome?.ok,false,
    'deletion must abort rather than erase the account while its payment callback is pending');
  assert.equal(deleteOutcome?.error?.code,'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING');
  assert.equal(webhookOutcome?.ok,true,
    'the provider callback must proceed after the deletion transaction rolls back');
  assert.equal(webhookOutcome?.value?.processed,true);

  const { rows: users } = await pool.query('SELECT status FROM users WHERE id=$1',[payerId]);
  assert.equal(users[0]?.status,'ACTIVE','rejected deletion must leave the payer account active');
  const { rows: payments } = await pool.query(
    'SELECT status FROM payments WHERE id=$1',[paymentId],
  );
  assert.equal(payments[0]?.status,isRelease ? 'RELEASED' : 'REFUNDED');
  const { rows: holds } = await pool.query(
    `SELECT status FROM wallet_holds
      WHERE reference_id=$1 AND hold_type='JOB_PAYMENT'
      ORDER BY created_at DESC,id DESC LIMIT 1`,
    [paymentId],
  );
  assert.equal(holds[0]?.status,isRelease ? 'RELEASED' : 'CANCELLED');
  const finalPayerWallet = await getWalletByUserId(payerId);
  assert.equal(String(finalPayerWallet.available_balance),isRelease ? '900' : '1000',
    'release preserves the held payer balance; refund returns the full employer charge');
  assert.equal(String(finalPayerWallet.locked_balance),'0',
    'the callback must resolve the locked escrow amount after deletion aborts');
  if (isRelease) {
    const { rows: jobsAfter } = await pool.query('SELECT status FROM jobs WHERE id=$1',[jobId]);
    assert.equal(jobsAfter[0]?.status,'SETTLED');
    const workerWallet = await getWalletByUserId(workerId);
    assert.equal(String(workerWallet?.available_balance),'99');
  } else {
    const { rows: refunds } = await pool.query(
      'SELECT status FROM refunds WHERE payment_id=$1',[paymentId],
    );
    assert.equal(refunds[0]?.status,'REFUNDED');
  }
}

test('account deletion and internal release webhook serialize on wallet locks without deadlock', { skip: !enabled, timeout: 30000 }, async () => {
  await runAccountDeletionAgainstInternalPaymentWebhook({eventType:'PAYMENT_RELEASED'});
});

test('account deletion and internal refund webhook serialize on wallet locks without deadlock', { skip: !enabled, timeout: 30000 }, async () => {
  await runAccountDeletionAgainstInternalPaymentWebhook({eventType:'PAYMENT_REFUNDED'});
});




test('account deletion and payout completion serialize on wallet locks without deadlock', { skip: !enabled, timeout: 30000 }, async () => {
  const pool = dbModule.getPool();
  const suffix = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}`;
  const userId = await createTransferTestUser(pool, `delete-payout-race-${suffix}`);
  const previousProvider = appConfig.paymentProvider;
  const previousNodeEnv = process.env.NODE_ENV;
  let holder = null;
  let holderOpen = false;
  let deleteOutcome = null;
  let payoutOutcome = null;

  try {
    appConfig.paymentProvider = 'internal';
    process.env.NODE_ENV = 'test';
    await creditWallet({
      userId,
      amount:'500',
      idempotencyKey:`delete-payout-wallet-seed-${suffix}`,
    });
    const payout = await requestPayoutAtomic({
      userId,
      amount:'500',
      idempotencyKey:`delete-payout-request-${suffix}`,
    });
    assert.equal(payout.status,'RESERVED');

    const { rows: events } = await pool.query(
      `UPDATE outbox_events
          SET status='PROCESSING',attempts=1,locked_at=NOW(),lease_token=gen_random_uuid()
        WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1
        RETURNING id,lease_token`,
      [payout.id],
    );
    assert.equal(events.length,1,'payout reservation must create one durable execution event');
    const event = events[0];

    const wallet = await getWalletByUserId(userId);
    assert.equal(String(wallet.available_balance),'0');
    assert.equal(String(wallet.locked_balance),'500');

    holder = await pool.connect();
    await holder.query('BEGIN');
    holderOpen = true;
    await holder.query('SELECT id FROM wallet_accounts WHERE id=$1 FOR UPDATE',[wallet.id]);

    const deletePromise = deleteUserPrivacyBundle(userId,{
      email:`deleted+${userId}@invalid.local`,
      passwordHash:'integration-only-deleted-account',
    }).then(
      (value) => { deleteOutcome = {ok:true,value}; return deleteOutcome; },
      (error) => { deleteOutcome = {ok:false,error}; return deleteOutcome; },
    );

    let deleteBlockedOnWallet = false;
    const deletionDeadline = Date.now() + 7000;
    while (Date.now() < deletionDeadline) {
      const { rows: waiters } = await pool.query(
        `SELECT pid,query FROM pg_stat_activity
          WHERE datname=current_database() AND pid<>pg_backend_pid()
            AND wait_event_type='Lock'
            AND query ILIKE '%FROM wallet_accounts%'
            AND query ILIKE '%WHERE user_id=$1%'`,
      );
      if (waiters.length) { deleteBlockedOnWallet = true; break; }
      if (deleteOutcome) break;
      await new Promise((resolve) => setTimeout(resolve,20));
    }

    const completionPromise = completePayoutOutbox({
      eventId:event.id,
      payoutId:payout.id,
      providerRef:`provider-payout-${suffix}`,
      leaseToken:event.lease_token,
    }).then(
      (value) => { payoutOutcome = {ok:true,value}; return payoutOutcome; },
      (error) => { payoutOutcome = {ok:false,error}; return payoutOutcome; },
    );

    let payoutBlockedOnWallet = false;
    const payoutDeadline = Date.now() + 7000;
    while (Date.now() < payoutDeadline) {
      const { rows: waiters } = await pool.query(
        `SELECT pid,query FROM pg_stat_activity
          WHERE datname=current_database() AND pid<>pg_backend_pid()
            AND wait_event_type='Lock'
            AND query ILIKE '%JOIN wallet_accounts%'
            AND query ILIKE '%FOR UPDATE%'`,
      );
      if (waiters.length) { payoutBlockedOnWallet = true; break; }
      if (payoutOutcome) break;
      await new Promise((resolve) => setTimeout(resolve,20));
    }

    await holder.query('COMMIT');
    holderOpen = false;
    await Promise.all([deletePromise,completionPromise]);

    assert.equal(deleteBlockedOnWallet,true,
      'account deletion must queue on the reserved payout wallet before evaluating obligations');
    assert.equal(payoutBlockedOnWallet,true,
      'payout completion must queue on its payout-wallet row while holding the event and payout');
    assert.equal(deleteOutcome?.ok,false,
      'account deletion must reject while a payout reservation remains active');
    assert.equal(deleteOutcome?.error?.code,'ACCOUNT_FINANCIAL_OBLIGATIONS_PENDING');
    assert.equal(payoutOutcome?.ok,true,
      'payout completion must continue after the rejected deletion rolls back');
    assert.equal(payoutOutcome?.value?.completed,true);

    const { rows: users } = await pool.query('SELECT status FROM users WHERE id=$1',[userId]);
    assert.equal(users[0]?.status,'ACTIVE');
    const { rows: payouts } = await pool.query('SELECT status FROM payouts WHERE id=$1',[payout.id]);
    assert.equal(payouts[0]?.status,'SUCCEEDED');
    const { rows: outbox } = await pool.query('SELECT status FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(outbox[0]?.status,'DONE');
    const { rows: holds } = await pool.query(
      `SELECT status FROM wallet_holds
        WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION'`,
      [payout.id],
    );
    assert.equal(holds[0]?.status,'RELEASED');
    const finalWallet = await getWalletByUserId(userId);
    assert.equal(String(finalWallet.available_balance),'0');
    assert.equal(String(finalWallet.locked_balance),'0',
      'completed payout must consume the reservation and leave no locked balance');
  } finally {
    if (holderOpen) await holder.query('ROLLBACK').catch(() => {});
    holder?.release();
    appConfig.paymentProvider = previousProvider;
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
  }
});






async function createPanelTestAdmin(pool, prefix) {
  const userId = await createTransferTestUser(pool, prefix);
  await pool.query("UPDATE users SET role='ADMIN' WHERE id=$1", [userId]);
  return userId;
}

async function assertPanelVerificationCleared(pool, userId) {
  const { rows } = await pool.query(
    "SELECT admin_panel_verified_at FROM users WHERE id=$1",
    [userId],
  );
  assert.equal(rows[0]?.admin_panel_verified_at ?? null, null);
  assert.equal(await isAdminPanelVerified(userId), false);
}

test('PostgreSQL logout session-version bump clears existing admin-panel verification', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createPanelTestAdmin(pool, 'admin-panel-logout-invalidation');
  assert.ok(await setAdminPanelVerified(userId));
  assert.equal(await isAdminPanelVerified(userId), true);

  const version = await bumpUserSessionVersion(userId);
  assert.equal(version, 1);
  await assertPanelVerificationCleared(pool, userId);
});

test('PostgreSQL password reset clears admin-panel verification atomically', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createPanelTestAdmin(pool, 'admin-panel-reset-invalidation');
  assert.ok(await setAdminPanelVerified(userId));

  const resetId = crypto.randomUUID();
  await insertResetToken({
    id: resetId,
    userId,
    tokenHash: `admin-panel-reset-${crypto.randomUUID()}`,
    familyId: crypto.randomUUID(),
    expiresAt: new Date(Date.now() + 60000).toISOString(),
    createdAt: new Date().toISOString(),
  });
  assert.equal(
    await consumeResetTokenAndChangePassword(resetId, userId, 'integration-only-password-hash'),
    true,
  );
  await assertPanelVerificationCleared(pool, userId);
});

test('PostgreSQL forced session revocation clears admin-panel verification', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createPanelTestAdmin(pool, 'admin-panel-revoke-session');
  assert.ok(await setAdminPanelVerified(userId));

  const result = await revokeUserSessions(userId);
  assert.equal(result?.id, userId);
  assert.equal(result?.sessionVersion, 1);
  await assertPanelVerificationCleared(pool, userId);
});

test('PostgreSQL admin status changes clear admin-panel verification', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createPanelTestAdmin(pool, 'admin-panel-status-invalidation');
  assert.ok(await setAdminPanelVerified(userId));

  const updated = await setUserStatus(userId, 'DISABLED');
  assert.equal(updated?.status, 'DISABLED');
  await assertPanelVerificationCleared(pool, userId);
});

test('PostgreSQL privacy deletion clears admin-panel verification from the account tombstone', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createPanelTestAdmin(pool, 'admin-panel-privacy-invalidation');
  assert.ok(await setAdminPanelVerified(userId));

  const result = await deleteUserPrivacyBundle(userId, {
    email: `deleted+${userId}@invalid.local`,
    passwordHash: 'integration-only-deleted-account',
  });
  assert.equal(result?.deleted, true);
  await assertPanelVerificationCleared(pool, userId);
});

test('PostgreSQL refuses to set or honor admin-panel verification for a disabled admin', { skip: !enabled }, async () => {
  const pool = dbModule.getPool();
  const userId = await createPanelTestAdmin(pool, 'admin-panel-disabled-guard');
  await pool.query(
    "UPDATE users SET status='DISABLED',admin_panel_verified_at=NOW() WHERE id=$1",
    [userId],
  );

  assert.equal(await setAdminPanelVerified(userId), null);
  assert.equal(await isAdminPanelVerified(userId), false);
});


after(async () => {
  if (enabled) await dbModule.db.close();
});
