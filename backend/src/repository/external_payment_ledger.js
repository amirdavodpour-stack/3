import crypto from 'node:crypto';
import { fundingJournal } from '../financial.js';

const SUPPORTED_LEDGER_CURRENCIES = new Set(['TOMAN','USD','EUR','IRR']);
const MAX_WHOLE_UNITS = 9000000000000000n;

function amountMinorUnits(value, currency) {
  const raw = String(value ?? '0').trim();
  const parts = raw.split('.');
  if (!/^[0-9]+$/.test(parts[0] || '')) throw new Error(`INVALID_${currency}_LEDGER_AMOUNT`);
  if (currency === 'TOMAN' && parts.length !== 1) throw new Error('INVALID_TOMAN_LEDGER_AMOUNT');
  if (currency !== 'TOMAN' && (parts.length > 2 || (parts.length === 2 && !/^[0-9]{1,2}$/.test(parts[1])))) {
    throw new Error(`INVALID_${currency}_LEDGER_AMOUNT`);
  }
  const minorUnits = currency === 'TOMAN'
    ? BigInt(parts[0])
    : BigInt(parts[0]) * 100n + BigInt((parts[1] || '').padEnd(2, '0') || '0');
  const maximum = currency === 'TOMAN' ? MAX_WHOLE_UNITS : MAX_WHOLE_UNITS * 100n;
  if (minorUnits < 0n || minorUnits > maximum) throw new Error('LEDGER_AMOUNT_OUT_OF_RANGE');
  return { raw, minorUnits };
}

function normalizedEntry(entry, currency) {
  const debit = amountMinorUnits(entry.debit, currency);
  const credit = amountMinorUnits(entry.credit, currency);
  if (debit.minorUnits === 0n && credit.minorUnits === 0n) return null;
  if ((debit.minorUnits === 0n) === (credit.minorUnits === 0n)) throw new Error('INVALID_LEDGER_ENTRY_DIRECTION');
  if (!String(entry.account || '').trim()) throw new Error('INVALID_PROVIDER_LEDGER_ACCOUNT');
  return { account: String(entry.account), debit: debit.raw, credit: credit.raw, debitMinor: debit.minorUnits, creditMinor: credit.minorUnits };
}

function requestDigest({ operationType, journalType, referenceType, referenceId, currency, entries }) {
  const payload = { operationType, journalType, referenceType, referenceId: String(referenceId), currency,
    entries: entries.map((entry) => ({ account: String(entry.account),
      debit: amountMinorUnits(entry.debit, currency).raw, credit: amountMinorUnits(entry.credit, currency).raw })) };
  return crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

export async function postExternalLedgerJournalWithClient(client, {
  operationType, journalType, referenceType, referenceId, currency, entries, idempotencyKey,
}) {
  const normalizedCurrency = String(currency || '').trim().toUpperCase();
  if (!SUPPORTED_LEDGER_CURRENCIES.has(normalizedCurrency)) throw new Error('UNSUPPORTED_PROVIDER_LEDGER_CURRENCY');
  if (!['HOLD','RELEASE','REFUND','PAYOUT'].includes(operationType)) throw new Error('INVALID_PROVIDER_LEDGER_OPERATION');
  if (!String(journalType || '').trim() || !String(referenceType || '').trim() || !String(referenceId || '').trim()) throw new Error('INVALID_PROVIDER_LEDGER_REFERENCE');
  if (!Array.isArray(entries) || entries.length < 2) throw new Error('INVALID_PROVIDER_LEDGER_ENTRIES');
  if (!String(idempotencyKey || '').trim()) throw new Error('PROVIDER_LEDGER_IDEMPOTENCY_REQUIRED');
  const normalizedEntries = entries.map((entry) => normalizedEntry(entry, normalizedCurrency)).filter(Boolean);
  if (normalizedEntries.length < 2) throw new Error('INVALID_PROVIDER_LEDGER_ENTRIES');
  const debitTotal = normalizedEntries.reduce((sum, entry) => sum + entry.debitMinor, 0n);
  const creditTotal = normalizedEntries.reduce((sum, entry) => sum + entry.creditMinor, 0n);
  if (debitTotal <= 0n || debitTotal !== creditTotal) throw new Error('UNBALANCED_PROVIDER_LEDGER_JOURNAL');
  const digest = requestDigest({ operationType, journalType, referenceType, referenceId, currency: normalizedCurrency, entries });
  const key = String(idempotencyKey);
  await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 918273650))', [`provider-ledger:${operationType}:${key}`]);
  const { rows: priorRows } = await client.query(`
    SELECT fo.id AS operation_id,fo.request_hash,fo.status AS operation_status, j.id AS journal_id,j.status AS journal_status
      FROM financial_operations fo LEFT JOIN journals j ON j.operation_id=fo.id AND j.journal_type=$2
     WHERE fo.actor_type='PROVIDER' AND fo.operation_type=$1 AND fo.idempotency_key=$3 FOR UPDATE OF fo
  `, [operationType,journalType,key]);
  const prior = priorRows[0];
  if (prior) {
    if (prior.request_hash !== digest) throw new Error('PROVIDER_LEDGER_IDEMPOTENCY_CONFLICT');
    if (!prior.journal_id || prior.operation_status !== 'SUCCEEDED' || prior.journal_status !== 'POSTED') throw new Error('PROVIDER_LEDGER_IDEMPOTENCY_STATE_INVALID');
    return prior.journal_id;
  }
  const { rows: operationRows } = await client.query(`
    INSERT INTO financial_operations(id,operation_type,actor_type,actor_id,status,idempotency_key,request_hash,created_at,completed_at)
    VALUES($1,$2,'PROVIDER',NULL,'SUCCEEDED',$3,$4,NOW(),NOW()) RETURNING id
  `, [crypto.randomUUID(),operationType,key,digest]);
  const journalId = crypto.randomUUID();
  await client.query(`INSERT INTO journals(id,operation_id,journal_type,currency,status,created_at) VALUES($1,$2,$3,$4,'CREATED',NOW())`,
    [journalId,operationRows[0].id,journalType,normalizedCurrency]);
  for (const entry of normalizedEntries) {
    await client.query(`INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
      VALUES($1,$2,$3,$4,$5,$6,$7,$8,NOW())`,
      [crypto.randomUUID(),journalId,referenceType,referenceId,entry.account,entry.debit,entry.credit,normalizedCurrency]);
  }
  await client.query(`UPDATE journals SET status='POSTED',posted_at=NOW() WHERE id=$1`, [journalId]);
  return journalId;
}

export async function postExternalFundingJournalWithClient(client, { paymentId, currency, breakdown }) {
  return postExternalLedgerJournalWithClient(client, {
    operationType:'HOLD', journalType:'EXTERNAL_FUNDING', referenceType:'PAYMENT_FUND',
    referenceId:paymentId, currency, entries:fundingJournal(breakdown), idempotencyKey:`external:HOLD:${paymentId}`,
  });
}
