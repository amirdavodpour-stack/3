export const migration = {
  version: 15,
  name: 'payout_provider_ref_guards',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_guard_payout_provider_ref() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD.provider_ref IS NOT NULL AND NEW.provider_ref IS DISTINCT FROM OLD.provider_ref THEN
          RAISE EXCEPTION 'payout provider_ref is write-once' USING ERRCODE='55000';
        END IF;
        IF NEW.provider_ref IS NOT NULL AND NEW.status <> 'SUCCEEDED' THEN
          RAISE EXCEPTION 'provider_ref is only valid for SUCCEEDED payouts' USING ERRCODE='55000';
        END IF;
        IF NEW.status = 'SUCCEEDED' AND NULLIF(BTRIM(NEW.provider_ref), '') IS NULL THEN
          RAISE EXCEPTION 'SUCCEEDED payout requires provider_ref' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS payout_provider_ref_guard ON payouts;
      CREATE TRIGGER payout_provider_ref_guard
        BEFORE INSERT OR UPDATE ON payouts
        FOR EACH ROW EXECUTE FUNCTION hope_guard_payout_provider_ref();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS payout_provider_ref_guard ON payouts;
      DROP FUNCTION IF EXISTS hope_guard_payout_provider_ref();
    `);
  },
};
