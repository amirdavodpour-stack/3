import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const workflowPath = path.join(root, '.github/workflows/hopev2-free-staging-validation.yml');

test('Free Staging CI runs only on the isolated branch and PRs targeting its Candidate base', () => {
  assert.equal(fs.existsSync(workflowPath), true, 'dedicated Free Staging workflow must exist');
  const workflow = fs.readFileSync(workflowPath, 'utf8');
  assert.match(workflow, /push:[\s\S]*branches:[\s\S]*integration\/hopev2-free-staging-serverless-20261119/);
  assert.match(workflow, /pull_request:[\s\S]*branches:[\s\S]*integration\/hopev2-combined-candidate-runtime-sdk-retry-20261118/);
  assert.match(workflow, /backend\/\*\*/);
  assert.match(workflow, /render\.yaml/);
});

test('Free Staging CI runs bounded backend checks and has no deploy or secret permissions', () => {
  const workflow = fs.readFileSync(workflowPath, 'utf8');
  for (const command of [
    'npm ci --no-audit --no-fund',
    'npm run check',
    'npm run check:migrations',
    'npm run test:fast',
    'npm audit --audit-level=high',
  ]) {
    assert.ok(workflow.includes(command), `missing CI command: ${command}`);
  }
  assert.match(workflow, /permissions:\s*\n\s*contents:\s*read/);
  assert.doesNotMatch(workflow, /secrets\.|environment:\s*production|deploy|railway|vercel|render deploy/i);
});
