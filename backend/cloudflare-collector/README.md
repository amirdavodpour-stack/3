# HOPEv2 operational receipt collector

**Source/tests/docs only.** No Worker, D1 database, route, cron, DNS record, secret, or deployment exists. The Wrangler file is a template only. The Worker FQDN is unknown; never guess it or substitute `*.workers.dev`.

## Responsibility and state boundaries

This Worker records a minimal durable receipt for an independently delivered HOPE Outbox event. It does not call PagerDuty, create incidents, send ACKs, or infer human acknowledgement/resolution.

HOPE's Outbox and per-sink delivery records remain authoritative for retries and financial/audit state. These are distinct: Outbox event, Collector receipt, PagerDuty event acceptance, incident creation, human ACK, resolution. A Collector receipt proves only durable receipt storage; it must never set PagerDuty ACK/resolution or release a financial workflow. No wallet, ledger, user balance, job payment or Production database is accessed or changed.

## Routes and signed contract

| Method | Path | Authentication / behavior |
|---|---|---|
| POST | `/v1/events` | HMAC-SHA256; stores or identifies one receipt |
| GET | `/v1/receipts/{eventId}` | Separate readback HMAC; returns one minimal receipt |
| GET | `/v1/healthz` | Public no-D1 liveness only; not readiness |

Unsupported methods return `405`; unknown paths return `404`; query strings are rejected on data routes. No outbound fetch, arbitrary destination, proxy, redirect, or CORS is implemented.

Only `hope-api` is accepted. The two independent secret bindings are `HOPE_INGEST_HMAC_SECRET` (POST only) and `HOPE_READBACK_HMAC_SECRET` (GET only); each must have at least 32 UTF-8 bytes and is imported for HMAC verification only. Never commit, log, or persist these secrets.

Required headers: `x-hope-timestamp` (10-digit epoch seconds, ±300 seconds), `x-hope-nonce` (16–128 URL-safe characters), `x-hope-source: hope-api`, `x-hope-signature: v1=<64 hex chars>`. POST additionally requires `idempotency-key: hope-outbox:<eventId>`.

The canonical UTF-8 HMAC message is timestamp, nonce, source, uppercase method, URL host (including explicit port), URL pathname, and original raw UTF-8 body, joined by `\n` without a trailing newline. GET signs an empty body. Query strings are rejected. The original bytes (including BOM and whitespace) are authenticated before JSON parsing/normalization.

POST accepts strict schema version 1 only: UUID event ID, fixed source, enumerated severity, uppercase event type, canonical ISO timestamp, and optional bounded PagerDuty incident correlation ID. Unknown fields, malformed JSON, unsupported content encoding, queries and bodies over 32 KiB are rejected. PagerDuty correlation metadata is not proof of incident creation or ACK.

## Idempotency, replay and atomicity

A nonce is unique per source and expires after 10 minutes. Same source/event ID and same raw-body SHA-256 returns `200 duplicate`; changed digest returns `409 EVENT_ID_CONFLICT`; repeated nonce returns `409 REPLAY_DETECTED`.

Ingestion uses one D1 `batch()` for daily budget reservation, nonce insert and receipt insert. The inserts are conditional on the previous statement succeeding. D1 batch statements execute sequentially in one SQL transaction; a failed statement rolls the batch back. The Worker returns `202` only after the batch confirms the durable receipt. A retry after failed D1 work must use a fresh nonce while retaining the same HOPE Outbox event ID/idempotency key. Unique DB constraints are the final concurrency control.

Receipt readback reserves its budget, nonce and receipt query in one batch and uses only the dedicated readback key.

## Zero-cost quotas and fail-closed policy

Application UTC counters stay below published Workers Free D1 ceilings:

| Counter | Daily ceiling |
|---|---:|
| Read reservation units | 4,000,000 |
| Authenticated request write reservation units (ingest + readback) | 60,000 |
| Cleanup write reservation units | 25,000 |

These are conservative **application reservation units**, not exact Cloudflare row metrics. Ingest reserves four request-write units and four read units; readback reserves three request-write units and two read units. Cleanup reserves the bounded candidate scan before reading it, then reserves further deletion headroom from the batch size. Cleanup has an independent allowance so it cannot consume ingest reservations.

Cloudflare currently documents Workers Free D1 at 5 million rows read/day, 100,000 rows written/day, 5 GB total account storage and a 500 MB maximum database size. Daily row limits are enforced; exceeding them causes D1 calls to fail until the UTC reset. Recognized row-quota or full-storage provider errors map to `429 QUOTA_BLOCKED`; other D1 errors map to `503 STORAGE_UNAVAILABLE`.

On quota/storage block, stop attempts for the event, preserve the HOPE Outbox record, and use only HOPE's bounded retry/manual recovery. Never upgrade, buy credits, enable overage/auto-top-up, or delete receipts to regain quota. Cleanup is best-effort and bounded; when reservation fails, it skips and retains expired nonce rows. Receipts are never automatically purged.

## Data minimization and retention

`collector_receipts` stores event/source identifiers, severity/type, event/receipt timestamps, raw-body SHA-256 digest, optional PagerDuty correlation ID and `received` status. Raw body, PII, credentials, authorization headers and arbitrary payload fields are not stored. `collector_nonces` holds source/nonce/issued/expiry metadata. Logs use fixed diagnostic labels only; they never log body, headers or secrets.

Receipt retention duration, legal holds, archive/restore, erasure and immutable-audit policy require separate owner/legal decisions. D1 is not described as tamper-proof or legally immutable.

## Local validation and evidence boundary

From `backend/`: `npm run check` and `npm run test:collector`.

Tests use Node's SQLite-compatible local database and a D1 fake with transactional batches. They cover HMAC raw-body/host/path binding, replay and idempotency, event conflicts, rollback, quota/storage handling, readback separation, cleanup and migration constraints. This is **local SQLite-compatible evidence only**, not Cloudflare Workers Runtime or deployed D1 verification. The repository requires Node `>=24 <25`; Node 22 is not a substitute. A skipped workflow is not PASS.

## Provisioning boundary

The Wrangler template has a placeholder D1 ID, disables `workers_dev` and preview URLs, and contains a cron template that is not active until authorized deployment. Worker FQDN, route, D1, secrets, DNS, cron and outbound allowlist remain unknown/unconfigured. No resource creation, secret creation, DNS/route change, deploy, PagerDuty traffic or allowlist entry is authorized here.

Cloudflare references: https://developers.cloudflare.com/d1/worker-api/d1-database/ ; https://developers.cloudflare.com/d1/platform/pricing/ ; https://developers.cloudflare.com/d1/platform/limits/ ; https://developers.cloudflare.com/d1/observability/debug-d1/ ; https://developers.cloudflare.com/workers/observability/logs/workers-logs/ ; https://developers.cloudflare.com/workers/observability/traces/ ; https://developers.cloudflare.com/observability/pricing/ .
