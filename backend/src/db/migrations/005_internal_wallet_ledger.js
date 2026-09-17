export const migration = {
  version: 5,
  name: 'internal_wallet_ledger',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS wallet_accounts (
        id UUID PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        currency TEXT NOT NULL,
        available_balance NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
        locked_balance NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (locked_balance >= 0),
        status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','CLOSED')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE(user_id, currency)
      );
      CREATE INDEX IF NOT EXISTS wallet_accounts_user_idx ON wallet_accounts(user_id, currency);

      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id UUID PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        transaction_type TEXT NOT NULL CHECK (transaction_type IN ('CREDIT','DEBIT','HOLD','RELEASE','REFUND','TRANSFER')),
        reference_type TEXT NOT NULL,
        reference_id UUID NULL,
        currency TEXT NOT NULL,
        amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
        status TEXT NOT NULL CHECK (status IN ('POSTED','FAILED','REVERSED')),
        source_wallet_id UUID NULL REFERENCES wallet_accounts(id) ON DELETE RESTRICT,
        destination_wallet_id UUID NULL REFERENCES wallet_accounts(id) ON DELETE RESTRICT,
        metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS wallet_transactions_reference_idx ON wallet_transactions(reference_type, reference_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS wallet_transactions_source_idx ON wallet_transactions(source_wallet_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS wallet_transactions_destination_idx ON wallet_transactions(destination_wallet_id, created_at DESC);

      INSERT INTO wallet_accounts(id,user_id,currency,available_balance,locked_balance,status,created_at,updated_at)
      SELECT gen_random_uuid(), u.id, 'HOPE', 0, 0, 'ACTIVE', NOW(), NOW()
      FROM users u
      WHERE NOT EXISTS (
        SELECT 1 FROM wallet_accounts w WHERE w.user_id=u.id AND w.currency='HOPE'
      );
    `);
  },
  async down(client) {
    await client.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT 1 FROM wallet_transactions LIMIT 1) THEN
          RAISE EXCEPTION 'Cannot rollback internal_wallet_ledger while wallet transaction data exists' USING ERRCODE='55000';
        END IF;
      END $$;
      DROP TABLE IF EXISTS wallet_transactions;
      DROP TABLE IF EXISTS wallet_accounts;
    `);
  },
};
