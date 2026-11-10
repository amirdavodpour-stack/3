CREATE TABLE IF NOT EXISTS collector_receipts (
  event_id TEXT NOT NULL,
  source TEXT NOT NULL,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical', 'page')),
  event_type TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  received_at TEXT NOT NULL,
  payload_sha256 TEXT NOT NULL CHECK (length(payload_sha256) = 64),
  pagerduty_incident_id TEXT,
  receipt_status TEXT NOT NULL CHECK (receipt_status IN ('received')),
  PRIMARY KEY (source, event_id)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS collector_nonces (
  source TEXT NOT NULL,
  nonce TEXT NOT NULL,
  issued_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  PRIMARY KEY (source, nonce)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS collector_nonces_expiry_idx
  ON collector_nonces (expires_at);

CREATE TABLE IF NOT EXISTS collector_daily_budget (
  budget_date TEXT PRIMARY KEY,
  reads_used INTEGER NOT NULL DEFAULT 0 CHECK (reads_used >= 0),
  writes_used INTEGER NOT NULL DEFAULT 0 CHECK (writes_used >= 0),
  cleanup_writes_used INTEGER NOT NULL DEFAULT 0 CHECK (cleanup_writes_used >= 0)
) WITHOUT ROWID;
