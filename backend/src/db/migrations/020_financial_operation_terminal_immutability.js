export const migration = {
  version: 20,
  name: 'financial_operation_terminal_immutability',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_guard_financial_operation_terminal_immutability() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF OLD.status IN ('SUCCEEDED','FAILED','CANCELLED') AND NEW IS DISTINCT FROM OLD THEN
          RAISE EXCEPTION 'terminal financial operations are immutable' USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS financial_operation_terminal_immutability_trigger ON financial_operations;
      CREATE TRIGGER financial_operation_terminal_immutability_trigger
        BEFORE UPDATE ON financial_operations
        FOR EACH ROW EXECUTE FUNCTION hope_guard_financial_operation_terminal_immutability();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS financial_operation_terminal_immutability_trigger ON financial_operations;
      DROP FUNCTION IF EXISTS hope_guard_financial_operation_terminal_immutability();
    `);
  },
};
