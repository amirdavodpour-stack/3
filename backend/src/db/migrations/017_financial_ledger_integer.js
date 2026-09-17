export const migration = {
  version: 17,
  name: 'financial_ledger_integer',
  async up(client) {
    await client.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM ledger_entries WHERE debit <> TRUNC(debit) OR credit <> TRUNC(credit)) THEN
          RAISE EXCEPTION 'Cannot convert ledger amounts to BIGINT: fractional values exist';
        END IF;
        IF EXISTS (SELECT 1 FROM ledger_entries WHERE debit < 0 OR credit < 0 OR debit > 9000000000000000 OR credit > 9000000000000000) THEN
          RAISE EXCEPTION 'Cannot convert ledger amounts to BIGINT: out-of-range values exist';
        END IF;
      END $$;
      ALTER TABLE ledger_entries
        ALTER COLUMN debit TYPE BIGINT USING debit::BIGINT,
        ALTER COLUMN credit TYPE BIGINT USING credit::BIGINT;
    `);
  },
  async down(client) {
    await client.query(`
      ALTER TABLE ledger_entries
        ALTER COLUMN debit TYPE NUMERIC(18,2) USING debit::NUMERIC(18,2),
        ALTER COLUMN credit TYPE NUMERIC(18,2) USING credit::NUMERIC(18,2);
    `);
  },
};
