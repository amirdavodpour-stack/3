export const migration = {
  version: 56,
  name: 'outbox_error_redaction',
  async up(client) {
    await client.query('ALTER TABLE outbox_events ADD COLUMN last_error_code TEXT NULL, ADD COLUMN last_error_category TEXT NULL, ADD COLUMN last_error_retryable BOOLEAN NULL, ADD COLUMN last_error_http_status SMALLINT NULL; ALTER TABLE outbox_events ADD CONSTRAINT outbox_events_last_error_code_check CHECK(last_error_code IS NULL OR last_error_code ~ \'^[A-Z][A-Z0-9_]{0,79}$\'), ADD CONSTRAINT outbox_events_last_error_category_check CHECK(last_error_category IS NULL OR last_error_category IN (\'payment\',\'payout\',\'security\',\'push\',\'email\',\'notification\',\'system\')), ADD CONSTRAINT outbox_events_last_error_http_status_check CHECK(last_error_http_status IS NULL OR last_error_http_status BETWEEN 100 AND 599); ALTER TABLE payouts ADD COLUMN failure_category TEXT NULL, ADD COLUMN failure_retryable BOOLEAN NULL, ADD COLUMN failure_http_status SMALLINT NULL; ALTER TABLE payouts ADD CONSTRAINT payouts_failure_category_check CHECK(failure_category IS NULL OR failure_category=\'payout\'), ADD CONSTRAINT payouts_failure_http_status_check CHECK(failure_http_status IS NULL OR failure_http_status BETWEEN 100 AND 599)');
  },
  async down(client) {
    await client.query('LOCK TABLE outbox_events,payouts IN ACCESS EXCLUSIVE MODE');
    const { rows } = await client.query('SELECT 1 FROM outbox_events WHERE last_error_code IS NOT NULL OR last_error_category IS NOT NULL OR last_error_retryable IS NOT NULL OR last_error_http_status IS NOT NULL UNION ALL SELECT 1 FROM payouts WHERE failure_category IS NOT NULL OR failure_retryable IS NOT NULL OR failure_http_status IS NOT NULL LIMIT 1');
    if (rows.length) throw new Error('Cannot rollback Outbox error redaction while structured failure metadata exists');
    await client.query('ALTER TABLE outbox_events DROP CONSTRAINT outbox_events_last_error_code_check, DROP CONSTRAINT outbox_events_last_error_category_check, DROP CONSTRAINT outbox_events_last_error_http_status_check, DROP COLUMN last_error_code, DROP COLUMN last_error_category, DROP COLUMN last_error_retryable, DROP COLUMN last_error_http_status; ALTER TABLE payouts DROP CONSTRAINT payouts_failure_category_check, DROP CONSTRAINT payouts_failure_http_status_check, DROP COLUMN failure_category, DROP COLUMN failure_retryable, DROP COLUMN failure_http_status');
  },
};