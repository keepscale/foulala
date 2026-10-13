-- Tests de l'espace organisateur : comptes, connexion (JWT), droits, cycle de vie d'une manif.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO private.jwt_secret (secret) VALUES ('secret-de-test-assez-long-pour-hs256-0123456789');

-- Deux collectifs ; leurs identifiants passent d'un bloc à l'autre par des paramètres de session
SELECT set_config('test.org1', public.create_organizer('Collectif A', 'A@Example.org ', 'mot-de-passe-solide')::text, true) \g /dev/null
SELECT set_config('test.org2', public.create_organizer('Collectif B', 'b@example.org', 'autre-mot-de-passe-solide')::text, true) \g /dev/null

DO $$
DECLARE
    failed boolean;
BEGIN
    -- Mot de passe stocké en bcrypt, jamais en clair ; e-mail normalisé
    ASSERT (SELECT password_hash LIKE '$2a$12$%' FROM organizer WHERE email = 'a@example.org'),
           'hash bcrypt attendu';

    BEGIN
        PERFORM public.create_organizer('Collectif C', 'c@example.org', 'court');
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'un mot de passe de moins de 12 caractères ne doit pas être accepté';

    INSERT INTO organizer (name, email, password_hash) VALUES ('Sans hash', 'seed@example.org', 'seed');
END $$;


-- Connexion, avec le rôle anonyme de l'API ----------------------------
SET LOCAL ROLE web_anon;

DO $$
DECLARE
    r      json;
    failed boolean;
BEGIN
    r := api.login('a@example.org', 'mot-de-passe-solide');
    ASSERT r->>'name' = 'Collectif A', 'login : nom du collectif';
    ASSERT (r->>'expires_at')::timestamptz > now() + interval '7 hours', 'login : expiration';
    PERFORM set_config('test.token', r->>'token', true);

    -- Majuscules et espaces dans l'e-mail : même compte
    ASSERT api.login(' A@EXAMPLE.ORG', 'mot-de-passe-solide') IS NOT NULL, 'login insensible à la casse';

    BEGIN
        PERFORM api.login('a@example.org', 'mauvais-mot-de-passe');
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'mauvais mot de passe accepté';

    BEGIN
        PERFORM api.login('inconnu@example.org', 'mot-de-passe-solide');
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'e-mail inconnu accepté';

    -- Compte sans vrai hash (données de test) : connexion impossible
    BEGIN
        PERFORM api.login('seed@example.org', 'seed');
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'compte sans hash bcrypt accepté';
END $$;

DO $$
DECLARE
    failed boolean;
BEGIN
    BEGIN
        PERFORM 1 FROM api.my_events;
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas lire api.my_events';

    BEGIN
        PERFORM api.create_event('Test', 'climat', 'Lyon', now(), now() + interval '1 hour',
                                 '{"type":"LineString","coordinates":[[4.83,45.76],[4.83,45.75]]}');
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas créer de manif';

    BEGIN
        PERFORM 1 FROM private.jwt_secret;
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'le secret de signature ne doit pas être lisible';

    BEGIN
        PERFORM public.create_organizer('Pirate', 'pirate@example.org', 'mot-de-passe-solide');
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas créer de compte';
END $$;

RESET ROLE;

-- Le jeton est un JWT HS256 valide, que PostgREST acceptera -------------
DO $$
DECLARE
    t      text := current_setting('test.token');
    h      text := split_part(t, '.', 1);
    p      text := split_part(t, '.', 2);
    s      text := split_part(t, '.', 3);
    claims json;
BEGIN
    claims := convert_from(decode(translate(p, '-_', '+/') || repeat('=', (4 - length(p) % 4) % 4), 'base64'), 'utf8')::json;
    ASSERT claims->>'role' = 'organizer', 'claim role';
    ASSERT claims->>'sub' = current_setting('test.org1'), 'claim sub';
    ASSERT (claims->>'exp')::bigint > extract(epoch FROM now()), 'claim exp';
    ASSERT s = private.base64url(hmac(h || '.' || p, (SELECT secret FROM private.jwt_secret), 'sha256')),
           'signature HS256';
    ASSERT position('=' IN t) = 0 AND position('+' IN t) = 0 AND position('/' IN t) = 0, 'encodage base64url';
END $$;


-- Cycle de vie, en organisateur A --------------------------------------
SET LOCAL ROLE organizer;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.org1'))::text, true) \g /dev/null

DO $$
DECLARE
    route  constant json := '{"type":"LineString","coordinates":[[4.8357,45.7676],[4.8320,45.7578],[4.8270,45.7500]]}';
    e      uuid;
    d      uuid;
    failed boolean;
BEGIN
    e := api.create_event('Marche de test', 'climat', 'Lyon', now() + interval '1 day',
                          now() + interval '1 day 3 hours', route, 100, '  Une description  ',
                          ARRAY['Première revendication', 'Deuxième'], true);
    PERFORM set_config('test.e1', e::text, true);

    ASSERT (SELECT status FROM api.my_events WHERE id = e) = 'draft', 'créée en brouillon';
    ASSERT (SELECT description FROM api.my_events WHERE id = e) = 'Une description', 'description nettoyée';
    ASSERT (SELECT segment_count FROM api.my_events WHERE id = e) > 0, 'tronçons calculés';
    ASSERT NOT EXISTS (SELECT 1 FROM api.events WHERE id = e), 'un brouillon n''est pas public';

    -- Modification d'un brouillon
    PERFORM api.update_event(e, 'Marche pour le climat', 'climat', 'Lyon', now() + interval '1 day',
                             now() + interval '1 day 4 hours', route, 150, NULL, ARRAY['Une seule'], true);
    ASSERT (SELECT title FROM api.my_events WHERE id = e) = 'Marche pour le climat', 'titre modifié';
    ASSERT (SELECT buffer_m FROM api.my_events WHERE id = e) = 150, 'zone modifiée';

    -- Saisies refusées
    BEGIN
        PERFORM api.create_event('Point', 'climat', 'Lyon', now(), now() + interval '1 hour',
                                 '{"type":"Point","coordinates":[4.83,45.76]}');
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'un point n''est pas un parcours';

    BEGIN
        PERFORM api.create_event('À l''envers', 'climat', 'Lyon', now() + interval '2 hours', now(), route);
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'fin avant début acceptée';

    BEGIN
        PERFORM api.create_event('Trop large', 'climat', 'Lyon', now(), now() + interval '1 hour', route, 600);
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'zone de 600 m acceptée';

    BEGIN
        PERFORM api.create_event('Trop longue', 'climat', 'Lyon', now(), now() + interval '30 hours', route);
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'manif de 30 h acceptée';

    -- Publication : visible du public, puis plus modifiable ni supprimable
    PERFORM api.publish_event(e);
    ASSERT (SELECT status FROM api.events WHERE id = e) = 'published', 'publiée et visible';

    BEGIN
        PERFORM api.update_event(e, 'Autre titre', 'climat', 'Lyon', now() + interval '1 day',
                                 now() + interval '1 day 4 hours', route);
        failed := false;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN failed := true;
    END;
    ASSERT failed, 'une manif publiée ne doit plus être modifiable';

    BEGIN
        PERFORM api.delete_draft(e);
        failed := false;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN failed := true;
    END;
    ASSERT failed, 'une manif publiée ne doit pas être supprimée';

    -- Annulation
    PERFORM api.cancel_event(e);
    ASSERT (SELECT status FROM api.events WHERE id = e) = 'cancelled', 'annulée, toujours visible';

    BEGIN
        PERFORM api.cancel_event(e);
        failed := false;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN failed := true;
    END;
    ASSERT failed, 'double annulation acceptée';

    -- Un brouillon se supprime
    d := api.create_event('Brouillon jetable', 'autre', 'Lyon', now() + interval '2 days',
                          now() + interval '2 days 1 hour', route);
    PERFORM api.delete_draft(d);
    ASSERT NOT EXISTS (SELECT 1 FROM api.my_events WHERE id = d), 'brouillon supprimé';

    -- Une manif terminée ne se publie pas
    d := api.create_event('Déjà passée', 'autre', 'Lyon', now() - interval '3 hours',
                          now() - interval '1 hour', route);
    BEGIN
        PERFORM api.publish_event(d);
        failed := false;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN failed := true;
    END;
    ASSERT failed, 'manif terminée publiée';
    PERFORM set_config('test.e2', d::text, true);
END $$;


-- Un autre collectif ne voit ni ne touche les manifs de A ---------------
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.org2'))::text, true) \g /dev/null

DO $$
DECLARE
    d      constant uuid := current_setting('test.e2')::uuid;
    failed boolean;
BEGIN
    ASSERT NOT EXISTS (SELECT 1 FROM api.my_events), 'B ne voit pas les manifs de A';

    BEGIN
        PERFORM api.delete_draft(d);
        failed := false;
    EXCEPTION WHEN no_data_found THEN failed := true;
    END;
    ASSERT failed, 'B a supprimé un brouillon de A';

    BEGIN
        PERFORM api.update_event(d, 'Piraté', 'autre', 'Lyon', now(), now() + interval '1 hour',
                                 '{"type":"LineString","coordinates":[[4.83,45.76],[4.83,45.75]]}');
        failed := false;
    EXCEPTION WHEN no_data_found THEN failed := true;
    END;
    ASSERT failed, 'B a modifié un brouillon de A';
END $$;


-- Sans identité dans le jeton : rien ----------------------------------
SELECT set_config('request.jwt.claims', '{"role":"organizer"}', true) \g /dev/null

DO $$
DECLARE
    failed boolean;
BEGIN
    ASSERT NOT EXISTS (SELECT 1 FROM api.my_events), 'sans sub, aucune manif';
    BEGIN
        PERFORM api.create_event('Anonyme', 'autre', 'Lyon', now() + interval '1 day',
                                 now() + interval '1 day 1 hour',
                                 '{"type":"LineString","coordinates":[[4.83,45.76],[4.83,45.75]]}');
        failed := false;
    EXCEPTION WHEN invalid_authorization_specification THEN failed := true;
    END;
    ASSERT failed, 'création sans organisateur acceptée';

    RAISE NOTICE '05_organizer : OK';
END $$;

ROLLBACK;
