import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { config } from '../config.js';
import { lockActiveWalletUsers } from '../wallet_ledger.js';
import { isInternalWalletPayoutEnabled } from '../wallet_payout_policy.js';
import { lockAuthorizedAdminActor } from './admin_authorization.js';

const MAX_AMOUNT = 9_000_000_000_000_000n;

const INTERNAL_CURRENCY = 'TOMAN';
const PAYOUT_PROVIDER = 'internal';

async function appendPayoutReversalEntry(client, {
  walletId, payoutId, amount, operationId, balanceAfter, failureCode,
}) {
  await client.query(
    `INSERT INTO wallet_entries(
       id,wallet_id,entry_type,direction,amount,currency,
       reference_type,reference_id,financial_operation_id,metadata,balance_after
     )
     VALUES($1,$2,'PAYOUT','CREDIT',$3,'TOMAN','PAYOUT',$4,$5,$6::jsonb,$7)`,
    [
      crypto.randomUUID(),
      walletId,
      amount,
      payoutId,
      operationId,
      JSON.stringify({ state:'REVERSED', failureCode }),
      balanceAfter,
    ],
  );
}

function parseAmount(value) {
  const raw = String(value ?? '').trim();
  if (!/^\d+$/.test(raw)) throw Object.assign(new Error('INVALID_AMOUNT'), { code:'INVALID_AMOUNT' });
  const n = BigInt(raw);
  if (n <= 0n || n > MAX_AMOUNT) throw Object.assign(new Error('INVALID_AMOUNT'), { code:'INVALID_AMOUNT' });
  return n;
}

export async function requestPayoutAtomic({ userId, amount, idempotencyKey, referenceType='PAYOUT', referenceId=null }) {
  const value = parseAmount(amount);
  const key = String(idempotencyKey || '').trim();
  if (!key) throw Object.assign(new Error('IDEMPOTENCY_KEY_REQUIRED'), { code:'IDEMPOTENCY_KEY_REQUIRED' });
  if (!isInternalWalletPayoutEnabled({ paymentProvider: config.paymentProvider })) {
    throw Object.assign(new Error('PAYOUT_PROVIDER_NOT_ENABLED'), { code:'PAYOUT_PROVIDER_NOT_ENABLED' });
  }

  return withSqlTransaction(async (client) => {
    const existing = await client.query(`SELECT * FROM payouts WHERE user_id=$1 AND idempotency_key=$2 FOR UPDATE`, [userId, key]);
    if (existing.rows[0]) {
      const p = existing.rows[0];
      if (BigInt(String(p.amount)) !== value) throw Object.assign(new Error('IDEMPOTENCY_CONFLICT'), { code:'IDEMPOTENCY_CONFLICT' });
      return p;
    }

    await lockActiveWalletUsers(client, [userId]);

    const { rows: walletRows } = await client.query(`SELECT * FROM wallet_accounts WHERE user_id=$1 AND currency='TOMAN' FOR UPDATE`, [userId]);
    const wallet = walletRows[0];
    if (!wallet) throw Object.assign(new Error('WALLET_NOT_FOUND'), { code:'WALLET_NOT_FOUND' });

    // Re-check the idempotency resource after acquiring the wallet lock. A concurrent
    // request can pass the initial lookup before the winner inserts its payout; this
    // second read turns that race into a deterministic replay instead of a unique-key 500.
    const concurrent = await client.query(`SELECT * FROM payouts WHERE user_id=$1 AND idempotency_key=$2 FOR UPDATE`, [userId, key]);
    if (concurrent.rows[0]) {
      const p = concurrent.rows[0];
      if (BigInt(String(p.amount)) !== value) throw Object.assign(new Error('IDEMPOTENCY_CONFLICT'), { code:'IDEMPOTENCY_CONFLICT' });
      return p;
    }
    if (wallet.status !== 'ACTIVE') throw Object.assign(new Error('WALLET_UNAVAILABLE'), { code:'WALLET_UNAVAILABLE' });
    if (BigInt(String(wallet.available_balance)) < value) throw Object.assign(new Error('INSUFFICIENT_FUNDS'), { code:'INSUFFICIENT_FUNDS' });

    const operationId = crypto.randomUUID();
    const payoutId = crypto.randomUUID();
    await client.query(`INSERT INTO financial_operations(id,operation_type,actor_type,actor_id,status,idempotency_key) VALUES($1,'PAYOUT','USER',$2,'PROCESSING',$3)`, [operationId,userId,key]);
    await client.query(`UPDATE wallet_accounts SET available_balance=available_balance-$2,locked_balance=locked_balance+$2,updated_at=NOW() WHERE id=$1`, [wallet.id,value]);
    await client.query(`INSERT INTO wallet_holds(wallet_id,hold_type,reference_type,reference_id,financial_operation_id,amount,status) VALUES($1,'PAYOUT_RESERVATION',$2,$3,$4,$5,'ACTIVE')`, [wallet.id,referenceType,referenceId || payoutId,operationId,value]);
    await client.query(`INSERT INTO wallet_entries(wallet_id,entry_type,direction,amount,currency,reference_type,reference_id,financial_operation_id,metadata,balance_after) VALUES($1,'PAYOUT','DEBIT',$2,'TOMAN',$3,$4,$5,$6::jsonb,$7)`, [wallet.id,value,referenceType,referenceId || payoutId,operationId,JSON.stringify({state:'RESERVED'}),(BigInt(String(wallet.available_balance))-value).toString()]);
    await client.query(`INSERT INTO payouts(id,wallet_id,user_id,amount,currency,status,provider,idempotency_key,created_at,updated_at) VALUES($1,$2,$3,$4,'TOMAN','RESERVED',$5,$6,NOW(),NOW())`, [payoutId,wallet.id,userId,value,PAYOUT_PROVIDER,key]);
    await client.query(`INSERT INTO journals(operation_id,journal_type,currency,status,posted_at) VALUES($1,'PAYOUT','TOMAN','CREATED',NULL)`, [operationId]);
    await client.query(`INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at) VALUES(gen_random_uuid(),'PAYOUT_EXECUTE','payout',$1,$2,$3::jsonb,'PENDING',0,NOW(),NOW())`, [payoutId,`PAYOUT_EXECUTE:${payoutId}`,JSON.stringify({payoutId,userId,amount:value.toString(),currency:INTERNAL_CURRENCY,idempotencyKey:key,operationId})]);
    const { rows } = await client.query(`SELECT * FROM payouts WHERE id=$1`, [payoutId]);
    return rows[0];
  });
}

function sameIntegerAmount(left, right) {
  try {
    return BigInt(String(left)) === BigInt(String(right));
  } catch {
    return false;
  }
}

function hasSufficientLockedBalance(wallet, payout) {
  try {
    return BigInt(String(wallet.locked_balance)) >= BigInt(String(payout.amount));
  } catch {
    return false;
  }
}

function payoutEventPayload(event) {
  if (event?.payload && typeof event.payload === 'object') return event.payload;
  if (typeof event?.payload === 'string') {
    try { return JSON.parse(event.payload); } catch { return null; }
  }
  return null;
}

function validatePayoutEventIdentity(event, payout) {
  const payload = payoutEventPayload(event);
  if (!payload ||
      event.event_type !== 'PAYOUT_EXECUTE' ||
      event.aggregate_type !== 'payout' ||
      String(event.aggregate_id || '') !== String(payout.id) ||
      String(payload.payoutId || '') !== String(payout.id) ||
      String(payload.userId || '') !== String(payout.user_id) ||
      !sameIntegerAmount(payload.amount, payout.amount) ||
      String(payload.currency || '') !== String(payout.currency) ||
      String(payload.idempotencyKey || '') !== String(payout.idempotency_key)) {
    return { valid: false, reason: 'PAYOUT_OUTBOX_IDENTITY_MISMATCH' };
  }
  return { valid: true, payload };
}

async function validatePayoutSettlementLinkage(client, event, payout) {
  const identity = validatePayoutEventIdentity(event, payout);
  if (!identity.valid) return identity;

  const { rows: wallets } = await client.query(
    `SELECT id,user_id,currency,status,locked_balance
       FROM wallet_accounts WHERE id=$1 FOR UPDATE`,
    [payout.wallet_id],
  );
  const wallet = wallets[0];
  if (!wallet ||
      String(wallet.user_id) !== String(payout.user_id) ||
      String(wallet.currency) !== String(payout.currency) ||
      wallet.status !== 'ACTIVE') {
    return { valid: false, reason: 'PAYOUT_WALLET_LINKAGE_MISMATCH' };
  }
  if (!hasSufficientLockedBalance(wallet, payout)) {
    return { valid: false, reason: 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT' };
  }

  const { rows: holds } = await client.query(
    `SELECT * FROM wallet_holds
      WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'
      FOR UPDATE`,
    [payout.id],
  );
  if (holds.length === 0) return { valid: false, reason: 'PAYOUT_RESERVATION_NOT_FOUND' };
  if (holds.length !== 1) return { valid: false, reason: 'PAYOUT_HOLD_AMBIGUOUS' };
  const hold = holds[0];
  if (hold.reference_type !== 'PAYOUT' ||
      String(hold.wallet_id) !== String(payout.wallet_id) ||
      !sameIntegerAmount(hold.amount, payout.amount) ||
      !hold.financial_operation_id) {
    return { valid: false, reason: 'PAYOUT_HOLD_LINKAGE_MISMATCH' };
  }
  if (String(identity.payload.operationId || '') !== String(hold.financial_operation_id)) {
    return { valid: false, reason: 'PAYOUT_OPERATION_LINKAGE_MISMATCH' };
  }

  const { rows: operations } = await client.query(
    `SELECT id,operation_type,actor_type,actor_id,status,idempotency_key
       FROM financial_operations WHERE id=$1 FOR UPDATE`,
    [hold.financial_operation_id],
  );
  const operation = operations[0];
  if (!operation ||
      operation.operation_type !== 'PAYOUT' ||
      operation.actor_type !== 'USER' ||
      String(operation.actor_id || '') !== String(payout.user_id) ||
      operation.status !== 'PROCESSING' ||
      String(operation.idempotency_key || '') !== String(payout.idempotency_key)) {
    return { valid: false, reason: 'PAYOUT_OPERATION_LINKAGE_MISMATCH' };
  }

  const { rows: journals } = await client.query(
    `SELECT id,operation_id,journal_type,currency,status
       FROM journals WHERE operation_id=$1 AND journal_type='PAYOUT' FOR UPDATE`,
    [hold.financial_operation_id],
  );
  if (journals.length !== 1 ||
      String(journals[0].currency) !== String(payout.currency) ||
      journals[0].status !== 'CREATED') {
    return { valid: false, reason: 'PAYOUT_JOURNAL_LINKAGE_INVALID' };
  }

  return { valid: true, payload: identity.payload, wallet, hold, operation, journal: journals[0] };
}

async function validatePayoutUnknownResolutionLinkage(client, payout) {
  const { rows: wallets } = await client.query(
    `SELECT id,user_id,currency,status,locked_balance
       FROM wallet_accounts WHERE id=$1 FOR UPDATE`,
    [payout.wallet_id],
  );
  const wallet = wallets[0];
  if (!wallet ||
      String(wallet.user_id) !== String(payout.user_id) ||
      String(wallet.currency) !== String(payout.currency) ||
      wallet.status !== 'ACTIVE') {
    return { valid: false, reason: 'PAYOUT_WALLET_LINKAGE_MISMATCH' };
  }
  if (!hasSufficientLockedBalance(wallet, payout)) {
    return { valid: false, reason: 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT' };
  }

  const { rows: holds } = await client.query(
    `SELECT * FROM wallet_holds
      WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'
      FOR UPDATE`,
    [payout.id],
  );
  if (holds.length === 0) return { valid: false, reason: 'PAYOUT_RESERVATION_NOT_FOUND' };
  if (holds.length !== 1) return { valid: false, reason: 'PAYOUT_HOLD_AMBIGUOUS' };
  const hold = holds[0];
  if (hold.reference_type !== 'PAYOUT' ||
      String(hold.wallet_id) !== String(payout.wallet_id) ||
      !sameIntegerAmount(hold.amount, payout.amount) ||
      !hold.financial_operation_id) {
    return { valid: false, reason: 'PAYOUT_HOLD_LINKAGE_MISMATCH' };
  }

  const { rows: operations } = await client.query(
    `SELECT id,operation_type,actor_type,actor_id,status,idempotency_key
       FROM financial_operations WHERE id=$1 FOR UPDATE`,
    [hold.financial_operation_id],
  );
  const operation = operations[0];
  if (!operation ||
      operation.operation_type !== 'PAYOUT' ||
      operation.actor_type !== 'USER' ||
      String(operation.actor_id || '') !== String(payout.user_id) ||
      operation.status !== 'UNKNOWN' ||
      String(operation.idempotency_key || '') !== String(payout.idempotency_key)) {
    return { valid: false, reason: 'PAYOUT_OPERATION_LINKAGE_MISMATCH' };
  }

  const { rows: journals } = await client.query(
    `SELECT id,operation_id,journal_type,currency,status
       FROM journals WHERE operation_id=$1 AND journal_type='PAYOUT' FOR UPDATE`,
    [hold.financial_operation_id],
  );
  if (journals.length !== 1 ||
      String(journals[0].currency) !== String(payout.currency) ||
      journals[0].status !== 'CREATED') {
    return { valid: false, reason: 'PAYOUT_JOURNAL_LINKAGE_INVALID' };
  }
  return { valid: true, wallet, hold, operation, journal: journals[0] };
}

export async function validatePayoutOutboxEvent({ eventId, payoutId, leaseToken }) {
  return withSqlTransaction(async (client) => {
    const { rows: events } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    const event = events[0];
    if (!event) return { valid: false, reason: 'OUTBOX_NOT_FOUND' };
    if (leaseToken && String(event.lease_token) !== String(leaseToken)) {
      return { valid: false, reason: 'STALE_LEASE' };
    }
    const { rows: payouts } = await client.query(`SELECT * FROM payouts WHERE id=$1 FOR UPDATE`, [payoutId]);
    const payout = payouts[0];
    if (!payout) return { valid: false, reason: 'PAYOUT_NOT_FOUND' };
    if (!['RESERVED','PROCESSING'].includes(payout.status)) {
      return { valid: false, reason: 'INVALID_PAYOUT_STATE' };
    }
    return validatePayoutSettlementLinkage(client, event, payout);
  });
}

async function blockPayoutOutboxIntegrityMismatchWithClient(client, {
  event,
  payout,
  eventId,
  payoutId,
  reason,
  providerInvoked = false,
}) {
  const identity = payout ? validatePayoutEventIdentity(event, payout) : { valid: false };
  let resourceType = 'outbox_event';
  let resourceId = event.id;

  if (payout && identity.valid && ['RESERVED','PROCESSING','UNKNOWN'].includes(payout.status)) {
    resourceType = 'payout';
    resourceId = payout.id;
    await client.query(
      `UPDATE payouts
          SET status='UNKNOWN',failure_code='PAYOUT_INTEGRITY_BLOCKED',
              failure_message=$2,updated_at=NOW(),completed_at=NULL
        WHERE id=$1 AND status IN ('RESERVED','PROCESSING','UNKNOWN')`,
      [payout.id, String(reason || 'PAYOUT_INTEGRITY_MISMATCH').slice(0, 1000)],
    );

    const { rows: holds } = await client.query(
      `SELECT * FROM wallet_holds
        WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'
        FOR UPDATE`,
      [payout.id],
    );
    if (holds.length === 1) {
      const hold = holds[0];
      if (hold.reference_type === 'PAYOUT' &&
          String(hold.wallet_id) === String(payout.wallet_id) &&
          sameIntegerAmount(hold.amount, payout.amount) &&
          String(identity.payload.operationId || '') === String(hold.financial_operation_id || '')) {
        await client.query(
          `UPDATE financial_operations SET status='UNKNOWN',completed_at=NULL
            WHERE id=$1 AND operation_type='PAYOUT' AND actor_type='USER'
              AND actor_id=$2 AND idempotency_key=$3 AND status IN ('PROCESSING','UNKNOWN')`,
          [hold.financial_operation_id, payout.user_id, payout.idempotency_key],
        );
      }
    }
    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),'PAYOUT_INTEGRITY_BLOCKED',NULL,'payout',$1,$2::jsonb,NOW())`,
      [payout.id, JSON.stringify({ eventId, reason: String(reason || 'PAYOUT_INTEGRITY_MISMATCH').slice(0, 1000), providerInvoked })],
    );
  }

  await client.query(
    `INSERT INTO reconciliation_cases(
       id,case_type,resource_type,resource_id,severity,expected,observed,status,created_at,updated_at
     ) VALUES(
       gen_random_uuid(),'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',$1,$2,'CRITICAL',
       $3::jsonb,$4::jsonb,'OPEN',NOW(),NOW()
     )
     ON CONFLICT (case_type,resource_type,resource_id)
       WHERE status IN ('OPEN','INVESTIGATING')
     DO UPDATE SET
       severity='CRITICAL',expected=EXCLUDED.expected,observed=EXCLUDED.observed,updated_at=NOW()`,
    [
      resourceType,
      resourceId,
      JSON.stringify({
        walletBalancesUnchanged: true,
        activeReservationHoldPreserved: true,
        providerInvoked: Boolean(providerInvoked),
      }),
      JSON.stringify({
        reason: String(reason || 'PAYOUT_INTEGRITY_MISMATCH').slice(0, 1000),
        eventId,
        payoutId,
      }),
    ],
  );
  await client.query(
    `UPDATE outbox_events
        SET status='DONE',processed_at=COALESCE(processed_at,NOW()),
            locked_at=NULL,lease_token=NULL,last_error=$2
      WHERE id=$1`,
    [eventId, String(reason || 'PAYOUT_INTEGRITY_MISMATCH').slice(0, 2000)],
  );
  return { blocked: true, payoutMarkedUnknown: resourceType === 'payout', resourceType, resourceId };
}

export async function blockPayoutOutboxIntegrityMismatch({ eventId, payoutId, reason, leaseToken, providerInvoked = false }) {
  return withSqlTransaction(async (client) => {
    const { rows: events } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    const event = events[0];
    if (!event) return { blocked: false, reason: 'OUTBOX_NOT_FOUND' };
    if (leaseToken && String(event.lease_token) !== String(leaseToken)) {
      return { blocked: false, reason: 'STALE_LEASE' };
    }
    const { rows: payouts } = await client.query(`SELECT * FROM payouts WHERE id=$1 FOR UPDATE`, [payoutId]);
    const payout = payouts[0];
    return blockPayoutOutboxIntegrityMismatchWithClient(client, {
      event,
      payout,
      eventId,
      payoutId,
      reason,
      providerInvoked,
    });
  });
}

export async function markPayoutUnknown({ eventId, payoutId, reason = 'PROVIDER_UNKNOWN', leaseToken }) {
  return withSqlTransaction(async (client) => {
    const { rows: events } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    const event = events[0];
    if (!event) return { marked: false, reason: 'OUTBOX_NOT_FOUND' };
    if (leaseToken && String(event.lease_token) !== String(leaseToken)) return { marked: false, reason: 'STALE_LEASE' };
    const { rows: payouts } = await client.query(`SELECT * FROM payouts WHERE id=$1 FOR UPDATE`, [payoutId]);
    const payout = payouts[0];
    if (!payout) return { marked: false, reason: 'PAYOUT_NOT_FOUND' };
    const alreadyUnknown = payout.status === 'UNKNOWN';
    if (!alreadyUnknown && !['RESERVED','PROCESSING'].includes(payout.status)) {
      return { marked: false, reason: 'INVALID_PAYOUT_STATE' };
    }

    // An ambiguous provider response must not use an event to mutate an
    // unrelated payout. First prove that the immutable Outbox identity names
    // this exact payout; only then may the payout enter UNKNOWN.
    const identity = validatePayoutEventIdentity(event, payout);
    let reconciliationReason = null;
    let operationId = null;
    let reconciliationResourceType = 'payout';
    let reconciliationResourceId = payoutId;

    if (!identity.valid) {
      reconciliationReason = identity.reason;
      reconciliationResourceType = 'outbox_event';
      reconciliationResourceId = event.id;
    } else {
      const linkage = alreadyUnknown
        ? await validatePayoutUnknownResolutionLinkage(client, payout)
        : await validatePayoutSettlementLinkage(client, event, payout);
      reconciliationReason = linkage.valid ? null : linkage.reason;
      operationId = linkage.valid ? linkage.hold.financial_operation_id : null;

      if (linkage.valid && !alreadyUnknown) {
        const { rows: operations } = await client.query(
          `UPDATE financial_operations
              SET status='UNKNOWN',completed_at=NULL
            WHERE id=$1 AND operation_type='PAYOUT' AND actor_type='USER'
              AND actor_id=$2 AND idempotency_key=$3 AND status='PROCESSING'
            RETURNING id`,
          [operationId, payout.user_id, payout.idempotency_key],
        );
        if (!operations[0]) reconciliationReason = 'FINANCIAL_OPERATION_NOT_PROCESSING';
      }

      if (!alreadyUnknown) {
        await client.query(
          `UPDATE payouts
              SET status='UNKNOWN',failure_code='PROVIDER_UNKNOWN',failure_message=$2,updated_at=NOW()
            WHERE id=$1`,
          [payoutId, String(reason).slice(0, 1000)],
        );
        await client.query(
          `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
           VALUES(gen_random_uuid(),'PAYOUT_UNKNOWN',NULL,'payout',$1,$2::jsonb,NOW())`,
          [payoutId, JSON.stringify({ eventId, reason, reconciliationReason })],
        );
      }
    }

    // Never release an active reservation for an ambiguous provider outcome.
    // A misidentified event is reconciled against the event itself; a correctly
    // identified payout with broken Hold/operation linkage remains UNKNOWN for
    // explicit manual repair.
    if (reconciliationReason) {
      await client.query(
        `INSERT INTO reconciliation_cases(
           id,case_type,resource_type,resource_id,severity,expected,observed,status,created_at,updated_at
         ) VALUES(
           gen_random_uuid(),'PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY',$1,$2,'CRITICAL',
           $3::jsonb,$4::jsonb,'OPEN',NOW(),NOW()
         )
         ON CONFLICT (case_type,resource_type,resource_id)
           WHERE status IN ('OPEN','INVESTIGATING')
         DO UPDATE SET
           severity='CRITICAL',expected=EXCLUDED.expected,observed=EXCLUDED.observed,updated_at=NOW()`,
        [
          reconciliationResourceType,
          reconciliationResourceId,
          JSON.stringify({
            payoutStatus: identity.valid ? 'UNKNOWN' : 'UNCHANGED',
            walletBalancesUnchanged: true,
            activeReservationHold: true,
            financialOperationMutation: 'UNKNOWN only when canonical linkage is verified',
          }),
          JSON.stringify({
            reason: reconciliationReason,
            payoutId,
            eventId,
            eventAggregateId: event.aggregate_id || null,
            eventPayoutId: payoutEventPayload(event)?.payoutId || null,
            eventOperationId: payoutEventPayload(event)?.operationId || null,
            holdOperationId: operationId,
          }),
        ],
      );
      if (!identity.valid) {
        await client.query(
          `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
           VALUES(gen_random_uuid(),'PAYOUT_UNKNOWN_IDENTITY_MISMATCH',NULL,'outbox_event',$1,$2::jsonb,NOW())`,
          [event.id, JSON.stringify({ payoutId, reason: reconciliationReason })],
        );
      }
    }

    await client.query(
      `UPDATE outbox_events
          SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,lease_token=NULL,last_error=$2
        WHERE id=$1`,
      [eventId, reconciliationReason],
    );
    return {
      marked: true,
      alreadyUnknown,
      requiresReconciliation: Boolean(reconciliationReason),
      reconciliationReason,
    };
  });
}

export async function resolvePayoutUnknown({ payoutId, decision, providerRef = null, source, adminId = null, adminSessionJti = null, verificationMinutes = 5, reason = null }) {
  const normalized = String(decision || '').toUpperCase();
  const resolutionSource = String(source || '').trim().toUpperCase();
  if (!['SUCCEEDED','FAILED'].includes(normalized)) throw Object.assign(new Error('INVALID_UNKNOWN_RESOLUTION'), { code: 'INVALID_UNKNOWN_RESOLUTION' });
  if (normalized === 'SUCCEEDED' && !String(providerRef || '').trim()) throw Object.assign(new Error('PROVIDER_REF_REQUIRED'), { code: 'PROVIDER_REF_REQUIRED' });
  if (!['ADMIN','PROVIDER_RECONCILIATION'].includes(resolutionSource)) throw Object.assign(new Error('UNKNOWN_RESOLUTION_SOURCE_REQUIRED'), { code:'UNKNOWN_RESOLUTION_SOURCE_REQUIRED',status:403 });
  if (resolutionSource === 'ADMIN' && !adminId) throw Object.assign(new Error('ADMIN_ACTOR_REQUIRED'), { code:'ADMIN_ACTOR_REQUIRED',status:401 });
  if (resolutionSource === 'PROVIDER_RECONCILIATION' && adminId) throw Object.assign(new Error('INVALID_PROVIDER_RECONCILIATION_ACTOR'), { code:'INVALID_PROVIDER_RECONCILIATION_ACTOR',status:403 });
  return withSqlTransaction(async (client) => {
    if (resolutionSource === 'ADMIN') {
      await lockAuthorizedAdminActor(client,{actorId:adminId,sessionJti:adminSessionJti,verificationMinutes,requiredScope:'WRITE'});
    }
    const { rows: payouts } = await client.query(`SELECT p.* FROM payouts p WHERE p.id=$1 FOR UPDATE`, [payoutId]);
    const payout = payouts[0];
    if (!payout) return null;
    if (payout.status !== 'UNKNOWN') throw Object.assign(new Error('PAYOUT_NOT_UNKNOWN'), { code: 'PAYOUT_NOT_UNKNOWN' });
    const linkage = await validatePayoutUnknownResolutionLinkage(client, payout);
    if (!linkage.valid) {
      throw Object.assign(new Error(linkage.reason), { code: linkage.reason });
    }
    const { hold, wallet } = linkage;
    if (normalized === 'SUCCEEDED') {
      if (BigInt(String(wallet.locked_balance)) < BigInt(String(payout.amount))) throw Object.assign(new Error('INSUFFICIENT_LOCKED_FUNDS'), { code: 'INSUFFICIENT_LOCKED_FUNDS' });
      await client.query(`UPDATE wallet_accounts SET locked_balance=locked_balance-$2,updated_at=NOW() WHERE id=$1`, [wallet.id, payout.amount]);
      await client.query(`UPDATE wallet_holds SET status='RELEASED',released_at=NOW() WHERE id=$1`, [hold.id]);
      await client.query(`UPDATE payouts SET status='SUCCEEDED',provider_ref=$2,updated_at=NOW(),completed_at=NOW() WHERE id=$1`, [payoutId, String(providerRef).trim()]);
      await client.query(`UPDATE financial_operations SET status='SUCCEEDED',completed_at=NOW() WHERE id=$1`, [hold.financial_operation_id]);
      await client.query(`INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at) SELECT gen_random_uuid(),j.id,'PAYOUT',$1,'WORKER_PAYABLE',$2,0,'TOMAN',NOW() FROM journals j WHERE j.operation_id=$3 AND j.journal_type='PAYOUT'`, [payoutId,payout.amount,hold.financial_operation_id]);
      await client.query(`INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at) SELECT gen_random_uuid(),j.id,'PAYOUT',$1,'PROVIDER_CLEARING',0,$2,'TOMAN',NOW() FROM journals j WHERE j.operation_id=$3 AND j.journal_type='PAYOUT'`, [payoutId,payout.amount,hold.financial_operation_id]);
      await client.query(`UPDATE journals SET status='POSTED',posted_at=NOW() WHERE operation_id=$1 AND journal_type='PAYOUT' AND status='CREATED'`, [hold.financial_operation_id]);
    } else {
      if (BigInt(String(wallet.locked_balance)) < BigInt(String(payout.amount))) throw Object.assign(new Error('INSUFFICIENT_LOCKED_FUNDS'), { code: 'INSUFFICIENT_LOCKED_FUNDS' });
      const { rows: restoredWallets } = await client.query(
        `UPDATE wallet_accounts
            SET available_balance=available_balance+$2,locked_balance=locked_balance-$2,updated_at=NOW()
          WHERE id=$1 RETURNING available_balance`,
        [wallet.id,payout.amount],
      );
      await appendPayoutReversalEntry(client, {
        walletId: wallet.id,
        payoutId,
        amount: payout.amount,
        operationId: hold.financial_operation_id,
        balanceAfter: restoredWallets[0].available_balance,
        failureCode: 'UNKNOWN_RESOLVED_FAILED',
      });
      await client.query(`UPDATE wallet_holds SET status='CANCELLED',released_at=NOW() WHERE id=$1`, [hold.id]);
      await client.query(`UPDATE payouts SET status='FAILED',failure_code='UNKNOWN_RESOLVED_FAILED',failure_message=$2,updated_at=NOW(),completed_at=NOW() WHERE id=$1`, [payoutId, reason ? String(reason).slice(0,1000) : 'Unknown payout resolved as failed']);
      await client.query(`UPDATE financial_operations SET status='FAILED',completed_at=NOW() WHERE id=$1`, [hold.financial_operation_id]);
      await client.query(`UPDATE journals SET status='FAILED' WHERE operation_id=$1 AND journal_type='PAYOUT' AND status='CREATED'`, [hold.financial_operation_id]);
    }
    // Resolve all active reconciliation cases in the same transaction as the
    // terminal payout decision. This keeps the admin queue consistent with the
    // wallet/ledger transition and also covers automatic provider reconciliation.
    const resolutionActor = adminId ? `admin:${String(adminId)}` : 'provider-reconciliation';
    const resolutionEvidence = providerRef
      ? `providerRef:${String(providerRef)}`
      : `reason:${String(reason || 'terminal-provider-confirmation')}`;
    const resolutionReference = `${resolutionActor}:${normalized}:${resolutionEvidence}`.slice(0, 200);
    const { rows: resolvedCases } = await client.query(
      `UPDATE reconciliation_cases
          SET status='RESOLVED',resolution_reference=$2,resolved_at=NOW(),updated_at=NOW()
        WHERE resource_type='payout'
          AND resource_id=$1
          AND status IN ('OPEN','INVESTIGATING')
        RETURNING id`,
      [payoutId, resolutionReference],
    );

    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES(gen_random_uuid(),'PAYOUT_UNKNOWN_RESOLVED',$1,'payout',$2,$3::jsonb,NOW())`, [adminId, payoutId, JSON.stringify({ decision: normalized, providerRef, reason, reconciliationCasesResolved: resolvedCases.length })]);
    return { payoutId, status: normalized, reconciliationCasesResolved: resolvedCases.length };
  });
}

export async function completePayoutOutbox({ eventId, payoutId, providerRef, leaseToken }) {
  return withSqlTransaction(async (client) => {
    const { rows: ev } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    if (!ev[0]) return {completed:false,reason:'OUTBOX_NOT_FOUND'};
    if (leaseToken && String(ev[0].lease_token)!==String(leaseToken)) return {completed:false,reason:'STALE_LEASE'};
    const { rows: pr } = await client.query(`SELECT p.*,w.id AS wallet_id FROM payouts p JOIN wallet_accounts w ON w.id=p.wallet_id WHERE p.id=$1 FOR UPDATE`, [payoutId]);
    const payout = pr[0];
    if (!payout) return {completed:false,reason:'PAYOUT_NOT_FOUND'};
    if (payout.status==='SUCCEEDED') {
      const identity = validatePayoutEventIdentity(ev[0], payout);
      if (!identity.valid) return {completed:false,reason:identity.reason};
      await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL WHERE id=$1`,[eventId]);
      return {completed:true,alreadyDone:true};
    }
    if (payout.status!=='RESERVED' && payout.status!=='PROCESSING') return {completed:false,reason:'INVALID_PAYOUT_STATE'};

    const linkage = await validatePayoutSettlementLinkage(client, ev[0], payout);
    if (!linkage.valid) {
      if (linkage.reason === 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT') {
        await blockPayoutOutboxIntegrityMismatchWithClient(client, {
          event: ev[0],
          payout,
          eventId,
          payoutId,
          reason: linkage.reason,
          providerInvoked: true,
        });
        return { completed:false, integrityBlocked:true, reason:linkage.reason };
      }
      return {completed:false,reason:linkage.reason};
    }
    const { hold, wallet } = linkage;
    if (BigInt(String(wallet.locked_balance)) < BigInt(String(payout.amount))) throw Object.assign(new Error('INSUFFICIENT_LOCKED_FUNDS'), {code:'INSUFFICIENT_LOCKED_FUNDS'});

    await client.query(`UPDATE wallet_accounts SET locked_balance=locked_balance-$2,updated_at=NOW() WHERE id=$1`, [wallet.id,payout.amount]);
    await client.query(`UPDATE wallet_holds SET status='RELEASED',released_at=NOW() WHERE id=$1`, [hold.id]);
    await client.query(`UPDATE payouts SET status='SUCCEEDED',provider_ref=$2,updated_at=NOW(),completed_at=NOW() WHERE id=$1`, [payoutId,providerRef]);
    await client.query(`INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at) VALUES($1,(SELECT id FROM journals WHERE operation_id=$2 AND journal_type='PAYOUT'), 'PAYOUT',$3,'WORKER_PAYABLE',$4,0,'TOMAN',NOW())`, [crypto.randomUUID(),hold.financial_operation_id,payoutId,payout.amount]);
    await client.query(`INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at) VALUES($1,(SELECT id FROM journals WHERE operation_id=$2 AND journal_type='PAYOUT'), 'PAYOUT',$3,'PROVIDER_CLEARING',0,$4,'TOMAN',NOW())`, [crypto.randomUUID(),hold.financial_operation_id,payoutId,payout.amount]);
    await client.query(`UPDATE journals j SET status='POSTED',posted_at=NOW() WHERE j.operation_id=(SELECT id FROM financial_operations WHERE id=$1 LIMIT 1) AND j.journal_type='PAYOUT' AND j.status='CREATED'`, [hold.financial_operation_id]);
    await client.query(`UPDATE financial_operations SET status='SUCCEEDED',completed_at=COALESCE(completed_at,NOW()) WHERE id=$1`, [hold.financial_operation_id]);
    await client.query(`UPDATE outbox_events SET status='DONE',processed_at=NOW(),locked_at=NULL,last_error=NULL WHERE id=$1`,[eventId]);
    return {completed:true,alreadyDone:false};
  });
}

export async function failPayoutOutboxWithClient(client, { eventId, payoutId, error, leaseToken, failureCode = 'PROVIDER_ERROR', providerInvoked = true }) {
    const { rows: ev } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    if (!ev[0]) return {completed:false,reason:'OUTBOX_NOT_FOUND'};
    if (leaseToken && String(ev[0].lease_token)!==String(leaseToken)) return {completed:false,reason:'STALE_LEASE'};
    const { rows: pr } = await client.query(`SELECT p.*,w.id AS wallet_id FROM payouts p JOIN wallet_accounts w ON w.id=p.wallet_id WHERE p.id=$1 FOR UPDATE`, [payoutId]);
    const payout = pr[0];
    if (!payout) return {completed:false,reason:'PAYOUT_NOT_FOUND'};
    if (payout.status==='FAILED') {
      const identity = validatePayoutEventIdentity(ev[0], payout);
      if (!identity.valid) return {completed:false,reason:identity.reason};
      await client.query(`UPDATE outbox_events SET status='FAILED',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=$2 WHERE id=$1`,[eventId,String(error).slice(0,2000)]);
      return {completed:true,alreadyFailed:true};
    }
    if (!['RESERVED','PROCESSING'].includes(payout.status)) return {completed:false,reason:'INVALID_PAYOUT_STATE'};
    const linkage = await validatePayoutSettlementLinkage(client, ev[0], payout);
    if (!linkage.valid) {
      if (linkage.reason === 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT') {
        await blockPayoutOutboxIntegrityMismatchWithClient(client, {
          event: ev[0],
          payout,
          eventId,
          payoutId,
          reason: linkage.reason,
          providerInvoked,
        });
        return { completed:false, integrityBlocked:true, reason:linkage.reason };
      }
      return {completed:false,reason:linkage.reason};
    }
    const { hold, wallet } = linkage;
    if (BigInt(String(wallet.locked_balance)) < BigInt(String(payout.amount))) {
      return {completed:false,reason:'INSUFFICIENT_LOCKED_FUNDS'};
    }
    const { rows: restoredWallets } = await client.query(
      `UPDATE wallet_accounts
          SET available_balance=available_balance+$2,locked_balance=locked_balance-$2,updated_at=NOW()
        WHERE id=$1 RETURNING available_balance`,
      [wallet.id,payout.amount],
    );
    await appendPayoutReversalEntry(client, {
      walletId: wallet.id,
      payoutId,
      amount: payout.amount,
      operationId: hold.financial_operation_id,
      balanceAfter: restoredWallets[0].available_balance,
      failureCode,
    });
    await client.query(`UPDATE wallet_holds SET status='CANCELLED',released_at=NOW() WHERE id=$1`, [hold.id]);
    await client.query(`UPDATE payouts SET status='FAILED',failure_code=$3,failure_message=$2,updated_at=NOW(),completed_at=NOW() WHERE id=$1`, [payoutId,String(error).slice(0,1000),String(failureCode || 'PROVIDER_ERROR')]);
    await client.query(`UPDATE financial_operations SET status='FAILED',completed_at=NOW() WHERE id=$1`, [hold.financial_operation_id]);
    await client.query(`UPDATE journals SET status='FAILED' WHERE operation_id=$1 AND journal_type='PAYOUT' AND status='CREATED'`, [hold.financial_operation_id]);
    await client.query(`UPDATE outbox_events SET status='FAILED',processed_at=NOW(),locked_at=NULL,last_error=$2 WHERE id=$1`,[eventId,String(error).slice(0,2000)]);
  return {completed:true,alreadyFailed:false};
}

export async function failPayoutOutbox({ eventId, payoutId, error, leaseToken, failureCode = 'PROVIDER_ERROR', providerInvoked = true }) {
  return withSqlTransaction((client) => failPayoutOutboxWithClient(client, { eventId, payoutId, error, leaseToken, failureCode, providerInvoked }));
}

export async function getPayoutForUser(userId,payoutId) {
  const {rows}=await requirePool().query(`SELECT * FROM payouts WHERE id=$1 AND user_id=$2`,[payoutId,userId]);
  return rows[0]||null;
}


export async function listPayoutsForUser(userId, { limit = 50 } = {}) {
  const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const { rows } = await requirePool().query(`
    SELECT id,
           wallet_id AS "walletId",
           user_id AS "userId",
           amount,
           currency,
           provider,
           status,
           provider_ref AS "providerRef",
           idempotency_key AS "idempotencyKey",
           failure_code AS "failureCode",
           failure_message AS "failureMessage",
           created_at AS "createdAt",
           updated_at AS "updatedAt",
           completed_at AS "completedAt"
      FROM payouts
     WHERE user_id=$1
     ORDER BY created_at DESC,id DESC
     LIMIT $2`, [userId, safeLimit]);
  return rows;
}


export async function listUnknownPayouts({ limit = 50 } = {}) {
  const safeLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const { rows } = await requirePool().query(`
    SELECT p.id,
           p.wallet_id AS "walletId",
           p.user_id AS "userId",
           p.amount,
           p.currency,
           p.provider,
           p.status,
           p.provider_ref AS "providerRef",
           p.failure_code AS "failureCode",
           p.failure_message AS "failureMessage",
           p.created_at AS "createdAt",
           p.updated_at AS "updatedAt",
           COALESCE((
             SELECT jsonb_agg(
               jsonb_build_object(
                 'id',rc.id,
                 'caseType',rc.case_type,
                 'severity',rc.severity,
                 'status',rc.status,
                 'expected',rc.expected,
                 'observed',rc.observed,
                 'createdAt',rc.created_at,
                 'updatedAt',rc.updated_at
               )
               ORDER BY rc.created_at DESC,rc.id DESC
             )
               FROM reconciliation_cases rc
              WHERE rc.resource_type='payout'
                AND rc.resource_id=p.id
                AND rc.status IN ('OPEN','INVESTIGATING')
           ),'[]'::jsonb) AS "reconciliationCases"
      FROM payouts p
     WHERE p.status='UNKNOWN'
     ORDER BY p.updated_at ASC,p.id ASC
     LIMIT $1`, [safeLimit]);
  return rows;
}
