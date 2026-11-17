import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

test('user dispute view does not expose the other party\'s full satisfaction report', () => {
  const source = fs.readFileSync(path.resolve(import.meta.dirname, '../src/routes/job_dispute_routes.js'), 'utf8');
  assert.match(source, /aiReport/);
  assert.doesNotMatch(source, /context:await repo\.getJobDisputeContext\(job\.id\)/);
});

test('user-triggered dispute fails closed to a HOLD/manual-review record when AI is unavailable', () => {
  const source = fs.readFileSync(path.resolve(import.meta.dirname, '../src/routes/job_dispute_routes.js'), 'utf8');
  assert.match(source, /parseDisputeDecision\(null\)/);
});