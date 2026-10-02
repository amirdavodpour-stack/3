export const migration = {
  version: 32,
  name: 'primary_admin_bootstrap',
  async up(client) {
    await client.query(`
      UPDATE users
      SET role='ADMIN'
      WHERE LOWER(email)=LOWER('amir.davodpour@gmail.com');
    `);
  },
  async down(client) {
    await client.query(`
      UPDATE users
      SET role='USER'
      WHERE LOWER(email)=LOWER('amir.davodpour@gmail.com')
        AND role='ADMIN';
    `);
  },
};