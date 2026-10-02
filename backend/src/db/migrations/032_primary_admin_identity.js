export const migration = {
  version: 32,
  name: 'primary_admin_identity',
  async up(client) {
    await client.query(
      `UPDATE users SET role='ADMIN'
       WHERE LOWER(email)=LOWER('amir.davodpour@gmail.com')`,
    );
  },
  async down() {
    // The owner identity is a security invariant and must not be demoted by rollback.
  },
};