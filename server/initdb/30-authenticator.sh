#!/usr/bin/env bash
# Donne son mot de passe au rôle de connexion de PostgREST (créé par api.sql).
set -euo pipefail
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v pwd="$AUTHENTICATOR_PASSWORD" <<'SQL'
ALTER ROLE authenticator PASSWORD :'pwd';
SQL
