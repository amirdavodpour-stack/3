export const migration = {
  version: 50,
  name: 'primary_admin_identity_policy_audit',
  async up(client) {
    await client.query(`
      WITH owner_state AS MATERIALIZED (
        SELECT u.id,u.role AS previous_role
          FROM users u
         WHERE LOWER(u.email)=LOWER('amir.davodpour@gmail.com')
           AND NULLIF(BTRIM(u.google_subject),'') IS NULL
           AND u.status <> 'DELETED'
           AND NOT EXISTS (
             SELECT 1
               FROM audit_logs a
              WHERE a.action='PRIMARY_ADMIN_IDENTITY_POLICY_ENFORCED'
                AND a.entity_id=u.id
                AND a.meta->>'migrationVersion'='50'
           )
         FOR UPDATE OF u
      ),
      affected AS (
        UPDATE users u
           SET role='USER',
               session_version=session_version+1,
               admin_panel_verified_at=NULL,
               admin_panel_verified_session_jti=NULL,
               admin_panel_verified_scope=NULL
          FROM owner_state o
         WHERE u.id=o.id
        RETURNING u.id,u.session_version
      ),
      revoked AS (
        UPDATE refresh_tokens rt
           SET revoked_at=COALESCE(rt.revoked_at,NOW())
          FROM affected a
         WHERE rt.user_id=a.id AND rt.revoked_at IS NULL
        RETURNING rt.user_id
      )
      INSERT INTO audit_logs(
        id,action,actor_id,entity_type,entity_id,meta,created_at
      )
      SELECT
        gen_random_uuid(),
        'PRIMARY_ADMIN_IDENTITY_POLICY_ENFORCED',
        NULL,
        'user',
        a.id,
        jsonb_build_object(
          'migrationVersion',50,
          'reason','Canonical primary administrator requires a linked, provider-verified Google subject',
          'provider','google',
          'googleSubjectLinked',false,
          'previousRole',o.previous_role,
          'effectiveRole','USER',
          'sessionVersion',a.session_version,
          'refreshTokensRevoked',(SELECT COUNT(*)::int FROM revoked r WHERE r.user_id=a.id)
        ),
        NOW()
      FROM affected a
      JOIN owner_state o ON o.id=a.id
    `);
  },
  async down() {
    throw new Error(
      'Migration 050 is a primary-admin security audit/invalidation invariant and cannot be rolled back.',
    );
  },
};
