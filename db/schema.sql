-- =====================================================================
--  Foulala : comptage anonyme de manifestations
--  Schéma PostgreSQL 14+ / PostGIS 3+
--
--  Côté participant, la base ne contient AUCUNE donnée personnelle :
--  pas de compte, pas de coordonnées GPS, pas d'adresse IP,
--  pas d'heure exacte : juste un jeton aléatoire par manif.
--  Les jetons sont supprimés 24 h après la fin ; seuls les totaux restent.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS postgis;


-- ---------------------------------------------------------------------
--  Organisateurs : les seuls utilisateurs avec un compte
-- ---------------------------------------------------------------------
CREATE TABLE organizer (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text NOT NULL,              -- collectif, syndicat, association…
    email         text NOT NULL UNIQUE,
    password_hash text NOT NULL,              -- argon2id ; à retirer si l'auth est déléguée (ex. Supabase Auth)
    created_at    timestamptz NOT NULL DEFAULT now()
);


-- ---------------------------------------------------------------------
--  Manifestations
-- ---------------------------------------------------------------------
CREATE TYPE event_status AS ENUM ('draft', 'published', 'cancelled');

CREATE TABLE event (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_id  uuid NOT NULL REFERENCES organizer(id) ON DELETE CASCADE,
    title         text NOT NULL,
    description   text,
    demands       text[] NOT NULL DEFAULT '{}',        -- revendications, dans l'ordre
    city          text NOT NULL,                        -- pour lister les manifs sans demander la position de l'utilisateur
    route         geometry(LineString, 4326) NOT NULL,  -- parcours, en longitude/latitude
    buffer_m      integer NOT NULL DEFAULT 100
                  CHECK (buffer_m BETWEEN 20 AND 500),  -- largeur de la zone de part et d'autre du parcours
    zone          geometry(Polygon, 4326),              -- calculée par trigger, envoyée au téléphone
    segment_count smallint,                             -- nb de tronçons d'environ 200 m, calculé par trigger
    starts_at     timestamptz NOT NULL,
    ends_at       timestamptz NOT NULL,
    declared      boolean NOT NULL DEFAULT false,       -- déclarée en préfecture/mairie (déclaratif, non vérifié)
    status        event_status NOT NULL DEFAULT 'draft',
    purged_at     timestamptz,                          -- jetons supprimés : seuls les totaux restent
    created_at    timestamptz NOT NULL DEFAULT now(),
    CHECK (ends_at > starts_at)
);

CREATE INDEX event_listing_idx   ON event (city, starts_at) WHERE status = 'published';
CREATE INDEX event_organizer_idx ON event (organizer_id);

-- Zone = parcours élargi de buffer_m mètres.
-- Tronçons de longueur égale (~200 m, 100 max) : le téléphone calcule sa position
-- relative le long du parcours (0 → 1) et en déduit le numéro de tronçon.
CREATE FUNCTION event_compute_geometry() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.zone := ST_Buffer(NEW.route::geography, NEW.buffer_m::float8)::geometry;
    NEW.segment_count := GREATEST(1, LEAST(100,
                            ceil(ST_Length(NEW.route::geography) / 200)))::smallint;
    RETURN NEW;
END $$;

CREATE TRIGGER event_geometry
BEFORE INSERT OR UPDATE OF route, buffer_m ON event
FOR EACH ROW EXECUTE FUNCTION event_compute_geometry();


-- ---------------------------------------------------------------------
--  « Je suis là » : un jeton par téléphone et par manif
-- ---------------------------------------------------------------------
CREATE TABLE presence (
    event_id  uuid NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    token     uuid NOT NULL,         -- tiré au hasard par le téléphone, différent pour chaque manif
    time_slot timestamptz NOT NULL   -- heure du « Je suis là », arrondie au quart d'heure
              CHECK (extract(epoch FROM time_slot)::bigint % 900 = 0),
    segment   smallint CHECK (segment >= 0),   -- tronçon le plus proche, calculé sur le téléphone (optionnel)
    PRIMARY KEY (event_id, token)    -- un jeton renvoyé n'est compté qu'une fois
    -- volontairement : pas de created_at, pas d'IP, pas d'identifiant d'appareil
);


-- ---------------------------------------------------------------------
--  « Je soutiens » : sans GPS, sans heure
-- ---------------------------------------------------------------------
CREATE TABLE support (
    event_id uuid NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    token    uuid NOT NULL,
    PRIMARY KEY (event_id, token)
);


-- ---------------------------------------------------------------------
--  Totaux conservés après la purge des jetons
-- ---------------------------------------------------------------------
CREATE TABLE event_tally (
    event_id  uuid NOT NULL REFERENCES event(id) ON DELETE CASCADE,
    kind      text NOT NULL CHECK (kind IN ('presence', 'support')),
    time_slot timestamptz,           -- NULL pour les soutiens
    segment   smallint,              -- NULL si non renseigné
    n         integer NOT NULL CHECK (n > 0)
);

CREATE INDEX event_tally_event_idx ON event_tally (event_id);


-- ---------------------------------------------------------------------
--  Enregistrement (appelé par l'API, ou en RPC avec Supabase)
--  Renvoie true si le jeton est nouveau, false si déjà compté.
-- ---------------------------------------------------------------------
CREATE FUNCTION record_presence(p_event uuid, p_token uuid,
                                p_slot timestamptz, p_segment smallint DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql AS $$
DECLARE
    e event%ROWTYPE;
    n integer;
BEGIN
    -- FOR SHARE : empêche une purge de passer entre la vérification et l'insertion
    SELECT * INTO e FROM event WHERE id = p_event FOR SHARE;
    IF NOT FOUND OR e.status <> 'published' OR e.purged_at IS NOT NULL THEN
        RAISE EXCEPTION 'manifestation indisponible';
    END IF;
    IF p_slot < e.starts_at - interval '30 minutes' OR p_slot > e.ends_at OR p_slot > now() THEN
        RAISE EXCEPTION 'créneau hors de la manifestation';
    END IF;
    IF p_segment IS NOT NULL AND p_segment >= e.segment_count THEN
        RAISE EXCEPTION 'tronçon inconnu';
    END IF;

    INSERT INTO presence (event_id, token, time_slot, segment)
    VALUES (p_event, p_token, p_slot, p_segment)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n = 1;
END $$;

CREATE FUNCTION record_support(p_event uuid, p_token uuid)
RETURNS boolean
LANGUAGE plpgsql AS $$
DECLARE
    e event%ROWTYPE;
    n integer;
BEGIN
    SELECT * INTO e FROM event WHERE id = p_event FOR SHARE;
    IF NOT FOUND OR e.status <> 'published' OR e.purged_at IS NOT NULL THEN
        RAISE EXCEPTION 'manifestation indisponible';
    END IF;

    INSERT INTO support (event_id, token)
    VALUES (p_event, p_token)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n = 1;
END $$;


-- ---------------------------------------------------------------------
--  Purge : remplace les jetons par des totaux
-- ---------------------------------------------------------------------
CREATE FUNCTION purge_event(p_event uuid) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM 1 FROM event WHERE id = p_event AND purged_at IS NULL FOR UPDATE;
    IF NOT FOUND THEN
        RETURN;                      -- déjà purgée ou inexistante
    END IF;

    INSERT INTO event_tally (event_id, kind, time_slot, segment, n)
    SELECT event_id, 'presence', time_slot, segment, count(*)
    FROM presence
    WHERE event_id = p_event
    GROUP BY event_id, time_slot, segment;

    INSERT INTO event_tally (event_id, kind, n)
    SELECT p_event, 'support', count(*)
    FROM support
    WHERE event_id = p_event
    HAVING count(*) > 0;

    DELETE FROM presence WHERE event_id = p_event;
    DELETE FROM support  WHERE event_id = p_event;
    UPDATE event SET purged_at = now() WHERE id = p_event;
END $$;

-- Purge toutes les manifs terminées depuis plus de 24 h
-- (le délai laisse le temps aux téléphones hors-ligne d'envoyer leur jeton).
CREATE FUNCTION purge_due_events() RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    e_id uuid;
    k    integer := 0;
BEGIN
    FOR e_id IN
        SELECT id FROM event
        WHERE purged_at IS NULL AND ends_at < now() - interval '24 hours'
    LOOP
        PERFORM purge_event(e_id);
        k := k + 1;
    END LOOP;
    RETURN k;
END $$;

-- À lancer toutes les heures, par exemple avec pg_cron :
-- SELECT cron.schedule('purge-manifs', '0 * * * *', 'SELECT purge_due_events()');


-- ---------------------------------------------------------------------
--  Vues publiques (jetons en cours + totaux déjà purgés)
-- ---------------------------------------------------------------------

-- Compteurs : présents et soutiens
CREATE VIEW event_count AS
SELECT e.id AS event_id,
       (SELECT count(*) FROM presence p WHERE p.event_id = e.id)
     + (SELECT COALESCE(sum(t.n), 0) FROM event_tally t
        WHERE t.event_id = e.id AND t.kind = 'presence')   AS present,
       (SELECT count(*) FROM support s WHERE s.event_id = e.id)
     + (SELECT COALESCE(sum(t.n), 0) FROM event_tally t
        WHERE t.event_id = e.id AND t.kind = 'support')    AS supporters
FROM event e
WHERE e.status <> 'draft';

-- Arrivées par quart d'heure (le cumul donne la montée en puissance)
CREATE VIEW event_timeline AS
SELECT event_id, time_slot, sum(n) AS arrivals
FROM (
    SELECT event_id, time_slot, 1::bigint AS n FROM presence
    UNION ALL
    SELECT event_id, time_slot, n FROM event_tally WHERE kind = 'presence'
) x
GROUP BY event_id, time_slot;

-- Densité par tronçon et par quart d'heure.
-- Seuil : on n'affiche jamais un groupe de moins de 20 personnes.
CREATE VIEW event_density AS
SELECT event_id, time_slot, segment, sum(n) AS n
FROM (
    SELECT event_id, time_slot, segment, 1::bigint AS n
    FROM presence WHERE segment IS NOT NULL
    UNION ALL
    SELECT event_id, time_slot, segment, n
    FROM event_tally WHERE kind = 'presence' AND segment IS NOT NULL
) x
GROUP BY event_id, time_slot, segment
HAVING sum(n) >= 20;


-- ---------------------------------------------------------------------
--  Exemple
-- ---------------------------------------------------------------------
-- INSERT INTO event (organizer_id, title, city, demands, route, starts_at, ends_at)
-- VALUES ('<id organisateur>', 'Marche pour le climat', 'Lyon',
--         ARRAY['Plan vélo', 'Zéro artificialisation'],
--         ST_SetSRID(ST_GeomFromGeoJSON(
--           '{"type":"LineString","coordinates":[[4.8357,45.7640],[4.8320,45.7578],[4.8270,45.7500]]}'), 4326),
--         '2026-10-17 14:00+02', '2026-10-17 17:00+02');
-- UPDATE event SET status = 'published' WHERE id = '<id manif>';
--
-- SELECT record_presence('<id manif>', gen_random_uuid(), '2026-10-17 14:15+02', 3::smallint);
-- SELECT * FROM event_count WHERE event_id = '<id manif>';
--
-- Zone à envoyer au téléphone :
-- SELECT ST_AsGeoJSON(zone), segment_count FROM event WHERE id = '<id manif>';
