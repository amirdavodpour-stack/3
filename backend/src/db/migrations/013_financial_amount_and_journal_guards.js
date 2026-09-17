export const migration = {
  version: 13,
  name: 'financial_amount_and_journal_guards',
  async up(client) {
    await client.query(`
      ALTER TABLE wallet_accounts
        ADD CONSTRAINT wallet_accounts_available_max_chk
        CHECK (available_balance <= 9000000000000000),
        ADD CONSTRAINT wallet_accounts_locked_max_chk
        CHECK (locked_balance <= 9000000000000000);

      ALTER TABLE wallet_holds
        ADD CONSTRAINT wallet_holds_amount_max_chk
        CHECK (amount <= 9000000000000000);

      ALTER TABLE wallet_entries
        ADD CONSTRAINT wallet_entries_amount_max_chk
        CHECK (amount <= 9000000000000000),
        ADD CONSTRAINT wallet_entries_balance_after_max_chk
        CHECK (balance_after IS NULL OR balance_after <= 9000000000000000);

      ALTER TABLE payouts
        ADD CONSTRAINT payouts_amount_max_chk
        CHECK (amount <= 9000000000000000);

      ALTER TABLE ledger_entries
        ADD CONSTRAINT ledger_entries_amount_max_chk
        CHECK (
          debit BETWEEN 0 AND 9000000000000000
          AND credit BETWEEN 0 AND 9000000000000000
        );

      CREATE OR REPLACE FUNCTION hope_validate_posted_journal_balance() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        debit_total NUMERIC;
        credit_total NUMERIC;
        entry_count BIGINT;
      BEGIN
        IF NEW.status = 'POSTED' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'POSTED') THEN
          SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
            INTO entry_count, debit_total, credit_total
          FROM ledger_entries
          WHERE journal_id = NEW.id;

          IF entry_count = 0 OR debit_total <> credit_total OR debit_total <= 0 THEN
            RAISE EXCEPTION 'posted journal must be balanced and non-empty' USING ERRCODE='55000';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS journals_posted_balance_trigger ON journals;
      CREATE CONSTRAINT TRIGGER journals_posted_balance_trigger
        AFTER INSERT OR UPDATE OF status ON journals
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION hope_validate_posted_journal_balance();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS journals_posted_balance_trigger ON journals;
      DROP FUNCTION IF EXISTS hope_validate_posted_journal_balance();
      ALTER TABLE ledger_entries
        DROP CONSTRAINT IF EXISTS ledger_entries_amount_max_chk;
      ALTER TABLE payouts
        DROP CONSTRAINT IF EXISTS payouts_amount_max_chk;
      ALTER TABLE wallet_entries
        DROP CONSTRAINT IF EXISTS wallet_entries_amount_max_chk,
        DROP CONSTRAINT IF EXISTS wallet_entries_balance_after_max_chk;
      ALTER TABLE wallet_holds
        DROP CONSTRAINT IF EXISTS wallet_holds_amount_max_chk;
      ALTER TABLE wallet_accounts
        DROP CONSTRAINT IF EXISTS wallet_accounts_available_max_chk,
        DROP CONSTRAINT IF EXISTS wallet_accounts_locked_max_chk;
    `);
  },
};
