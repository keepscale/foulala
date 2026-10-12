-- =====================================================================
--  Foulala : API publique exposée par PostgREST (schéma `api`)
--
--  PostgREST n'expose QUE ce schéma. Les tables de `public` ne sont
--  jamais accessibles directement : le rôle anonyme ne voit que des
--  vues en lecture et deux fonctions d'écriture.
--  À charger après schema.sql.
-- =====================================================================

-- Rôles PostgREST ------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN
        CREATE ROLE web_anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN;   -- mot de passe posé au déploiement
    END IF;
END $$;

GRANT web_anon TO authenticator;

-- Les fonctions sont exécutables par PUBLIC par défaut : on ferme tout.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS api;
GRANT USAGE ON SCHEMA api TO web_anon;


-- Lecture --------------------------------------------------------------

-- Manifs visibles du public (jamais l'e-mail de l'organisateur)
CREATE VIEW api.events AS
SELECT e.id,
       e.title,
       e.description,
       e.demands,
       e.city,
       e.starts_at,
       e.ends_at,
       e.declared,
       e.status,
       e.buffer_m,
       e.segment_count,
       ST_AsGeoJSON(e.route)::json AS route,
       ST_AsGeoJSON(e.zone)::json  AS zone,
       o.name                      AS organizer
FROM public.event e
JOIN public.organizer o ON o.id = e.organizer_id
WHERE e.status IN ('published', 'cancelled');

CREATE VIEW api.event_count    AS SELECT * FROM public.event_count;
CREATE VIEW api.event_timeline AS SELECT * FROM public.event_timeline;
CREATE VIEW api.event_density  AS SELECT * FROM public.event_density;   -- seuil de 20 déjà appliqué

GRANT SELECT ON api.events, api.event_count, api.event_timeline, api.event_density TO web_anon;


-- Écriture -------------------------------------------------------------
-- POST /rpc/presence {"event_id", "token", "time_slot", "segment"}
CREATE FUNCTION api.presence(event_id uuid, token uuid, time_slot timestamptz,
                             segment smallint DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.record_presence(event_id, token, time_slot, segment);
$$;

-- POST /rpc/support {"event_id", "token"}
CREATE FUNCTION api.support(event_id uuid, token uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.record_support(event_id, token);
$$;

REVOKE EXECUTE ON FUNCTION api.presence(uuid, uuid, timestamptz, smallint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION api.support(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.presence(uuid, uuid, timestamptz, smallint) TO web_anon;
GRANT  EXECUTE ON FUNCTION api.support(uuid, uuid) TO web_anon;

-- TODO : rôle `organizer` authentifié par JWT pour créer / publier des manifs.
