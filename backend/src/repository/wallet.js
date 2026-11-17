import { requirePool } from './context.js';
import { ensureWalletForUserPublic, INTERNAL_CURRENCY } from '../wallet_ledger.js';

function walletFromRow(r) {
  if (!r) return null;
  return {
    id: r.id, userId: r.user_id, currency: r.currency,
    availableBalance: String(r.currency || INTERNAL_CURRENCY).toUpperCase() === 'TOMAN' ? String(r.available_balance ?? '0') : Number(r.available_balance),
    lockedBalance: String(r.currency || INTERNAL_CURRENCY).toUpperCase() === 'TOMAN' ? String(r.locked_balance ?? '0') : Number(r.locked_balance),
    escrowBalance: String(r.escrow_balance ?? '0'),
    pendingWithdrawalBalance: String(r.pending_withdrawal_balance ?? '0'),
    otherLockedBalance: String(r.other_locked_balance ?? '0'),
    totalBalance: String(r.total_balance ?? '0'),
    status: r.status, createdAt: r.created_at?.toISOString?.() ?? r.created_at, updatedAt: r.updated_at?.toISOString?.() ?? r.updated_at,
  };
}

export async function getWalletById(walletId, currency = INTERNAL_CURRENCY) {
  const { rows } = await requirePool().query(
    `SELECT id,user_id,currency,available_balance,locked_balance,status,created_at,updated_at
       FROM wallet_accounts WHERE id=$1 AND currency=$2`,
    [walletId, currency],
  );
  return walletFromRow(rows[0]);
}

export async function getWalletForUser(userId) {
  let { rows } = await requirePool().query(`
    SELECT id,user_id,currency,available_balance,locked_balance,status,created_at,updated_at
      FROM wallet_accounts
     WHERE user_id=$1 AND currency='TOMAN'
  `, [userId]);
  if (!rows[0]) {
    await ensureWalletForUserPublic(userId);
    ({ rows } = await requirePool().query(`
      SELECT id,user_id,currency,available_balance,locked_balance,status,created_at,updated_at
        FROM wallet_accounts
       WHERE user_id=$1 AND currency='TOMAN'
    `, [userId]));
  }
  const wallet = rows[0];
  if (!wallet) return null;
  const { rows: holds } = await requirePool().query(`
    SELECT
      COALESCE(SUM(amount) FILTER (WHERE hold_type='JOB_PAYMENT'),0) AS escrow_balance,
      COALESCE(SUM(amount) FILTER (WHERE hold_type='PAYOUT_RESERVATION'),0) AS pending_withdrawal_balance,
      COALESCE(SUM(amount) FILTER (WHERE hold_type NOT IN ('JOB_PAYMENT','PAYOUT_RESERVATION')),0) AS other_locked_balance
    FROM wallet_holds
    WHERE wallet_id=$1 AND status='ACTIVE'
  `, [wallet.id]);
  const hold = holds[0] || {};
  return walletFromRow({
    ...wallet,
    escrow_balance: String(hold.escrow_balance ?? '0'),
    pending_withdrawal_balance: String(hold.pending_withdrawal_balance ?? '0'),
    other_locked_balance: String(hold.other_locked_balance ?? '0'),
    total_balance: (BigInt(String(wallet.available_balance ?? '0')) + BigInt(String(wallet.locked_balance ?? '0'))).toString(),
  });
}

export async function listWalletTransactions(userId, _currency = INTERNAL_CURRENCY, options = {}) {
  // Keep compatibility with the old numeric third argument while exposing the
  // canonical cursor-paginated wallet entry stream to the API.
  const opts = (options !== null && typeof options === 'object') ? options : { limit: options };
  const safeLimit = Math.min(Math.max(Number(opts.limit) || 50, 1), 100);
  let cursorDate = null;
  let cursorId = null;
  if (opts.cursor) {
    try {
      const decoded = Buffer.from(String(opts.cursor), 'base64url').toString('utf8');
      const parsed = JSON.parse(decoded);
      cursorDate = String(parsed.createdAt || '');
      cursorId = String(parsed.id || '');
      if (!/^\d{4}-\d{2}-\d{2}T/.test(cursorDate) || !/^[0-9a-f-]{36}$/i.test(cursorId)) throw new Error('invalid cursor');
    } catch {
      throw Object.assign(new Error('INVALID_CURSOR'), { code: 'INVALID_CURSOR', status: 400 });
    }
  }

  const params = [userId, INTERNAL_CURRENCY];
  const cursorClause = cursorDate
    ? ` AND (e.created_at,e.id) < ($3::timestamptz,$4::uuid)`
    : '';
  if (cursorDate) params.push(cursorDate, cursorId);
  params.push(safeLimit + 1);

  const { rows } = await requirePool().query(`
    SELECT e.id,
           e.entry_type AS "entryType",
           e.direction,
           e.amount,
           e.currency,
           e.reference_type AS "referenceType",
           e.reference_id AS "referenceId",
           e.financial_operation_id AS "financialOperationId",
           e.balance_after AS "balanceAfter",
           e.metadata,
           e.created_at AS "createdAt"
      FROM wallet_entries e
      JOIN wallet_accounts w ON w.id=e.wallet_id
     WHERE w.user_id=$1 AND e.currency=$2${cursorClause}
     ORDER BY e.created_at DESC,e.id DESC
     LIMIT $${params.length}
  `, params);

  const hasMore = rows.length > safeLimit;
  const items = hasMore ? rows.slice(0, safeLimit) : rows;
  const last = items.at(-1);
  const nextCursor = hasMore && last
    ? Buffer.from(JSON.stringify({
        createdAt: last.createdAt?.toISOString?.() ?? last.createdAt,
        id: last.id,
      })).toString('base64url')
    : null;
  return { items, nextCursor };
}
