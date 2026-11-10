import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFile } from 'node:fs/promises';
import worker from '../cloudflare-collector/src/worker.mjs';

const migration = await readFile(new URL('../cloudflare-collector/migrations/0001_init.sql', import.meta.url), 'utf8');
const ingestSecret = 'ingest-secret-used-only-by-local-tests-32';
const readSecret = 'readback-secret-used-only-by-local-tests-32';
const eventId = '5a2fd1d8-ae0e-4f53-ae67-4d7723db9db1';
let sequence = 0;

class Statement {
  constructor(db, sql, params) { Object.assign(this, { db, sql, params }); }
  before() {
    this.db.queries.push(this.sql.trim().replace(/\s+/g, ' '));
    if (this.db.failReceiptWrite && /^INSERT OR IGNORE INTO collector_receipts/i.test(this.sql.trim())) throw new Error('simulated receipt insert failure');
    if (this.db.failReceiptRead && /^SELECT .*FROM collector_receipts/is.test(this.sql.trim())) throw new Error('simulated receipt read failure');
    if (this.db.failBudget && /^\s*INSERT INTO collector_daily_budget/i.test(this.sql)) throw new Error(this.db.quotaMessage);
  }
  sync() {
    this.before();
    const q = this.db.sqlite.prepare(this.sql);
    if (/^\s*SELECT\b/i.test(this.sql)) return { results: q.all(...this.params), meta: { changes: 0 } };
    const r = q.run(...this.params);
    return { meta: { changes: Number(r.changes) } };
  }
  async run() { this.before(); const r = this.db.sqlite.prepare(this.sql).run(...this.params); return { meta: { changes: Number(r.changes) } }; }
  async first() { this.before(); return this.db.sqlite.prepare(this.sql).get(...this.params) || null; }
  async all() { this.before(); return { results: this.db.sqlite.prepare(this.sql).all(...this.params) }; }
}
class D1Fake {
  constructor() {
    this.sqlite = new DatabaseSync(':memory:');
    this.sqlite.exec(migration);
    this.queries = [];
    this.failReceiptWrite = false;
    this.failReceiptRead = false;
    this.failBudget = false;
    this.quotaMessage = "Your account has exceeded D1's free tier daily row write limit";
  }
  prepare(sql) { return { bind: (...params) => new Statement(this, sql, params) }; }
  async batch(statements) {
    this.sqlite.exec('BEGIN');
    try {
      const results = statements.map(statement => statement.sync());
      this.sqlite.exec('COMMIT');
      return results;
    } catch (error) {
      this.sqlite.exec('ROLLBACK');
      throw error;
    }
  }
  close() { this.sqlite.close(); }
}
const makeEnv = (DB = new D1Fake()) => ({ DB, HOPE_INGEST_HMAC_SECRET: ingestSecret, HOPE_READBACK_HMAC_SECRET: readSecret });
const event = (extra = {}) => ({
  schemaVersion: 1, eventId, source: 'hope-api', severity: 'page',
  eventType: 'AUTH_REFRESH_REUSE_DETECTED', occurredAt: '2026-11-10T12:00:00.000Z', ...extra,
});
async function sign(secret, { timestamp, nonce, method, url, body = '' }) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const parsed = new URL(url);
  const canonical = [timestamp, nonce, 'hope-api', method, parsed.host, parsed.pathname, body].join('\n');
  const mac = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(canonical)));
  return 'v1=' + [...mac].map(byte => byte.toString(16).padStart(2, '0')).join('');
}
async function post(env, opts = {}) {
  const body = opts.body ?? JSON.stringify(event());
  const url = opts.url ?? 'https://collector.example.test/v1/events';
  const method = opts.method ?? 'POST';
  const nonce = opts.nonce ?? 'ingest_nonce_' + (++sequence) + '_unique';
  const timestamp = opts.timestamp ?? String(Math.floor(Date.now() / 1000));
  const signature = await sign(opts.secret ?? ingestSecret, {
    timestamp, nonce, method, url: opts.signatureUrl ?? url, body: opts.signatureBody ?? body,
  });
  const headers = {
    'content-type': 'application/json',
    'idempotency-key': 'hope-outbox:' + eventId,
    'x-hope-timestamp': timestamp, 'x-hope-nonce': nonce,
    'x-hope-source': 'hope-api', 'x-hope-signature': signature,
    ...(opts.headers || {}),
  };
  return worker.fetch(new Request(url, { method, headers, body: method === 'GET' ? undefined : body }), env);
}
async function receipt(env, opts = {}) {
  const url = 'https://collector.example.test/v1/receipts/' + eventId;
  const nonce = opts.nonce ?? 'read_nonce_' + (++sequence) + '_unique';
  const timestamp = String(Math.floor(Date.now() / 1000));
  const signature = await sign(opts.secret ?? readSecret, { timestamp, nonce, method: 'GET', url });
  return worker.fetch(new Request(url, { method: 'GET', headers: {
    'x-hope-timestamp': timestamp, 'x-hope-nonce': nonce,
    'x-hope-source': 'hope-api', 'x-hope-signature': signature,
  } }), env);
}
const count = (db, table) => db.sqlite.prepare('SELECT COUNT(*) AS n FROM ' + table).get().n;
function setBudget(db, { reads = 0, writes = 0, cleanup = 0 } = {}) {
  const day = new Date().toISOString().slice(0, 10);
  db.sqlite.prepare('INSERT INTO collector_daily_budget (budget_date,reads_used,writes_used,cleanup_writes_used) VALUES (?,?,?,?)')
    .run(day, reads, writes, cleanup);
}

test('health is public liveness and never consumes D1 quota', async () => {
  const DB = new D1Fake();
  const response = await worker.fetch(new Request('https://collector.example.test/v1/healthz'), { DB });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'alive' });
  assert.equal(DB.queries.length, 0);
  DB.close();
});
test('signed ingest reserves budget first and stores only minimal durable metadata', async () => {
  const env = makeEnv();
  const response = await post(env);
  assert.equal(response.status, 202);
  assert.match(env.DB.queries[0], /^INSERT INTO collector_daily_budget/);
  const row = env.DB.sqlite.prepare('SELECT * FROM collector_receipts').get();
  assert.equal(row.payload_sha256.length, 64);
  assert.equal(row.receipt_status, 'received');
  assert.equal('raw_body' in row, false);
  assert.equal(env.DB.sqlite.prepare('SELECT writes_used FROM collector_daily_budget').get().writes_used, 4); assert.equal(env.DB.sqlite.prepare('SELECT reads_used FROM collector_daily_budget').get().reads_used, 4);
  env.DB.close();
});
test('HMAC binds exact raw bytes including BOM, whitespace, host and path', async () => {
  const env = makeEnv();
  const body = JSON.stringify(event());
  assert.equal((await post(env, { body: '\uFEFF' + body, signatureBody: body })).status, 401);
  assert.equal((await post(env, { body: body + ' ', signatureBody: body })).status, 401);
  assert.equal((await post(env, { nonce: 'wrong_host_nonce_123456', signatureUrl: 'https://other.example.test/v1/events' })).status, 401);
  assert.equal((await post(env, { nonce: 'wrong_path_nonce_123456', signatureUrl: 'https://collector.example.test/v1/other' })).status, 401);
  assert.equal(count(env.DB, 'collector_receipts'), 0);
  env.DB.close();
});
test('expired timestamp and wrong ingest key fail before D1 access', async () => {
  const env = makeEnv();
  assert.equal((await post(env, { timestamp: '1600000000' })).status, 401);
  assert.equal((await post(env, { nonce: 'wrong_key_nonce_123456', secret: readSecret })).status, 401);
  assert.equal(env.DB.queries.length, 0);
  env.DB.close();
});
test('strict schema, malformed JSON, unsupported query/encoding and oversized body fail closed', async () => {
  const env = makeEnv();
  assert.equal((await post(env, { body: '{bad-json' })).status, 400);
  assert.equal((await post(env, { nonce: 'unknown_field_nonce_123456', body: JSON.stringify(event({ customerEmail: 'private@example.test' })) })).status, 400);
  assert.equal((await post(env, { nonce: 'large_body_nonce_123456', body: 'x'.repeat(32769) })).status, 413);
  assert.equal((await post(env, { nonce: 'large_length_nonce_123456', headers: { 'content-length': '32769' } })).status, 413);
  assert.equal((await post(env, { nonce: 'query_nonce_123456789', url: 'https://collector.example.test/v1/events?x=1' })).status, 415);
  assert.equal((await post(env, { nonce: 'encoding_nonce_123456', headers: { 'content-encoding': 'gzip' } })).status, 415);
  assert.equal(env.DB.queries.length, 0);
  env.DB.close();
});
test('idempotency header must match the immutable Outbox event ID', async () => {
  const env = makeEnv();
  const response = await post(env, { headers: { 'idempotency-key': 'hope-outbox:wrong' } });
  assert.equal(response.status, 400);
  assert.equal(count(env.DB, 'collector_receipts'), 0);
  env.DB.close();
});
test('nonce replay is rejected and identical event with a fresh nonce is idempotent', async () => {
  const env = makeEnv();
  const nonce = 'replay_nonce_123456789';
  assert.equal((await post(env, { nonce })).status, 202);
  assert.equal((await post(env, { nonce })).status, 409);
  assert.equal((await post(env, { nonce: 'fresh_duplicate_nonce_123456' })).status, 200);
  assert.equal(count(env.DB, 'collector_receipts'), 1);
  env.DB.close();
});
test('same event ID with changed payload is a conflict', async () => {
  const env = makeEnv();
  assert.equal((await post(env)).status, 202);
  const response = await post(env, { nonce: 'changed_payload_nonce_123456', body: JSON.stringify(event({ severity: 'critical' })) });
  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: 'EVENT_ID_CONFLICT' });
  env.DB.close();
});
test('atomic batch rolls back budget and nonce when receipt insert fails', async () => {
  const DB = new D1Fake();
  DB.failReceiptWrite = true;
  const response = await post(makeEnv(DB));
  assert.equal(response.status, 503);
  assert.equal(count(DB, 'collector_nonces'), 0);
  assert.equal(count(DB, 'collector_receipts'), 0);
  assert.equal(count(DB, 'collector_daily_budget'), 0);
  DB.close();
});
test('concurrent duplicate deliveries create at most one durable receipt', async () => {
  const env = makeEnv();
  const [a, b] = await Promise.all([
    post(env, { nonce: 'parallel_nonce_A_123456' }),
    post(env, { nonce: 'parallel_nonce_B_123456' }),
  ]);
  assert.deepEqual([a.status, b.status].sort(), [200, 202]);
  assert.equal(count(env.DB, 'collector_receipts'), 1);
  env.DB.close();
});
test('local budget, D1 daily quota and database storage errors return QUOTA_BLOCKED', async () => {
  const DB = new D1Fake();
  setBudget(DB, { reads: 3_999_999 });
  const blocked = await post(makeEnv(DB));
  assert.equal(blocked.status, 429);
  assert.equal(count(DB, 'collector_nonces'), 0);
  DB.close();
  const provider = new D1Fake();
  provider.failBudget = true;
  provider.quotaMessage = 'Exceeded maximum DB size.';
  const response = await post(makeEnv(provider));
  assert.equal(response.status, 429);
  assert.deepEqual(await response.json(), { error: 'QUOTA_BLOCKED' });
  provider.close();
});
test('readback uses a separate credential and rolls back nonce/budget on read failure', async () => {
  const env = makeEnv();
  assert.equal((await post(env)).status, 202);
  assert.equal((await receipt(env, { nonce: 'wrong_read_key_nonce_123456', secret: ingestSecret })).status, 401);
  env.DB.failReceiptRead = true;
  const before = env.DB.sqlite.prepare('SELECT reads_used,writes_used FROM collector_daily_budget').get();
  assert.equal((await receipt(env, { nonce: 'read_failure_nonce_123456' })).status, 503);
  assert.equal(count(env.DB, 'collector_nonces'), 1);
  assert.deepEqual(env.DB.sqlite.prepare('SELECT reads_used,writes_used FROM collector_daily_budget').get(), before);
  env.DB.failReceiptRead = false;
  assert.equal((await receipt(env, { nonce: 'read_ok_nonce_123456' })).status, 200);
  assert.equal(env.DB.sqlite.prepare('SELECT writes_used FROM collector_daily_budget').get().writes_used, 7);
  env.DB.close();
});
test('cleanup reserves bounded reads first and preserves expired nonces when quota is blocked', async () => {
  const DB = new D1Fake();
  const now = Math.floor(Date.now() / 1000);
  DB.sqlite.prepare('INSERT INTO collector_nonces (source,nonce,issued_at,expires_at) VALUES (?,?,?,?)')
    .run('hope-api', 'expired_nonce_123456', now - 700, now - 100);
  await worker.scheduled({}, { DB });
  assert.match(DB.queries[0], /^INSERT INTO collector_daily_budget/);
  assert.equal(count(DB, 'collector_nonces'), 0);
  assert.equal(DB.sqlite.prepare('SELECT cleanup_writes_used FROM collector_daily_budget').get().cleanup_writes_used, 4);
  DB.close();
  const blocked = new D1Fake();
  blocked.sqlite.prepare('INSERT INTO collector_nonces (source,nonce,issued_at,expires_at) VALUES (?,?,?,?)')
    .run('hope-api', 'keep_expired_nonce_123', now - 700, now - 100);
  setBudget(blocked, { cleanup: 25_000 });
  await worker.scheduled({}, { DB: blocked });
  assert.equal(count(blocked, 'collector_nonces'), 1);
  blocked.close();
});
test('migration enforces receipt, nonce, digest, severity and expiry-index constraints', () => {
  const DB = new D1Fake();
  const insert = DB.sqlite.prepare('INSERT INTO collector_receipts (event_id,source,severity,event_type,occurred_at,received_at,payload_sha256,pagerduty_incident_id,receipt_status) VALUES (?,?,?,?,?,?,?,?,?)');
  const row = [eventId, 'hope-api', 'page', 'AUTH_REFRESH_REUSE_DETECTED', '2026-11-10T12:00:00.000Z', new Date().toISOString(), 'a'.repeat(64), null, 'received'];
  insert.run(...row);
  assert.throws(() => insert.run(...row));
  assert.throws(() => insert.run(...[...row.slice(0, 2), 'urgent', ...row.slice(3)]));
  assert.ok(DB.sqlite.prepare("PRAGMA index_list('collector_nonces')").all().some(x => x.name === 'collector_nonces_expiry_idx'));
  const nonce = DB.sqlite.prepare('INSERT INTO collector_nonces (source,nonce,issued_at,expires_at) VALUES (?,?,?,?)');
  nonce.run('hope-api', 'unique_nonce_123456', 1, 2);
  assert.throws(() => nonce.run('hope-api', 'unique_nonce_123456', 1, 2));
  DB.close();
});
