export const migration = {
  version: 25,
  name: 'payment_refund_pending_transition',
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
    `);
  },
  async down(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_payment_transition_allowed(current_status TEXT, next_status TEXT) RETURNS BOOLEAN
      LANGUAGE plpgsql IMMUTABLE AS $$
      BEGIN
        IF current_status = next_status THEN RETURN TRUE; END IF;
        RETURN CASE current_status
          WHEN 'HOLD_PENDING' THEN next_status IN ('HELD','HOLD_FAILED')
          WHEN 'HOLD_FAILED' THEN next_status = 'HOLD_PENDING'
          WHEN 'HELD' THEN next_status IN ('RELEASE_PENDING','REFUNDED')
          WHEN 'RELEASE_PENDING' THEN next_status IN ('RELEASED','RELEASE_FAILED')
          WHEN 'RELEASE_FAILED' THEN next_status = 'RELEASE_PENDING'
          WHEN 'RELEASED' THEN FALSE
          WHEN 'REFUNDED' THEN FALSE
          ELSE FALSE
        END;
      END;
      $$;
    `);
  },
};
