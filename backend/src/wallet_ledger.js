import crypto from 'node:crypto';
import { withSqlTransaction } from './db.js';
import { requirePool } from './repository/context.js';

export const INTERNAL_CURRENCY = 'TOMAN';
export const MAX_AMOUNT = 9_000_000_000_000_000n;

function amount(value, { allowZero = false } = {}) {
  let raw = String(value ?? '').trim();
  // PostgreSQL NUMERIC(18,2) round-trips integer TOMAN values as strings such
  // as "165.00". Normalize only zero-fraction decimals; genuine TOMAN
  // fractions remain invalid by design.
  if (/^\d+\.0+$/.test(raw)) raw = raw.slice(0, raw.indexOf('.'));
  if (!/^\d+$/.test(raw)) throw Object.assign(new Error('INVALID_AMOUNT'), { code: 'INVALID_AMOUNT' });
  const parsed = BigInt(raw);
  if ((allowZero ? parsed < 0n : parsed <= 0n) || parsed > MAX_AMOUNT) {
    throw Object.assign(new Error('INVALID_AMOUNT'), { code: 'INVALID_AMOUNT' });
  }
  return parsed;
}

function assertActive(wallet) {
  if (!wallet || wallet.status !== 'ACTIVE') {
    throw Object.assign(new Error('WALLET_UNAVAILABLE'), { code: 'WALLET_UNAVAILABLE' });
  }
}

function assertReceivable(wallet) {
  if (!wallet || wallet.status === 'CLOSED') {
    throw Object.assign(new Error('WALLET_UNAVAILABLE'), { code: 'WALLET_UNAVAILABLE' });
  }
}

async function ensureWalletForUser(userId, client) {
  const { rows } = await client.query(`
    INSERT INTO wallet_accounts(id,user_id,currency,created_at,updated_at)
    VALUES($1,$2,'TOMAN',NOW(),NOW())
    ON CONFLICT(user_id) DO UPDATE SET updated_at=wallet_accounts.updated_at
    RETURNING *
  `, [crypto.randomUUID(), userId]);
  return rows[0];
}

export async function ensureWalletForUserPublic(userId) {
  return withSqlTransaction((client) => ensureWalletForUser(userId, client));
}

export async function getWalletByUserId(userId) {
  const { rows } = await requirePool().query(
    `SELECT * FROM wallet_accounts WHERE user_id=$1 AND currency='TOMAN'`, [userId],
  );
  return rows[0] || null;
}

async function createOperation(client, { type, actorType = 'SYSTEM', actorId = null, idempotencyKey = null }) {
  const { rows } = await client.query(`
    INSERT INTO financial_operations(operation_type,actor_type,actor_id,status,idempotency_key)
    VALUES($1,$2,$3,'PROCESSING',$4)
    RETURNING *
  `, [type, actorType, actorId, idempotencyKey]);
  return rows[0];
}

async function finishOperation(client, operationId, status = 'SUCCEEDED') {
  await client.query(`
    UPDATE financial_operations SET status=$2,completed_at=CASE WHEN $2 IN ('SUCCEEDED','FAILED','CANCELLED') THEN NOW() ELSE completed_at END
    WHERE id=$1
  `, [operationId, status]);
}

async function beginIdempotency(client, { principalId = null, operation, key, requestHash = '' }) {
  // INSERT ... ON CONFLICT DO UPDATE is unsafe here: two transactions that
  // observe a missing key can race, and the later upsert could reset the
  // first committed operation from SUCCEEDED back to PROCESSING.
  // Insert-only reservation + a post-conflict row lock makes the unique index
  // the serialization point without ever overwriting a completed request.
  const inserted = await client.query(`
    INSERT INTO idempotency_keys(principal_id,operation,idempotency_key,request_hash,status)
    VALUES($1,$2,$3,$4,'PROCESSING')
    ON CONFLICT(principal_id,operation,idempotency_key) DO NOTHING
    RETURNING *
  `, [principalId, operation, key, requestHash]);
  if (inserted.rows[0]) return { existing: null };

  const existing = await client.query(`
    SELECT * FROM idempotency_keys WHERE principal_id IS NOT DISTINCT FROM $1 AND operation=$2 AND idempotency_key=$3 FOR UPDATE
  `, [principalId, operation, key]);
  if (!existing.rows[0]) {
    throw Object.assign(new Error('IDEMPOTENCY_RESERVATION_LOST'), { code: 'IDEMPOTENCY_RESERVATION_LOST' });
  }
  if (existing.rows[0].request_hash !== requestHash) {
    throw Object.assign(new Error('IDEMPOTENCY_CONFLICT'), { code: 'IDEMPOTENCY_CONFLICT' });
  }
  if (existing.rows[0].status === 'SUCCEEDED') return { existing: existing.rows[0] };
  if (existing.rows[0].status === 'PROCESSING') {
    throw Object.assign(new Error('IDEMPOTENCY_IN_PROGRESS'), { code: 'IDEMPOTENCY_IN_PROGRESS' });
  }

  await client.query(`
    UPDATE idempotency_keys
    SET status='PROCESSING',resource_type=NULL,resource_id=NULL,response_code=NULL,response_body=NULL
    WHERE principal_id IS NOT DISTINCT FROM $1 AND operation=$2 AND idempotency_key=$3
  `, [principalId, operation, key]);
  return { existing: null };
}

async function completeIdempotency(client, { principalId = null, operation, key, resourceType, resourceId, responseCode = 200, responseBody }) {
  await client.query(`
    UPDATE idempotency_keys
    SET status='SUCCEEDED',resource_type=$4,resource_id=$5,response_code=$6,response_body=$7::jsonb
    WHERE principal_id IS NOT DISTINCT FROM $1 AND operation=$2 AND idempotency_key=$3
  `, [principalId, operation, key, resourceType, resourceId, responseCode, JSON.stringify(responseBody ?? {})]);
}

async function postEntry(client, { walletId, entryType, direction, amount: value, referenceType, referenceId, operationId, metadata = {}, balanceAfter = null }) {
  const { rows } = await client.query(`
    INSERT INTO wallet_entries(wallet_id,entry_type,direction,amount,currency,reference_type,reference_id,financial_operation_id,metadata,balance_after)
    VALUES($1,$2,$3,$4,'TOMAN',$5,$6,$7,$8::jsonb,$9)
    RETURNING *
  `, [walletId, entryType, direction, value, referenceType, referenceId, operationId, JSON.stringify(metadata, (_key, item) => typeof item === 'bigint' ? item.toString() : item), balanceAfter]);
  return rows[0];
}

async function postJournal(client, { operationId, journalType, referenceType, referenceId, entries }) {
  const { rows } = await client.query(`
    INSERT INTO journals(operation_id,journal_type,currency,status)
    VALUES($1,$2,'TOMAN','CREATED') RETURNING id
  `, [operationId, journalType]);
  const journalId = rows[0].id;
  for (const entry of entries) {
    await client.query(`
      INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,'TOMAN',NOW())
    `, [crypto.randomUUID(), journalId, referenceType, referenceId, entry.account, entry.debit ?? 0, entry.credit ?? 0]);
  }
  await client.query(`UPDATE journals SET status='POSTED',posted_at=NOW() WHERE id=$1`, [journalId]);
  return journalId;
}

async function lockWallets(client, ids) {
  const uniqueIds = [...new Set(ids)].sort();
  const { rows } = await client.query(`
    SELECT * FROM wallet_accounts WHERE id = ANY($1::uuid[]) ORDER BY id FOR UPDATE
  `, [uniqueIds]);
  const byId = new Map(rows.map((row) => [row.id, row]));
  return uniqueIds.map((id) => byId.get(id));
}

async function getActiveHold(client, paymentId) {
  const { rows } = await client.query(`
    SELECT * FROM wallet_holds
    WHERE reference_id=$1 AND hold_type='JOB_PAYMENT' AND status='ACTIVE'
    ORDER BY created_at DESC,id DESC LIMIT 1 FOR UPDATE
  `, [paymentId]);
  return rows[0] || null;
}

export async function postInternalPaymentHoldWithClient(client, {
  paymentId, payerId, employerCharge, providerPayout, platformFee, idempotencyKey, actorId = payerId,
}) {
  const charge = amount(employerCharge); const payout = amount(providerPayout); const fee = amount(platformFee, { allowZero: true });
  if (BigInt(charge) !== BigInt(payout) + BigInt(fee)) throw Object.assign(new Error('INVALID_PAYMENT_BREAKDOWN'), { code: 'INVALID_PAYMENT_BREAKDOWN' });
  const key = String(idempotencyKey || '').trim(); if (!key) throw new Error('IDEMPOTENCY_KEY_REQUIRED');
  const idem = await beginIdempotency(client, { principalId: actorId, operation: 'HOLD', key, requestHash: `${paymentId}:${charge}:${payout}:${fee}` });
  if (idem.existing) return JSON.parse(idem.existing.response_body);

  const payer = await ensureWalletForUser(payerId, client);
  assertActive(payer);
  const [lockedPayer] = await lockWallets(client, [payer.id]);
  assertActive(lockedPayer);
  if (BigInt(String(lockedPayer.available_balance)) < charge) throw Object.assign(new Error('INSUFFICIENT_FUNDS'), { code: 'INSUFFICIENT_FUNDS' });

  const operation = await createOperation(client, { type: 'HOLD', actorType: 'USER', actorId: payerId, idempotencyKey: key });
  const { rows } = await client.query(`
    UPDATE wallet_accounts SET available_balance=available_balance-$2,locked_balance=locked_balance+$3,updated_at=NOW()
    WHERE id=$1 RETURNING *
  `, [lockedPayer.id, charge, payout]);
  const wallet = rows[0];
  const hold = await client.query(`
    INSERT INTO wallet_holds(wallet_id,hold_type,reference_type,reference_id,financial_operation_id,amount,status)
    VALUES($1,'JOB_PAYMENT','PAYMENT',$2,$3,$4,'ACTIVE') RETURNING *
  `, [wallet.id, paymentId, operation.id, payout]);
  await postEntry(client, { walletId: wallet.id, entryType: 'HOLD', direction: 'DEBIT', amount: charge, referenceType: 'PAYMENT_FUND', referenceId: paymentId, operationId: operation.id, metadata: { employerCharge: charge, providerPayout: payout, platformFee: fee }, balanceAfter: wallet.available_balance });
  await postJournal(client, { operationId: operation.id, journalType: 'HOLD', referenceType: 'PAYMENT_FUND', referenceId: paymentId, entries: [
    { account: 'CUSTOMER_WALLET_LIABILITY', debit: charge },
    { account: 'ESCROW_LIABILITY', credit: payout },
    { account: 'PLATFORM_FEE_REVENUE', credit: fee },
  ] });
  await finishOperation(client, operation.id);
  const result = { operationId: operation.id, hold: hold.rows[0], wallet, currency: INTERNAL_CURRENCY };
  await completeIdempotency(client, { principalId: actorId, operation: 'HOLD', key, resourceType: 'financial_operation', resourceId: operation.id, responseBody: result });
  return result;
}

export async function postInternalPaymentReleaseWithClient(client, {
  paymentId, payerId, workerId, providerPayout, idempotencyKey, actorId = workerId,
}) {
  const payout = amount(providerPayout); const key = String(idempotencyKey || '').trim(); if (!key) throw new Error('IDEMPOTENCY_KEY_REQUIRED');
  const idem = await beginIdempotency(client, { principalId: actorId, operation: 'RELEASE', key, requestHash: `${paymentId}:${payout}:${payerId}:${workerId}` });
  if (idem.existing) return JSON.parse(idem.existing.response_body);
  const payer = await ensureWalletForUser(payerId, client); const worker = await ensureWalletForUser(workerId, client);
  assertActive(payer); assertActive(worker);
  const [lockedPayer, lockedWorker] = await lockWallets(client, [payer.id, worker.id]);
  assertActive(lockedPayer);
  assertReceivable(lockedWorker);
  const hold = await getActiveHold(client, paymentId);
  if (!hold) throw Object.assign(new Error(`ACTIVE_HOLD_NOT_FOUND:${paymentId}`), { code: 'ACTIVE_HOLD_NOT_FOUND' });
  const holdAmount = amount(hold.amount);
  if (holdAmount !== payout) throw Object.assign(new Error(`ACTIVE_HOLD_AMOUNT_MISMATCH:${hold.amount}:${payout}`), { code: 'ACTIVE_HOLD_AMOUNT_MISMATCH' });
  if (String(hold.wallet_id) !== String(lockedPayer.id)) throw Object.assign(new Error(`ACTIVE_HOLD_WALLET_MISMATCH:${hold.wallet_id}:${lockedPayer.id}`), { code: 'ACTIVE_HOLD_WALLET_MISMATCH' });
  if (BigInt(String(lockedPayer.locked_balance)) < payout) throw Object.assign(new Error('INSUFFICIENT_LOCKED_FUNDS'), { code: 'INSUFFICIENT_LOCKED_FUNDS' });

  const operation = await createOperation(client, { type: 'RELEASE', actorType: 'SYSTEM', actorId, idempotencyKey: key });
  const { rows: payerRows } = await client.query(`UPDATE wallet_accounts SET locked_balance=locked_balance-$2,updated_at=NOW() WHERE id=$1 RETURNING *`, [lockedPayer.id, payout]);
  const { rows: workerRows } = await client.query(`UPDATE wallet_accounts SET available_balance=available_balance+$2,updated_at=NOW() WHERE id=$1 RETURNING *`, [lockedWorker.id, payout]);
  await client.query(`UPDATE wallet_holds SET status='RELEASED',released_at=NOW() WHERE id=$1`, [hold.id]);
  // RELEASE settles the previously-held payer funds; the payer's available balance is unchanged.
  // Only the worker receives a wallet CREDIT at this stage. Adding a payer-side DEBIT would create
  // a false second money movement because HOLD already removed the amount from available balance.
  const credit = await postEntry(client, { walletId: workerRows[0].id, entryType: 'RELEASE', direction: 'CREDIT', amount: payout, referenceType: 'PAYMENT_RELEASE', referenceId: paymentId, operationId: operation.id, balanceAfter: workerRows[0].available_balance });
  await postJournal(client, { operationId: operation.id, journalType: 'RELEASE', referenceType: 'PAYMENT_RELEASE', referenceId: paymentId, entries: [
    { account: 'ESCROW_LIABILITY', debit: payout }, { account: 'WORKER_PAYABLE', credit: payout },
  ] });
  await finishOperation(client, operation.id);
  const result = { operationId: operation.id, entries: [credit], payerWallet: payerRows[0], workerWallet: workerRows[0], currency: INTERNAL_CURRENCY };
  await completeIdempotency(client, { principalId: actorId, operation: 'RELEASE', key, resourceType: 'financial_operation', resourceId: operation.id, responseBody: result });
  return result;
}

export async function postInternalPaymentRefundWithClient(client, {
  paymentId, payerId, providerPayout, platformFee, employerCharge, idempotencyKey, actorId = payerId,
}) {
  const payout = amount(providerPayout); const fee = amount(platformFee, { allowZero: true }); const charge = amount(employerCharge);
  if (BigInt(charge) !== BigInt(payout) + BigInt(fee)) throw Object.assign(new Error('INVALID_PAYMENT_BREAKDOWN'), { code: 'INVALID_PAYMENT_BREAKDOWN' });
  const key = String(idempotencyKey || '').trim(); if (!key) throw new Error('IDEMPOTENCY_KEY_REQUIRED');
  const idem = await beginIdempotency(client, { principalId: actorId, operation: 'REFUND', key, requestHash: `${paymentId}:${payout}:${fee}:${charge}` });
  if (idem.existing) return JSON.parse(idem.existing.response_body);
  const payer = await ensureWalletForUser(payerId, client); assertActive(payer);
  const [lockedPayer] = await lockWallets(client, [payer.id]);
  assertActive(lockedPayer);
  const hold = await getActiveHold(client, paymentId);
  if (!hold || BigInt(String(hold.amount)) !== payout || hold.wallet_id !== lockedPayer.id) throw Object.assign(new Error('ACTIVE_HOLD_NOT_FOUND'), { code: 'ACTIVE_HOLD_NOT_FOUND' });
  if (BigInt(String(lockedPayer.locked_balance)) < payout) throw Object.assign(new Error('INSUFFICIENT_LOCKED_FUNDS'), { code: 'INSUFFICIENT_LOCKED_FUNDS' });

  const operation = await createOperation(client, { type: 'REFUND', actorType: 'USER', actorId: payerId, idempotencyKey: key });
  const { rows } = await client.query(`UPDATE wallet_accounts SET locked_balance=locked_balance-$2,available_balance=available_balance+$3,updated_at=NOW() WHERE id=$1 RETURNING *`, [lockedPayer.id, payout, charge]);
  await client.query(`UPDATE wallet_holds SET status='CANCELLED',released_at=NOW() WHERE id=$1`, [hold.id]);
  const entry = await postEntry(client, { walletId: rows[0].id, entryType: 'REFUND', direction: 'CREDIT', amount: charge, referenceType: 'PAYMENT_REFUND', referenceId: paymentId, operationId: operation.id, metadata: { providerPayout: payout, platformFee: fee }, balanceAfter: rows[0].available_balance });
  await postJournal(client, { operationId: operation.id, journalType: 'REFUND', referenceType: 'PAYMENT_REFUND', referenceId: paymentId, entries: [
    { account: 'ESCROW_LIABILITY', debit: payout }, { account: 'PLATFORM_FEE_REVENUE', debit: fee }, { account: 'CUSTOMER_WALLET_LIABILITY', credit: charge },
  ] });
  await finishOperation(client, operation.id);
  const result = { operationId: operation.id, entry, wallet: rows[0], currency: INTERNAL_CURRENCY };
  await completeIdempotency(client, { principalId: actorId, operation: 'REFUND', key, resourceType: 'financial_operation', resourceId: operation.id, responseBody: result });
  return result;
}

export async function creditWallet({ userId, amount: rawAmount, idempotencyKey, referenceType = 'WALLET_TOP_UP', referenceId = null, metadata = {}, actorId = userId }) {
  const value = amount(rawAmount); const key = String(idempotencyKey || '').trim(); if (!key) throw new Error('IDEMPOTENCY_KEY_REQUIRED');
  return withSqlTransaction(async (client) => {
    const idem = await beginIdempotency(client, { principalId: actorId, operation: 'TOP_UP', key, requestHash: `${userId}:${value}:${referenceType}:${referenceId}` });
    if (idem.existing) return JSON.parse(idem.existing.response_body);
    const wallet = await ensureWalletForUser(userId, client); assertActive(wallet);
    const [locked] = await lockWallets(client, [wallet.id]);
    assertActive(locked);
    const operation = await createOperation(client, { type: 'TOP_UP', actorType: actorId === userId ? 'USER' : 'ADMIN', actorId, idempotencyKey: key });
    const { rows } = await client.query(`UPDATE wallet_accounts SET available_balance=available_balance+$2,updated_at=NOW() WHERE id=$1 RETURNING *`, [locked.id, value]);
    const entry = await postEntry(client, { walletId: locked.id, entryType: 'TOP_UP', direction: 'CREDIT', amount: value, referenceType, referenceId, operationId: operation.id, metadata, balanceAfter: rows[0].available_balance });
    await postJournal(client, { operationId: operation.id, journalType: 'TOP_UP', referenceType, referenceId: referenceId || operation.id, entries: [
      { account: 'PLATFORM_CASH', debit: value }, { account: 'CUSTOMER_WALLET_LIABILITY', credit: value },
    ] });
    await finishOperation(client, operation.id);
    const result = { operationId: operation.id, entry, wallet: rows[0], currency: INTERNAL_CURRENCY };
    await completeIdempotency(client, { principalId: actorId, operation: 'TOP_UP', key, resourceType: 'financial_operation', resourceId: operation.id, responseBody: result });
    return result;
  });
}

export async function transferAvailable({ sourceUserId, destinationUserId, amount: rawAmount, idempotencyKey, referenceType = 'WALLET_TRANSFER', referenceId = null, metadata = {} }) {
  const value = amount(rawAmount); const key = String(idempotencyKey || '').trim(); if (!key) throw new Error('IDEMPOTENCY_KEY_REQUIRED');
  if (sourceUserId === destinationUserId) throw Object.assign(new Error('SELF_TRANSFER_NOT_ALLOWED'), { code: 'SELF_TRANSFER_NOT_ALLOWED' });
  return withSqlTransaction(async (client) => {
    const idem = await beginIdempotency(client, { principalId: sourceUserId, operation: 'TRANSFER', key, requestHash: `${destinationUserId}:${value}:${referenceType}:${referenceId}` });
    if (idem.existing) return JSON.parse(idem.existing.response_body);
    const source = await ensureWalletForUser(sourceUserId, client); const destination = await ensureWalletForUser(destinationUserId, client);
    assertActive(source); assertActive(destination);
    const [lockedSource, lockedDestination] = await lockWallets(client, [source.id, destination.id]);
    assertActive(lockedSource);
    assertActive(lockedDestination);
    if (BigInt(String(lockedSource.available_balance)) < value) throw Object.assign(new Error('INSUFFICIENT_FUNDS'), { code: 'INSUFFICIENT_FUNDS' });
    const operation = await createOperation(client, { type: 'TRANSFER', actorType: 'USER', actorId: sourceUserId, idempotencyKey: key });
    const { rows: sourceRows } = await client.query(`UPDATE wallet_accounts SET available_balance=available_balance-$2,updated_at=NOW() WHERE id=$1 RETURNING *`, [lockedSource.id, value]);
    const { rows: destinationRows } = await client.query(`UPDATE wallet_accounts SET available_balance=available_balance+$2,updated_at=NOW() WHERE id=$1 RETURNING *`, [lockedDestination.id, value]);
    const sourceEntry = await postEntry(client, { walletId: lockedSource.id, entryType: 'TRANSFER', direction: 'DEBIT', amount: value, referenceType, referenceId, operationId: operation.id, metadata, balanceAfter: sourceRows[0].available_balance });
    const destinationEntry = await postEntry(client, { walletId: destinationRows[0].id, entryType: 'TRANSFER', direction: 'CREDIT', amount: value, referenceType, referenceId, operationId: operation.id, metadata, balanceAfter: destinationRows[0].available_balance });
    await postJournal(client, { operationId: operation.id, journalType: 'TRANSFER', referenceType, referenceId: referenceId || operation.id, entries: [
      { account: 'CUSTOMER_WALLET_LIABILITY', debit: value }, { account: 'CUSTOMER_WALLET_LIABILITY', credit: value },
    ] });
    await finishOperation(client, operation.id);
    const result = { operationId: operation.id, entries: [sourceEntry, destinationEntry], sourceWallet: sourceRows[0], destinationWallet: destinationRows[0], currency: INTERNAL_CURRENCY };
    await completeIdempotency(client, { principalId: sourceUserId, operation: 'TRANSFER', key, resourceType: 'financial_operation', resourceId: operation.id, responseBody: result });
    return result;
  });
}
