const DEFAULT_MONTHS = 6;
const MAX_MONTHS = 12;

function integerAmount(value) {
  const raw = String(value ?? '').trim();
  if (!/^\d+$/.test(raw)) return 0n;
  return BigInt(raw);
}

function monthKey(date) {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

function monthLabel(key) {
  const [year, month] = key.split('-');
  return `${year}/${month}`;
}

function safeDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function add(map, key, amount) {
  map.set(key, (map.get(key) || 0n) + amount);
}

function toSortedArray(map, mapper) {
  return [...map.entries()].sort(([a], [b]) => a.localeCompare(b)).map(mapper);
}

export function buildFinancialInsights({ wallet = {}, entries = [], months = DEFAULT_MONTHS, now = new Date().toISOString() } = {}) {
  const safeMonths = Math.min(Math.max(Number(months) || DEFAULT_MONTHS, 1), MAX_MONTHS);
  const end = safeDate(now) || new Date();
  const start = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth() - safeMonths + 1, 1));

  const monthly = new Map();
  const sources = new Map();
  const balancePoints = [];
  let totalInflow = 0n;
  let totalOutflow = 0n;
  let totalReserved = 0n;

  for (const raw of Array.isArray(entries) ? entries : []) {
    if (!raw || typeof raw !== 'object') continue;
    const date = safeDate(raw.createdAt ?? raw.created_at);
    if (!date || date < start || date > end) continue;
    const amount = integerAmount(raw.amount);
    if (amount <= 0n) continue;

    const direction = String(raw.direction || '').toUpperCase();
    if (!['CREDIT', 'DEBIT'].includes(direction)) continue;
    const referenceType = String(raw.referenceType ?? raw.reference_type ?? 'OTHER').toUpperCase();
    const key = monthKey(date);
    const bucket = monthly.get(key) || { inflow: 0n, outflow: 0n, reserved: 0n };
    if (referenceType === 'HOLD') {
      bucket.reserved += amount;
      totalReserved += amount;
    } else if (direction === 'CREDIT') {
      bucket.inflow += amount;
      totalInflow += amount;
    } else {
      bucket.outflow += amount;
      totalOutflow += amount;
    }
    monthly.set(key, bucket);

    if (referenceType !== 'HOLD') {
      const source = sources.get(referenceType) || { credit: 0n, debit: 0n };
      source[direction === 'CREDIT' ? 'credit' : 'debit'] += amount;
      sources.set(referenceType, source);
    }

    const balanceAfter = integerAmount(raw.balanceAfter ?? raw.balance_after);
    if (balanceAfter >= 0n && raw.balanceAfter != null) {
      balancePoints.push({
        date: date.toISOString(),
        balance: balanceAfter.toString(),
      });
    }
  }

  const monthlyRows = [];
  for (let i = safeMonths - 1; i >= 0; i -= 1) {
    const date = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth() - i, 1));
    const key = monthKey(date);
    const bucket = monthly.get(key) || { inflow: 0n, outflow: 0n, reserved: 0n };
    monthlyRows.push({
      month: key,
      label: monthLabel(key),
      inflow: bucket.inflow.toString(),
      outflow: bucket.outflow.toString(),
      reserved: bucket.reserved.toString(),
      net: (bucket.inflow - bucket.outflow).toString(),
    });
  }

  const sourceRows = toSortedArray(sources, ([source, value]) => ({
    source,
    credit: value.credit.toString(),
    debit: value.debit.toString(),
    amount: (value.credit + value.debit).toString(),
  })).sort((a, b) => BigInt(b.amount) > BigInt(a.amount) ? 1 : BigInt(b.amount) < BigInt(a.amount) ? -1 : a.source.localeCompare(b.source));

  const lastBalance = balancePoints.at(-1)?.balance ?? String(wallet.availableBalance ?? '0');

  return {
    version: '1.0',
    currency: 'TOMAN',
    range: { months: safeMonths, from: start.toISOString(), to: end.toISOString() },
    summary: {
      availableBalance: String(wallet.availableBalance ?? lastBalance),
      lockedBalance: String(wallet.lockedBalance ?? '0'),
      totalInflow: totalInflow.toString(),
      totalOutflow: totalOutflow.toString(),
      totalReserved: totalReserved.toString(),
      netCashFlow: (totalInflow - totalOutflow).toString(),
    },
    monthlyCashFlow: monthlyRows,
    balanceTrend: balancePoints.sort((a, b) => a.date.localeCompare(b.date)).slice(-120),
    bySource: sourceRows.slice(0, 12),
  };
}
