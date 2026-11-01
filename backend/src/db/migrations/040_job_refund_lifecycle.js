export const migration = {
  version: 40,
  name: 'job_refund_lifecycle',
  async up(client) {
    await client.query(\`
      CREATE OR REPLACE FUNCTION hope_job_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'DRAFT' THEN next_status IN ('PUBLISHED','CANCELLED')
          WHEN 'PUBLISHED' THEN next_status IN ('ASSIGNED','CANCELLED')
          WHEN 'ASSIGNED' THEN next_status IN ('FUNDED','PUBLISHED','CANCELLED')
          WHEN 'FUNDED' THEN next_status IN ('IN_PROGRESS','PUBLISHED','CANCELLED')
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

      CREATE OR REPLACE FUNCTION hope_guard_job_state_transition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE linked_payment_status TEXT;
      BEGIN
        IF NEW.status IS DISTINCT FROM OLD.status AND NOT hope_job_transition_allowed(OLD.status, NEW.status) THEN
          RAISE EXCEPTION 'invalid JOB state transition: % -> %', OLD.status, NEW.status USING ERRCODE='55000';
        END IF;
        IF OLD.status='FUNDED' AND NEW.status='IN_PROGRESS' THEN
          SELECT status INTO linked_payment_status
            FROM payments
           WHERE job_id=OLD.id
           ORDER BY created_at DESC,id DESC
           LIMIT 1
           FOR UPDATE;
          IF linked_payment_status IS DISTINCT FROM 'HELD' THEN
            RAISE EXCEPTION 'funded job cannot start unless its payment is HELD (current: %)', COALESCE(linked_payment_status,'missing') USING ERRCODE='55000';
          END IF;
        END IF;
        RETURN NEW;
      END;
      $$;
    \`);
  },
  async down(client) {
    await client.query(\`
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

      CREATE OR REPLACE FUNCTION hope_guard_job_state_transition() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.status IS DISTINCT FROM OLD.status AND NOT hope_job_transition_allowed(OLD.status, NEW.status) THEN
          RAISE EXCEPTION 'invalid JOB state transition: % -> %', OLD.status, NEW.status USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $$;
    \`);
  },
};
