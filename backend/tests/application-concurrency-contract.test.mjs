import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const moduleSource = fs.readFileSync(new URL('../src/repository/applications.js', import.meta.url), 'utf8');
const employerStart = moduleSource.indexOf('export async function transitionEmployerApplication(');
const source = employerStart >= 0 ? moduleSource.slice(employerStart) : moduleSource;

test('employer application lifecycle locks the job aggregate before the application row', () => {
  const lockJob = source.indexOf('SELECT id,owner_id,kind,status FROM jobs');
  const lockApplication = source.indexOf('SELECT * FROM job_applications WHERE id=$1 FOR UPDATE');
  assert.ok(lockJob >= 0, 'job row must be locked');
  assert.ok(lockApplication > lockJob, 'application lock must follow job lock');
});

test('accepted application writes job assignment under the same transaction and aggregate lock', () => {
  assert.match(source, /UPDATE job_applications SET status=\$2,updated_at=NOW\(\) WHERE id=\$1 RETURNING \*/);
  assert.match(source, /UPDATE jobs[\s\S]*SET provider_id=\$2,status='ASSIGNED'/);
  assert.match(source, /return withSqlTransaction\(async\(client\)=>/);
});
