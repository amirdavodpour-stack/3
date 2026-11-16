export const migration = {
  version: 60,
  name: 'reconciliation_event_attestation_and_disposition',
  async up(client) {
    await client.query(`
      ALTER TABLE reconciliation_case_events
        ADD COLUMN evidence_source_type TEXT,
        ADD COLUMN evidence_issuer TEXT,
        ADD COLUMN artifact_sha256 TEXT,
        ADD COLUMN source_observed_at TIMESTAMPTZ,
        ADD COLUMN reviewed_case_digest TEXT;

      ALTER TABLE reconciliation_case_events
        DROP CONSTRAINT reconciliation_case_events_action_check,
        ADD CONSTRAINT reconciliation_case_events_action_check
          CHECK (action IN (
            'INVESTIGATION_NOTE_ADDED',
            'INVESTIGATION_ATTESTATION_RECORDED',
            'INVESTIGATION_CLOSED_UNRESOLVED',
            'INVESTIGATION_REOPENED'
          )),
        ADD CONSTRAINT reconciliation_case_events_source_type_check
          CHECK (
            evidence_source_type IS NULL
            OR evidence_source_type IN (
              'BANK_STATEMENT',
              'INTERNAL_LEDGER',
              'OUTBOX_EVENT',
              'OPERATOR_REPORT',
              'PROVIDER_ARTIFACT',
              'SUPPORT_TICKET',
              'OTHER'
            )
          ),
        ADD CONSTRAINT reconciliation_case_events_issuer_check
          CHECK (
            evidence_issuer IS NULL
            OR length(trim(evidence_issuer)) BETWEEN 2 AND 160
          ),
        ADD CONSTRAINT reconciliation_case_events_artifact_sha256_check
          CHECK (
            artifact_sha256 IS NULL
            OR artifact_sha256 ~ '^[0-9a-f]{64}$'
          ),
        ADD CONSTRAINT reconciliation_case_events_reviewed_digest_check
          CHECK (
            reviewed_case_digest IS NULL
            OR reviewed_case_digest ~ '^[0-9a-f]{64}$'
          ),
        ADD CONSTRAINT reconciliation_case_events_attestation_provenance_check
          CHECK (
            action='INVESTIGATION_NOTE_ADDED'
            OR (
              evidence_source_type IS NOT NULL
              AND evidence_issuer IS NOT NULL
              AND evidence_reference IS NOT NULL
              AND reviewed_case_digest IS NOT NULL
            )
          );

      CREATE INDEX reconciliation_case_events_case_attestation_idx
        ON reconciliation_case_events(case_id,created_at DESC,id DESC)
        WHERE reviewed_case_digest IS NOT NULL;
    `);
  },
  async down(client) {
    const { rows } = await client.query(`
      SELECT 1
        FROM reconciliation_case_events
       WHERE action <> 'INVESTIGATION_NOTE_ADDED'
          OR evidence_source_type IS NOT NULL
          OR evidence_issuer IS NOT NULL
          OR artifact_sha256 IS NOT NULL
          OR source_observed_at IS NOT NULL
          OR reviewed_case_digest IS NOT NULL
       LIMIT 1
    `);
    if (rows.length) {
      throw new Error('Cannot rollback event attestation migration while attestation or disposition evidence exists');
    }
    await client.query(`
      DROP INDEX reconciliation_case_events_case_attestation_idx;
      ALTER TABLE reconciliation_case_events
        DROP CONSTRAINT reconciliation_case_events_attestation_provenance_check,
        DROP CONSTRAINT reconciliation_case_events_reviewed_digest_check,
        DROP CONSTRAINT reconciliation_case_events_artifact_sha256_check,
        DROP CONSTRAINT reconciliation_case_events_issuer_check,
        DROP CONSTRAINT reconciliation_case_events_source_type_check,
        DROP CONSTRAINT reconciliation_case_events_action_check,
        ADD CONSTRAINT reconciliation_case_events_action_check
          CHECK (action='INVESTIGATION_NOTE_ADDED'),
        DROP COLUMN reviewed_case_digest,
        DROP COLUMN source_observed_at,
        DROP COLUMN artifact_sha256,
        DROP COLUMN evidence_issuer,
        DROP COLUMN evidence_source_type;
    `);
  },
};
