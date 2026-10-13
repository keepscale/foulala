#!/usr/bin/env bash
# Donne son mot de passe au rôle de connexion de PostgREST (créé par api.sql),
# et range le secret qui signe les jetons des organisateurs (même valeur que PGRST_JWT_SECRET).
set -euo pipefail
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v pwd="$AUTHENTICATOR_PASSWORD" -v jwt="$JWT_SECRET" <<'SQL'
ALTER ROLE authenticator PASSWORD :'pwd';
INSERT INTO private.jwt_secret (secret) VALUES (:'jwt')
ON CONFLICT (id) DO UPDATE SET secret = EXCLUDED.secret;
SQL
