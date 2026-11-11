import crypto from 'node:crypto';

const DIGEST_VERSION = 1;
const DIGEST_DOMAIN = 'hopev2:outbox-dedupe:v1\0';

const EVENT_POLICIES = Object.freeze({
  PAYMENT_CREATE_HOLD:'STATUS_GATED_REQUEUE',
  PAYMENT_RELEASE:'STATUS_GATED_REQUEUE',
  PAYMENT_REFUND:'STATUS_GATED_REQUEUE',
  PAYOUT_EXECUTE:'CREATE_ONLY',
  NOTIFICATION_DISPATCH:'FIRST_WINS',
  AUTH_REFRESH_REUSE_ALERT:'FIRST_WINS',
  SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL:'FIRST_WINS',
});

const EVENT_AGGREGATES = Object.freeze({
  PAYMENT_CREATE_HOLD:'payment',
  PAYMENT_RELEASE:'payment',
  PAYMENT_REFUND:'payment',
  PAYOUT_EXECUTE:'payout',
  NOTIFICATION_DISPATCH:'notification',
  AUTH_REFRESH_REUSE_ALERT:'user',
  SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL:'outbox_event',
});

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function dedupeError(code, status = 409) {
  return Object.assign(new Error(code), { code, status });
}

function sameId(left, right) {
  return String(left ?? '').toLowerCase() === String(right ?? '').toLowerCase();
}

function assertEventIdentity(requested, event) {
  if (
    String(event?.event_type || '') !== requested.eventType
    || String(event?.aggregate_type || '') !== requested.aggregateType
    || !sameId(event?.aggregate_id, requested.aggregateId)
  ) {
    throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
  }
}

export function outboxDedupePolicyForEventType(eventType) {
  const policy = EVENT_POLICIES[String(eventType || '')];
  if (!policy) throw dedupeError('OUTBOX_DEDUPE_EVENT_TYPE_UNSUPPORTED', 500);
  return policy;
}

export function createOutboxDedupeDigest(dedupeKey) {
  if (
    typeof dedupeKey !== 'string'
    || dedupeKey.length === 0
    || Buffer.byteLength(dedupeKey, 'utf8') > 512
    || /[\u0000-\u001f\u007f]/u.test(dedupeKey)
  ) {
    throw dedupeError('OUTBOX_DEDUPE_KEY_INVALID', 400);
  }
  return crypto.createHash('sha256')
    .update(DIGEST_DOMAIN, 'utf8')
    .update(dedupeKey, 'utf8')
    .digest();
}

function assertRequestedIdentity(input) {
  if (!UUID_PATTERN.test(String(input.eventId || ''))) throw dedupeError('OUTBOX_DEDUPE_EVENT_ID_INVALID', 400);
  if (!UUID_PATTERN.test(String(input.aggregateId || ''))) throw dedupeError('OUTBOX_DEDUPE_AGGREGATE_ID_INVALID', 400);
  const expectedAggregate = EVENT_AGGREGATES[String(input.eventType || '')];
  if (!expectedAggregate || expectedAggregate !== input.aggregateType) {
    throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
  }
  if (input.conflictPolicy !== outboxDedupePolicyForEventType(input.eventType)) {
    throw dedupeError('OUTBOX_DEDUPE_POLICY_MISMATCH');
  }
  createOutboxDedupeDigest(input.dedupeKey);
}

function assertPersistedIdentity(row, requested, digest) {
  assertEventIdentity(requested, row);
  const storedDigest = createOutboxDedupeDigest(row?.dedupe_key);
  if (!storedDigest.equals(digest)) throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
}

async function lockEventById(client, eventId) {
  const { rows } = await client.query(
    "SELECT id,event_type,aggregate_type,aggregate_id,dedupe_key,status FROM outbox_events WHERE id=$1 FOR UPDATE",
    [eventId],
  );
  return rows[0] || null;
}

/**
 * Reserve a permanent digest -> original event identity mapping in the same
 * SQL transaction as the Outbox insert or producer-specific state transition.
 * No raw key or event payload is stored in the registry.
 */
export async function reserveOutboxDedupeKeyWithClient(client, {
  eventId,
  eventType,
  aggregateType,
  aggregateId,
  dedupeKey,
  conflictPolicy,
} = {}) {
  const requested = { eventId, eventType, aggregateType, aggregateId, dedupeKey, conflictPolicy };
  assertRequestedIdentity(requested);
  const digest = createOutboxDedupeDigest(dedupeKey);

  const { rows: insertedRows } = await client.query(
    "INSERT INTO outbox_dedupe_registry(key_digest,digest_version,original_event_id,event_type,aggregate_type,aggregate_id,conflict_policy,state,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,'ACTIVE',NOW()) ON CONFLICT(key_digest) DO NOTHING RETURNING original_event_id",
    [digest,DIGEST_VERSION,eventId,eventType,aggregateType,aggregateId,conflictPolicy],
  );
  const inserted = insertedRows.length === 1;

  const { rows: registryRows } = await client.query(
    "SELECT key_digest,digest_version,original_event_id,event_type,aggregate_type,aggregate_id,conflict_policy,state FROM outbox_dedupe_registry WHERE key_digest=$1 FOR UPDATE",
    [digest],
  );
  const registry = registryRows[0];
  if (!registry) throw dedupeError('OUTBOX_DEDUPE_REGISTRY_RESERVATION_MISSING', 500);
  if (Number(registry.digest_version) !== DIGEST_VERSION || !Buffer.from(registry.key_digest).equals(digest)) {
    throw dedupeError('OUTBOX_DEDUPE_DIGEST_VERSION_CONFLICT');
  }
  if (
    String(registry.event_type) !== eventType
    || String(registry.aggregate_type) !== aggregateType
    || !sameId(registry.aggregate_id, aggregateId)
    || String(registry.conflict_policy) !== conflictPolicy
  ) {
    throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
  }

  const state = String(registry.state || '').toUpperCase();
  if (state === 'TOMBSTONED') throw dedupeError('OUTBOX_DEDUPE_TOMBSTONED');
  if (state === 'ARCHIVED') throw dedupeError('OUTBOX_DEDUPE_ARCHIVED');
  if (state !== 'ACTIVE') throw dedupeError('OUTBOX_DEDUPE_STATE_INVALID', 500);

  // Adopt rows produced by an older application instance after migration 057.
  // This lookup is ordered after the registry lock to keep one canonical order.
  const { rows: keyRows } = await client.query(
    "SELECT id,event_type,aggregate_type,aggregate_id,dedupe_key,status FROM outbox_events WHERE dedupe_key=$1 FOR UPDATE",
    [dedupeKey],
  );
  if (keyRows[0]) {
    const existing = keyRows[0];
    assertPersistedIdentity(existing, requested, digest);
    if (!sameId(existing.id, registry.original_event_id)) {
      if (!inserted) throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
      const { rowCount } = await client.query(
        "UPDATE outbox_dedupe_registry SET original_event_id=$2 WHERE key_digest=$1 AND original_event_id=$3 AND state='ACTIVE'",
        [digest,existing.id,eventId],
      );
      if (rowCount !== 1) throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
    }
    return {
      created:false,
      eventId:existing.id,
      event:existing,
      conflictPolicy,
      digestVersion:DIGEST_VERSION,
      keyDigest:digest,
    };
  }

  if (inserted) {
    return {
      created:true,
      eventId,
      event:null,
      conflictPolicy,
      digestVersion:DIGEST_VERSION,
      keyDigest:digest,
    };
  }

  const existing = await lockEventById(client, registry.original_event_id);
  if (!existing) throw dedupeError('OUTBOX_DEDUPE_ORPHANED');
  assertPersistedIdentity(existing, requested, digest);
  return {
    created:false,
    eventId:existing.id,
    event:existing,
    conflictPolicy,
    digestVersion:DIGEST_VERSION,
    keyDigest:digest,
  };
}

/**
 * Insert only after a successful new reservation. The retained Outbox unique
 * constraint remains a second line of defence against legacy writers racing
 * the reservation; on such a conflict, the original event UUID is adopted.
 */
export async function insertReservedOutboxEventWithClient(client, {
  reservation,
  eventType,
  aggregateType,
  aggregateId,
  dedupeKey,
  payload,
  status='PENDING',
  attempts=0,
} = {}) {
  if (!reservation?.created || !reservation.eventId || !reservation.keyDigest) {
    throw dedupeError('OUTBOX_DEDUPE_RESERVATION_REQUIRED', 500);
  }
  if (reservation.conflictPolicy !== outboxDedupePolicyForEventType(eventType)) {
    throw dedupeError('OUTBOX_DEDUPE_POLICY_MISMATCH');
  }

  const { rows } = await client.query(
    "INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at) VALUES($1,$2,$3,$4,$5,$6::jsonb,$7,$8,NOW(),NOW()) ON CONFLICT(dedupe_key) DO NOTHING RETURNING *",
    [reservation.eventId,eventType,aggregateType,aggregateId,dedupeKey,JSON.stringify(payload || {}),status,attempts],
  );
  if (rows[0]) return { ...reservation, created:true, eventId:rows[0].id, event:rows[0] };

  const { rows: existingRows } = await client.query(
    "SELECT id,event_type,aggregate_type,aggregate_id,dedupe_key,status FROM outbox_events WHERE dedupe_key=$1 FOR UPDATE",
    [dedupeKey],
  );
  const existing = existingRows[0];
  if (!existing) throw dedupeError('OUTBOX_DEDUPE_RESERVATION_LOST', 500);
  const requested = { eventType, aggregateType, aggregateId };
  assertPersistedIdentity(existing, { ...requested, dedupeKey }, reservation.keyDigest);
  const { rowCount } = await client.query(
    "UPDATE outbox_dedupe_registry SET original_event_id=$2 WHERE key_digest=$1 AND original_event_id=$3 AND state='ACTIVE'",
    [reservation.keyDigest,existing.id,reservation.eventId],
  );
  if (rowCount !== 1) throw dedupeError('OUTBOX_DEDUPE_IDENTITY_CONFLICT');
  return {
    ...reservation,
    created:false,
    eventId:existing.id,
    event:existing,
  };
}
