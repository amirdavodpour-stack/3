export const migration = {
  version: 46,
  name: 'chat_retention_constraint_hardening',
  async up(client) {
    await client.query(`
      ALTER TABLE chat_conversations
        ADD CONSTRAINT chat_conversations_terminal_event_consistency_v2_check
        CHECK (
          (terminal_at IS NULL AND terminal_event IS NULL)
          OR
          (
            terminal_at IS NOT NULL
            AND terminal_event IS NOT NULL
            AND terminal_event IN ('COMPLETED','CANCELLED')
          )
        ) NOT VALID;

      ALTER TABLE chat_conversation_legal_holds
        ADD CONSTRAINT chat_conversation_legal_holds_release_actor_v2_check
        CHECK (
          (released_at IS NULL AND released_by IS NULL AND release_reason IS NULL)
          OR
          (
            released_at IS NOT NULL
            AND released_by IS NOT NULL
            AND release_reason IS NOT NULL
            AND char_length(btrim(release_reason)) BETWEEN 1 AND 1000
            AND released_at >= created_at
          )
        ) NOT VALID;
    `);
  },
  async down(client) {
    await client.query(`
      ALTER TABLE chat_conversation_legal_holds
        DROP CONSTRAINT IF EXISTS chat_conversation_legal_holds_release_actor_v2_check;
      ALTER TABLE chat_conversations
        DROP CONSTRAINT IF EXISTS chat_conversations_terminal_event_consistency_v2_check;
    `);
  },
};
