export const migration = {
  version: 45,
  name: 'chat_retention_metadata_and_legal_holds',
  async up(client) {
    await client.query(`
      ALTER TABLE chat_conversations
        ADD COLUMN IF NOT EXISTS terminal_at TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS terminal_event TEXT NULL;

      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conrelid='chat_conversations'::regclass
            AND conname='chat_conversations_terminal_event_check'
        ) THEN
          ALTER TABLE chat_conversations
            ADD CONSTRAINT chat_conversations_terminal_event_check
            CHECK (
              (terminal_at IS NULL AND terminal_event IS NULL)
              OR
              (terminal_at IS NOT NULL AND terminal_event IN ('COMPLETED','CANCELLED'))
            );
        END IF;
      END $$;

      CREATE TABLE IF NOT EXISTS chat_conversation_legal_holds (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        conversation_id UUID NOT NULL
          REFERENCES chat_conversations(id) ON DELETE RESTRICT,
        hold_kind TEXT NOT NULL
          CHECK (hold_kind IN ('LEGAL','ADMIN')),
        reason TEXT NOT NULL
          CHECK (char_length(btrim(reason)) BETWEEN 1 AND 1000),
        created_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        released_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
        released_at TIMESTAMPTZ NULL,
        release_reason TEXT NULL,
        CONSTRAINT chat_conversation_legal_holds_release_check
          CHECK (
            (released_at IS NULL AND released_by IS NULL AND release_reason IS NULL)
            OR
            (
              released_at IS NOT NULL
              AND (release_reason IS NOT NULL AND char_length(btrim(release_reason)) BETWEEN 1 AND 1000)
              AND released_at >= created_at
            )
          )
      );

      CREATE INDEX IF NOT EXISTS chat_conversations_open_terminal_idx
        ON chat_conversations(terminal_at,created_at,id)
        WHERE kind='JOB' AND status='OPEN';

      CREATE INDEX IF NOT EXISTS chat_conversations_closed_retention_idx
        ON chat_conversations(closed_at,created_at,id)
        WHERE kind='JOB' AND status='CLOSED';

      CREATE INDEX IF NOT EXISTS chat_conversation_legal_holds_active_idx
        ON chat_conversation_legal_holds(conversation_id,created_at DESC)
        WHERE released_at IS NULL;
    `);
  },
  async down(client) {
    const { rows } = await client.query(`
      SELECT
        EXISTS (
          SELECT 1 FROM chat_conversations
          WHERE terminal_at IS NOT NULL OR terminal_event IS NOT NULL
        ) AS has_terminal_metadata,
        EXISTS (
          SELECT 1 FROM chat_conversation_legal_holds
        ) AS has_legal_holds
    `);
    if (rows[0]?.has_terminal_metadata || rows[0]?.has_legal_holds) {
      throw new Error(
        'Cannot rollback chat retention migration while terminal metadata or legal-hold records exist',
      );
    }

    await client.query(`
      DROP INDEX IF EXISTS chat_conversation_legal_holds_active_idx;
      DROP INDEX IF EXISTS chat_conversations_closed_retention_idx;
      DROP INDEX IF EXISTS chat_conversations_open_terminal_idx;
      DROP TABLE IF EXISTS chat_conversation_legal_holds;
      ALTER TABLE chat_conversations
        DROP CONSTRAINT IF EXISTS chat_conversations_terminal_event_check,
        DROP COLUMN IF EXISTS terminal_event,
        DROP COLUMN IF EXISTS terminal_at;
    `);
  },
};
