import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { releaseJournal, payoutJournal } from '../financial.js';
import { config } from '../config.js';
import { postInternalPaymentHoldWithClient, postInternalPaymentReleaseWithClient } from '../wallet_ledger.js';
import { failPayoutOutboxWithClient } from './payouts.js';
function financialNumber(currency, value) {
  return String(currency || config.paymentCurrency).toUpperCase() === 'TOMAN' ? String(value ?? '0') : Number(value ?? 0);
}

export async function completePaymentCreateHoldOutbox({ eventId, jobId, paymentId, providerRef, actorId, leaseToken }) {
  return withSqlTransaction(async (client) => {
    const { rows: er } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    if (!er[0]) return { completed:false, reason:'OUTBOX_NOT_FOUND' };
    if (leaseToken && String(er[0].lease_token) !== String(leaseToken)) return { completed:false, reason:'STALE_LEASE' };
    const { rows: pr } = await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`, [paymentId, jobId]);
    const payment = pr[0];
    if (!payment) return { completed:false, reason:'PAYMENT_NOT_FOUND' };
    if (payment.status === 'HELD') {
      if (payment.provider_ref !== providerRef) {
        const e = new Error('PROVIDER_REF_MISMATCH'); e.code = 'PROVIDER_REF_MISMATCH'; throw e;
      }
      await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL WHERE id=$1`, [eventId]);
      return { completed:true, alreadyDone:true };
    }
    if (payment.status !== 'HOLD_PENDING') return { completed:false, reason:'INVALID_PAYMENT_STATE' };
    if (config.paymentProvider === 'internal') {
      const employerCharge = financialNumber(payment.currency, payment.employer_charge || payment.amount);
      const providerPayout = financialNumber(payment.currency, payment.provider_payout || payment.amount);
      const platformFee = financialNumber(payment.currency, payment.platform_fee || 0);
      const currency = payment.currency || config.paymentCurrency;
      if (currency !== 'TOMAN') {
        const e = new Error('INTERNAL_CURRENCY_MISMATCH'); e.code = 'INTERNAL_CURRENCY_MISMATCH'; throw e;
      }
      // The Financial Core operation owns the canonical wallet entries and
      // accounting journal. Do not append a second legacy ledger journal here.
      await postInternalPaymentHoldWithClient(client, {
        paymentId, payerId: payment.payer_id, employerCharge, providerPayout, platformFee, currency,
        idempotencyKey: `internal:hold:${paymentId}`,
      });
    }
    await client.query(`UPDATE payments SET status='HELD',provider_ref=$2,updated_at=NOW() WHERE id=$1`, [paymentId, providerRef]);
    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES($1,'PAYMENT_HOLD_CONFIRMED',$2,'payment',$3,$4::jsonb,NOW())`, [crypto.randomUUID(), actorId, paymentId, JSON.stringify({ jobId, outboxEventId:eventId, providerRef })]);
    await client.query(`UPDATE outbox_events SET status='DONE',processed_at=NOW(),locked_at=NULL,last_error=NULL WHERE id=$1`, [eventId]);
    return { completed:true, alreadyDone:false };
  });
}

export async function enqueuePaymentRelease({ jobId, ownerId, paymentId, dedupeKey }) {
  return withSqlTransaction(async (client) => {
    const { rows: jr } = await client.query(`SELECT * FROM jobs WHERE id=$1 FOR UPDATE`, [jobId]);
    const job = jr[0];
    if (!job) return null;
    if (job.owner_id !== ownerId) { const e=new Error('FORBIDDEN'); e.code='FORBIDDEN'; throw e; }
    if (job.status !== 'COMPLETED') { const e=new Error('INVALID_STATE'); e.code='INVALID_STATE'; throw e; }
    const { rows: pr } = await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`, [paymentId, jobId]);
    const payment = pr[0];
    if (!payment || !['RELEASE_PENDING','RELEASE_FAILED'].includes(payment.status)) { const e=new Error('INVALID_PAYMENT_STATE'); e.code='INVALID_PAYMENT_STATE'; throw e; }
    if (payment.status === 'RELEASE_FAILED') {
      await client.query(`UPDATE payments SET status='RELEASE_PENDING',updated_at=NOW() WHERE id=$1`, [paymentId]);
    }
    const { rows } = await client.query(
      `INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at)
       VALUES(gen_random_uuid(),'PAYMENT_RELEASE','payment',$1,$2,$3::jsonb,'PENDING',0,NOW(),NOW())
       ON CONFLICT(dedupe_key) DO UPDATE SET
         status=CASE WHEN outbox_events.status='DONE' THEN outbox_events.status ELSE 'PENDING' END,
         attempts=CASE WHEN outbox_events.status='DONE' THEN outbox_events.attempts ELSE 0 END,
         available_at=CASE WHEN outbox_events.status='DONE' THEN outbox_events.available_at ELSE NOW() END,
         locked_at=CASE WHEN outbox_events.status='DONE' THEN outbox_events.locked_at ELSE NULL END,
         last_error=CASE WHEN outbox_events.status='DONE' THEN outbox_events.last_error ELSE NULL END,
         processed_at=CASE WHEN outbox_events.status='DONE' THEN outbox_events.processed_at ELSE NULL END
       RETURNING *`,
      [paymentId, dedupeKey, JSON.stringify({ jobId, ownerId, paymentId, providerRef: payment.provider_ref, idempotencyKey: payment.idempotency_key || `payment-release:${paymentId}` })]
    );
    return { id: rows[0].id, status: rows[0].status, paymentId, jobId };
  });
}

export async function getOutboxEvent(id) {
  const { rows } = await requirePool().query(`SELECT * FROM outbox_events WHERE id=$1`, [id]);
  return rows[0] ? rows[0] : null;
}

export async function claimOutboxEvent(leaseSeconds = 60) {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(
      `WITH candidate AS (
         SELECT id FROM outbox_events
         WHERE status IN ('PENDING','PROCESSING')
           AND (status='PENDING' OR locked_at < NOW() - make_interval(secs => $1))
           AND available_at <= NOW()
         ORDER BY CASE
                    WHEN event_type IN ('PAYMENT_CREATE_HOLD','PAYMENT_RELEASE','PAYMENT_REFUND','PAYOUT_EXECUTE') THEN 0
                    ELSE 1
                  END,
                  created_at,
                  id
         FOR UPDATE SKIP LOCKED
         LIMIT 1
       )
       UPDATE outbox_events o
       SET status='PROCESSING', attempts=o.attempts+1, locked_at=NOW(), lease_token=gen_random_uuid()
       FROM candidate c
       WHERE o.id=c.id
       RETURNING o.*`, [leaseSeconds]);
    return rows[0] || null;
  });
}

export async function completePaymentReleaseOutbox({ eventId, jobId, paymentId, actorId, leaseToken }) {
  return withSqlTransaction(async (client) => {
    const { rows: er } = await client.query(`SELECT * FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    if (!er[0]) return { completed:false, reason:'OUTBOX_NOT_FOUND' };
    if (leaseToken && String(er[0].lease_token) !== String(leaseToken)) return { completed:false, reason:'STALE_LEASE' };
    const { rows: pr } = await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`, [paymentId, jobId]);
    const payment = pr[0];
    if (!payment) return { completed:false, reason:'PAYMENT_NOT_FOUND' };
    if (payment.status === 'RELEASED') {
      await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL WHERE id=$1`, [eventId]);
      return { completed:true, alreadyDone:true };
    }
    if (payment.status !== 'RELEASE_PENDING') return { completed:false, reason:'INVALID_PAYMENT_STATE' };
    const breakdown = { baseAmount:financialNumber(payment.currency,payment.base_amount || payment.amount), employerFee:financialNumber(payment.currency,payment.employer_fee || 0), workerFee:financialNumber(payment.currency,payment.worker_fee || 0), platformFee:financialNumber(payment.currency,payment.platform_fee || 0), employerCharge:financialNumber(payment.currency,payment.employer_charge || payment.amount), providerPayout:financialNumber(payment.currency,payment.provider_payout || payment.amount), currency:payment.currency || config.paymentCurrency, policyVersion:payment.fee_policy_version || 'legacy', kind:'JOB' };
    await client.query(`UPDATE payments SET status='RELEASED',updated_at=NOW() WHERE id=$1`, [paymentId]);
    await client.query(`UPDATE jobs SET status='SETTLED',updated_at=NOW() WHERE id=$1`, [jobId]);
    if (config.paymentProvider === 'internal') {
      if (breakdown.currency !== 'TOMAN') {
        const e = new Error('INTERNAL_CURRENCY_MISMATCH'); e.code = 'INTERNAL_CURRENCY_MISMATCH'; throw e;
      }
      // Release is the transfer from escrow to the worker's internal wallet.
      // Payout is a separate future operation and must not be posted here.
      await postInternalPaymentReleaseWithClient(client, {
        paymentId, payerId:payment.payer_id, workerId:payment.payee_id,
        providerPayout:breakdown.providerPayout, currency:breakdown.currency,
        idempotencyKey:`internal:release:${paymentId}`,
      });
    } else {
      for (const [idx,journal] of [releaseJournal(breakdown),payoutJournal(breakdown)].entries()) {
        const journalId=crypto.randomUUID(); const reference=idx===0?'PAYMENT_RELEASE':'PAYMENT_PAYOUT';
        for (const entry of journal) await client.query(`INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,NOW())`, [crypto.randomUUID(),journalId,reference,paymentId,entry.account,entry.debit,entry.credit,breakdown.currency]);
      }
    }
    await client.query(`INSERT INTO settlements(id,payment_id,provider_ref,amount,currency,status,created_at,updated_at) VALUES($1,$2,$3,$4,$5,'RELEASED',NOW(),NOW()) ON CONFLICT(payment_id) DO UPDATE SET status='RELEASED',provider_ref=EXCLUDED.provider_ref,updated_at=NOW()`, [crypto.randomUUID(),paymentId,payment.provider_ref,breakdown.providerPayout,breakdown.currency]);
    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES($1,'PAYMENT_RELEASE',$2,'payment',$3,$4::jsonb,NOW())`, [crypto.randomUUID(), actorId, paymentId, JSON.stringify({ jobId, outboxEventId:eventId, providerPayout:breakdown.providerPayout, platformFee:breakdown.platformFee })]);
    await client.query(`UPDATE outbox_events SET status='DONE',processed_at=NOW(),locked_at=NULL,last_error=NULL WHERE id=$1`, [eventId]);
    return { completed:true, alreadyDone:false };
  });
}

function outboxRetryDelaySeconds(eventId, attempts, baseSeconds = 5) {
  const exponent = Math.max(0, Number(attempts || 1) - 1);
  const capped = Math.min(300, Number(baseSeconds) * Math.pow(2, exponent));
  const digest = crypto.createHash('sha256').update(`${eventId}:${attempts}`).digest();
  const jitterFactor = 0.75 + (digest.readUInt16BE(0) / 0xffff) * 0.5;
  return Math.min(300, Math.max(1, Math.round(capped * jitterFactor)));
}

export async function failOutboxEvent({ eventId, error, maxAttempts, backoffSeconds = 5, leaseToken }) {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`SELECT attempts, lease_token FROM outbox_events WHERE id=$1 FOR UPDATE`, [eventId]);
    if (!rows[0]) return null;
    if (leaseToken && String(rows[0].lease_token) !== String(leaseToken)) return { terminal:false, stale:true, attempts:Number(rows[0].attempts || 0) };
    const attempts = Number(rows[0].attempts || 0);
    const terminal = attempts >= maxAttempts;
    const nextStatus = terminal ? 'FAILED' : 'PENDING';
    const retryDelay = terminal ? 0 : outboxRetryDelaySeconds(eventId, attempts, backoffSeconds);
    await client.query(
      `UPDATE outbox_events SET status=$2,available_at=NOW()+make_interval(secs => $3),locked_at=NULL,lease_token=NULL,last_error=$4 WHERE id=$1`,
      [eventId, nextStatus, retryDelay, String(error).slice(0,2000)]
    );
    if (terminal) {
      const { rows: eventRows } = await client.query(`SELECT event_type,aggregate_id FROM outbox_events WHERE id=$1`, [eventId]);
      const terminalEvent = eventRows[0];
      if (terminalEvent?.event_type === 'PAYOUT_EXECUTE') {
        await failPayoutOutboxWithClient(client, { eventId, payoutId: terminalEvent.aggregate_id, error, leaseToken: null });
        return { terminal, attempts };
      }
      const { rows: failedHoldRows } = await client.query(`
        SELECT p.id,p.job_id,p.funding_previous_job_status,p.payer_id AS owner_id,j.status AS job_status
          FROM payments p
          JOIN outbox_events o ON o.id=$1 AND o.event_type='PAYMENT_CREATE_HOLD' AND p.id=o.aggregate_id
          JOIN jobs j ON j.id=p.job_id
         WHERE p.status='HOLD_PENDING'
         FOR UPDATE OF p,j
      `, [eventId]);
      if (failedHoldRows[0]) {
        const failedHold = failedHoldRows[0];
        await client.query(`UPDATE payments SET status='HOLD_FAILED',updated_at=NOW() WHERE id=$1`, [failedHold.id]);
        if (['PUBLISHED','ASSIGNED'].includes(failedHold.funding_previous_job_status) && failedHold.job_status === 'FUNDED') {
          await client.query(`UPDATE jobs SET status=$2,updated_at=NOW() WHERE id=$1 AND status='FUNDED'`, [failedHold.job_id, failedHold.funding_previous_job_status]);
        }
        await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES(gen_random_uuid(),'PAYMENT_HOLD_FAILED',$1,'payment',$2,$3::jsonb,NOW())`, [null, failedHold.id, JSON.stringify({ eventId, restoredJobStatus: failedHold.funding_previous_job_status }),]);
      }
      await client.query(`UPDATE refunds r SET status='FAILED',updated_at=NOW() FROM outbox_events o WHERE o.id=$1 AND o.event_type='PAYMENT_REFUND' AND r.id=(o.payload->>'refundId')::uuid AND r.status='PENDING'`, [eventId]);
      await client.query(`UPDATE payments p SET status='HELD',updated_at=NOW() FROM outbox_events o WHERE o.id=$1 AND o.event_type='PAYMENT_REFUND' AND p.id=o.aggregate_id AND p.status='REFUND_PENDING'`, [eventId]);
      await client.query(`UPDATE payments p SET status='RELEASE_FAILED',updated_at=NOW() FROM outbox_events o WHERE o.id=$1 AND o.event_type='PAYMENT_RELEASE' AND p.id=o.aggregate_id AND p.status='RELEASE_PENDING'`, [eventId]);
    }
    return { terminal, attempts };
  });
}
