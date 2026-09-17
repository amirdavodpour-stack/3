export const migration = {
  version: 12,
  name: 'payout_state_guards',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_payout_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'REQUESTED' THEN next_status IN ('RESERVED','FAILED')
          WHEN 'RESERVED' THEN next_status IN ('PROCESSING','SUCCEEDED','FAILED','UNKNOWN')
          WHEN 'PROCESSING' THEN next_status IN ('SUCCEEDED','FAILED','UNKNOWN')
          WHEN 'UNKNOWN' THEN next_status IN ('SUCCEEDED','FAILED')
          WHEN 'SUCCEEDED' THEN FALSE
          WHEN 'FAILED' THEN FALSE
          ELSE FALSE
        END;
      END;
      $$;

      CREATE OR REPLACE FUNCTION hope_guard_payout_state_transition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.status IS DISTINCT FROM OLD.status
           AND NOT hope_payout_transition_allowed(OLD.status, NEW.status) THEN
          RAISE EXCEPTION 'invalid PAYOUT state transition: % -> %', OLD.status, NEW.status USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS payout_state_transition_guard ON payouts;
      CREATE TRIGGER payout_state_transition_guard
        BEFORE UPDATE ON payouts
        FOR EACH ROW EXECUTE FUNCTION hope_guard_payout_state_transition();

      CREATE OR REPLACE FUNCTION hope_guard_payout_identity_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND (
          NEW.id <> OLD.id
          OR NEW.wallet_id <> OLD.wallet_id
          OR NEW.user_id <> OLD.user_id
          OR NEW.amount <> OLD.amount
          OR NEW.currency <> OLD.currency
          OR NEW.provider <> OLD.provider
          OR NEW.idempotency_key <> OLD.idempotency_key
          OR NEW.created_at <> OLD.created_at
        ) THEN
          RAISE EXCEPTION 'PAYOUT identity is immutable' USING ERRCODE='55000';
        END IF;
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'payouts are immutable' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS payout_identity_immutable_trigger ON payouts;
      CREATE TRIGGER payout_identity_immutable_trigger
        BEFORE UPDATE OR DELETE ON payouts
        FOR EACH ROW EXECUTE FUNCTION hope_guard_payout_identity_mutation();

      ALTER TABLE payouts
        ADD CONSTRAINT payouts_terminal_timestamp_chk
        CHECK (
          (status IN ('SUCCEEDED','FAILED') AND completed_at IS NOT NULL)
          OR
          (status IN ('REQUESTED','RESERVED','PROCESSING','UNKNOWN') AND completed_at IS NULL)
        );
    `);
  },
  async down(client) {
    await client.query(`
      ALTER TABLE payouts DROP CONSTRAINT IF EXISTS payouts_terminal_timestamp_chk;
      DROP TRIGGER IF EXISTS payout_identity_immutable_trigger ON payouts;
      DROP FUNCTION IF EXISTS hope_guard_payout_identity_mutation();
      DROP TRIGGER IF EXISTS payout_state_transition_guard ON payouts;
      DROP FUNCTION IF EXISTS hope_guard_payout_state_transition();
      DROP FUNCTION IF EXISTS hope_payout_transition_allowed(TEXT,TEXT);
    `);
  },
};
