export const migration = {
  version: 19,
  name: 'financial_operation_state_guards',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_financial_operation_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'PENDING' THEN next_status IN ('PROCESSING','FAILED','CANCELLED')
          WHEN 'PROCESSING' THEN next_status IN ('SUCCEEDED','FAILED','UNKNOWN','CANCELLED')
          WHEN 'UNKNOWN' THEN next_status IN ('SUCCEEDED','FAILED')
          WHEN 'SUCCEEDED' THEN FALSE
          WHEN 'FAILED' THEN FALSE
          WHEN 'CANCELLED' THEN FALSE
          ELSE FALSE
        END;
      END;
      $$;
      CREATE OR REPLACE FUNCTION hope_guard_financial_operation_state_transition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.status IS DISTINCT FROM OLD.status AND NOT hope_financial_operation_transition_allowed(OLD.status, NEW.status) THEN
          RAISE EXCEPTION 'invalid FINANCIAL_OPERATION state transition: % -> %', OLD.status, NEW.status USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS financial_operation_state_transition_guard ON financial_operations;
      CREATE TRIGGER financial_operation_state_transition_guard
        BEFORE UPDATE ON financial_operations
        FOR EACH ROW EXECUTE FUNCTION hope_guard_financial_operation_state_transition();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS financial_operation_state_transition_guard ON financial_operations;
      DROP FUNCTION IF EXISTS hope_guard_financial_operation_state_transition();
      DROP FUNCTION IF EXISTS hope_financial_operation_transition_allowed(TEXT,TEXT);
    `);
  },
};
