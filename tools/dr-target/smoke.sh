#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$ROOT_DIR"

docker compose up -d
trap 'docker compose down' EXIT

echo "Waiting for DR PostgreSQL..."
for _ in $(seq 1 30); do
  if docker compose exec -T hope-dr-postgres pg_isready -U "${DR_POSTGRES_USER:-hope}" -d "${DR_POSTGRES_DB:-hope_dr}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

docker compose exec -T hope-dr-postgres pg_isready -U "${DR_POSTGRES_USER:-hope}" -d "${DR_POSTGRES_DB:-hope_dr}" >/dev/null

echo "DR target smoke PASS"
docker compose ps
