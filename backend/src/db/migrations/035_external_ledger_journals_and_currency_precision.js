export const migration = {
  version: 35,
  name: 'external_ledger_journals_and_currency_precision',
  async up(client) {
    await client.query(`
      ALTER TABLE ledger_entries
        ALTER COLUMN debit TYPE NUMERIC(18,2) USING debit::NUMERIC(18,2),
        ALTER COLUMN credit TYPE NUMERIC(18,2) USING credit::NUMERIC(18,2);

      ALTER TABLE ledger_entries
        ADD CONSTRAINT ledger_entries_toman_integer_chk
        CHECK (currency <> 'TOMAN' OR (debit = TRUNC(debit) AND credit = TRUNC(credit)));

      ALTER TABLE journals DROP CONSTRAINT IF EXISTS journals_currency_check;
      ALTER TABLE journals
        ADD CONSTRAINT journals_currency_supported_chk
        CHECK (currency IN ('TOMAN','USD','EUR','IRR'));
    `);

    const { rows: duplicateProviderKeys } = await client.query(`
      SELECT operation_type,idempotency_key,COUNT(*)::int AS row_count
        FROM financial_operations
       WHERE actor_type='PROVIDER' AND idempotency_key IS NOT NULL
       GROUP BY operation_type,idempotency_key
      HAVING COUNT(*) > 1
       LIMIT 5
    `);
    if (duplicateProviderKeys.length) {
      throw new Error(`Cannot enforce provider operation idempotency: ${duplicateProviderKeys.map((row) => `${row.operation_type}/${row.idempotency_key}`).join(', ')}`);
    }

    const { rows: invalidGroups } = await client.query(`
      SELECT le.journal_id,COUNT(*)::int AS entry_count,
             MIN(le.currency) AS min_currency,MAX(le.currency) AS max_currency,
             COALESCE(SUM(le.debit),0) AS debit_total,COALESCE(SUM(le.credit),0) AS credit_total
        FROM ledger_entries le
        LEFT JOIN journals j ON j.id=le.journal_id
       WHERE j.id IS NULL
       GROUP BY le.journal_id
      HAVING MIN(le.currency) <> MAX(le.currency)
          OR MIN(le.currency) NOT IN ('TOMAN','USD','EUR','IRR')
          OR COALESCE(SUM(le.debit),0) <> COALESCE(SUM(le.credit),0)
          OR COALESCE(SUM(le.debit),0) <= 0
       ORDER BY le.journal_id
       LIMIT 10
    `);
    if (invalidGroups.length) {
      const details = invalidGroups.map((row) => `${row.journal_id}[${row.min_currency}/${row.max_currency}; debit=${row.debit_total}; credit=${row.credit_total}]`).join('; ');
      throw new Error(`Cannot canonicalize invalid legacy ledger groups; reconcile them before migration 035: ${details}`);
    }

    const { rows: orphanGroups } = await client.query(`
      SELECT le.journal_id,MIN(le.currency) AS currency,
             MIN(le.created_at) AS created_at,MAX(le.created_at) AS posted_at
        FROM ledger_entries le
        LEFT JOIN journals j ON j.id=le.journal_id
       WHERE j.id IS NULL
       GROUP BY le.journal_id
       ORDER BY MIN(le.created_at),le.journal_id
    `);
    for (const group of orphanGroups) {
      const idempotencyKey = `migration-035:legacy-ledger:${group.journal_id}`;
      const { rows: operationRows } = await client.query(`
        INSERT INTO financial_operations(
          id,operation_type,actor_type,actor_id,status,idempotency_key,request_hash,created_at,completed_at
        )
        VALUES(gen_random_uuid(),'ADJUSTMENT','SYSTEM',NULL,'SUCCEEDED',$1,NULL,$2,$3)
        RETURNING id
      `, [idempotencyKey,group.created_at,group.posted_at]);
      await client.query(`
        INSERT INTO journals(id,operation_id,journal_type,currency,status,created_at,posted_at)
        VALUES($1,$2,'LEGACY_IMPORT',$3,'POSTED',$4,$5)
      `, [group.journal_id,operationRows[0].id,group.currency,group.created_at,group.posted_at]);
    }

    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS financial_operations_provider_idempotency_uq
        ON financial_operations(operation_type,idempotency_key)
        WHERE actor_type='PROVIDER' AND idempotency_key IS NOT NULL;
      ALTER TABLE ledger_entries
        ADD CONSTRAINT ledger_entries_journal_id_fk
        FOREIGN KEY (journal_id) REFERENCES journals(id) ON DELETE RESTRICT NOT VALID;
      ALTER TABLE ledger_entries VALIDATE CONSTRAINT ledger_entries_journal_id_fk;
      ALTER TABLE ledger_entries ALTER COLUMN journal_id SET NOT NULL;
    `);
  },
  async down() {
    throw new Error('Migration 035 is forward-only: it canonicalizes historical financial entries and enables exact external-currency amounts.');
  },
};
