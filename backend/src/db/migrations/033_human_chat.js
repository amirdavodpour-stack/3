export const migration = {
  version: 33,
  name: 'human_chat',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS chat_conversations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        kind TEXT NOT NULL CHECK (kind IN ('JOB','ADMIN')),
        job_id UUID NULL UNIQUE REFERENCES jobs(id) ON DELETE RESTRICT,
        status TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','CLOSED')),
        title TEXT NOT NULL DEFAULT '',
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        closed_at TIMESTAMPTZ NULL,
        CHECK (
          (kind='JOB' AND job_id IS NOT NULL)
          OR
          (kind='ADMIN' AND job_id IS NULL)
        )
      );
      CREATE UNIQUE INDEX IF NOT EXISTS chat_conversations_admin_uq
        ON chat_conversations(kind) WHERE kind='ADMIN';
      CREATE INDEX IF NOT EXISTS chat_conversations_job_idx
        ON chat_conversations(job_id,status);
      CREATE TABLE IF NOT EXISTS chat_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        conversation_id UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE CASCADE,
        sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS chat_messages_conversation_idx
        ON chat_messages(conversation_id,created_at ASC,id ASC);
    `);
  },
  async down(client) {
    const { rows } = await client.query(`SELECT 1 FROM chat_messages LIMIT 1`);
    if (rows.length) throw new Error('Cannot rollback human_chat while it contains messages');
    await client.query(`DROP TABLE IF EXISTS chat_messages; DROP TABLE IF EXISTS chat_conversations;`);
  },
};