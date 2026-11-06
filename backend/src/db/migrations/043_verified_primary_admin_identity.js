export const migration = {
  version: 43,
  name: 'verified_primary_admin_identity',
  async up(client) {
    // Migration 032 historically promoted the canonical email by address alone.
    // Until that account has a Google subject linked through the authenticated,
    // provider-verified account-link route, it must not retain an ADMIN role.
    // This is a forward-only repair: verified linked owners and operational admins
    // are untouched, and any stale panel verification on an unlinked owner is cleared.
    await client.query(`
      UPDATE users
         SET role='USER',
             admin_panel_verified_at=NULL,
             admin_panel_verified_session_jti=NULL
       WHERE LOWER(email)=LOWER('amir.davodpour@gmail.com')
         AND role='ADMIN'
         AND NULLIF(BTRIM(google_subject),'') IS NULL
    `);
  },
  async down() {
    throw new Error(
      'Migration 043 is a security invariant and cannot be rolled back; recover the primary owner through verified Google account linking.',
    );
  },
};
