import test from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';

const { Client } = pg;
const enabled = process.env.SUPABASE_STORAGE_RLS_INTEGRATION === '1';
const databaseUrl = process.env.DATABASE_URL || '';

if (enabled && !databaseUrl) throw new Error('SUPABASE_STORAGE_RLS_INTEGRATION=1 requires DATABASE_URL');

test('Supabase Storage RLS prevents cross-user reads/deletes while allowing owner access', { skip: !enabled }, async () => {
  const client = new Client({ connectionString: databaseUrl, ssl: { rejectUnauthorized: false } });
  await client.connect();
  const objectId = '33333333-3333-3333-3333-333333333333';
  const ownerId = '11111111-1111-1111-1111-111111111111';
  const otherId = '22222222-2222-2222-2222-222222222222';
  const objectName = `${ownerId}/rls-ci-${objectId}.txt`;
  try {
    await client.query('BEGIN');
    await client.query('SET LOCAL ROLE authenticated');
    await client.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: ownerId, role: 'authenticated' })]);

    await client.query(
      `insert into storage.objects(id,bucket_id,name,owner_id,metadata)
       values ($1,'v2hope-private',$2,$3,'{"mimetype":"text/plain","size":4}'::jsonb)`,
      [objectId, objectName, ownerId],
    );

    const own = await client.query(`select count(*)::int as count from storage.objects where id=$1`, [objectId]);
    assert.equal(Number(own.rows[0].count), 1, 'owner must be able to read own private object metadata');

    await client.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: otherId, role: 'authenticated' })]);
    const other = await client.query(`select count(*)::int as count from storage.objects where id=$1`, [objectId]);
    assert.equal(Number(other.rows[0].count), 0, 'other user must not read private object metadata');

    const deletedByOther = await client.query(`delete from storage.objects where id=$1`, [objectId]);
    assert.equal(deletedByOther.rowCount, 0, 'other user must not delete private object');

    await client.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: ownerId, role: 'authenticated' })]);
    const deletedByOwner = await client.query(`delete from storage.objects where id=$1`, [objectId]);
    assert.equal(deletedByOwner.rowCount, 1, 'owner must be able to delete own private object');

    await client.query('ROLLBACK');
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch {}
    throw error;
  } finally {
    await client.end();
  }
});