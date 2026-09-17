export const migration = {
  version: 9,
  name: 'posted_journal_entry_immutability',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_reject_posted_journal_entry_mutation() RETURNS trigger
      LANGUAGE plpgsql AS $$
      BEGIN
        IF EXISTS (SELECT 1 FROM journals WHERE id = COALESCE(NEW.journal_id, OLD.journal_id) AND status='POSTED') THEN
          RAISE EXCEPTION 'ledger entries of posted journals are immutable' USING ERRCODE='55000';
        END IF;
        RETURN COALESCE(NEW, OLD);
      END;
      $$;
      DROP TRIGGER IF EXISTS ledger_entries_posted_journal_immutable_trigger ON ledger_entries;
      CREATE TRIGGER ledger_entries_posted_journal_immutable_trigger
        BEFORE INSERT OR UPDATE OR DELETE ON ledger_entries
        FOR EACH ROW EXECUTE FUNCTION hope_reject_posted_journal_entry_mutation();
    `);
  },
  async down(client) {
    await client.query(`DROP TRIGGER IF EXISTS ledger_entries_posted_journal_immutable_trigger ON ledger_entries; DROP FUNCTION IF EXISTS hope_reject_posted_journal_entry_mutation();`);
  },
};
