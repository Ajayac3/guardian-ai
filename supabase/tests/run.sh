#!/usr/bin/env bash
# Runs the Guardian AI safety-core SQL tests against the local Supabase DB.
# Usage: supabase/tests/run.sh
set -euo pipefail

# Find the running Supabase Postgres container (works for docker or podman).
CTR=$(podman ps --format '{{.Names}}' 2>/dev/null | grep -m1 'supabase_db_' || true)
if [ -z "${CTR:-}" ]; then
  CTR=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 'supabase_db_' || true)
  RUNNER=docker
else
  RUNNER=podman
fi
if [ -z "${CTR:-}" ]; then
  echo "No supabase_db_* container running. Start it: supabase start" >&2
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$RUNNER" exec -i "$CTR" psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < "$DIR/rls_test.sql"
