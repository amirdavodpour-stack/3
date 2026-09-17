export const migration = {
  version: 21,
  name: 'refund_currency',
  async up(client) {
    await client.query(`
      ALTER TABLE refunds ADD COLUMN IF NOT EXISTS currency TEXT;
      UPDATE refunds r SET currency = COALESCE(p.currency, 'USD')
      FROM payments p WHERE p.id = r.payment_id AND r.currency IS NULL;
      UPDATE refunds SET currency='USD' WHERE currency IS NULL;
      ALTER TABLE refunds ALTER COLUMN currency SET DEFAULT 'USD';
      ALTER TABLE refunds ALTER COLUMN currency SET NOT NULL;
      ALTER TABLE refunds DROP CONSTRAINT IF EXISTS refunds_currency_chk;
      ALTER TABLE refunds ADD CONSTRAINT refunds_currency_chk CHECK (currency IN ('TOMAN','USD','EUR','IRR'));
    `);
  },
  async down(client) {
    await client.query(`ALTER TABLE refunds DROP CONSTRAINT IF EXISTS refunds_currency_chk; ALTER TABLE refunds DROP COLUMN IF EXISTS currency;`);
  },
};
