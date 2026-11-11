import { recordJobChatTerminalEventWithClient } from './human_chat.js';
import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { config } from '../config.js';
import { normalizeFinancialAmount, fundingJournal, releaseJournal, payoutJournal, refundJournal, calculatePaymentBreakdown } from '../financial.js';
import { jobFromRow, offerFromRow, paymentFromRow } from './mappers.js';
import { postInternalPaymentRefundWithClient } from '../wallet_ledger.js';
import { postExternalLedgerJournalWithClient } from './external_payment_ledger.js';
import { reserveOutboxDedupeKeyWithClient, insertReservedOutboxEventWithClient } from './outbox_dedupe_registry.js';

export function refundablePaymentStateAllowed(status, allowPendingRelease = false) {
  const allowed = allowPendingRelease ? ['HELD','RELEASE_PENDING','RELEASE_FAILED'] : ['HELD'];
  return allowed.includes(String(status || '').toUpperCase());
}

export async function createRefundAtomic({jobId,paymentId,ownerId,amount,id,idempotencyKey,createdAt,allowPendingRelease=false}) {
  return withSqlTransaction(async(client)=>{
    if (idempotencyKey) {
      await client.query(`SELECT pg_advisory_xact_lock(hashtextextended($1, 918273645))`, [`refund:${paymentId}:${idempotencyKey}`]);
    }
    const {rows:jr}=await client.query(`SELECT * FROM jobs WHERE id=$1 FOR UPDATE`,[jobId]);
    if(!jr[0]) return null;
    if(jr[0].owner_id!==ownerId){const e=new Error('FORBIDDEN');e.code='FORBIDDEN';throw e;}
    // A terminal release failure locks the outbox row before updating payments.
    // Acquire the release event before the payment row so refund supersession
    // cannot form payment -> outbox against failOutboxEvent's outbox -> payment.
    // The job lock above still serializes normal release completion and webhooks.
    const {rows:paymentMetadataRows}=await client.query(
      `SELECT status FROM payments WHERE id=$1 AND job_id=$2`,
      [paymentId,jobId],
    );
    const paymentMetadata=paymentMetadataRows[0];
    if(!paymentMetadata){const e=new Error('PAYMENT_NOT_FOUND');e.code='PAYMENT_NOT_FOUND';throw e;}
    if (allowPendingRelease && ['RELEASE_PENDING', 'RELEASE_FAILED'].includes(paymentMetadata.status)) {
      const releaseEvents = await client.query(
        `SELECT id,status FROM outbox_events
          WHERE aggregate_type='payment' AND aggregate_id=$1
            AND event_type='PAYMENT_RELEASE'
            AND status IN ('PENDING','FAILED','PROCESSING')
          ORDER BY id FOR UPDATE`,
        [paymentId],
      );
      if (releaseEvents.rows.some((event) => event.status === 'PROCESSING')) {
        const e = new Error('PAYMENT_RELEASE_IN_PROGRESS');
        e.code = 'PAYMENT_RELEASE_IN_PROGRESS';
        throw e;
      }
      for (const release of releaseEvents.rows) {
        if (['PENDING', 'FAILED'].includes(release.status)) {
          await client.query(
            `UPDATE outbox_events
               SET status='DONE',
                   processed_at=COALESCE(processed_at,NOW()),
                   locked_at=NULL,
                   lease_token=NULL,
                   last_error=NULL,
                   last_error_code='SUPERSEDED_BY_REFUND',
                   last_error_category='payment',
                   last_error_retryable=FALSE,
                   last_error_http_status=NULL
             WHERE id=$1`,
            [release.id],
          );
        }
      }
    }

    const {rows:pr}=await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`,[paymentId,jobId]);
    const payment=pr[0]; if(!payment){const e=new Error('PAYMENT_NOT_FOUND');e.code='PAYMENT_NOT_FOUND';throw e;}
    if(!refundablePaymentStateAllowed(payment.status, allowPendingRelease)){const e=new Error('INVALID_PAYMENT_STATE');e.code='INVALID_PAYMENT_STATE';throw e;}
    if (!allowPendingRelease && jr[0].status !== 'FUNDED') {
      const e = new Error('REFUND_REQUIRES_DISPUTE'); e.code = 'REFUND_REQUIRES_DISPUTE'; e.status = 409; throw e;
    }
    const refundCurrency=String(payment.currency || config.paymentCurrency).toUpperCase(); const refundAmount=normalizeFinancialAmount(refundCurrency, amount || payment.amount); if(String(refundAmount)!==String(normalizeFinancialAmount(refundCurrency, payment.amount))){const e=new Error('PARTIAL_REFUND_UNSUPPORTED');e.code='PARTIAL_REFUND_UNSUPPORTED';throw e;}
    let refundRow = null;
    if (idempotencyKey) {
      const prior = await client.query(`SELECT * FROM refunds WHERE payment_id=$1 AND idempotency_key=$2 FOR UPDATE`, [paymentId, idempotencyKey]);
      refundRow = prior.rows[0] || null;
      if (refundRow?.status === 'REFUNDED') return { refund: refundRow, payment };
    }

    // A payment has one immutable PAYMENT_REFUND outbox identity. Enforce
    // one unresolved refund row per payment, whether the prior operation is
    // PENDING or terminally FAILED, before creating or acknowledging a retry.
    const { rows: unresolvedRefunds } = await client.query(
      `SELECT * FROM refunds
        WHERE payment_id=$1 AND status IN ('PENDING','FAILED')
        ORDER BY created_at DESC,id DESC
        FOR UPDATE`,
      [paymentId],
    );
    if (unresolvedRefunds.length) {
      const suppliedKey = String(idempotencyKey || '');
      const matchingRefunds = unresolvedRefunds.filter(
        (candidate) => String(candidate.idempotency_key || '') === suppliedKey,
      );
      if (unresolvedRefunds.length !== 1 || matchingRefunds.length !== 1 ||
          (refundRow && refundRow.id !== matchingRefunds[0].id)) {
        const error = new Error('REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY');
        error.code = 'REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY';
        error.status = 409;
        throw error;
      }
      refundRow = matchingRefunds[0];
    }

    if (refundRow?.status === 'PENDING') {
      return { refund: refundRow, payment:{...payment,status:'REFUND_PENDING'} };
    }
    // Reopen the same semantic refund; never create a second refund operation.
    if (refundRow?.status === 'FAILED') {
      const { rows: reopened } = await client.query(
        `UPDATE refunds SET status='PENDING',provider_ref=NULL,updated_at=$2 WHERE id=$1 RETURNING *`,
        [refundRow.id, createdAt],
      );
      refundRow = reopened[0];
    }
    if (!refundRow) {
      const {rows:rr}=await client.query(`INSERT INTO refunds(id,payment_id,amount,currency,status,provider_ref,idempotency_key,created_at,updated_at) VALUES($1,$2,$3,$4,'PENDING',NULL,$5,$6,$6) RETURNING *`,[id,paymentId,refundAmount,payment.currency || config.paymentCurrency,idempotencyKey||null,createdAt]);
      refundRow = rr[0];
    }
    await client.query(`UPDATE payments SET status='REFUND_PENDING',updated_at=$2 WHERE id=$1`,[paymentId,createdAt]);
    const dedupe='PAYMENT_REFUND:'+paymentId;
    const eventPayload={
      jobId,
      ownerId,
      paymentId,
      refundId:refundRow.id,
      providerRef:payment.provider_ref,
      idempotencyKey:idempotencyKey||('refund:'+refundRow.id),
    };
    const reservation=await reserveOutboxDedupeKeyWithClient(client,{
      eventId:crypto.randomUUID(),
      eventType:'PAYMENT_REFUND',
      aggregateType:'payment',
      aggregateId:paymentId,
      dedupeKey:dedupe,
      conflictPolicy:'STATUS_GATED_REQUEUE',
    });
    const ev=reservation.created
      ? await insertReservedOutboxEventWithClient(client,{
          reservation,
          eventType:'PAYMENT_REFUND',
          aggregateType:'payment',
          aggregateId:paymentId,
          dedupeKey:dedupe,
          payload:eventPayload,
        })
      : await (async()=>{
          const {rows}=await client.query(
            "UPDATE outbox_events SET status=CASE WHEN status='FAILED' THEN 'PENDING' ELSE status END,attempts=CASE WHEN status='FAILED' THEN 0 ELSE attempts END,available_at=CASE WHEN status='FAILED' THEN NOW() ELSE available_at END,locked_at=CASE WHEN status='FAILED' THEN NULL ELSE locked_at END,lease_token=CASE WHEN status='FAILED' THEN NULL ELSE lease_token END,last_error=CASE WHEN status='FAILED' THEN NULL ELSE last_error END,last_error_code=CASE WHEN status='FAILED' THEN NULL ELSE last_error_code END,last_error_category=CASE WHEN status='FAILED' THEN NULL ELSE last_error_category END,last_error_retryable=CASE WHEN status='FAILED' THEN NULL ELSE last_error_retryable END,last_error_http_status=CASE WHEN status='FAILED' THEN NULL ELSE last_error_http_status END,processed_at=CASE WHEN status='FAILED' THEN NULL ELSE processed_at END WHERE id=$1 RETURNING *",
            [reservation.eventId],
          );
          if(!rows[0]) throw Object.assign(new Error('OUTBOX_DEDUPE_ORPHANED'),{code:'OUTBOX_DEDUPE_ORPHANED'});
          return {...reservation,event:rows[0]};
        })();
    return {refund:refundRow,payment:{...payment,status:'REFUND_PENDING'},outboxEvent:{id:ev.event.id}};
  });
}
export async function cancelJobAfterConfirmedRefundWithClient(client,jobId) {
  const {rows}=await client.query(
    `UPDATE jobs SET status='CANCELLED',updated_at=NOW()
      WHERE id=$1 RETURNING updated_at`,
    [jobId],
  );
  if(!rows[0])return false;
  await recordJobChatTerminalEventWithClient(
    client,
    jobId,
    'CANCELLED',
    rows[0].updated_at,
  );
  return true;
}

export async function completePaymentRefundOutbox({eventId,jobId,paymentId,refundId,providerRef,actorId,leaseToken}) {
  return withSqlTransaction(async(client)=>{
    // Match request/webhook lock ordering: serialize the job aggregate before
    // claiming the outbox row or locking its payment/refund records.
    const {rows:jr}=await client.query(`SELECT id FROM jobs WHERE id=$1 FOR UPDATE`,[jobId]);
    if(!jr[0])return {completed:false,reason:'PAYMENT_NOT_FOUND'};
    const {rows:er}=await client.query(`SELECT lease_token FROM outbox_events WHERE id=$1 FOR UPDATE`,[eventId]);
    if(!er[0])return {completed:false,reason:'OUTBOX_NOT_FOUND'};
    if(leaseToken && String(er[0].lease_token)!==String(leaseToken))return {completed:false,reason:'STALE_LEASE'};
    const {rows:pr}=await client.query(`SELECT * FROM payments WHERE id=$1 AND job_id=$2 FOR UPDATE`,[paymentId,jobId]);
    const payment=pr[0]; if(!payment)return {completed:false,reason:'PAYMENT_NOT_FOUND'};
    const {rows:rr}=await client.query(`SELECT * FROM refunds WHERE id=$1 AND payment_id=$2 FOR UPDATE`,[refundId,paymentId]); const refund=rr[0]; if(!refund)return {completed:false,reason:'REFUND_NOT_FOUND'};
    if(payment.status==='REFUNDED' && refund.status==='REFUNDED'){await client.query(`UPDATE outbox_events SET status='DONE',processed_at=COALESCE(processed_at,NOW()),locked_at=NULL,last_error=NULL,last_error_code=NULL,last_error_category=NULL,last_error_retryable=NULL,last_error_http_status=NULL WHERE id=$1`,[eventId]);return {completed:true,alreadyDone:true};}
    if(payment.status!=='REFUND_PENDING' || refund.status!=='PENDING'){return {completed:false,reason:'INVALID_REFUND_STATE'};}
    const breakdown={baseAmount:normalizeFinancialAmount(payment.currency,payment.base_amount||payment.amount),employerFee:normalizeFinancialAmount(payment.currency,payment.employer_fee||0),workerFee:normalizeFinancialAmount(payment.currency,payment.worker_fee||0),platformFee:normalizeFinancialAmount(payment.currency,payment.platform_fee||0),employerCharge:normalizeFinancialAmount(payment.currency,payment.employer_charge||payment.amount),providerPayout:normalizeFinancialAmount(payment.currency,payment.provider_payout||payment.amount),currency:payment.currency||config.paymentCurrency,policyVersion:payment.fee_policy_version||'legacy',kind:'JOB'};
    await client.query(`UPDATE refunds SET status='REFUNDED',provider_ref=$2,updated_at=NOW() WHERE id=$1`,[refundId,providerRef]);
    await client.query(`UPDATE payments SET status='REFUNDED',provider_ref=$2,updated_at=NOW() WHERE id=$1`,[paymentId,payment.provider_ref]);
    const cancelled=await cancelJobAfterConfirmedRefundWithClient(client,jobId);
    if(!cancelled)return {completed:false,reason:'JOB_NOT_FOUND'};
    if (config.paymentProvider === 'internal') {
      if (breakdown.currency !== 'TOMAN') {
        const e = new Error('INTERNAL_CURRENCY_MISMATCH'); e.code = 'INTERNAL_CURRENCY_MISMATCH'; throw e;
      }
      // The Financial Core refund operation already posts the canonical wallet
      // entry and balanced journal. Avoid a second legacy accounting journal.
      await postInternalPaymentRefundWithClient(client, {
        paymentId, payerId:payment.payer_id, providerPayout:breakdown.providerPayout,
        platformFee:breakdown.platformFee, employerCharge:breakdown.employerCharge,
        currency:breakdown.currency, idempotencyKey:`internal:refund:${paymentId}`,
      });
    } else {
      await postExternalLedgerJournalWithClient(client, {
        operationType:'REFUND', journalType:'EXTERNAL_REFUND', referenceType:'PAYMENT_REFUND',
        referenceId:paymentId, currency:breakdown.currency, entries:refundJournal(breakdown),
        idempotencyKey:`external:REFUND:${paymentId}`,
      });
    }
    await client.query(`INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at) VALUES($1,'PAYMENT_REFUND',$2,'payment',$3,$4::jsonb,NOW())`,[crypto.randomUUID(),actorId,paymentId,JSON.stringify({jobId,refundId,eventId,providerRef})]);
    await client.query(`UPDATE outbox_events SET status='DONE',processed_at=NOW(),locked_at=NULL,last_error=NULL,last_error_code=NULL,last_error_category=NULL,last_error_retryable=NULL,last_error_http_status=NULL WHERE id=$1`,[eventId]);
    return {completed:true,alreadyDone:false};
  });
}
