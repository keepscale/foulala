-- Tests des données de dev (db/seed.sql) : chargement, rechargement, ce que voit l'API.
-- Chemin relatif à la racine du dépôt (scripts/db-test.sh s'y place).
\set ON_ERROR_STOP on
BEGIN;

\i db/seed.sql
\i db/seed.sql

DO $$
DECLARE
    e1 constant uuid := '5eed0000-0000-0000-0000-0000000000e1';
    e5 constant uuid := '5eed0000-0000-0000-0000-0000000000e5';
BEGIN
    -- Rechargé deux fois : pas de doublons
    ASSERT (SELECT count(*) FROM event WHERE id::text LIKE '5eed0000-%') = 9, '9 manifs attendues';
    ASSERT (SELECT count(*) FROM presence WHERE event_id = e1) = 2500, '2500 présences attendues sur e1';

    -- Manif terminée : purgée, il ne reste que les totaux
    ASSERT (SELECT purged_at IS NOT NULL FROM event WHERE id = e5), 'e5 doit être purgée';
    ASSERT NOT EXISTS (SELECT 1 FROM presence WHERE event_id = e5), 'e5 ne doit plus avoir de jetons';

    -- Manif en cours : on peut encore dire « J'y suis ! » maintenant
    ASSERT record_presence(e1, gen_random_uuid(), date_bin('15 minutes', now(), 'epoch'), 0::smallint),
           'e1 doit accepter une présence maintenant';
END $$;

SET LOCAL ROLE web_anon;

DO $$
BEGIN
    -- Brouillon caché, annulée visible
    ASSERT (SELECT count(*) FROM api.events WHERE city = 'Lyon' AND id::text LIKE '5eed0000-%') = 5,
           '5 manifs visibles à Lyon';
    ASSERT (SELECT count(*) FROM api.events WHERE city = 'Paris' AND id::text LIKE '5eed0000-%') = 2,
           '2 manifs visibles à Paris';
    ASSERT (SELECT count(*) FROM api.events WHERE city = 'Nancy' AND id::text LIKE '5eed0000-%') = 1,
           '1 manif visible à Nancy';
    ASSERT (SELECT count(DISTINCT cause) FROM api.events WHERE id::text LIKE '5eed0000-%') = 7,
           'toutes les causes doivent être représentées';

    ASSERT (SELECT present FROM api.event_count WHERE event_id = '5eed0000-0000-0000-0000-0000000000e5') = 900,
           'e5 : 900 présents conservés après purge';

    -- La densité sert des cases, toutes au-dessus du seuil
    ASSERT EXISTS (SELECT 1 FROM api.event_density WHERE event_id = '5eed0000-0000-0000-0000-0000000000e1'),
           'e1 doit avoir des cases de densité affichables';
    ASSERT NOT EXISTS (SELECT 1 FROM api.event_density WHERE n < 20), 'seuil de 20 non respecté';

    RAISE NOTICE '04_seed : OK';
END $$;

ROLLBACK;
