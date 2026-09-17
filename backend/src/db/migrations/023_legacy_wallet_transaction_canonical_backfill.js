export const migration = {
  version: 23,
  name: 'legacy_wallet_transaction_canonical_backfill',
  async up(client) {
    // Migration 006 converted wallet_accounts.currency before selecting legacy
    // wallet_transactions, so its intended backfill can be skipped entirely.
    // This forward-only repair migrates the retained legacy stream without
    // rewriting any already-canonical wallet entries.
    const { rows } = await client.query(`
      SELECT id,idempotency_key,transaction_type,reference_type,reference_id,currency,amount,
             source_wallet_id,destination_wallet_id,metadata,created_at
      FROM wallet_transactions
      WHERE currency='HOPE'
      ORDER BY created_at,id
    `);

    const operationType = (type) => ({
      CREDIT: 'TOP_UP',
      DEBIT: 'ADJUSTMENT',
      TRANSFER: 'TRANSFER',
      HOLD: 'HOLD',
      RELEASE: 'RELEASE',
      REFUND: 'REFUND',
    }[type] || 'ADJUSTMENT');

    for (const row of rows) {
      const legacyKey = `legacy-wallet:${row.idempotency_key}`;
      const existing = await client.query(
        `SELECT id FROM financial_operations WHERE idempotency_key=$1 LIMIT 1`,
        [legacyKey],
      );

      let operationId = existing.rows[0]?.id;
      if (!operationId) {
        const inserted = await client.query(`
          INSERT INTO financial_operations(
            operation_type,actor_type,status,idempotency_key,request_hash,created_at,completed_at
          )
          VALUES($1,'SYSTEM','SUCCEEDED',$2,NULL,$3,$3)
          RETURNING id
        `, [operationType(row.transaction_type), legacyKey, row.created_at]);
        operationId = inserted.rows[0].id;
      }

      const metadata = {
        ...(row.metadata || {}),
        legacy_wallet_transaction_id: row.id,
        legacy_backfill: true,
      };
      const referenceId = row.reference_id || row.id;

      const existingEntry = await client.query(`
        SELECT 1
        FROM wallet_entries
        WHERE financial_operation_id=$1
          AND metadata->>'legacy_wallet_transaction_id'=$2
        LIMIT 1
      `, [operationId, row.id]);

      if (!existingEntry.rows[0]) {
        if (row.source_wallet_id && row.destination_wallet_id && row.source_wallet_id === row.destination_wallet_id) {
          const direction = row.transaction_type === 'HOLD' ? 'DEBIT' : 'CREDIT';
          const entryType = row.transaction_type === 'CREDIT' ? 'TOP_UP' : row.transaction_type;
          await client.query(`
            INSERT INTO wallet_entries(
              wallet_id,entry_type,direction,amount,currency,reference_type,reference_id,
              financial_operation_id,metadata,created_at
            )
            VALUES($1,$2,$3,$4,'TOMAN',$5,$6,$7,$8::jsonb,$9)
          `, [
            row.destination_wallet_id,
            entryType,
            direction,
            row.amount,
            row.reference_type,
            referenceId,
            operationId,
            JSON.stringify(metadata),
            row.created_at,
          ]);
        } else {
          if (row.source_wallet_id) {
            await client.query(`
              INSERT INTO wallet_entries(
                wallet_id,entry_type,direction,amount,currency,reference_type,reference_id,
                financial_operation_id,metadata,created_at
              )
              VALUES($1,$2,'DEBIT',$3,'TOMAN',$4,$5,$6,$7::jsonb,$8)
            `, [
              row.source_wallet_id,
              row.transaction_type,
              row.amount,
              row.reference_type,
              referenceId,
              operationId,
              JSON.stringify(metadata),
              row.created_at,
            ]);
          }
          if (row.destination_wallet_id) {
            await client.query(`
              INSERT INTO wallet_entries(
                wallet_id,entry_type,direction,amount,currency,reference_type,reference_id,
                financial_operation_id,metadata,created_at
              )
              VALUES($1,$2,'CREDIT',$3,'TOMAN',$4,$5,$6,$7::jsonb,$8)
            `, [
              row.destination_wallet_id,
              row.transaction_type,
              row.amount,
              row.reference_type,
              referenceId,
              operationId,
              JSON.stringify(metadata),
              row.created_at,
            ]);
          }
        }
      }

      const journal = await client.query(`
        SELECT id FROM journals WHERE operation_id=$1 AND journal_type='LEGACY_BACKFILL' LIMIT 1
      `, [operationId]);

      if (!journal.rows[0]) {
        const { rows: journalRows } = await client.query(`
          INSERT INTO journals(operation_id,journal_type,currency,status)
          VALUES($1,'LEGACY_BACKFILL','TOMAN','CREATED')
          RETURNING id
        `, [operationId]);
        const journalId = journalRows[0].id;

        const addEntry = async (account, debit, credit) => {
          await client.query(`
            INSERT INTO ledger_entries(
              id,journal_id,reference_type,reference_id,account,debit,credit,currency,created_at
            )
            VALUES(gen_random_uuid(),$1,$2,$3,$4,$5,$6,'TOMAN',$7)
          `, [journalId, row.reference_type, referenceId, account, debit, credit, row.created_at]);
        };

        const amount = row.amount;
        switch (row.transaction_type) {
          case 'CREDIT':
            await addEntry('PLATFORM_CASH', amount, 0);
            await addEntry('CUSTOMER_WALLET_LIABILITY', 0, amount);
            break;
          case 'DEBIT':
            await addEntry('CUSTOMER_WALLET_LIABILITY', amount, 0);
            await addEntry('PLATFORM_CASH', 0, amount);
            break;
          case 'TRANSFER':
            await addEntry('CUSTOMER_WALLET_LIABILITY', amount, 0);
            await addEntry('CUSTOMER_WALLET_LIABILITY', 0, amount);
            break;
          case 'HOLD':
            await addEntry('CUSTOMER_WALLET_LIABILITY', amount, 0);
            await addEntry('ESCROW_LIABILITY', 0, amount);
            break;
          case 'RELEASE':
            await addEntry('ESCROW_LIABILITY', amount, 0);
            await addEntry('WORKER_PAYABLE', 0, amount);
            break;
          case 'REFUND':
            await addEntry('ESCROW_LIABILITY', amount, 0);
            await addEntry('CUSTOMER_WALLET_LIABILITY', 0, amount);
            break;
          default:
            await addEntry('CUSTOMER_WALLET_LIABILITY', amount, 0);
            await addEntry('PLATFORM_CASH', 0, amount);
        }

        await client.query(`
          UPDATE journals SET status='POSTED',posted_at=NOW() WHERE id=$1
        `, [journalId]);
      }
    }
  },
  async down() {
    throw new Error('Migration 023 is a forward-only financial data repair and is not reversible without risking canonical ledger integrity');
  },
};
