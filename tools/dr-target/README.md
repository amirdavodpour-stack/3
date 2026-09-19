# HOPE Standalone DR Target

This target is intentionally independent from Railway, Supabase billing, payment providers, DNS, and other paid infrastructure.

## Components

- PostgreSQL 17 in Docker
- Persistent local Docker volume for the restored DR database
- Local backup directory for controlled backup artifacts
- Existing HOPE restore tooling
- Optional GitHub Actions drill using an ephemeral PostgreSQL target

The DR target is not production and must never receive live write traffic.

## Start the target

Copy .env.example to .env, replace the local password, then run:

    docker compose up -d
    docker compose ps

The database is available at:

    postgresql://<user>:<password>@127.0.0.1:55432/<database>

## Restore a verified dump

    DRILL_DATABASE_URL='postgresql://hope:<password>@127.0.0.1:55432/hope_dr' bash ../../backend/scripts/restore.sh ./backups/hope-<timestamp>.dump

After restore, validate application migrations:

    DATABASE_URL='postgresql://hope:<password>@127.0.0.1:55432/hope_dr' (cd ../../backend && npm ci && npm run migrate:status)

## Full DR drill

    SOURCE_DATABASE_URL='postgresql://...' DRILL_DATABASE_URL='postgresql://hope:<password>@127.0.0.1:55432/hope_dr' RTO_TARGET_SECONDS=900 bash ../../backend/scripts/dr-restore-drill.sh

Do not put a production/source URL or credentials into this directory or commit them to Git.

## Isolation guarantees

- Source and DR URLs must be different.
- Restore uses pg_restore --clean --if-exists --no-owner.
- The target is a separate PostgreSQL database and persistent Docker volume.
- The app must be pointed at the DR target only during a controlled recovery exercise.
