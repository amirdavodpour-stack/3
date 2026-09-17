import crypto from 'node:crypto';

export const migration = {
  version: 6,
  name: 'financial_core',
  async up(client) {
    await client.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM wallet_accounts WHERE currency <> 'HOPE') THEN
          RAISE EXCEPTION 'Cannot migrate wallet currency: unsupported legacy currency exists';
        END IF;
        IF EXISTS (
          SELECT 1 FROM wallet_accounts
          WHERE available_balance <> TRUNC(available_balance)
             OR locked_balance <> TRUNC(locked_balance)
        ) THEN
          RAISE EXCEPTION 'Cannot migrate wallet balances: fractional legacy values exist';
        END IF;
      END $$;

      ALTER TABLE wallet_accounts
        ALTER COLUMN currency SET DEFAULT 'TOMAN';
      UPDATE wallet_accounts SET currency='TOMAN' WHERE currency='HOPE';
      ALTER TABLE wallet_accounts
        ALTER COLUMN available_balance TYPE BIGINT USING available_balance::BIGINT,
        ALTER COLUMN locked_balance TYPE BIGINT USING locked_balance::BIGINT;
      ALTER TABLE wallet_accounts
        DROP CONSTRAINT IF EXISTS wallet_accounts_currency_check;
      ALTER TABLE wallet_accounts
        ADD CONSTRAINT wallet_accounts_currency_chk CHECK (currency='TOMAN');
      ALTER TABLE wallet_accounts
        DROP CONSTRAINT IF EXISTS wallet_accounts_user_id_currency_key;
      CREATE UNIQUE INDEX IF NOT EXISTS wallet_accounts_user_uq ON wallet_accounts(user_id);
      ALTER TABLE wallet_accounts
        DROP CONSTRAINT IF EXISTS wallet_accounts_user_id_currency_key;
      ALTER TABLE wallet_accounts
        ALTER COLUMN user_id SET NOT NULL;

      CREATE TABLE IF NOT EXISTS financial_operations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        operation_type TEXT NOT NULL CHECK (operation_type IN (
          'TOP_UP','TRANSFER','HOLD','RELEASE','REFUND','PAYOUT','ADJUSTMENT'
        )),
        actor_type TEXT NOT NULL CHECK (actor_type IN ('USER','ADMIN','SYSTEM','PROVIDER')),
        actor_id UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
        status TEXT NOT NULL CHECK (status IN ('PENDING','PROCESSING','SUCCEEDED','FAILED','UNKNOWN','CANCELLED')),
        idempotency_key TEXT NULL,
        request_hash TEXT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        completed_at TIMESTAMPTZ NULL
      );
      CREATE UNIQUE INDEX IF NOT EXISTS financial_operations_idempotency_uq
        ON financial_operations(actor_id, operation_type, idempotency_key)
        WHERE idempotency_key IS NOT NULL;
      CREATE INDEX IF NOT EXISTS financial_operations_status_idx
        ON financial_operations(status, created_at DESC);

      CREATE TABLE IF NOT EXISTS idempotency_keys (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        principal_id UUID NULL REFERENCES users(id) ON DELETE RESTRICT,
        operation TEXT NOT NULL,
        idempotency_key TEXT NOT NULL,
        request_hash TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('PROCESSING','SUCCEEDED','FAILED')),
        resource_type TEXT NULL,
        resource_id UUID NULL,
        response_code INTEGER NULL,
        response_body JSONB NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        expires_at TIMESTAMPTZ NULL
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idempotency_keys_principal_operation_key_uq
        ON idempotency_keys(principal_id, operation, idempotency_key);
      CREATE INDEX IF NOT EXISTS idempotency_keys_expires_idx
        ON idempotency_keys(expires_at) WHERE expires_at IS NOT NULL;

      CREATE TABLE IF NOT EXISTS wallet_holds (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        wallet_id UUID NOT NULL REFERENCES wallet_accounts(id) ON DELETE RESTRICT,
        hold_type TEXT NOT NULL CHECK (hold_type IN ('JOB_PAYMENT','PAYOUT_RESERVATION','OTHER')),
        reference_type TEXT NOT NULL,
        reference_id UUID NULL,
        financial_operation_id UUID NULL REFERENCES financial_operations(id) ON DELETE RESTRICT,
        amount BIGINT NOT NULL CHECK (amount > 0),
        status TEXT NOT NULL CHECK (status IN ('ACTIVE','RELEASED','CANCELLED')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        released_at TIMESTAMPTZ NULL
      );
      CREATE INDEX IF NOT EXISTS wallet_holds_wallet_status_idx
        ON wallet_holds(wallet_id,status,created_at DESC);
      CREATE INDEX IF NOT EXISTS wallet_holds_reference_idx
        ON wallet_holds(reference_type,reference_id);
      CREATE INDEX IF NOT EXISTS wallet_holds_operation_idx
        ON wallet_holds(financial_operation_id);

      CREATE TABLE IF NOT EXISTS wallet_entries (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        wallet_id UUID NOT NULL REFERENCES wallet_accounts(id) ON DELETE RESTRICT,
        entry_type TEXT NOT NULL CHECK (entry_type IN (
          'TOP_UP','TRANSFER','HOLD','RELEASE','REFUND','PAYOUT','ADJUSTMENT'
        )),
        direction TEXT NOT NULL CHECK (direction IN ('CREDIT','DEBIT')),
        amount BIGINT NOT NULL CHECK (amount > 0),
        currency TEXT NOT NULL DEFAULT 'TOMAN' CHECK (currency='TOMAN'),
        reference_type TEXT NOT NULL,
        reference_id UUID NULL,
        financial_operation_id UUID NOT NULL REFERENCES financial_operations(id) ON DELETE RESTRICT,
        balance_after BIGINT NULL CHECK (balance_after IS NULL OR balance_after >= 0),
        metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS wallet_entries_wallet_cursor_idx
        ON wallet_entries(wallet_id,created_at DESC,id DESC);
      CREATE INDEX IF NOT EXISTS wallet_entries_operation_idx
        ON wallet_entries(financial_operation_id);
      CREATE INDEX IF NOT EXISTS wallet_entries_reference_idx
        ON wallet_entries(reference_type,reference_id,created_at DESC);

      CREATE TABLE IF NOT EXISTS journals (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        operation_id UUID NOT NULL REFERENCES financial_operations(id) ON DELETE RESTRICT,
        journal_type TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'TOMAN' CHECK (currency='TOMAN'),
        status TEXT NOT NULL DEFAULT 'CREATED' CHECK (status IN ('CREATED','POSTED','FAILED')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        posted_at TIMESTAMPTZ NULL,
        UNIQUE(operation_id,journal_type)
      );
      CREATE INDEX IF NOT EXISTS journals_status_idx ON journals(status,created_at DESC);

      CREATE TABLE IF NOT EXISTS payouts (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        wallet_id UUID NOT NULL REFERENCES wallet_accounts(id) ON DELETE RESTRICT,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        amount BIGINT NOT NULL CHECK (amount > 0),
        currency TEXT NOT NULL DEFAULT 'TOMAN' CHECK (currency='TOMAN'),
        status TEXT NOT NULL CHECK (status IN ('REQUESTED','RESERVED','PROCESSING','SUCCEEDED','FAILED','UNKNOWN')),
        provider TEXT NOT NULL,
        provider_ref TEXT NULL,
        idempotency_key TEXT NOT NULL,
        failure_code TEXT NULL,
        failure_message TEXT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        completed_at TIMESTAMPTZ NULL,
        UNIQUE(user_id,idempotency_key),
        UNIQUE(provider,provider_ref)
      );
      CREATE INDEX IF NOT EXISTS payouts_user_created_idx ON payouts(user_id,created_at DESC,id DESC);
      CREATE INDEX IF NOT EXISTS payouts_wallet_status_idx ON payouts(wallet_id,status,updated_at DESC);
      CREATE INDEX IF NOT EXISTS payouts_status_updated_idx ON payouts(status,updated_at DESC);

      CREATE TABLE IF NOT EXISTS provider_events (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        provider TEXT NOT NULL,
        provider_event_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        resource_type TEXT NULL,
        resource_id UUID NULL,
        payload JSONB NOT NULL,
        signature_valid BOOLEAN NOT NULL DEFAULT FALSE,
        status TEXT NOT NULL DEFAULT 'RECEIVED' CHECK (status IN ('RECEIVED','PROCESSING','PROCESSED','FAILED','IGNORED')),
        received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        processed_at TIMESTAMPTZ NULL,
        UNIQUE(provider,provider_event_id)
      );
      CREATE INDEX IF NOT EXISTS provider_events_resource_idx
        ON provider_events(resource_type,resource_id,received_at DESC);
      CREATE INDEX IF NOT EXISTS provider_events_status_idx
        ON provider_events(status,received_at DESC);

      CREATE TABLE IF NOT EXISTS reconciliation_cases (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        case_type TEXT NOT NULL,
        resource_type TEXT NOT NULL,
        resource_id UUID NULL,
        severity TEXT NOT NULL CHECK (severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
        expected JSONB NOT NULL DEFAULT '{}'::jsonb,
        observed JSONB NOT NULL DEFAULT '{}'::jsonb,
        status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','INVESTIGATING','RESOLVED','DISMISSED')),
        resolution_reference TEXT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        resolved_at TIMESTAMPTZ NULL
      );
      CREATE INDEX IF NOT EXISTS reconciliation_cases_status_idx
        ON reconciliation_cases(status,severity,created_at DESC);
      CREATE INDEX IF NOT EXISTS reconciliation_cases_resource_idx
        ON reconciliation_cases(resource_type,resource_id,created_at DESC);
    `);

    // Preserve the old wallet transaction stream while creating the canonical immutable entry stream.
    // Legacy rows are represented by one financial operation per transaction. This is a staging-safe
    // backfill; new code will write only to wallet_entries.
    const legacy = await client.query(`
      SELECT id,idempotency_key,transaction_type,reference_type,reference_id,currency,amount,
             source_wallet_id,destination_wallet_id,metadata,created_at
      FROM wallet_transactions
      WHERE currency='HOPE'
      ORDER BY created_at,id
    `);

    for (const row of legacy.rows) {
      const operationId = crypto.randomUUID();
      await client.query(`
        INSERT INTO financial_operations(
          id,operation_type,actor_type,status,idempotency_key,request_hash,created_at,completed_at
        ) VALUES($1,$2,'SYSTEM','SUCCEEDED',$3,NULL,$4,$4)
        ON CONFLICT DO NOTHING
      `, [operationId,
        row.transaction_type === 'CREDIT' ? 'TOP_UP' :
          row.transaction_type === 'TRANSFER' ? 'TRANSFER' :
            row.transaction_type === 'HOLD' ? 'HOLD' :
              row.transaction_type === 'RELEASE' ? 'RELEASE' :
                row.transaction_type === 'REFUND' ? 'REFUND' : 'ADJUSTMENT',
        `legacy-wallet:${row.idempotency_key}`,
        row.created_at]);

      if (row.source_wallet_id && row.destination_wallet_id && row.source_wallet_id === row.destination_wallet_id) {
        if (row.transaction_type === 'CREDIT' || row.transaction_type === 'REFUND') {
          await client.query(`
            INSERT INTO wallet_entries(id,wallet_id,entry_type,direction,amount,reference_type,reference_id,financial_operation_id,metadata,created_at)
            VALUES($1,$2,$3,'CREDIT',$4,$5,$6,$7,$8,$9)
            ON CONFLICT DO NOTHING
          `, [crypto.randomUUID(),row.destination_wallet_id,row.transaction_type,row.amount,row.reference_type,row.reference_id,operationId,row.metadata,row.created_at]);
        } else if (row.transaction_type === 'HOLD') {
          await client.query(`
            INSERT INTO wallet_entries(id,wallet_id,entry_type,direction,amount,reference_type,reference_id,financial_operation_id,metadata,created_at)
            VALUES($1,$2,'HOLD','DEBIT',$3,$4,$5,$6,$7,$8)
            ON CONFLICT DO NOTHING
          `, [crypto.randomUUID(),row.source_wallet_id,row.amount,row.reference_type,row.reference_id,operationId,row.metadata,row.created_at]);
        }
      } else {
        if (row.source_wallet_id) {
          await client.query(`
            INSERT INTO wallet_entries(id,wallet_id,entry_type,direction,amount,reference_type,reference_id,financial_operation_id,metadata,created_at)
            VALUES($1,$2,$3,'DEBIT',$4,$5,$6,$7,$8,$9)
            ON CONFLICT DO NOTHING
          `, [crypto.randomUUID(),row.source_wallet_id,row.transaction_type,row.amount,row.reference_type,row.reference_id,operationId,row.metadata,row.created_at]);
        }
        if (row.destination_wallet_id) {
          await client.query(`
            INSERT INTO wallet_entries(id,wallet_id,entry_type,direction,amount,reference_type,reference_id,financial_operation_id,metadata,created_at)
            VALUES($1,$2,$3,'CREDIT',$4,$5,$6,$7,$8,$9)
            ON CONFLICT DO NOTHING
          `, [crypto.randomUUID(),row.destination_wallet_id,row.transaction_type,row.amount,row.reference_type,row.reference_id,operationId,row.metadata,row.created_at]);
        }
      }
    }
  },
  async down(client) {
    const protectedTables = ['wallet_entries','wallet_holds','payouts','journals','financial_operations','idempotency_keys','provider_events','reconciliation_cases'];
    for (const table of protectedTables) {
      const { rows } = await client.query(`SELECT 1 FROM ${table} LIMIT 1`);
      if (rows.length) throw new Error(`Cannot rollback financial_core while ${table} contains data`);
    }
    await client.query(`
      DROP TABLE IF EXISTS reconciliation_cases;
      DROP TABLE IF EXISTS provider_events;
      DROP TABLE IF EXISTS payouts;
      DROP TABLE IF EXISTS journals;
      DROP TABLE IF EXISTS wallet_entries;
      DROP TABLE IF EXISTS wallet_holds;
      DROP TABLE IF EXISTS idempotency_keys;
      DROP TABLE IF EXISTS financial_operations;
      DROP INDEX IF EXISTS wallet_accounts_user_uq;
      ALTER TABLE wallet_accounts DROP CONSTRAINT IF EXISTS wallet_accounts_currency_chk;
      ALTER TABLE wallet_accounts ALTER COLUMN available_balance TYPE NUMERIC(18,2) USING available_balance::NUMERIC(18,2);
      ALTER TABLE wallet_accounts ALTER COLUMN locked_balance TYPE NUMERIC(18,2) USING locked_balance::NUMERIC(18,2);
      UPDATE wallet_accounts SET currency='HOPE' WHERE currency='TOMAN';
      ALTER TABLE wallet_accounts ALTER COLUMN currency SET DEFAULT 'HOPE';
    `);
  },
};
