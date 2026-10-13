-- =====================================================================
--  Foulala : données de test pour le développement (JAMAIS en production)
--
--  Collectifs fictifs, manifs à Lyon et Paris, dates calculées depuis
--  now() : rejouer le fichier remet des manifs « en cours ».
--  Rejouable : supprime d'abord ses propres données (identifiants 5eed…).
--
--  Rechargement sur le serveur de dev :
--    docker compose -f docker-compose.yml -f docker-compose.dev.yml \
--      exec -T db psql -U foulala -d foulala -1 -f /seed.sql
--
--  Pas de BEGIN/COMMIT ici : le fichier est aussi chargé dans un test
--  (db/tests/04_seed.sql) à l'intérieur d'une transaction annulée.
-- =====================================================================
\set ON_ERROR_STOP on

DELETE FROM organizer WHERE id::text LIKE '5eed0000-%';   -- cascade sur event, presence, support, event_tally

INSERT INTO organizer (id, name, email, password_hash) VALUES
    -- Compte de dev pour la page organisateur : lyon@example.org / foulala-dev-2026 (hash bcrypt figé)
    ('5eed0000-0000-0000-0000-000000000001', 'Collectif test Lyon',  'lyon@example.org',
     '$2a$12$mxR9wJhkmqQqAPP4xupOMOKWfx4EMigSXI4GfN0wteMJ6hBjgqFZu'),
    ('5eed0000-0000-0000-0000-000000000002', 'Collectif test Paris', 'paris@example.org', 'seed'),
    ('5eed0000-0000-0000-0000-000000000003', 'Collectif test Nancy', 'nancy@example.org', 'seed');

-- Jour J à 14 h, heure de Paris
CREATE FUNCTION pg_temp.seed_day(days integer, at time DEFAULT '14:00')
RETURNS timestamptz LANGUAGE sql AS $$
    SELECT (((now() AT TIME ZONE 'Europe/Paris')::date + days) + at) AT TIME ZONE 'Europe/Paris';
$$;

-- Manif en cours : commencée il y a 45 min, calée sur le quart d'heure
CREATE FUNCTION pg_temp.seed_now() RETURNS timestamptz LANGUAGE sql AS $$
    SELECT date_bin('15 minutes', now(), 'epoch') - interval '45 minutes';
$$;

INSERT INTO event (id, organizer_id, title, cause, description, demands, city, route, buffer_m,
                   starts_at, ends_at, declared, status) VALUES
-- Lyon, en cours : Terreaux → Bellecour → Perrache
(   '5eed0000-0000-0000-0000-0000000000e1', '5eed0000-0000-0000-0000-000000000001',
    'Marche pour le climat', 'climat',
    'Départ place des Terreaux, arrivée place Carnot. Venez avec vos vélos !',
    ARRAY['Un plan vélo dans toute la métropole', 'Zéro artificialisation nette dès 2030', 'Des transports en commun gratuits pour les moins de 26 ans'],
    'Lyon',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8357,45.7676],[4.8357,45.7640],[4.8350,45.7605],[4.8320,45.7578],[4.8295,45.7545],[4.8270,45.7500]]}'), 4326),
    100, pg_temp.seed_now(), pg_temp.seed_now() + interval '3 hours', true, 'published'),

-- Lyon, après-demain : Jean Macé → Guillotière → Bellecour
(   '5eed0000-0000-0000-0000-0000000000e2', '5eed0000-0000-0000-0000-000000000001',
    'Pour les salaires et les services publics', 'social',
    'Rassemblement à 13 h 30 place Jean Macé.',
    ARRAY['Augmentation du SMIC', 'Embauches dans les hôpitaux et les écoles', 'Retrait de la réforme'],
    'Lyon',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8424,45.7456],[4.8420,45.7500],[4.8410,45.7545],[4.8370,45.7560],[4.8320,45.7578]]}'), 4326),
    150, pg_temp.seed_day(2), pg_temp.seed_day(2, '17:30'), true, 'published'),

-- Lyon, dans 9 jours : Bellecour → quais du Rhône
(   '5eed0000-0000-0000-0000-0000000000e3', '5eed0000-0000-0000-0000-000000000001',
    'Marche des fiertés', 'fiertes',
    NULL,
    ARRAY['Égalité des droits', 'Lutte contre les violences LGBTphobes'],
    'Lyon',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8320,45.7578],[4.8365,45.7585],[4.8400,45.7620],[4.8430,45.7660],[4.8480,45.7700]]}'), 4326),
    200, pg_temp.seed_day(9), pg_temp.seed_day(9, '19:00'), false, 'published'),

-- Lyon, annulée
(   '5eed0000-0000-0000-0000-0000000000e4', '5eed0000-0000-0000-0000-000000000001',
    'Rassemblement pour la paix', 'paix',
    'Annulé faute d''autorisation.',
    ARRAY['Cessez-le-feu immédiat'],
    'Lyon',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8357,45.7640],[4.8320,45.7578]]}'), 4326),
    100, pg_temp.seed_day(4, '18:00'), pg_temp.seed_day(4, '20:00'), false, 'cancelled'),

-- Lyon, terminée il y a 3 jours (purgée plus bas : il ne reste que les totaux)
(   '5eed0000-0000-0000-0000-0000000000e5', '5eed0000-0000-0000-0000-000000000001',
    'Marche des voisins', 'autre',
    NULL,
    ARRAY['Un parc à la place du parking'],
    'Lyon',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8357,45.7676],[4.8357,45.7640],[4.8350,45.7605]]}'), 4326),
    80, pg_temp.seed_day(-3), pg_temp.seed_day(-3, '16:00'), true, 'published'),

-- Paris, en cours : République → Bastille
(   '5eed0000-0000-0000-0000-0000000000e6', '5eed0000-0000-0000-0000-000000000002',
    'Pour l''hôpital public', 'sante',
    'Cortège soignant en tête.',
    ARRAY['Des lits rouverts', 'Des ratios soignants par patient'],
    'Paris',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[2.3631,48.8674],[2.3660,48.8630],[2.3670,48.8590],[2.3685,48.8555],[2.3692,48.8532]]}'), 4326),
    120, pg_temp.seed_now(), pg_temp.seed_now() + interval '3 hours', true, 'published'),

-- Paris, dans 5 jours : Port-Royal → Sorbonne
(   '5eed0000-0000-0000-0000-0000000000e7', '5eed0000-0000-0000-0000-000000000002',
    'L''école a besoin de moyens', 'education',
    NULL,
    ARRAY['Pas plus de 24 élèves par classe', 'Remplacement de tous les profs absents'],
    'Paris',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[2.3372,48.8399],[2.3404,48.8432],[2.3430,48.8462],[2.3440,48.8487]]}'), 4326),
    100, pg_temp.seed_day(5), pg_temp.seed_day(5, '17:00'), true, 'published'),

-- Nancy, en cours pendant 24 h (pour tester « J'y suis ! » sur un vrai téléphone) :
-- rue Sainte-Catherine → place Stanislas → rue Stanislas → boulevard Albert-Ier.
-- Tracé des rues d'après OpenStreetMap ; entre la gare et le boulevard Albert-Ier,
-- le passage au-dessus des voies est approximé par une ligne droite.
(   '5eed0000-0000-0000-0000-0000000000e9', '5eed0000-0000-0000-0000-000000000003',
    'Marche de test à Nancy', 'social',
    'Manif fictive pour tester l''app sur le terrain.',
    ARRAY['Tester le « J''y suis ! » en conditions réelles'],
    'Nancy',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[
        [6.18987,48.69546],[6.18929,48.69538],[6.18791,48.69495],[6.18752,48.69483],[6.18564,48.69426],
        [6.18495,48.69405],[6.18401,48.69376],
        [6.18255,48.69331],[6.18124,48.69291],[6.18095,48.69282],[6.17983,48.69249],[6.17906,48.69225],
        [6.17781,48.69187],[6.17621,48.69139],[6.17572,48.69124],[6.17530,48.69110],
        [6.16781,48.69289],
        [6.16795,48.69319],[6.16774,48.69416],[6.16754,48.69507],[6.16734,48.69599],[6.16715,48.69694],
        [6.16691,48.69803],[6.16680,48.69848],[6.16627,48.69911]]}'), 4326),
    100, pg_temp.seed_now(), pg_temp.seed_now() + interval '24 hours', true, 'published'),

-- Lyon, brouillon : ne doit jamais apparaître dans l'API
(   '5eed0000-0000-0000-0000-0000000000e8', '5eed0000-0000-0000-0000-000000000001',
    'Brouillon pas encore publié', 'autre',
    NULL, '{}', 'Lyon',
    ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8357,45.7640],[4.8320,45.7578]]}'), 4326),
    100, pg_temp.seed_day(20), pg_temp.seed_day(20, '16:00'), false, 'draft');

-- Présences fictives : plus d'arrivées au début, tronçons au hasard.
-- Assez de monde pour que certaines cases (tronçon × quart d'heure)
-- dépassent le seuil de 20 et que d'autres restent masquées.
INSERT INTO presence (event_id, token, time_slot, segment)
SELECT e.id,
       gen_random_uuid(),
       e.starts_at - interval '30 minutes'
           + interval '15 minutes' * floor(power(random(), 1.5) * s.slots),
       floor(random() * e.segment_count)::smallint
FROM event e
JOIN (VALUES ('5eed0000-0000-0000-0000-0000000000e1'::uuid, 2500),
             ('5eed0000-0000-0000-0000-0000000000e5'::uuid,  900),
             ('5eed0000-0000-0000-0000-0000000000e6'::uuid, 1200),
             ('5eed0000-0000-0000-0000-0000000000e9'::uuid,  300)) AS v(id, n) ON v.id = e.id
CROSS JOIN LATERAL (
    SELECT floor(extract(epoch FROM least(date_bin('15 minutes', now(), 'epoch'), e.ends_at)
                                    - (e.starts_at - interval '30 minutes')) / 900)::int + 1 AS slots
) s
CROSS JOIN LATERAL generate_series(1, v.n);

INSERT INTO support (event_id, token)
SELECT v.id, gen_random_uuid()
FROM (VALUES ('5eed0000-0000-0000-0000-0000000000e1'::uuid, 800),
             ('5eed0000-0000-0000-0000-0000000000e2'::uuid, 350),
             ('5eed0000-0000-0000-0000-0000000000e3'::uuid, 1200),
             ('5eed0000-0000-0000-0000-0000000000e5'::uuid, 150),
             ('5eed0000-0000-0000-0000-0000000000e6'::uuid, 600),
             ('5eed0000-0000-0000-0000-0000000000e7'::uuid, 90),
             ('5eed0000-0000-0000-0000-0000000000e9'::uuid, 120)) AS v(id, n)
CROSS JOIN LATERAL generate_series(1, v.n);

DO $$ BEGIN PERFORM purge_event('5eed0000-0000-0000-0000-0000000000e5'); END $$;

DROP FUNCTION pg_temp.seed_day(integer, time);
DROP FUNCTION pg_temp.seed_now();
