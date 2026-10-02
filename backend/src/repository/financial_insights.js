import { requirePool } from './context.js';
import { getWalletForUser } from './wallet.js';
import { buildFinancialInsights } from '../services/financial_insights.js';

export async function getWalletFinancialInsights(userId, { months = 6, now = new Date().toISOString() } = {}) {
  const wallet = await getWalletForUser(userId);
  if (!wallet) return buildFinancialInsights({ wallet: {}, entries: [], months, now });
  const safeMonths = Math.min(Math.max(Number(months) || 6, 1), 12);
  const start = new Date(now);
  start.setUTCMonth(start.getUTCMonth() - safeMonths + 1);
  start.setUTCDate(1);
  const { rows } = await requirePool().query(
    `SELECT e.id,
            e.entry_type AS "entryType",
            e.direction,
            e.amount,
            e.currency,
            e.reference_type AS "referenceType",
            e.reference_id AS "referenceId",
            e.balance_after AS "balanceAfter",
            e.created_at AS "createdAt"
       FROM wallet_entries e
       JOIN wallet_accounts w ON w.id=e.wallet_id
      WHERE w.user_id=$1
        AND e.currency='TOMAN'
        AND e.created_at >= $2
      ORDER BY e.created_at ASC,e.id ASC
      LIMIT 5000`,
    [userId, start.toISOString()],
  );
  return buildFinancialInsights({ wallet, entries: rows, months: safeMonths, now });
}
