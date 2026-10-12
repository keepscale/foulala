#!/usr/bin/env bash
# Recrée une base de test, charge le schéma et l'API, puis lance tous les tests SQL.
# Usage : PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres ./scripts/db-test.sh
set -euo pipefail

cd "$(dirname "$0")/.."
DB="${TEST_DB:-foulala_test}"

psql -v ON_ERROR_STOP=1 -q -d postgres -c "DROP DATABASE IF EXISTS ${DB}" -c "CREATE DATABASE ${DB}"
psql -v ON_ERROR_STOP=1 -q -d "${DB}" -f db/schema.sql
psql -v ON_ERROR_STOP=1 -q -d "${DB}" -f db/api.sql

for t in db/tests/*.sql; do
  echo "→ ${t}"
  psql -v ON_ERROR_STOP=1 -q -d "${DB}" -f "${t}"
done

echo "Tous les tests SQL passent."
