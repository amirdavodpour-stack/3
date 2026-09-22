import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { config } from '../config.js';

const MAX_AMOUNT = 9_000_000_000_000_000n;

const INTERNAL_CURRENCY = 'TOMAN';
const PAYOUT_PROVIDER = 'internal';

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
  if (config.paymentProvider !== 'internal') throw Object.assign(new Error('PAYOUT_PROVIDER_NOT_ENABLED'), { code:'PAYOUT_PROVIDER_NOT_ENABLED' });

  return withSqlTransaction(async (client) => {
    const existing = await client.query(`SELECT * FROM payouts WHERE user_id=$1 AND idempotency_key=$2 FOR UPDATE`, [userId, key]);
    if (existing.rows[0]) {
      const p = existing.rows[0];
      if (BigInt(String(p.amount)) !== value) throw Object.assign(new Error('IDEMPOTENCY_CONFLICT'), { code:'IDEMPOTENCY_CONFLICT' });
      return p;
    }

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
    await client.query(`INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at) VALUES(gen_random_uuid(),'PAYOUT_EXECUTE','payout',$1,$2,$3::jsonb,'PENDING',0,NOW(),NOW())`, [payoutId,`PAYOUT_EXECUTE:${payoutId}`,JSON.stringify({payoutId,userId,amount:value,currency:INTERNAL_CURRENCY,idempotencyKey:key,operationId})]);
    const { rows } = await client.query(`SELECT * FROM payouts WHERE id=$1`, [payoutId]);
    return rows[0];
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
    if (payout.status === 'UNKNOWN') {
      await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL WHERE id=$1`, [eventId]);
      return { marked: true, alreadyUnknown: true };
    }
    if (!['RESERVED','PROCESSING'].includes(payout.status)) return { marked: false, reason: 'INVALID_PAYOUT_STATE' };
    await client.query(`UPDATE payouts SET status='UNKNOWN',failure_code='PROVIDER_UNKNOWN',failure_message=$2,updated_at=NOW() WHERE id=$1`, [payoutId, String(reason).slice(0, 1000)]);
    await client.query(`UPDATE financial_operations SET status='UNKNOWN',completed_at=NULL WHERE id=$1`, [payout.financial_operation_id]);
    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES(gen_random_uuid(),'PAYOUT_UNKNOWN',NULL,'payout',$1,$2::jsonb,NOW())`, [payoutId, JSON.stringify({ eventId, reason })]);
    await client.query(`UPDATE outbox_events SET status='DONE',processed_at=NOW(),locked_at=NULL,last_error=NULL WHERE id=$1`, [eventId]);
    return { marked: true, alreadyUnknown: false };
  });
}

export async function resolvePayoutUnknown({ payoutId, decision, providerRef = null, adminId = null, reason = null }) {
  const normalized = String(decision || '').toUpperCase();
  if (!['SUCCEEDED','FAILED'].includes(normalized)) throw Object.assign(new Error('INVALID_UNKNOWN_RESOLUTION'), { code: 'INVALID_UNKNOWN_RESOLUTION' });
  if (normalized === 'SUCCEEDED' && !String(providerRef || '').trim()) throw Object.assign(new Error('PROVIDER_REF_REQUIRED'), { code: 'PROVIDER_REF_REQUIRED' });
  return withSqlTransaction(async (client) => {
    const { rows: payouts } = await client.query(`SELECT p.* FROM payouts p WHERE p.id=$1 FOR UPDATE`, [payoutId]);
    const payout = payouts[0];
    if (!payout) return null;
    if (payout.status !== 'UNKNOWN') throw Object.assign(new Error('PAYOUT_NOT_UNKNOWN'), { code: 'PAYOUT_NOT_UNKNOWN' });
    const { rows: holds } = await client.query(`SELECT * FROM wallet_holds WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE' FOR UPDATE`, [payoutId]);
    const hold = holds[0];
    const { rows: wallets } = await client.query(`SELECT * FROM wallet_accounts WHERE id=$1 FOR UPDATE`, [payout.wallet_id]);
    const wallet = wallets[0];
    if (!hold || !wallet) throw Object.assign(new Error('PAYOUT_RESERVATION_NOT_FOUND'), { code: 'PAYOUT_RESERVATION_NOT_FOUND' });
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
      await client.query(`UPDATE wallet_accounts SET available_balance=available_balance+$2,locked_balance=locked_balance-$2,updated_at=NOW() WHERE id=$1`, [wallet.id,payout.amount]);
      await client.query(`UPDATE wallet_holds SET status='CANCELLED',released_at=NOW() WHERE id=$1`, [hold.id]);
      await client.query(`UPDATE payouts SET status='FAILED',failure_code='UNKNOWN_RESOLVED_FAILED',failure_message=$2,updated_at=NOW(),completed_at=NOW() WHERE id=$1`, [payoutId, reason ? String(reason).slice(0,1000) : 'Unknown payout resolved as failed']);
      await client.query(`UPDATE financial_operations SET status='FAILED',completed_at=NOW() WHERE id=$1`, [hold.financial_operation_id]);
      await client.query(`UPDATE journals SET status='FAILED' WHERE operation_id=$1 AND journal_type='PAYOUT' AND status='CREATED'`, [hold.financial_operation_id]);
    }
    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES(gen_random_uuid(),'PAYOUT_UNKNOWN_RESOLVED',$1,'payout',$2,$3::jsonb,NOW())`, [adminId, payoutId, JSON.stringify({ decision: normalized, providerRef, reason })]);
    return { payoutId, status: normalized };
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
    if (payout.status==='SUCCEEDED') { await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL WHERE id=$1`,[eventId]); return {completed:true,alreadyDone:true}; }
    if (payout.status!=='RESERVED' && payout.status!=='PROCESSING') return {completed:false,reason:'INVALID_PAYOUT_STATE'};

    const { rows: holdRows } = await client.query(`SELECT * FROM wallet_holds WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE' FOR UPDATE`, [payout.id]);
    const hold = holdRows[0];
    if (!hold) return {completed:false,reason:'PAYOUT_HOLD_NOT_FOUND'};
    const { rows: walletRows } = await client.query(`SELECT * FROM wallet_accounts WHERE id=$1 FOR UPDATE`, [payout.wallet_id]);
    const wallet = walletRows[0];
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

export async function failPayoutOutboxWithClient(client, { eventId, payoutId, error, leaseToken }) {
    const { rows: ev } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    if (!ev[0]) return {completed:false,reason:'OUTBOX_NOT_FOUND'};
    if (leaseToken && String(ev[0].lease_token)!==String(leaseToken)) return {completed:false,reason:'STALE_LEASE'};
    const { rows: pr } = await client.query(`SELECT p.*,w.id AS wallet_id FROM payouts p JOIN wallet_accounts w ON w.id=p.wallet_id WHERE p.id=$1 FOR UPDATE`, [payoutId]);
    const payout = pr[0];
    if (!payout) return {completed:false,reason:'PAYOUT_NOT_FOUND'};
    if (payout.status==='FAILED') {
      await client.query(`UPDATE outbox_events SET status='FAILED',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=$2 WHERE id=$1`,[eventId,String(error).slice(0,2000)]);
      return {completed:true,alreadyFailed:true};
    }
    if (!['RESERVED','PROCESSING'].includes(payout.status)) return {completed:false,reason:'INVALID_PAYOUT_STATE'};
    const { rows: holds } = await client.query(`SELECT * FROM wallet_holds WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE' FOR UPDATE`, [payout.id]);
    const hold = holds[0];
    const { rows: walletRows } = await client.query(`SELECT * FROM wallet_accounts WHERE id=$1 FOR UPDATE`, [payout.wallet_id]);
    const wallet = walletRows[0];
    if (!hold || !wallet) return {completed:false,reason:'PAYOUT_RESERVATION_NOT_FOUND'};
    await client.query(`UPDATE wallet_accounts SET available_balance=available_balance+$2,locked_balance=locked_balance-$2,updated_at=NOW() WHERE id=$1`, [wallet.id,payout.amount]);
    await client.query(`UPDATE wallet_holds SET status='CANCELLED',released_at=NOW() WHERE id=$1`, [hold.id]);
    await client.query(`UPDATE payouts SET status='FAILED',failure_code='PROVIDER_ERROR',failure_message=$2,updated_at=NOW(),completed_at=NOW() WHERE id=$1`, [payoutId,String(error).slice(0,1000)]);
    await client.query(`UPDATE financial_operations SET status='FAILED',completed_at=NOW() WHERE id=$1`, [hold.financial_operation_id]);
    await client.query(`UPDATE journals SET status='FAILED' WHERE operation_id=$1 AND journal_type='PAYOUT' AND status='CREATED'`, [hold.financial_operation_id]);
    await client.query(`UPDATE outbox_events SET status='FAILED',processed_at=NOW(),locked_at=NULL,last_error=$2 WHERE id=$1`,[eventId,String(error).slice(0,2000)]);
  return {completed:true,alreadyFailed:false};
}

export async function failPayoutOutbox({ eventId, payoutId, error, leaseToken }) {
  return withSqlTransaction((client) => failPayoutOutboxWithClient(client, { eventId, payoutId, error, leaseToken }));
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
    SELECT id,
           wallet_id AS "walletId",
           user_id AS "userId",
           amount,
           currency,
           provider,
           status,
           provider_ref AS "providerRef",
           failure_code AS "failureCode",
           failure_message AS "failureMessage",
           created_at AS "createdAt",
           updated_at AS "updatedAt"
      FROM payouts
     WHERE status='UNKNOWN'
     ORDER BY updated_at ASC,id ASC
     LIMIT $1`, [safeLimit]);
  return rows;
}
