# HOPE Disaster Recovery

## Purpose

This document defines the minimum recovery path for the backend and its PostgreSQL data. Recovery is fail-closed: a backup is not considered usable until a restore has been exercised and validated.

## Backup and restore operators

Create a backup with:

```bash
backend/scripts/backup.sh
```

Restore into an isolated recovery database with:

```bash
backend/scripts/restore.sh
```

The restore target must not be the production database unless the incident procedure explicitly authorizes that action. Prefer an isolated database first, validate schema/migrations, then perform controlled promotion or data repair.

## CI recovery drill

The staging certification pipeline owns the automated DR restore drill. The drill records the observed result through `backend/tools/write-evidence.mjs --gate dr_restore` and is tied to the staging certification SHA and run attempt. A skipped or failed drill does not create PASS evidence.

## Recovery sequence

1. Identify the latest known-good backup and its timestamp.
2. Validate that the backup artifact is non-empty and has an independently recorded checksum.
3. Provision an isolated PostgreSQL target.
4. Run `backend/scripts/restore.sh` against that target.
5. Validate migrations, relational constraints, critical wallet/ledger records, and application startup.
6. Record the restore result and preserve the CI log/artifact identifiers.
7. Only after validation, determine whether production recovery, point-in-time replay, or a controlled data repair is appropriate.

## Financial integrity

Wallet balances, journal entries, payment holds, refunds, releases, and payout state must be reconciled after restore. Terminal financial records are not reconstructed from mutable UI state. Any discrepancy becomes an operations case rather than an automatic balance overwrite.

## Data protection

Backups and recovery credentials are environment-managed secrets. Do not commit database dumps, production credentials, signing keys, or provider tokens to the repository.
