export const migration = {
  version: 14,
  name: 'payout_terminal_immutability',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_guard_payout_terminal_immutability() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          IF OLD.status IN ('SUCCEEDED','FAILED') THEN
            RAISE EXCEPTION 'terminal payouts are immutable' USING ERRCODE='55000';
          END IF;
          RETURN OLD;
        END IF;
        IF OLD.status IN ('SUCCEEDED','FAILED') AND NEW IS DISTINCT FROM OLD THEN
          RAISE EXCEPTION 'terminal payouts are immutable' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS payout_terminal_immutability_trigger ON payouts;
      CREATE TRIGGER payout_terminal_immutability_trigger
        BEFORE UPDATE OR DELETE ON payouts
        FOR EACH ROW EXECUTE FUNCTION hope_guard_payout_terminal_immutability();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS payout_terminal_immutability_trigger ON payouts;
      DROP FUNCTION IF EXISTS hope_guard_payout_terminal_immutability();
    `);
  },
};
