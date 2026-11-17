import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const app = fs.readFileSync(path.join(root, 'backend/src/app.js'), 'utf8');
const workflow = fs.readFileSync(path.join(root, '.github/workflows/staging-certification.yml'), 'utf8');
const regressionWorkflow = fs.readFileSync(path.join(root, '.github/workflows/staging-runtime-sha-gate-regression.yml'), 'utf8');

test('runtime commit identity is exposed only by the authenticated metrics endpoint', () => {
  const metricsBlock = app.match(
    /if \(url\.pathname === '\/metrics'\)[\s\S]*?\n  }\n  if \(url\.pathname\.startsWith\('\/api\/v1\/auth\/'\)/,
  )?.[0] || '';

  assert.ok(metricsBlock, 'metrics route block must be found');
  assert.match(metricsBlock, /config\.metricsToken/);
  assert.match(metricsBlock, /crypto\.timingSafeEqual/);
  assert.match(metricsBlock, /metricsTokenVerified/);
  assert.match(metricsBlock, /if \(metricsTokenVerified\)/);
  assert.match(metricsBlock, /RAILWAY_GIT_COMMIT_SHA/);
  assert.match(metricsBlock, /\^\[a-f0-9\]\{40\}\$/i);

  const liveBlock = app.match(
    /if \(url\.pathname === '\/live'[\s\S]*?\n    }\n    if \(url\.pathname === '\/health'/,
  )?.[0] || '';
  assert.ok(liveBlock, 'liveness route block must be found');
  assert.doesNotMatch(liveBlock, /RAILWAY_GIT_COMMIT_SHA|commitSha|build\.commit/);
});

test('Staging SHA regression workflow runs on pushes to this isolated child branch', () => {
  const pushBlock = regressionWorkflow.match(/push:\s*\n\s*branches:\s*\n([\s\S]*?)\n\s*paths:/)?.[1] || '';
  assert.match(pushBlock, /fix\/hopev2-staging-runtime-sha-redirect-guard-20261117/);
});

test('Staging SHA probe rejects redirects before forwarding the metrics credential', () => {
  const fetchStart = workflow.indexOf('const response = await fetch(metricsUrl, {');
  assert.ok(fetchStart >= 0, 'the authenticated runtime identity request must be present');
  const fetchEnd = workflow.indexOf('          });', fetchStart);
  assert.ok(fetchEnd > fetchStart, 'the metrics request options must be present');
  const requestOptions = workflow.slice(fetchStart, fetchEnd);
  assert.match(requestOptions, /redirect:\s*['\"]error['\"]/);
});

test('Staging fails closed on a deployed-SHA mismatch before any data or provider side effects', () => {
  const identityGate = workflow.indexOf('name: Verify live Staging build SHA');
  assert.ok(identityGate >= 0, 'an explicit live build SHA verification step is required');

  for (const laterSideEffect of [
    'name: Staging external integration gate',
    'name: Staging product workflow',
    'name: Notification delivery',
    'name: S3 runtime probe',
    'name: Staging performance smoke',
    'name: PostHog staging ingestion preflight',
    'name: Start Railway Postgres SSH tunnel for DR',
    'name: DR restore drill',
    'name: Android emulator certification',
  ]) {
    const position = workflow.indexOf(laterSideEffect);
    assert.ok(position > identityGate, `${laterSideEffect} must run after live SHA verification`);
  }

  const stepStart = workflow.lastIndexOf('      - name: Verify live Staging build SHA', identityGate);
  const stepEnd = workflow.indexOf('\n      - name:', identityGate + 1);
  const step = workflow.slice(stepStart, stepEnd < 0 ? undefined : stepEnd);

  assert.match(step, /STAGING_METRICS_TOKEN/);
  assert.match(step, /\/metrics/);
  assert.match(step, /X-Metrics-Token/);
  assert.match(step, /GITHUB_SHA/);
  assert.match(step, /build\?\.commitSha/);
  assert.match(step, /!==/);
  assert.doesNotMatch(step, /continue-on-error:\s*true/);
  assert.match(workflow, /certification_sha=\$\{GITHUB_SHA\}/);
});
