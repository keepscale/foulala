#!/usr/bin/env bash
# Assemble les scripts SQL à coller dans l'éditeur SQL de Supabase (TESTS UNIQUEMENT).
#
#   ./scripts/supabase-bundle.sh
#
#   supabase/build/setup.sql  : base vide → schéma, API, espace organisateur, administration,
#                               purge horaire, droits Supabase, données de test
#   supabase/build/reset.sql  : efface tout ce que Foulala a créé, avant de rejouer setup.sql
#   supabase/build/reseed.sql : recharge les données de test (dates recalculées depuis maintenant)
#
# Les sources restent db/*.sql : ne jamais modifier les fichiers générés.
# L'éditeur de Supabase ne comprend pas les commandes psql (\set…) : elles sont retirées.
set -euo pipefail

cd "$(dirname "$0")/.."
out=supabase/build
mkdir -p "$out"

# Chez Supabase, pgcrypto (crypt, hmac, gen_random_bytes) vit dans le schéma `extensions` :
# on l'ajoute au search_path des fonctions qui le fixent.
strip_psql() {
  grep -v '^\\' "$1" | sed 's/SET search_path = public, pg_temp/SET search_path = public, extensions, pg_temp/'
}

header() {
  cat <<EOF
-- GÉNÉRÉ par scripts/supabase-bundle.sh le $(date -u +%Y-%m-%dT%H:%MZ) : ne pas modifier.
-- $1
-- Supabase journalise les adresses IP : tests entre amis uniquement, jamais de vraie manif.

EOF
}

{
  header "À coller dans l'éditeur SQL de Supabase, sur une base VIDE (sinon reset.sql d'abord)."
  for f in db/schema.sql db/api.sql db/organizer.sql db/admin.sql server/initdb/40-cron.sql \
           supabase/adapter.sql db/seed.sql; do
    printf -- '\n-- ===== %s =====\n\n' "$f"
    strip_psql "$f"
  done
} > "$out/setup.sql"

{
  header "Recharge les données de test (manifs fictives, dont deux en cours)."
  strip_psql db/seed.sql
} > "$out/reseed.sql"

{
  header "EFFACE tout ce que Foulala a créé (tables, API, comptes, secret), avant de rejouer setup.sql."
  cat <<'SQL'
-- Les rôles (web_anon, organizer, foulala_admin) restent : setup.sql les réutilise.
DO $$
BEGIN
    -- EXECUTE : la requête n'est analysée que si pg_cron est installé
    IF to_regclass('cron.job') IS NOT NULL THEN
        EXECUTE $q$SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'purge-manifs'$q$;
    END IF;
END $$;

DROP SCHEMA IF EXISTS api CASCADE;
DROP SCHEMA IF EXISTS private CASCADE;
DROP TABLE IF EXISTS public.event_tally, public.support, public.presence, public.event, public.organizer CASCADE;
DROP FUNCTION IF EXISTS public.event_compute_geometry();
DROP FUNCTION IF EXISTS public.record_presence(uuid, uuid, timestamptz, smallint);
DROP FUNCTION IF EXISTS public.record_support(uuid, uuid);
DROP FUNCTION IF EXISTS public.purge_event(uuid);
DROP FUNCTION IF EXISTS public.purge_due_events();
DROP FUNCTION IF EXISTS public.create_organizer(text, text, text);
DROP FUNCTION IF EXISTS public.create_admin(text, text, text);
DROP TYPE IF EXISTS public.event_status;
DROP TYPE IF EXISTS public.event_cause;
SQL
} > "$out/reset.sql"

echo "→ $out/setup.sql ($(wc -l < "$out/setup.sql") lignes)"
echo "→ $out/reset.sql (efface tout, avant de rejouer setup.sql)"
echo "→ $out/reseed.sql"
