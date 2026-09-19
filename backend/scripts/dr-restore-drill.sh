#!/usr/bin/env sh
set -eu

: "${SOURCE_DATABASE_URL:?SOURCE_DATABASE_URL is required}"
: "${DRILL_DATABASE_URL:?DRILL_DATABASE_URL is required}"

[ "$SOURCE_DATABASE_URL" != "$DRILL_DATABASE_URL" ] || { echo "SOURCE_DATABASE_URL and DRILL_DATABASE_URL must be different isolated targets." >&2; exit 1; }

command -v pg_dump >/dev/null 2>&1 || { echo 'pg_dump is required' >&2; exit 1; }
command -v pg_restore >/dev/null 2>&1 || { echo 'pg_restore is required' >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo 'psql is required' >&2; exit 1; }

WORK_DIR="${DRILL_WORK_DIR:-$(mktemp -d)}"
mkdir -p "$WORK_DIR"

DUMP="$WORK_DIR/restore-drill.dump"
EVIDENCE="${DRILL_EVIDENCE_FILE:-$WORK_DIR/restore-evidence.txt}"
DIAGNOSTIC="${DRILL_DIAGNOSTIC_FILE:-docs/audit/evidence/dr-restore-diagnostics.txt}"
STAGE="initialization"

write_failure_evidence() {
  rc="$?"
  if [ "$rc" -ne 0 ] && [ ! -f "$EVIDENCE" ]; then
    {
      echo 'HOPE DR restore drill'
      echo "Result: FAIL"
      echo "Failure stage: $STAGE"
      echo "Completed UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "Diagnostic file: $DIAGNOSTIC"
    } > "$EVIDENCE"
  fi
  rm -f "$DUMP"
  exit "$rc"
}
trap write_failure_evidence EXIT

START_EPOCH="$(date +%s)"
START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STAGE="backup"
echo '== PostgreSQL backup =='
BACKUP_START="$(date +%s)"
pg_dump "$SOURCE_DATABASE_URL" --format=custom --file="$DUMP"
"$(dirname "$0")/verify-backup.sh" "$DUMP"
BACKUP_END="$(date +%s)"
BACKUP_SECONDS=$((BACKUP_END-BACKUP_START))

STAGE="archive-inspection"
pg_restore --list "$DUMP" >"$WORK_DIR/restore-toc.txt"
{
  echo '== Archive TOC entries for required tables =='
  grep -E 'TABLE (DATA )?public (users|categories|jobs|offers|job_applications|payments|outbox_events)' "$WORK_DIR/restore-toc.txt" || true
  echo
  echo '== Drill target tables before restore =='
  psql "$DRILL_DATABASE_URL" -Atqc "select table_name from information_schema.tables where table_schema='public' order by table_name;" || true
  echo
  echo '== Drill job_applications before restore =='
  psql "$DRILL_DATABASE_URL" -Atqc "select to_regclass('public.job_applications');" || true
} > "$DIAGNOSTIC"

if ! grep -Eq 'TABLE public job_applications([[:space:]]|$)' "$WORK_DIR/restore-toc.txt"; then
  echo 'Restore archive is missing the TABLE definition for public.job_applications.' >&2
  exit 1
fi
if ! grep -Eq 'TABLE DATA public job_applications([[:space:]]|$)' "$WORK_DIR/restore-toc.txt"; then
  echo 'Restore archive is missing TABLE DATA for public.job_applications.' >&2
  exit 1
fi

STAGE="restore"
echo '== Isolated restore =='
RESTORE_START="$(date +%s)"
pg_restore --exit-on-error --clean --if-exists --no-owner --dbname="$DRILL_DATABASE_URL" "$DUMP"

STAGE="post-restore"
RESTORE_END="$(date +%s)"
RESTORE_SECONDS=$((RESTORE_END-RESTORE_START))
TOTAL_SECONDS=$((RESTORE_END-START_EPOCH))
RTO_TARGET_SECONDS="${RTO_TARGET_SECONDS:-900}"
[ "$TOTAL_SECONDS" -le "$RTO_TARGET_SECONDS" ] || { echo "RTO target exceeded: ${TOTAL_SECONDS}s > ${RTO_TARGET_SECONDS}s" >&2; exit 1; }

count="$(psql "$DRILL_DATABASE_URL" -Atqc "select count(*) from information_schema.tables where table_schema='public';")"
[ "${count:-0}" -ge 15 ] || { echo "Unexpected public table count: $count" >&2; exit 1; }

users="$(psql "$DRILL_DATABASE_URL" -Atqc 'select count(*) from public.users;')"
categories="$(psql "$DRILL_DATABASE_URL" -Atqc 'select count(*) from public.categories;')"
required="users,categories,jobs,offers,payments,outbox_events"
for table in $(printf '%s' "$required" | tr ',' ' '); do
  exists="$(psql "$DRILL_DATABASE_URL" -Atqc "select to_regclass('public.' || '$table') is not null;")"
  [ "$exists" = "t" ] || { echo "Missing required table after restore: $table" >&2; exit 1; }
done
psql "$DRILL_DATABASE_URL" -Atqc 'select 1;' >/dev/null

cat > "$EVIDENCE" <<EOF
HOPE DR restore drill
Started UTC: $START_ISO
Completed UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Backup seconds: $BACKUP_SECONDS
Restore seconds: $RESTORE_SECONDS
Total RTO seconds: $TOTAL_SECONDS
RTO target seconds: $RTO_TARGET_SECONDS
Public tables: $count
Users rows: $users
Categories rows: $categories
Result: PASS
EOF

printf '%s\n' "DR restore drill PASS: evidence=$EVIDENCE"
