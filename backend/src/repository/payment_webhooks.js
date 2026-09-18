import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { fundingJournal, releaseJournal, payoutJournal, refundJournal } from '../financial.js';
import { config } from '../config.js';
import { postInternalPaymentHoldWithClient, postInternalPaymentReleaseWithClient, postInternalPaymentRefundWithClient } from '../wallet_ledger.js';

const RELEASE_STATES = new Set(['RELEASE_PENDING', 'RELEASE_FAILED']);

function providerRefMatches(payment, providerRef) {
  if (!providerRef) return true;
  if (!payment?.provider_ref) return true;
  return String(payment.provider_ref) === String(providerRef);
}

function conflict(code, message) {
  const e = new Error(code);
  e.code = code;
  e.status = 409;
  e.message = message;
  return e;
}

function financialNumber(currency, value) {
  return String(currency || config.paymentCurrency).toUpperCase() === 'TOMAN' ? String(value ?? '0') : Number(value ?? 0);
}

export async function applyPaymentWebhookAtomic({eventId,eventType,paymentId,providerRef,payload}) {
  return withSqlTransaction(async(client)=>{
    const providerName = config.paymentProvider || 'webhook';
    const { rows: claimedProviderEvent } = await client.query(
      `INSERT INTO provider_events(provider,provider_event_id,event_type,resource_type,resource_id,payload,signature_valid,status,received_at)
       VALUES($1,$2,$3,'payment',$4,$5::jsonb,TRUE,'PROCESSING',NOW())
       ON CONFLICT(provider,provider_event_id) DO NOTHING
       RETURNING id`,
      [providerName,eventId,eventType,paymentId,JSON.stringify(payload||{})]
    );
    if (!claimedProviderEvent.length) {
      return {processed:true,duplicate:true,paymentId};
    }

    const prior=await client.query(`SELECT * FROM payment_webhook_events WHERE event_id=$1`,[eventId]);
    if(prior.rows[0]) {
      await client.query(`UPDATE provider_events SET status='PROCESSED',processed_at=NOW() WHERE provider=$1 AND provider_event_id=$2`,[providerName,eventId]);
      return {processed:true,duplicate:true,paymentId:prior.rows[0].payment_id};
    }

    // Resolve the aggregate before recording the event. An unknown aggregate
    // must rollback the entire transaction so the provider can safely retry.
    const {rows:pr}=await client.query(`SELECT * FROM payments WHERE id=$1 FOR UPDATE`,[paymentId]);
    if(!pr[0]) throw conflict('PAYMENT_NOT_FOUND','Payment not found');
    const p=pr[0];

    // Provider references belong to the provider operation being acknowledged:
    // HOLD uses the hold reference, RELEASE uses a distinct release reference,
    // and REFUND uses its own refund reference. They must not be compared to the
    // payment's original hold reference.
    const {rows:insertedEvents}=await client.query(
      `INSERT INTO payment_webhook_events(id,event_id,event_type,payment_id,provider_ref,payload,processed_at,created_at)
       VALUES($1,$2,$3,$4,$5,$6::jsonb,NOW(),NOW())
       ON CONFLICT(event_id) DO NOTHING RETURNING payment_id`,
      [crypto.randomUUID(),eventId,eventType,paymentId,providerRef || null,JSON.stringify(payload||{})]
    );
    if (!insertedEvents.length) {
      const duplicate = await client.query(`SELECT payment_id FROM payment_webhook_events WHERE event_id=$1`,[eventId]);
      return {processed:true,duplicate:true,paymentId:duplicate.rows[0]?.payment_id || null};
    }

    const b={baseAmount:financialNumber(p.currency,p.base_amount||p.amount),employerFee:financialNumber(p.currency,p.employer_fee||0),workerFee:financialNumber(p.currency,p.worker_fee||0),platformFee:financialNumber(p.currency,p.platform_fee||0),employerCharge:financialNumber(p.currency,p.employer_charge||p.amount),providerPayout:financialNumber(p.currency,p.provider_payout||p.amount),currency:p.currency||config.paymentCurrency};
    if(eventType==='PAYMENT_HELD' && p.status==='HOLD_PENDING') {
      if (config.paymentProvider === 'internal') {
        if (b.currency !== 'TOMAN') throw conflict('INTERNAL_CURRENCY_MISMATCH','Internal payment webhook requires TOMAN');
        await postInternalPaymentHoldWithClient(client, {
          paymentId, payerId:p.payer_id, employerCharge:b.employerCharge, providerPayout:b.providerPayout,
          platformFee:b.platformFee, actorId:p.payer_id, idempotencyKey:`internal:webhook:hold:${eventId}`,
        });
      }
      await client.query(`UPDATE payments SET status='HELD',provider_ref=COALESCE($2,provider_ref),updated_at=NOW() WHERE id=$1`,[paymentId,providerRef||null]);
    } else if(eventType==='PAYMENT_RELEASED' && RELEASE_STATES.has(p.status)) {
      if (p.job_id) {
        const { rows: jobRows } = await client.query(`SELECT status FROM jobs WHERE id=$1 FOR UPDATE`, [p.job_id]);
        if (!jobRows[0]) throw conflict('JOB_NOT_FOUND','Job not found for payment');
        if (jobRows[0].status !== 'COMPLETED') throw conflict('INVALID_JOB_STATE','Job must be completed before payment release');
      }
      if (config.paymentProvider === 'internal') {
        if (b.currency !== 'TOMAN') throw conflict('INTERNAL_CURRENCY_MISMATCH','Internal payment webhook requires TOMAN');
        await postInternalPaymentReleaseWithClient(client, {
          paymentId, payerId:p.payer_id, workerId:p.payee_id, providerPayout:b.providerPayout,
          actorId:p.payee_id, idempotencyKey:`internal:webhook:release:${eventId}`,
        });
      } else {
        for(const journal of [releaseJournal(b),payoutJournal(b)]){
          const jid=crypto.randomUUID();
          for(const e of journal) await client.query(
            `INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
             VALUES($1,$2,'PAYMENT_WEBHOOK',$3,$4,$5,$6,$7,NOW())`,
            [crypto.randomUUID(),jid,paymentId,e.account,e.debit,e.credit,b.currency]
          );
        }
      }
      await client.query(`UPDATE payments SET status='RELEASED',updated_at=NOW() WHERE id=$1`,[paymentId]);
      await client.query(`UPDATE jobs SET status='SETTLED',updated_at=NOW() WHERE id=$1 AND status='COMPLETED'`,[p.job_id]);
      await client.query(
        `INSERT INTO settlements(id,payment_id,provider_ref,amount,currency,status,created_at,updated_at)
         VALUES($1,$2,$3,$4,$5,'RELEASED',NOW(),NOW())
         ON CONFLICT(payment_id) DO UPDATE SET status='RELEASED',provider_ref=EXCLUDED.provider_ref,updated_at=NOW()`,
        [crypto.randomUUID(),paymentId,providerRef || p.provider_ref, b.providerPayout,b.currency]
      );
    } else if(eventType==='PAYMENT_REFUNDED' && p.status==='REFUND_PENDING') {
      const {rows:rr}=await client.query(`SELECT * FROM refunds WHERE payment_id=$1 AND status='PENDING' ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,[paymentId]);
      const refund=rr[0];
      if(!refund) throw conflict('REFUND_NOT_FOUND','Pending refund not found');
      if (config.paymentProvider === 'internal') {
        if (b.currency !== 'TOMAN') throw conflict('INTERNAL_CURRENCY_MISMATCH','Internal payment webhook requires TOMAN');
        await postInternalPaymentRefundWithClient(client, {
          paymentId, payerId:p.payer_id, providerPayout:b.providerPayout, platformFee:b.platformFee, employerCharge:b.employerCharge,
          actorId:p.payer_id, idempotencyKey:`internal:webhook:refund:${refund.id}`,
        });
      } else {
        for(const e of refundJournal(b)){
          const jid=crypto.randomUUID();
          await client.query(
            `INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
             VALUES($1,$2,'PAYMENT_WEBHOOK',$3,$4,$5,$6,$7,NOW())`,
            [crypto.randomUUID(),jid,paymentId,e.account,e.debit,e.credit,b.currency]
          );
        }
      }
      await client.query(`UPDATE refunds SET status='REFUNDED',provider_ref=COALESCE($2,provider_ref),updated_at=NOW() WHERE id=$1`,[refund.id,providerRef||null]);
      await client.query(`UPDATE payments SET status='REFUNDED',updated_at=NOW() WHERE id=$1`,[paymentId]);
      await client.query(`UPDATE jobs SET status=CASE WHEN provider_id IS NULL THEN 'PUBLISHED' ELSE 'ASSIGNED' END,updated_at=NOW() WHERE id=$1`,[p.job_id]);
    }
    await client.query(`UPDATE provider_events SET status='PROCESSED',processed_at=NOW() WHERE provider=$1 AND provider_event_id=$2`,[providerName,eventId]);
    return {processed:true,duplicate:false,paymentId};
  });
}

export { RELEASE_STATES };
