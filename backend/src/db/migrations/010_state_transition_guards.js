export const migration = {
  version: 10,
  name: 'state_transition_guards',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_payment_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'HOLD_PENDING' THEN next_status IN ('HELD','HOLD_FAILED')
          WHEN 'HOLD_FAILED' THEN next_status = 'HOLD_PENDING'
          WHEN 'HELD' THEN next_status IN ('RELEASE_PENDING','REFUND_PENDING')
          WHEN 'REFUND_PENDING' THEN next_status IN ('REFUNDED','HELD')
          WHEN 'RELEASE_PENDING' THEN next_status IN ('RELEASED','RELEASE_FAILED')
          WHEN 'RELEASE_FAILED' THEN next_status = 'RELEASE_PENDING'
          WHEN 'RELEASED' THEN FALSE
          WHEN 'REFUNDED' THEN FALSE
          ELSE FALSE
        END;
      END;
      $$;

      CREATE OR REPLACE FUNCTION hope_job_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'DRAFT' THEN next_status IN ('PUBLISHED','CANCELLED')
          WHEN 'PUBLISHED' THEN next_status IN ('ASSIGNED','CANCELLED')
          WHEN 'ASSIGNED' THEN next_status IN ('FUNDED','PUBLISHED','CANCELLED')
          WHEN 'FUNDED' THEN next_status IN ('IN_PROGRESS','PUBLISHED')
          WHEN 'IN_PROGRESS' THEN next_status = 'DELIVERED'
          WHEN 'DELIVERED' THEN next_status IN ('UNDER_REVIEW','COMPLETED')
          WHEN 'UNDER_REVIEW' THEN next_status = 'COMPLETED'
          WHEN 'COMPLETED' THEN next_status = 'SETTLED'
          WHEN 'SETTLED' THEN FALSE
          WHEN 'CANCELLED' THEN FALSE
          ELSE FALSE
        END;
      END;
      $$;

      CREATE OR REPLACE FUNCTION hope_guard_payment_state_transition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.status IS DISTINCT FROM OLD.status AND NOT hope_payment_transition_allowed(OLD.status, NEW.status) THEN
          RAISE EXCEPTION 'invalid PAYMENT state transition: % -> %', OLD.status, NEW.status USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS payment_state_transition_guard ON payments;
      CREATE TRIGGER payment_state_transition_guard
        BEFORE UPDATE ON payments
        FOR EACH ROW EXECUTE FUNCTION hope_guard_payment_state_transition();

      CREATE OR REPLACE FUNCTION hope_guard_job_state_transition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.status IS DISTINCT FROM OLD.status AND NOT hope_job_transition_allowed(OLD.status, NEW.status) THEN
          RAISE EXCEPTION 'invalid JOB state transition: % -> %', OLD.status, NEW.status USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
      DROP TRIGGER IF EXISTS job_state_transition_guard ON jobs;
      CREATE TRIGGER job_state_transition_guard
        BEFORE UPDATE ON jobs
        FOR EACH ROW EXECUTE FUNCTION hope_guard_job_state_transition();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS job_state_transition_guard ON jobs;
      DROP FUNCTION IF EXISTS hope_guard_job_state_transition();
      DROP TRIGGER IF EXISTS payment_state_transition_guard ON payments;
      DROP FUNCTION IF EXISTS hope_guard_payment_state_transition();
      DROP FUNCTION IF EXISTS hope_job_transition_allowed(TEXT,TEXT);
      DROP FUNCTION IF EXISTS hope_payment_transition_allowed(TEXT,TEXT);
    `);
  },
};
