import test from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';

const { Client } = pg;
const enabled = process.env.SUPABASE_STORAGE_RLS_INTEGRATION === '1';
const databaseUrl = process.env.SUPABASE_STORAGE_DATABASE_URL || process.env.DATABASE_URL || '';

if (enabled && !databaseUrl) throw new Error('SUPABASE_STORAGE_RLS_INTEGRATION=1 requires SUPABASE_STORAGE_DATABASE_URL or DATABASE_URL');

test('Supabase Storage RLS prevents cross-user reads/updates and enforces owner-folder inserts', { skip: !enabled }, async () => {
  const client = new Client({ connectionString: databaseUrl, ssl: { rejectUnauthorized: false } });
  await client.connect();
  const objectId = '33333333-3333-3333-3333-333333333333';
  const otherObjectId = '44444444-4444-4444-4444-444444444444';
  const ownerId = '11111111-1111-1111-1111-111111111111';
  const otherId = '22222222-2222-2222-2222-222222222222';
  const objectName = `${ownerId}/rls-ci-${objectId}.txt`;
  const otherOwnName = `${otherId}/rls-ci-${otherObjectId}.txt`;
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
    await client.query('SAVEPOINT cross_user_insert');
    try {
      await assert.rejects(
        () => client.query(
          `insert into storage.objects(id,bucket_id,name,owner_id,metadata)
           values ($1,'v2hope-private',$2,$3,'{"mimetype":"text/plain","size":4}'::jsonb)`,
          [otherObjectId, `${ownerId}/rls-ci-${otherObjectId}.txt`, otherId],
        ),
        /row-level security|permission denied/i,
        'other user must not insert into another user folder',
      );
    } finally {
      await client.query('ROLLBACK TO SAVEPOINT cross_user_insert');
      await client.query('RELEASE SAVEPOINT cross_user_insert');
    }

    const correctFolderInsert = await client.query(
      `insert into storage.objects(id,bucket_id,name,owner_id,metadata)
       values ($1,'v2hope-private',$2,$3,'{"mimetype":"text/plain","size":4}'::jsonb)`,
      [otherObjectId, otherOwnName, otherId],
    );
    assert.equal(correctFolderInsert.rowCount, 1, 'other user must be able to insert into own folder');

    const otherRead = await client.query(`select count(*)::int as count from storage.objects where id=$1`, [objectId]);
    assert.equal(Number(otherRead.rows[0].count), 0, 'other user must not read private object metadata');

    const otherUpdate = await client.query(
      `update storage.objects set metadata='{"mimetype":"text/plain","size":9}'::jsonb where id=$1`,
      [objectId],
    );
    assert.equal(otherUpdate.rowCount, 0, 'other user must not update private object');

    await client.query(`select set_config('request.jwt.claims', $1, true)`, [JSON.stringify({ sub: ownerId, role: 'authenticated' })]);
    const ownerUpdate = await client.query(
      `update storage.objects set metadata='{"mimetype":"text/plain","size":8}'::jsonb where id=$1`,
      [objectId],
    );
    assert.equal(ownerUpdate.rowCount, 1, 'owner must be able to update own private object');

    // Supabase deliberately blocks direct SQL DELETE on storage.objects via protect_delete();
    // delete authorization is therefore verified through pg_policies rather than by direct DML.
    const deletePolicy = await client.query(`
      select count(*)::int as count
      from pg_policies
      where schemaname='storage' and tablename='objects'
        and policyname='v2hope_private_delete_own_objects'
        and cmd='DELETE'
        and roles @> ARRAY['authenticated']::name[]
        and qual like '%owner_id%auth.uid()%'
    `);
    assert.equal(Number(deletePolicy.rows[0].count), 1, 'private delete policy must remain owner-scoped for authenticated users');

    await client.query('ROLLBACK');
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch {}
    throw error;
  } finally {
    await client.end();
  }
});