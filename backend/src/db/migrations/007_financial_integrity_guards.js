export const migration = {
  version: 7,
  name: 'financial_integrity_guards',
  async up(client) {
    await client.query(`
      ALTER TABLE wallet_accounts
        ADD CONSTRAINT wallet_accounts_nonnegative_chk
        CHECK (available_balance >= 0 AND locked_balance >= 0);

      ALTER TABLE financial_operations
        ADD CONSTRAINT financial_operations_completed_at_chk
        CHECK (
          (status IN ('SUCCEEDED','FAILED','CANCELLED') AND completed_at IS NOT NULL)
          OR
          (status IN ('PENDING','PROCESSING','UNKNOWN') AND completed_at IS NULL)
        );

      CREATE OR REPLACE FUNCTION hope_reject_immutable_wallet_entry() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'wallet_entries are immutable' USING ERRCODE='55000';
      END;
      $$;
      DROP TRIGGER IF EXISTS wallet_entries_immutable_trigger ON wallet_entries;
      CREATE TRIGGER wallet_entries_immutable_trigger
        BEFORE UPDATE OR DELETE ON wallet_entries
        FOR EACH ROW EXECUTE FUNCTION hope_reject_immutable_wallet_entry();

      CREATE OR REPLACE FUNCTION hope_reject_posted_journal_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.status = 'POSTED' THEN
          IF TG_OP <> 'UPDATE'
             OR NEW.id <> OLD.id
             OR NEW.operation_id <> OLD.operation_id
             OR NEW.journal_type <> OLD.journal_type
             OR NEW.currency <> OLD.currency
             OR NEW.status <> OLD.status
             OR NEW.created_at <> OLD.created_at
             OR NEW.posted_at <> OLD.posted_at THEN
            RAISE EXCEPTION 'posted journals are immutable' USING ERRCODE='55000';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS journals_posted_immutable_trigger ON journals;
      CREATE TRIGGER journals_posted_immutable_trigger
        BEFORE UPDATE OR DELETE ON journals
        FOR EACH ROW EXECUTE FUNCTION hope_reject_posted_journal_mutation();

      CREATE OR REPLACE FUNCTION hope_reject_financial_operation_identity_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND (
          NEW.id <> OLD.id
          OR NEW.operation_type <> OLD.operation_type
          OR NEW.actor_type <> OLD.actor_type
          OR NEW.actor_id IS DISTINCT FROM OLD.actor_id
          OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
        ) THEN
          RAISE EXCEPTION 'financial operation identity is immutable' USING ERRCODE='55000';
        END IF;
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'financial operations are immutable' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS financial_operations_identity_trigger ON financial_operations;
      CREATE TRIGGER financial_operations_identity_trigger
        BEFORE UPDATE OR DELETE ON financial_operations
        FOR EACH ROW EXECUTE FUNCTION hope_reject_financial_operation_identity_mutation();

      CREATE OR REPLACE FUNCTION hope_reject_wallet_identity_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.id <> OLD.id
           OR NEW.user_id <> OLD.user_id
           OR NEW.currency <> OLD.currency
           OR NEW.created_at <> OLD.created_at THEN
          RAISE EXCEPTION 'wallet identity is immutable' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS wallet_identity_immutable_trigger ON wallet_accounts;
      CREATE TRIGGER wallet_identity_immutable_trigger
        BEFORE UPDATE ON wallet_accounts
        FOR EACH ROW EXECUTE FUNCTION hope_reject_wallet_identity_mutation();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS wallet_identity_immutable_trigger ON wallet_accounts;
      DROP FUNCTION IF EXISTS hope_reject_wallet_identity_mutation();
      DROP TRIGGER IF EXISTS financial_operations_identity_trigger ON financial_operations;
      DROP FUNCTION IF EXISTS hope_reject_financial_operation_identity_mutation();
      DROP TRIGGER IF EXISTS journals_posted_immutable_trigger ON journals;
      DROP FUNCTION IF EXISTS hope_reject_posted_journal_mutation();
      DROP TRIGGER IF EXISTS wallet_entries_immutable_trigger ON wallet_entries;
      DROP FUNCTION IF EXISTS hope_reject_immutable_wallet_entry();
      ALTER TABLE financial_operations DROP CONSTRAINT IF EXISTS financial_operations_completed_at_chk;
      ALTER TABLE wallet_accounts DROP CONSTRAINT IF EXISTS wallet_accounts_nonnegative_chk;
    `);
  },
};
