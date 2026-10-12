-- Tests de la cause d'une manif : valeur par défaut, valeurs refusées, exposition dans l'API.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO organizer (id, name, email, password_hash)
VALUES ('00000000-0000-0000-0000-000000000003', 'Collectif cause', 'cause@example.org', 'x');

INSERT INTO event (id, organizer_id, title, city, route, starts_at, ends_at, status)
VALUES ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-000000000003',
        'Marche sans cause', 'Lyon',
        ST_SetSRID(ST_MakeLine(ST_MakePoint(4.835, 45.764), ST_MakePoint(4.827, 45.750)), 4326),
        now() + interval '1 day', now() + interval '1 day 3 hours', 'published');

DO $$
DECLARE
    e      constant uuid := '00000000-0000-0000-0000-0000000000e3';
    failed boolean;
BEGIN
    ASSERT (SELECT cause FROM event WHERE id = e) = 'autre', 'cause par défaut attendue : autre';

    -- Doit rester aligné sur les clés `causes` de design/tokens.json
    ASSERT enum_range(NULL::event_cause)::text[]
           = ARRAY['climat', 'fiertes', 'paix', 'social', 'sante', 'education', 'autre'],
           'les causes ne correspondent plus à design/tokens.json';

    BEGIN
        UPDATE event SET cause = 'inconnue' WHERE id = e;
        failed := false;
    EXCEPTION WHEN invalid_text_representation THEN failed := true;
    END;
    ASSERT failed, 'une cause inconnue doit être refusée';

    UPDATE event SET cause = 'climat' WHERE id = e;
END $$;

SET LOCAL ROLE web_anon;

DO $$
BEGIN
    ASSERT (SELECT cause FROM api.events WHERE id = '00000000-0000-0000-0000-0000000000e3') = 'climat',
           'api.events doit exposer la cause';
    RAISE NOTICE '03_cause : OK';
END $$;

ROLLBACK;
