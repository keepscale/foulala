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
       e.cause,
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
WHERE e.status IN ('published', 'cancelled')
  AND e.hidden_at IS NULL;                     -- masquée par la modération : retirée de l'app

-- Les fonctions appelées dans une vue sont vérifiées avec les droits de l'APPELANT.
-- Le REVOKE plus haut a aussi fermé les fonctions PostGIS (installées dans `public`) :
-- on rouvre la seule dont api.events a besoin. Elle ne fait que mettre une géométrie en GeoJSON.
GRANT EXECUTE ON FUNCTION public.st_asgeojson(geometry, integer, integer) TO web_anon;

-- Chiffres des manifs visibles seulement (une manif masquée disparaît aussi des compteurs)
CREATE VIEW api.event_count AS
SELECT c.* FROM public.event_count c
WHERE c.event_id IN (SELECT id FROM public.event WHERE hidden_at IS NULL);
CREATE VIEW api.event_timeline AS                  -- seuil de 20 déjà appliqué
SELECT t.* FROM public.event_timeline t
WHERE t.event_id IN (SELECT id FROM public.event WHERE hidden_at IS NULL);
CREATE VIEW api.event_density AS                   -- seuil de 20 déjà appliqué
SELECT d.* FROM public.event_density d
WHERE d.event_id IN (SELECT id FROM public.event WHERE hidden_at IS NULL);

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
