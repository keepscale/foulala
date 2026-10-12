-- Tests des droits de l'API : le rôle anonyme passe par `api`, jamais par les tables.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO organizer (id, name, email, password_hash)
VALUES ('00000000-0000-0000-0000-000000000002', 'Collectif API', 'secret@example.org', 'x');

INSERT INTO event (id, organizer_id, title, city, route, starts_at, ends_at, status)
VALUES ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-000000000002',
        'Marche API', 'Lyon',
        ST_SetSRID(ST_MakeLine(ST_MakePoint(4.835, 45.764), ST_MakePoint(4.827, 45.750)), 4326),
        now() - interval '1 hour', now() + interval '2 hours', 'published');

SET LOCAL ROLE web_anon;

DO $$
DECLARE
    e      constant uuid := '00000000-0000-0000-0000-0000000000e2';
    failed boolean;
BEGIN
    ASSERT api.presence(e, gen_random_uuid(), date_bin('15 minutes', now(), 'epoch')), 'api.presence';
    ASSERT api.support(e, gen_random_uuid()), 'api.support';
    ASSERT (SELECT present FROM api.event_count WHERE event_id = e) = 1, 'api.event_count';
    ASSERT (SELECT organizer FROM api.events WHERE id = e) = 'Collectif API', 'api.events';

    -- Parcours et zone en GeoJSON : le téléphone en a besoin pour vérifier la présence localement
    ASSERT (SELECT route->>'type' FROM api.events WHERE id = e) = 'LineString', 'api.events.route';
    ASSERT (SELECT zone->>'type' FROM api.events WHERE id = e) = 'Polygon', 'api.events.zone';

    -- Aucune colonne e-mail exposée
    ASSERT NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema = 'api' AND column_name ILIKE '%mail%'),
           'une vue api expose un e-mail';

    -- Accès direct aux tables : refusé
    BEGIN
        PERFORM 1 FROM public.presence;
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas lire public.presence';

    BEGIN
        PERFORM public.purge_event(e);
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas pouvoir purger';

    RAISE NOTICE '02_api : OK';
END $$;

ROLLBACK;
