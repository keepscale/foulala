-- Tests du comptage : enregistrement, validations, seuil de densité, purge.
-- Lancés dans une transaction annulée à la fin : la base reste propre.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO organizer (id, name, email, password_hash)
VALUES ('00000000-0000-0000-0000-000000000001', 'Collectif test', 'test@example.org', 'x');

INSERT INTO event (id, organizer_id, title, city, route, starts_at, ends_at)
VALUES ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000001',
        'Marche test', 'Lyon',
        ST_SetSRID(ST_GeomFromGeoJSON(
          '{"type":"LineString","coordinates":[[4.8357,45.7640],[4.8320,45.7578],[4.8270,45.7500]]}'), 4326),
        now() - interval '1 hour', now() + interval '2 hours');

DO $$
DECLARE
    e      constant uuid := '00000000-0000-0000-0000-0000000000e1';
    t      constant uuid := '11111111-1111-1111-1111-111111111111';
    slot   constant timestamptz := date_bin('15 minutes', now(), 'epoch');
    failed boolean;
    i      integer;
BEGIN
    -- Géométrie calculée par trigger
    ASSERT (SELECT segment_count FROM event WHERE id = e) = 9, 'segment_count attendu : 9';
    ASSERT (SELECT GeometryType(zone) FROM event WHERE id = e) = 'POLYGON', 'zone attendue : POLYGON';

    -- Brouillon : refusé
    BEGIN
        PERFORM record_presence(e, gen_random_uuid(), slot);
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'une manif en brouillon ne doit pas accepter de présence';

    UPDATE event SET status = 'published' WHERE id = e;

    -- Un jeton n'est compté qu'une fois
    ASSERT record_presence(e, t, slot, 2::smallint), 'premier envoi accepté';
    ASSERT NOT record_presence(e, t, slot, 2::smallint), 'doublon ignoré';

    -- Créneau non arrondi au quart d'heure : refusé
    BEGIN
        PERFORM record_presence(e, gen_random_uuid(), slot + interval '7 minutes');
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'créneau non arrondi accepté';

    -- Créneau hors de la manif : refusé
    BEGIN
        PERFORM record_presence(e, gen_random_uuid(), slot - interval '5 hours');
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'créneau hors manif accepté';

    -- Tronçon inexistant : refusé
    BEGIN
        PERFORM record_presence(e, gen_random_uuid(), slot, 99::smallint);
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'tronçon inconnu accepté';

    -- Seuil de densité : 24 jetons sur le tronçon 2, 5 sur le tronçon 3
    FOR i IN 1..23 LOOP PERFORM record_presence(e, gen_random_uuid(), slot, 2::smallint); END LOOP;
    FOR i IN 1..5  LOOP PERFORM record_presence(e, gen_random_uuid(), slot, 3::smallint); END LOOP;
    ASSERT (SELECT n FROM event_density WHERE event_id = e AND segment = 2) = 24, 'tronçon 2 visible';
    ASSERT NOT EXISTS (SELECT 1 FROM event_density WHERE event_id = e AND segment = 3),
           'un tronçon de moins de 20 personnes ne doit jamais apparaître';

    -- Soutiens
    FOR i IN 1..40 LOOP PERFORM record_support(e, gen_random_uuid()); END LOOP;
    ASSERT (SELECT present FROM event_count WHERE event_id = e) = 29, 'présents avant purge';
    ASSERT (SELECT supporters FROM event_count WHERE event_id = e) = 40, 'soutiens avant purge';

    -- Purge : plus aucun jeton, totaux identiques, nouvelle présence refusée
    PERFORM purge_event(e);
    PERFORM purge_event(e);   -- idempotente
    ASSERT NOT EXISTS (SELECT 1 FROM presence WHERE event_id = e), 'jetons de présence supprimés';
    ASSERT NOT EXISTS (SELECT 1 FROM support  WHERE event_id = e), 'jetons de soutien supprimés';
    ASSERT (SELECT present FROM event_count WHERE event_id = e) = 29, 'présents conservés après purge';
    ASSERT (SELECT supporters FROM event_count WHERE event_id = e) = 40, 'soutiens conservés après purge';
    ASSERT (SELECT n FROM event_density WHERE event_id = e AND segment = 2) = 24, 'densité conservée';

    BEGIN
        PERFORM record_presence(e, gen_random_uuid(), slot);
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'présence acceptée après purge';

    RAISE NOTICE '01_comptage : OK';
END $$;

ROLLBACK;
