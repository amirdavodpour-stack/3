import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const root = new URL('../src/repository/', import.meta.url);
const repoSource = fs.readFileSync(new URL('../src/repository.js', import.meta.url), 'utf8');

const read = (name) => fs.readFileSync(new URL(name, root), 'utf8');

function assertSmallReexportFacade(source, label) {
  const declarations = source.split('\n').map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith('//'));
  assert.ok(declarations.length <= 25, `${label} should expose a bounded set of repository domains`);
  assert.ok(
    declarations.every((line) => /^export \* from ['"]\.\/repository\/[a-z0-9_]+\.js';?$/.test(line)),
    `${label} must contain only repository re-exports, not persistence/business logic`,
  );
}

test('repository domains are physically separated behind a small public facade', () => {
  for (const file of ['context.js', 'core.js', 'auth.js', 'storage.js', 'payments.js', 'payment_queries.js', 'payment_lifecycle.js', 'payment_funding.js', 'payment_refunds.js', 'payment_webhooks.js', 'views.js', 'notifications.js', 'analytics.js']) {
    assert.equal(fs.existsSync(new URL(file, root)), true, `missing repository/${file}`);
  }
  assertSmallReexportFacade(repoSource, 'repository facade');
  for (const file of ['core.js','auth.js','storage.js','payments.js','outbox.js','views.js','notifications.js','analytics.js']) {
    assert.match(repoSource, new RegExp(`repository/${file.replace('.', '\\.')}`));
  }
  const paymentsFacade = read('payments.js');
  for (const file of ['payment_queries.js','payment_lifecycle.js','payment_funding.js','payment_refunds.js','payment_webhooks.js']) {
    assert.match(paymentsFacade, new RegExp(file.replace('.', '\\.' )));
  }
});

test('bounded contexts own their implementations rather than the facade', () => {
  assert.match(read('notifications.js'), /export async function queueNotification/);
  assert.match(read('analytics.js'), /export async function insertAnalyticsEvent/);
  assert.match(read('payment_funding.js'), /export async function fundJobAtomic/);
  assert.match(read('outbox.js'), /export async function claimOutboxEvent/);
  assert.match(read('storage.js'), /export async function completeUploadAtomic/);
  assert.match(read('auth.js'), /export async function rotateRefreshToken/);
  assert.match(read('views.js'), /export async function listJobViews/);
  for (const marker of ['queueNotification','insertAnalyticsEvent','fundJobAtomic','completeUploadAtomic']) {
    assert.doesNotMatch(repoSource, new RegExp(`export async function ${marker}`));
  }
});

test('repository architecture guard keeps bounded contexts independently evolvable', () => {
  const facade = fs.readFileSync(new URL('../src/repository.js', import.meta.url), 'utf8');
  assertSmallReexportFacade(facade, 'public facade');
  for (const file of fs.readdirSync(root).filter((name) => name.endsWith('.js') && !['context.js','mappers.js'].includes(name))) {
    const source = read(file);
    assert.doesNotMatch(source, /from ['"]\.\/\.\/repository\.js['"]/);
    assert.doesNotMatch(source, /from ['"]\.\/repository\.js['"]/);
    assert.ok(source.length <= 26000, `${file} exceeds the bounded-context source-size guard`);
  }
});
