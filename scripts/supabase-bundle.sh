#!/usr/bin/env bash
# Assemble les scripts SQL à coller dans l'éditeur SQL de Supabase (TESTS UNIQUEMENT).
#
#   ./scripts/supabase-bundle.sh
#
#   supabase/build/setup.sql  : base vide → schéma, API, purge horaire, droits Supabase, données de test
#   supabase/build/reseed.sql : recharge les données de test (dates recalculées depuis maintenant)
#
# Les sources restent db/*.sql : ne jamais modifier les fichiers générés.
# L'éditeur de Supabase ne comprend pas les commandes psql (\set…) : elles sont retirées.
set -euo pipefail

cd "$(dirname "$0")/.."
out=supabase/build
mkdir -p "$out"

strip_psql() { grep -v '^\\' "$1"; }

header() {
  cat <<EOF
-- GÉNÉRÉ par scripts/supabase-bundle.sh le $(date -u +%Y-%m-%dT%H:%MZ) : ne pas modifier.
-- $1
-- Supabase journalise les adresses IP : tests entre amis uniquement, jamais de vraie manif.

EOF
}

{
  header "À coller dans l'éditeur SQL de Supabase, sur une base VIDE."
  for f in db/schema.sql db/api.sql server/initdb/40-cron.sql supabase/adapter.sql db/seed.sql; do
    printf -- '\n-- ===== %s =====\n\n' "$f"
    strip_psql "$f"
  done
} > "$out/setup.sql"

{
  header "Recharge les données de test (manifs fictives, dont deux en cours)."
  strip_psql db/seed.sql
} > "$out/reseed.sql"

echo "→ $out/setup.sql ($(wc -l < "$out/setup.sql") lignes)"
echo "→ $out/reseed.sql"
