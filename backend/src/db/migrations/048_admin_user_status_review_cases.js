export const migration = {
  version: 48,
  name: 'admin_user_status_review_cases',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS admin_user_status_review_cases (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        status TEXT NOT NULL DEFAULT 'OPEN'
          CHECK (status IN ('OPEN','RESOLVED')),
        reason TEXT NOT NULL
          CHECK (char_length(btrim(reason)) BETWEEN 3 AND 1000),
        created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        review_due_at TIMESTAMPTZ NOT NULL,
        resolved_by UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
        resolved_at TIMESTAMPTZ NULL,
        resolution_reason TEXT NULL,
        CONSTRAINT admin_user_status_review_due_check
          CHECK (review_due_at > created_at),
        CONSTRAINT admin_user_status_review_resolution_check
          CHECK (
            (status='OPEN' AND resolved_by IS NULL AND resolved_at IS NULL AND resolution_reason IS NULL)
            OR
            (
              status='RESOLVED'
              AND resolved_by IS NOT NULL
              AND resolved_at IS NOT NULL
              AND resolved_at >= created_at
              AND resolution_reason IS NOT NULL
              AND char_length(btrim(resolution_reason)) BETWEEN 3 AND 1000
            )
          )
      );
      CREATE UNIQUE INDEX IF NOT EXISTS admin_user_status_one_open_review_uq
        ON admin_user_status_review_cases(user_id)
        WHERE status='OPEN';
      CREATE INDEX IF NOT EXISTS admin_user_status_review_queue_idx
        ON admin_user_status_review_cases(review_due_at,created_at,id)
        WHERE status='OPEN';
    `);
  },
  async down(client) {
    const { rows } = await client.query(
      'SELECT EXISTS(SELECT 1 FROM admin_user_status_review_cases) AS has_cases',
    );
    if (rows[0]?.has_cases) {
      throw new Error('Cannot rollback admin status review cases while human-review history exists');
    }
    await client.query(`
      DROP INDEX IF EXISTS admin_user_status_review_queue_idx;
      DROP INDEX IF EXISTS admin_user_status_one_open_review_uq;
      DROP TABLE IF EXISTS admin_user_status_review_cases;
    `);
  },
};
