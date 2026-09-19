export const migration = {
  version: 26,
  name: 'payment_refund_job_transition',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_job_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'DRAFT' THEN next_status IN ('PUBLISHED','CANCELLED')
          WHEN 'PUBLISHED' THEN next_status IN ('ASSIGNED','CANCELLED')
          WHEN 'ASSIGNED' THEN next_status IN ('FUNDED','PUBLISHED','CANCELLED')
          WHEN 'FUNDED' THEN next_status IN ('IN_PROGRESS','PUBLISHED','ASSIGNED')
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
    `);
  },
  async down(client) {
    await client.query(`
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
    `);
  },
};
