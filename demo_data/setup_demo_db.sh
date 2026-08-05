#!/usr/bin/env bash
# Create and load the levaintron_demo database from the checked-in dump.
# Safe to re-run: drops ONLY the demo database, never touches anything else.
set -euo pipefail

PG_SUPER_URL="${PG_SUPER_URL:-postgresql://postgres:8989@127.0.0.1:5432/postgres}"
DEMO_DB="${DEMO_DB:-levaintron_demo}"
HERE="$(cd "$(dirname "$0")" && pwd)"

psql "$PG_SUPER_URL" -c "DROP DATABASE IF EXISTS $DEMO_DB"
psql "$PG_SUPER_URL" -c "CREATE DATABASE $DEMO_DB"
psql "${PG_SUPER_URL%/*}/$DEMO_DB" -q -v ON_ERROR_STOP=1 -f "$HERE/levaintron_demo.sql"
echo "Demo database '$DEMO_DB' ready."
echo "Point the pipeline at it with: export DEMO_DATABASE_URL=${PG_SUPER_URL%/*}/$DEMO_DB"
