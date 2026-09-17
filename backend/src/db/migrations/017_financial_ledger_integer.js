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
      DROP TRIGGER IF EXISTS ledger_journal_balance_deferred ON ledger_entries;
      ALTER TABLE ledger_entries
        ALTER COLUMN debit TYPE BIGINT USING debit::BIGINT,
        ALTER COLUMN credit TYPE BIGINT USING credit::BIGINT;
      CREATE CONSTRAINT TRIGGER ledger_journal_balance_deferred
        AFTER INSERT OR UPDATE OF debit,credit,journal_id OR DELETE ON ledger_entries
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION hope_assert_ledger_journal_balanced();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS ledger_journal_balance_deferred ON ledger_entries;
      ALTER TABLE ledger_entries
        ALTER COLUMN debit TYPE NUMERIC(18,2) USING debit::NUMERIC(18,2),
        ALTER COLUMN credit TYPE NUMERIC(18,2) USING credit::NUMERIC(18,2);
      CREATE CONSTRAINT TRIGGER ledger_journal_balance_deferred
        AFTER INSERT OR UPDATE OF debit,credit,journal_id OR DELETE ON ledger_entries
        DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION hope_assert_ledger_journal_balanced();
    `);
  },
};
