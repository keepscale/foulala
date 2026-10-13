-- =====================================================================
--  Foulala : adaptation à Supabase (TESTS UNIQUEMENT)
--
--  À exécuter après db/schema.sql, db/api.sql, db/organizer.sql et db/admin.sql
--  (scripts/supabase-bundle.sh assemble le tout). Supabase diffère de server/
--  sur quatre points :
--
--  1. PostgREST s'y connecte avec le rôle `anon`, pas `web_anon`.
--  2. Supabase donne par défaut à `anon` et `authenticated` TOUS les droits
--     sur les tables et fonctions du schéma `public` : sans ce fichier,
--     n'importe qui lirait `organizer` (e-mails) et `presence`, ou appellerait
--     `purge_event` par l'API. On révoque tout et on active RLS.
--  3. Le schéma `api` doit être exposé dans les réglages (voir supabase/README.md).
--  4. Les jetons des organisateurs et de l'administration doivent être signés
--     avec le secret JWT du projet Supabase (« Legacy JWT secret ») : il se range
--     dans private.jwt_secret, à la main (voir supabase/README.md).
--
--  Rappel : la passerelle de Supabase journalise les adresses IP.
--  Jamais de vraie manif sur Supabase (CLAUDE.md, « Hébergement prévu »).
-- =====================================================================

-- 1. Rien de `public` pour les rôles de l'API -----------------------------
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

-- Et pas davantage pour ce qui y sera créé plus tard par postgres.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon, authenticated;

-- Double sécurité : RLS sans aucune politique = aucune ligne pour anon/authenticated,
-- même si un droit revenait par erreur. Les vues et fonctions de `api` appartiennent
-- à postgres, propriétaire des tables : elles ne sont pas concernées.
ALTER TABLE public.organizer   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presence    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_tally ENABLE ROW LEVEL SECURITY;

-- Schéma privé (secret de signature, comptes admin, journal) : jamais pour l'API
REVOKE ALL ON SCHEMA private FROM anon, authenticated;
REVOKE ALL ON ALL TABLES    IN SCHEMA private FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA private FROM anon, authenticated;
ALTER TABLE private.jwt_secret    ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.admin_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.admin_log     ENABLE ROW LEVEL SECURITY;


-- 2. `anon` reçoit exactement les droits de `web_anon` --------------------
-- (rôles NOINHERIT chez Supabase : appartenir à web_anon ne suffirait pas)
REVOKE ALL ON ALL TABLES    IN SCHEMA api FROM anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA api FROM anon, authenticated;

GRANT USAGE  ON SCHEMA api TO anon;
GRANT SELECT ON api.events, api.event_count, api.event_timeline, api.event_density TO anon;
GRANT EXECUTE ON FUNCTION api.presence(uuid, uuid, timestamptz, smallint) TO anon;
GRANT EXECUTE ON FUNCTION api.support(uuid, uuid) TO anon;
-- Connexions (organisateurs, administration) : le reste passe par leurs propres rôles
GRANT EXECUTE ON FUNCTION api.login(text, text) TO anon;
GRANT EXECUTE ON FUNCTION api.admin_login(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.st_asgeojson(geometry, integer, integer) TO anon;


-- 3. Vérification : le script s'arrête si quelque chose reste exposé ------
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['organizer', 'event', 'presence', 'support', 'event_tally',
                             'event_count', 'event_timeline', 'event_density'] LOOP
        IF has_table_privilege('anon', 'public.' || t, 'SELECT')
           OR has_table_privilege('authenticated', 'public.' || t, 'SELECT') THEN
            RAISE EXCEPTION 'public.% est encore lisible par l''API', t;
        END IF;
    END LOOP;

    FOREACH t IN ARRAY ARRAY['jwt_secret', 'admin_account', 'admin_log'] LOOP
        IF has_table_privilege('anon', 'private.' || t, 'SELECT')
           OR has_table_privilege('authenticated', 'private.' || t, 'SELECT') THEN
            RAISE EXCEPTION 'private.% est lisible par l''API', t;
        END IF;
    END LOOP;

    IF has_function_privilege('anon', 'api.create_event(text, event_cause, text, timestamptz, timestamptz, json, integer, text, text[], boolean)', 'EXECUTE')
       OR has_function_privilege('anon', 'api.admin_overview()', 'EXECUTE')
       OR has_function_privilege('anon', 'public.create_admin(text, text, text)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.create_organizer(text, text, text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'une fonction réservée aux organisateurs ou à l''administration est appelable sans connexion';
    END IF;

    IF has_function_privilege('anon', 'public.purge_event(uuid)', 'EXECUTE')
       OR has_function_privilege('anon', 'public.record_presence(uuid, uuid, timestamptz, smallint)', 'EXECUTE') THEN
        RAISE EXCEPTION 'une fonction interne de public est encore appelable par l''API';
    END IF;

    IF NOT has_table_privilege('anon', 'api.events', 'SELECT')
       OR NOT has_function_privilege('anon', 'api.presence(uuid, uuid, timestamptz, smallint)', 'EXECUTE')
       OR NOT has_function_privilege('anon', 'api.login(text, text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'anon n''a pas accès à l''API';
    END IF;

    RAISE NOTICE 'Supabase : droits vérifiés, seul le schéma api est accessible.';
END $$;
