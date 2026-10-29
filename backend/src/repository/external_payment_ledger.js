import crypto from 'node:crypto';
import { fundingJournal } from '../financial.js';

// Post the legacy external-provider funding entries as one balanced group.
// Both the signed webhook and the provider outbox completion use this helper
// so callback/outbox ordering cannot silently omit or duplicate the funding group.
export async function postExternalFundingJournalWithClient(client, { paymentId, currency, breakdown }) {
  const journalId = crypto.randomUUID();
  for (const entry of fundingJournal(breakdown)) {
    await client.query(
      `INSERT INTO ledger_entries(id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at)
       VALUES($1,$2,'PAYMENT_FUND',$3,$4,$5,$6,$7,NOW())`,
      [crypto.randomUUID(), journalId, paymentId, entry.account, entry.debit, entry.credit, currency],
    );
  }
  return journalId;
}
