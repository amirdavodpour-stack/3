export const migration = {
  version: 34,
  name: 'chat_capabilities',
  async up(client) {
    await client.query(`
      ALTER TABLE chat_messages ADD COLUMN IF NOT EXISTS message_type TEXT NOT NULL DEFAULT 'TEXT';
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='chat_messages_message_type_check') THEN
          ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_message_type_check CHECK (message_type IN ('TEXT','ATTACHMENT','VOICE'));
        END IF;
      END $$;
      CREATE TABLE IF NOT EXISTS chat_message_attachments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
        upload_id UUID NOT NULL UNIQUE REFERENCES uploads(id) ON DELETE RESTRICT,
        storage_key TEXT NOT NULL, filename TEXT NOT NULL, content_type TEXT NOT NULL,
        size INTEGER NOT NULL CHECK(size > 0), created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS chat_message_attachments_message_idx ON chat_message_attachments(message_id,created_at,id);
      CREATE TABLE IF NOT EXISTS chat_message_reads (
        message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY(message_id,user_id)
      );
      CREATE INDEX IF NOT EXISTS chat_message_reads_user_idx ON chat_message_reads(user_id,read_at DESC);
      CREATE TABLE IF NOT EXISTS chat_presence (
        conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), typing_until TIMESTAMPTZ NULL,
        PRIMARY KEY(conversation_id,user_id)
      );
      CREATE INDEX IF NOT EXISTS chat_presence_expiry_idx ON chat_presence(last_seen_at,typing_until);
      CREATE TABLE IF NOT EXISTS chat_conversation_preferences (
        conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        is_pinned BOOLEAN NOT NULL DEFAULT FALSE, is_important BOOLEAN NOT NULL DEFAULT FALSE,
        is_archived BOOLEAN NOT NULL DEFAULT FALSE, updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY(conversation_id,user_id)
      );
      CREATE INDEX IF NOT EXISTS chat_conversation_preferences_user_idx
        ON chat_conversation_preferences(user_id,is_pinned DESC,is_important DESC,updated_at DESC);
    `);
  },
  async down(client) {
    const {rows: guards}=await client.query(`
      SELECT
        EXISTS(SELECT 1 FROM chat_message_attachments LIMIT 1) AS has_attachments,
        EXISTS(SELECT 1 FROM chat_messages WHERE message_type <> 'TEXT' LIMIT 1) AS has_non_text,
        EXISTS(SELECT 1 FROM chat_message_reads LIMIT 1) AS has_reads,
        EXISTS(SELECT 1 FROM chat_presence LIMIT 1) AS has_presence,
        EXISTS(SELECT 1 FROM chat_conversation_preferences LIMIT 1) AS has_preferences
    `);
    const guard=guards[0]||{};
    if(Object.values(guard).some(Boolean)){
      throw new Error(
        'Cannot rollback chat_capabilities while capability data exists (attachments, non-text messages, read receipts, presence, or preferences)',
      );
    }
    await client.query(`
      DROP TABLE IF EXISTS chat_conversation_preferences;
      DROP TABLE IF EXISTS chat_presence;
      DROP TABLE IF EXISTS chat_message_reads;
      DROP TABLE IF EXISTS chat_message_attachments;
      ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;
      ALTER TABLE chat_messages DROP COLUMN IF EXISTS message_type;
    `);
  },
};
