-- =====================================================================
--  Foulala : espace organisateur (connexion par JWT, gestion des manifs)
--
--  À charger après api.sql. Sans code serveur : PostgREST vérifie la
--  signature du jeton (PGRST_JWT_SECRET) et bascule sur le rôle
--  `organizer` ; chaque fonction vérifie ensuite que la manif appartient
--  bien à l'organisateur du jeton.
--
--  Comptes : sur invitation uniquement, créés par un administrateur avec
--  public.create_organizer(). Pas d'inscription libre : elle ouvrirait la
--  porte aux fausses manifs.
--
--  Rien ici ne touche aux données des participants.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Secret de signature des jetons --------------------------------------
-- Dans une table plutôt qu'un paramètre de base : un paramètre est lisible
-- par toute session, cette table ne l'est que par son propriétaire.
-- Rempli au déploiement (server/initdb/30-authenticator.sh), même valeur
-- que PGRST_JWT_SECRET.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC;

CREATE TABLE private.jwt_secret (
    id     boolean PRIMARY KEY DEFAULT true CHECK (id),   -- une seule ligne
    secret text NOT NULL CHECK (length(secret) >= 32)
);


-- Rôle ----------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'organizer') THEN
        CREATE ROLE organizer NOLOGIN;
    END IF;
END $$;

GRANT organizer TO authenticator;
GRANT web_anon TO organizer;          -- lit aussi tout ce qui est public
GRANT USAGE ON SCHEMA api TO organizer;


-- Outils internes -----------------------------------------------------
CREATE FUNCTION private.base64url(data bytea) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
    SELECT translate(rtrim(replace(encode(data, 'base64'), E'\n', ''), '='), '+/', '-_');
$$;

-- JWT HS256, le format attendu par PostgREST
CREATE FUNCTION private.sign_jwt(claims json) RETURNS text
LANGUAGE sql STABLE
SET search_path = public, pg_temp
AS $$
    WITH parts AS (
        SELECT private.base64url(convert_to('{"alg":"HS256","typ":"JWT"}', 'utf8')) AS header,
               private.base64url(convert_to(claims::text, 'utf8'))                 AS payload
    )
    SELECT header || '.' || payload || '.' ||
           private.base64url(hmac(header || '.' || payload,
                                  (SELECT secret FROM private.jwt_secret), 'sha256'))
    FROM parts;
$$;

-- Organisateur du jeton en cours (jamais NULL : erreur sinon).
-- Un compte suspendu par l'administration perd aussitôt ses droits, même avec un jeton encore valide.
CREATE FUNCTION private.current_organizer() RETURNS uuid
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    sub text := current_setting('request.jwt.claims', true)::json ->> 'sub';
BEGIN
    IF sub IS NULL THEN
        RAISE EXCEPTION 'connexion requise' USING ERRCODE = '28000';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM organizer WHERE id = sub::uuid AND suspended_at IS NULL) THEN
        RAISE EXCEPTION 'compte suspendu ou supprimé' USING ERRCODE = '28000';
    END IF;
    RETURN sub::uuid;
END $$;

-- Manif de l'organisateur courant, verrouillée ; même message qu'elle
-- n'existe pas ou appartienne à un autre : on ne révèle rien.
CREATE FUNCTION private.own_event(p_id uuid) RETURNS event
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    e event%ROWTYPE;
BEGIN
    SELECT * INTO e FROM event
    WHERE id = p_id AND organizer_id = private.current_organizer()
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'manifestation introuvable' USING ERRCODE = 'P0002';
    END IF;
    RETURN e;
END $$;

-- Validation commune à la création et à la modification
CREATE FUNCTION private.check_event_input(
    p_title text, p_city text, p_starts_at timestamptz, p_ends_at timestamptz,
    p_route json, p_buffer_m integer, p_description text, p_demands text[]
) RETURNS geometry
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    g      geometry;
    len_m  float8;
    d      text;
BEGIN
    IF length(btrim(coalesce(p_title, ''))) NOT BETWEEN 3 AND 120 THEN
        RAISE EXCEPTION 'le titre doit faire entre 3 et 120 caractères' USING ERRCODE = '22023';
    END IF;
    IF length(btrim(coalesce(p_city, ''))) NOT BETWEEN 1 AND 80 THEN
        RAISE EXCEPTION 'la ville est obligatoire (80 caractères au plus)' USING ERRCODE = '22023';
    END IF;
    IF p_starts_at IS NULL OR p_ends_at IS NULL OR p_ends_at <= p_starts_at THEN
        RAISE EXCEPTION 'la fin doit être après le début' USING ERRCODE = '22023';
    END IF;
    IF p_ends_at - p_starts_at > interval '24 hours' THEN
        RAISE EXCEPTION 'une manifestation dure 24 h au plus' USING ERRCODE = '22023';
    END IF;
    IF p_buffer_m IS NULL OR p_buffer_m NOT BETWEEN 20 AND 500 THEN
        RAISE EXCEPTION 'la largeur de zone doit être entre 20 et 500 m' USING ERRCODE = '22023';
    END IF;
    IF length(coalesce(p_description, '')) > 2000 THEN
        RAISE EXCEPTION 'la description fait 2000 caractères au plus' USING ERRCODE = '22023';
    END IF;
    IF coalesce(array_length(p_demands, 1), 0) > 10 THEN
        RAISE EXCEPTION '10 revendications au plus' USING ERRCODE = '22023';
    END IF;
    FOREACH d IN ARRAY coalesce(p_demands, '{}') LOOP
        IF length(btrim(d)) NOT BETWEEN 1 AND 200 THEN
            RAISE EXCEPTION 'chaque revendication fait entre 1 et 200 caractères' USING ERRCODE = '22023';
        END IF;
    END LOOP;

    BEGIN
        g := ST_SetSRID(ST_GeomFromGeoJSON(p_route::text), 4326);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'parcours illisible (GeoJSON LineString attendu)' USING ERRCODE = '22023';
    END;
    IF GeometryType(g) <> 'LINESTRING' OR ST_NPoints(g) < 2 OR NOT ST_IsValid(g) THEN
        RAISE EXCEPTION 'le parcours doit être une ligne d''au moins deux points' USING ERRCODE = '22023';
    END IF;
    IF ST_XMin(g) < -180 OR ST_XMax(g) > 180 OR ST_YMin(g) < -90 OR ST_YMax(g) > 90 THEN
        RAISE EXCEPTION 'coordonnées hors limites (longitude, latitude attendues)' USING ERRCODE = '22023';
    END IF;
    len_m := ST_Length(g::geography);
    IF len_m < 50 OR len_m > 50000 THEN
        RAISE EXCEPTION 'le parcours doit mesurer entre 50 m et 50 km' USING ERRCODE = '22023';
    END IF;

    RETURN g;
END $$;


-- Comptes (administration, jamais exposé) -----------------------------
CREATE FUNCTION public.create_organizer(p_name text, p_email text, p_password text)
RETURNS uuid
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    new_id uuid;
BEGIN
    IF length(coalesce(p_password, '')) < 12 THEN
        RAISE EXCEPTION 'mot de passe trop court (12 caractères au moins)';
    END IF;
    INSERT INTO organizer (name, email, password_hash)
    VALUES (btrim(p_name), lower(btrim(p_email)), crypt(p_password, gen_salt('bf', 12)))
    RETURNING id INTO new_id;
    RETURN new_id;
END $$;


-- Connexion -----------------------------------------------------------
-- POST /rpc/login {"email", "password"} → {"token", "expires_at", "name"}
CREATE FUNCTION api.login(email text, password text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    o       organizer%ROWTYPE;
    expires timestamptz := now() + interval '8 hours';
    -- Hash factice : on calcule bcrypt même si l'e-mail est inconnu,
    -- pour ne pas révéler par le temps de réponse quels e-mails existent.
    dummy   constant text := '$2a$12$TlZw0LbeS5pIN/cqnZTv3.wa.nB7zdDylE1umWNzUSSMwNm9tCxsG';
    ok      boolean;
BEGIN
    SELECT * INTO o FROM organizer WHERE organizer.email = lower(btrim(login.email));

    ok := o.id IS NOT NULL
          AND o.password_hash LIKE '$2%'
          AND crypt(login.password, o.password_hash) = o.password_hash;
    IF o.id IS NULL OR o.password_hash NOT LIKE '$2%' THEN
        PERFORM crypt(coalesce(login.password, ''), dummy);
    END IF;

    IF NOT ok THEN
        RAISE EXCEPTION 'e-mail ou mot de passe incorrect' USING ERRCODE = '28P01';
    END IF;
    -- Seulement après le bon mot de passe : on ne révèle rien aux autres
    IF o.suspended_at IS NOT NULL THEN
        RAISE EXCEPTION 'compte suspendu par l''administration de Foulala : écrivez-nous pour en savoir plus'
            USING ERRCODE = '28000';
    END IF;

    RETURN json_build_object(
        'token', private.sign_jwt(json_build_object(
                     'role', 'organizer',
                     'sub',  o.id,
                     'exp',  extract(epoch FROM expires)::bigint)),
        'expires_at', expires,
        'name', o.name);
END $$;


-- Lecture : mes manifs (tous statuts) ---------------------------------
CREATE VIEW api.my_events AS
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
       e.purged_at,
       e.created_at,
       e.hidden_at,                -- masquée par la modération, avec le motif : le collectif sait pourquoi
       e.hidden_reason,
       ST_AsGeoJSON(e.route)::json AS route,
       ST_AsGeoJSON(e.zone)::json  AS zone,
       c.present,
       c.supporters
FROM public.event e
JOIN public.organizer o ON o.id = e.organizer_id AND o.suspended_at IS NULL
LEFT JOIN public.event_count c ON c.event_id = e.id
WHERE e.organizer_id = (current_setting('request.jwt.claims', true)::json ->> 'sub')::uuid;


-- Écriture ------------------------------------------------------------
-- POST /rpc/change_password {"current_password", "new_password"}
-- Un compte invité reçoit un mot de passe provisoire : le collectif le remplace ici.
CREATE FUNCTION api.change_password(current_password text, new_password text) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    me   uuid := private.current_organizer();
    hash text;
BEGIN
    SELECT password_hash INTO hash FROM organizer WHERE id = me FOR UPDATE;
    IF hash NOT LIKE '$2%' OR crypt(coalesce(current_password, ''), hash) <> hash THEN
        -- 22023 plutôt que 28P01 : PostgREST répondrait 403, et la page déconnecterait le collectif
        RAISE EXCEPTION 'mot de passe actuel incorrect' USING ERRCODE = '22023';
    END IF;
    IF length(coalesce(new_password, '')) < 12 THEN
        RAISE EXCEPTION 'le nouveau mot de passe doit faire 12 caractères au moins' USING ERRCODE = '22023';
    END IF;
    UPDATE organizer SET password_hash = crypt(new_password, gen_salt('bf', 12)) WHERE id = me;
END $$;

-- POST /rpc/create_event → id de la manif, en brouillon
CREATE FUNCTION api.create_event(
    title text, cause event_cause, city text, starts_at timestamptz, ends_at timestamptz,
    route json, buffer_m integer DEFAULT 100, description text DEFAULT NULL,
    demands text[] DEFAULT '{}', declared boolean DEFAULT false
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    g      geometry;
    new_id uuid;
BEGIN
    g := private.check_event_input(title, city, starts_at, ends_at, route, buffer_m, description, demands);
    INSERT INTO event (organizer_id, title, cause, city, starts_at, ends_at, route, buffer_m,
                       description, demands, declared, status)
    VALUES (private.current_organizer(), btrim(title), cause, btrim(city),
            create_event.starts_at, create_event.ends_at, g, create_event.buffer_m,
            nullif(btrim(description), ''), coalesce(demands, '{}'), coalesce(declared, false), 'draft')
    RETURNING id INTO new_id;
    RETURN new_id;
END $$;

-- POST /rpc/update_event : brouillons seulement. Une fois publiée, le
-- parcours et les horaires ne bougent plus : ils fondent le comptage.
CREATE FUNCTION api.update_event(
    id uuid, title text, cause event_cause, city text, starts_at timestamptz, ends_at timestamptz,
    route json, buffer_m integer DEFAULT 100, description text DEFAULT NULL,
    demands text[] DEFAULT '{}', declared boolean DEFAULT false
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    e event%ROWTYPE := private.own_event(update_event.id);
    g geometry;
BEGIN
    IF e.status <> 'draft' THEN
        RAISE EXCEPTION 'seul un brouillon peut être modifié' USING ERRCODE = '55000';
    END IF;
    g := private.check_event_input(title, city, starts_at, ends_at, route, buffer_m, description, demands);
    UPDATE event SET
        title       = btrim(update_event.title),
        cause       = update_event.cause,
        city        = btrim(update_event.city),
        starts_at   = update_event.starts_at,
        ends_at     = update_event.ends_at,
        route       = g,
        buffer_m    = update_event.buffer_m,
        description = nullif(btrim(update_event.description), ''),
        demands     = coalesce(update_event.demands, '{}'),
        declared    = coalesce(update_event.declared, false)
    WHERE event.id = e.id;
END $$;

-- POST /rpc/delete_draft : un brouillon n'a jamais été public, on peut l'effacer
CREATE FUNCTION api.delete_draft(id uuid) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    e event%ROWTYPE := private.own_event(delete_draft.id);
BEGIN
    IF e.status <> 'draft' THEN
        RAISE EXCEPTION 'seul un brouillon peut être supprimé ; une manif publiée s''annule'
            USING ERRCODE = '55000';
    END IF;
    DELETE FROM event WHERE event.id = e.id;
END $$;

-- POST /rpc/publish_event
CREATE FUNCTION api.publish_event(id uuid) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    e event%ROWTYPE := private.own_event(publish_event.id);
BEGIN
    IF e.status <> 'draft' THEN
        RAISE EXCEPTION 'seul un brouillon peut être publié' USING ERRCODE = '55000';
    END IF;
    IF e.ends_at <= now() THEN
        RAISE EXCEPTION 'cette manifestation est déjà terminée' USING ERRCODE = '55000';
    END IF;
    UPDATE event SET status = 'published' WHERE event.id = e.id;
END $$;

-- POST /rpc/cancel_event : reste visible, marquée annulée ; les comptes déjà faits sont gardés
CREATE FUNCTION api.cancel_event(id uuid) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    e event%ROWTYPE := private.own_event(cancel_event.id);
BEGIN
    IF e.status <> 'published' THEN
        RAISE EXCEPTION 'seule une manifestation publiée peut être annulée' USING ERRCODE = '55000';
    END IF;
    UPDATE event SET status = 'cancelled' WHERE event.id = e.id;
END $$;


-- Droits --------------------------------------------------------------
-- Tout ce qui vient d'être créé dans `public` et `private` est fermé.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public  FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC;
REVOKE ALL     ON ALL TABLES    IN SCHEMA private FROM PUBLIC;
-- api.events a besoin de ST_AsGeoJSON (rouverte dans api.sql, refermée par la ligne ci-dessus)
GRANT EXECUTE ON FUNCTION public.st_asgeojson(geometry, integer, integer) TO web_anon;

REVOKE EXECUTE ON FUNCTION api.login(text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.login(text, text) TO web_anon;

GRANT SELECT ON api.my_events TO organizer;

DO $$
DECLARE
    f text;
BEGIN
    FOREACH f IN ARRAY ARRAY[
        'api.change_password(text, text)',
        'api.create_event(text, event_cause, text, timestamptz, timestamptz, json, integer, text, text[], boolean)',
        'api.update_event(uuid, text, event_cause, text, timestamptz, timestamptz, json, integer, text, text[], boolean)',
        'api.delete_draft(uuid)',
        'api.publish_event(uuid)',
        'api.cancel_event(uuid)'
    ] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO organizer', f);
    END LOOP;
END $$;
