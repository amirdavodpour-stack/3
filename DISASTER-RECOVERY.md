# HOPE Disaster Recovery

## Purpose

This document defines the minimum recovery path for the backend and its PostgreSQL data. Recovery is fail-closed: a backup is not considered usable until a restore has been exercised and validated.

## Independent DR target

The current external DR target is a separate PostgreSQL project on Neon Free:

- Project: HOPE-V8-DR-free
- Project ID: round-bird-08883415
- PostgreSQL: 17
- Region: AWS us-east-1
- Database: neondb

The target is separate from the Railway staging database and from Supabase. It is not production and must never receive normal application write traffic.

The GitHub Actions credential is:

    DRILL_DATABASE_URL=<Neon PostgreSQL connection string>

Do not commit or print this value. It contains a database credential.

A local Docker fallback is also provided under:

    tools/dr-target/

That fallback is useful when an operator needs a self-hosted recovery target without any cloud dependency.

## Backup and restore operators

Create a backup with:

    backend/scripts/backup.sh

Restore into an isolated recovery database with:

    backend/scripts/restore.sh

The restore target must not be the production database. Recovery is performed against the independent DR target first.

## CI recovery drill

The DR workflow requires:

    SOURCE_DATABASE_URL
    DRILL_DATABASE_URL

For the current staging setup, DRILL_DATABASE_URL should point to the independent Neon DR target.

The workflow validates:

- backup structure
- restore success and RTO
- migration checksum/status
- required application tables
- wallet currency and non-negative balances
- posted journal balance
- payout terminal/state invariants

A skipped or failed drill does not create PASS evidence.

## Recovery sequence

1. Identify the latest known-good backup and its timestamp.
2. Validate that the backup artifact is non-empty and structurally valid.
3. Confirm that the source and DR connection strings identify different databases.
4. Restore the backup into the independent DR target.
5. Validate migrations, relational constraints, critical wallet/ledger records, and application startup.
6. Record the restore result and preserve the CI log/artifact identifiers.
7. Only after validation, determine whether production recovery, point-in-time replay, or a controlled data repair is appropriate.

## Financial integrity

Wallet balances, journal entries, payment holds, refunds, releases, and payout state must be reconciled after restore. Terminal financial records are not reconstructed from mutable UI state. Any discrepancy becomes an operations case rather than an automatic balance overwrite.

## Data protection

Backups and recovery credentials are environment-managed secrets. Do not commit database dumps, production credentials, signing keys, provider tokens, or the Neon connection string to the repository.

For GitHub Actions, use the repository secret named DRILL_DATABASE_URL. The value should be copied directly from the Neon connection string for project round-bird-08883415.
