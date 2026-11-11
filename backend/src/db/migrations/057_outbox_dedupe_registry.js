import {
  createOutboxDedupeDigest,
  outboxDedupePolicyForEventType,
} from '../../repository/outbox_dedupe_registry.js';

export const migration = {
  version:57,
  name:'outbox_dedupe_registry',
  async up(client) {
    // Block event inserts while taking the one-time legacy identity snapshot.
    await client.query('LOCK TABLE outbox_events IN SHARE ROW EXCLUSIVE MODE');
    const createTableSql = [
      'CREATE TABLE IF NOT EXISTS outbox_dedupe_registry (',
      '  key_digest BYTEA NOT NULL UNIQUE,',
      '  digest_version SMALLINT NOT NULL CHECK(digest_version=1),',
      '  original_event_id UUID NOT NULL UNIQUE,',
      '  event_type TEXT NOT NULL,',
      '  aggregate_type TEXT NOT NULL,',
      '  aggregate_id UUID NULL,',
      "  conflict_policy TEXT NOT NULL CHECK(conflict_policy IN ('CREATE_ONLY','FIRST_WINS','STATUS_GATED_REQUEUE')),",
      "  state TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(state IN ('ACTIVE','ARCHIVED','TOMBSTONED')),",
      '  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),',
      '  archived_at TIMESTAMPTZ NULL,',
      '  tombstoned_at TIMESTAMPTZ NULL,',
      '  CHECK((',
      "    state='ACTIVE' AND archived_at IS NULL AND tombstoned_at IS NULL",
      "  ) OR (state='ARCHIVED' AND archived_at IS NOT NULL AND tombstoned_at IS NULL)",
      "    OR (state='TOMBSTONED' AND tombstoned_at IS NOT NULL))",
      ')',
    ].join('\\n');
    await client.query(createTableSql);
    await client.query(
      'CREATE INDEX IF NOT EXISTS outbox_dedupe_registry_aggregate_idx ON outbox_dedupe_registry(aggregate_type,aggregate_id)',
    );
    await client.query(
      'CREATE INDEX IF NOT EXISTS outbox_dedupe_registry_state_idx ON outbox_dedupe_registry(state,created_at)',
    );

    const { rows } = await client.query(
      'SELECT id,event_type,aggregate_type,aggregate_id,dedupe_key FROM outbox_events WHERE dedupe_key IS NOT NULL ORDER BY id',
    );
    for (const event of rows) {
      const conflictPolicy=outboxDedupePolicyForEventType(event.event_type);
      const keyDigest=createOutboxDedupeDigest(event.dedupe_key);
      await client.query(
        "INSERT INTO outbox_dedupe_registry(key_digest,digest_version,original_event_id,event_type,aggregate_type,aggregate_id,conflict_policy,state,created_at) VALUES($1,1,$2,$3,$4,$5,$6,'ACTIVE',NOW())",
        [
          keyDigest,
          event.id,
          event.event_type,
          event.aggregate_type,
          event.aggregate_id,
          conflictPolicy,
        ],
      );
    }
  },
  async down(client) {
    const { rows } = await client.query('SELECT 1 FROM outbox_dedupe_registry LIMIT 1');
    if (rows.length) {
      throw new Error('Cannot roll back a populated permanent Outbox dedupe identity registry');
    }
    await client.query('DROP TABLE IF EXISTS outbox_dedupe_registry');
  },
};
