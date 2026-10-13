-- =====================================================================
--  Foulala : administration globale (pilotage, modération, comptes)
--
--  À charger après organizer.sql (il en reprend le schéma `private`
--  et la signature des jetons).
--
--  Rôle `foulala_admin`, distinct des organisateurs :
--  - connexion par mot de passe ET code à usage unique (TOTP, RFC 6238),
--    calculé en SQL ; jeton d'une heure ;
--  - comptes créés en ligne de commande seulement (public.create_admin),
--    jamais depuis l'API ;
--  - chaque action (suspension, masquage, mot de passe) est inscrite au
--    journal private.admin_log, avec son motif.
--
--  Vie privée : l'administration ne voit JAMAIS un jeton, une présence ou un
--  soutien un par un. Elle ne manipule que des comptes organisateurs, des
--  manifs et des totaux déjà publics.
-- =====================================================================

-- Rôle ----------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'foulala_admin') THEN
        CREATE ROLE foulala_admin NOLOGIN;
    END IF;
END $$;

GRANT foulala_admin TO authenticator;
GRANT USAGE ON SCHEMA api TO foulala_admin;


-- Comptes et journal (schéma privé, jamais exposé) ---------------------
CREATE TABLE private.admin_account (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name           text NOT NULL,
    email          text NOT NULL UNIQUE,
    password_hash  text NOT NULL,                                   -- bcrypt
    totp_secret    bytea NOT NULL CHECK (length(totp_secret) = 20), -- 160 bits, RFC 4226
    totp_last_step bigint NOT NULL DEFAULT 0,                       -- un code ne sert qu'une fois
    created_at     timestamptz NOT NULL DEFAULT now(),
    disabled_at    timestamptz
);

-- Ce que l'administration a fait, et pourquoi. Aucune donnée de participant.
CREATE TABLE private.admin_log (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    at          timestamptz NOT NULL DEFAULT now(),
    admin_id    uuid NOT NULL REFERENCES private.admin_account(id),
    action      text NOT NULL,
    target_kind text NOT NULL CHECK (target_kind IN ('organizer', 'event')),
    target_id   uuid NOT NULL,
    reason      text
);

CREATE INDEX admin_log_at_idx ON private.admin_log (at DESC);


-- TOTP (RFC 6238 : HMAC-SHA1, 6 chiffres, pas de 30 s) -----------------
CREATE FUNCTION private.totp(secret bytea, step bigint) RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    mac bytea := hmac(int8send(step), secret, 'sha1');
    o   integer := get_byte(mac, 19) & 15;
    bin bigint;
BEGIN
    bin := ((get_byte(mac, o) & 127)::bigint << 24)
         | (get_byte(mac, o + 1)::bigint << 16)
         | (get_byte(mac, o + 2)::bigint << 8)
         |  get_byte(mac, o + 3)::bigint;
    RETURN lpad((bin % 1000000)::text, 6, '0');
END $$;

-- Base32 (RFC 4648, sans « = ») : le format des applis d'authentification
CREATE FUNCTION private.base32(data bytea) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    alphabet constant text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    bits text := '';
    res  text := '';
    i    integer;
BEGIN
    FOR i IN 0 .. length(data) - 1 LOOP
        bits := bits || get_byte(data, i)::bit(8)::text;
    END LOOP;
    bits := rpad(bits, ((length(bits) + 4) / 5) * 5, '0');
    FOR i IN 0 .. length(bits) / 5 - 1 LOOP
        res := res || substr(alphabet, substring(bits FROM i * 5 + 1 FOR 5)::bit(5)::integer + 1, 1);
    END LOOP;
    RETURN res;
END $$;

-- Mot de passe provisoire lisible : 16 caractères sans 0/O ni 1/l/I
CREATE FUNCTION private.temporary_password() RETURNS text
LANGUAGE plpgsql VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE
    alphabet constant text := 'abcdefghjkmnpqrstuvwxyzACDEFGHJKLMNPQRSTUVWXYZ23456789';
    b   bytea := gen_random_bytes(16);
    res text := '';
    i   integer;
BEGIN
    FOR i IN 0 .. 15 LOOP
        res := res || substr(alphabet, get_byte(b, i) % length(alphabet) + 1, 1);
    END LOOP;
    RETURN res;
END $$;


-- Création d'un compte (ligne de commande seulement) --------------------
-- psql : SELECT public.create_admin('Prénom', 'moi@example.org', 'phrase de passe longue');
-- Renvoie l'adresse otpauth:// à saisir (ou à transformer en QR code) dans
-- une appli d'authentification. Elle n'est affichée qu'une fois.
CREATE FUNCTION public.create_admin(p_name text, p_email text, p_password text)
RETURNS text
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    secret bytea := gen_random_bytes(20);
    email  text := lower(btrim(p_email));
BEGIN
    IF length(coalesce(p_password, '')) < 16 THEN
        RAISE EXCEPTION 'mot de passe administrateur trop court (16 caractères au moins)';
    END IF;
    INSERT INTO private.admin_account (name, email, password_hash, totp_secret)
    VALUES (btrim(p_name), email, crypt(p_password, gen_salt('bf', 12)), secret);
    RETURN format('otpauth://totp/Foulala:%s?secret=%s&issuer=Foulala&algorithm=SHA1&digits=6&period=30',
                  replace(email, '@', '%40'), private.base32(secret));
END $$;


-- Connexion -----------------------------------------------------------
-- POST /rpc/admin_login {"email", "password", "code"} → {"token", "expires_at", "name"}
CREATE FUNCTION api.admin_login(email text, password text, code text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    a       private.admin_account%ROWTYPE;
    expires timestamptz := now() + interval '1 hour';
    step    constant bigint := floor(extract(epoch FROM now()) / 30)::bigint;
    dummy   constant text := '$2a$12$TlZw0LbeS5pIN/cqnZTv3.wa.nB7zdDylE1umWNzUSSMwNm9tCxsG';
    ok      boolean := false;
    matched bigint;
    s       bigint;
BEGIN
    SELECT * INTO a FROM private.admin_account
    WHERE admin_account.email = lower(btrim(admin_login.email)) AND disabled_at IS NULL
    FOR UPDATE;

    IF a.id IS NULL THEN
        PERFORM crypt(coalesce(admin_login.password, ''), dummy);   -- même durée qu'un vrai essai
    ELSE
        ok := crypt(coalesce(admin_login.password, ''), a.password_hash) = a.password_hash;
    END IF;

    -- Code du pas courant, ou d'un pas avant/après (décalage d'horloge) ; jamais un code déjà servi
    IF ok THEN
        FOR s IN step - 1 .. step + 1 LOOP
            IF s > a.totp_last_step AND private.totp(a.totp_secret, s) = btrim(coalesce(admin_login.code, '')) THEN
                matched := s;
                EXIT;
            END IF;
        END LOOP;
    END IF;

    IF matched IS NULL THEN
        RAISE EXCEPTION 'e-mail, mot de passe ou code incorrect' USING ERRCODE = '28P01';
    END IF;

    UPDATE private.admin_account SET totp_last_step = matched WHERE id = a.id;

    RETURN json_build_object(
        'token', private.sign_jwt(json_build_object(
                     'role', 'foulala_admin',
                     'sub',  a.id,
                     'exp',  extract(epoch FROM expires)::bigint)),
        'expires_at', expires,
        'name', a.name);
END $$;

-- Administrateur du jeton en cours. Un compte désactivé perd aussitôt ses droits.
CREATE FUNCTION private.current_admin() RETURNS uuid
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
    claims json := current_setting('request.jwt.claims', true)::json;
    id     uuid;
BEGIN
    IF claims ->> 'role' IS DISTINCT FROM 'foulala_admin' OR claims ->> 'sub' IS NULL THEN
        RAISE EXCEPTION 'connexion administrateur requise' USING ERRCODE = '28000';
    END IF;
    SELECT a.id INTO id FROM private.admin_account a
    WHERE a.id = (claims ->> 'sub')::uuid AND a.disabled_at IS NULL;
    IF id IS NULL THEN
        RAISE EXCEPTION 'compte administrateur désactivé' USING ERRCODE = '28000';
    END IF;
    RETURN id;
END $$;

CREATE FUNCTION private.log_admin(p_action text, p_kind text, p_target uuid, p_reason text)
RETURNS void
LANGUAGE sql
SET search_path = public, pg_temp
AS $$
    INSERT INTO private.admin_log (admin_id, action, target_kind, target_id, reason)
    VALUES (private.current_admin(), p_action, p_kind, p_target, nullif(btrim(p_reason), ''));
$$;

-- Motif obligatoire pour une sanction : le collectif le lira
CREATE FUNCTION private.require_reason(p_reason text) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF length(btrim(coalesce(p_reason, ''))) NOT BETWEEN 5 AND 500 THEN
        RAISE EXCEPTION 'indiquez un motif (5 à 500 caractères)' USING ERRCODE = '22023';
    END IF;
    RETURN btrim(p_reason);
END $$;


-- Lecture : pilotage ----------------------------------------------------
-- Fonctions plutôt que vues : chacune vérifie d'abord que le compte est actif.

-- GET /rpc/admin_overview : chiffres globaux et santé du système
CREATE FUNCTION api.admin_overview() RETURNS json
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    result json;
    cron   json;
BEGIN
    PERFORM private.current_admin();

    -- Dernière purge automatique (pg_cron absent des bases de test)
    IF to_regclass('cron.job_run_details') IS NOT NULL THEN
        EXECUTE $q$
            SELECT json_build_object('status', d.status, 'at', d.end_time, 'message', d.return_message)
            FROM cron.job_run_details d JOIN cron.job j ON j.jobid = d.jobid
            WHERE j.jobname = 'purge-manifs'
            ORDER BY d.start_time DESC LIMIT 1
        $q$ INTO cron;
    END IF;

    SELECT json_build_object(
        'organizers', (SELECT json_build_object(
                           'active',    count(*) FILTER (WHERE suspended_at IS NULL),
                           'suspended', count(*) FILTER (WHERE suspended_at IS NOT NULL))
                       FROM organizer),
        'events', (SELECT json_build_object(
                       'draft',     count(*) FILTER (WHERE status = 'draft'),
                       'upcoming',  count(*) FILTER (WHERE status = 'published' AND hidden_at IS NULL AND starts_at > now()),
                       'live',      count(*) FILTER (WHERE status = 'published' AND hidden_at IS NULL
                                                       AND starts_at - interval '30 minutes' <= now() AND ends_at > now()),
                       'ended',     count(*) FILTER (WHERE status = 'published' AND hidden_at IS NULL AND ends_at <= now()),
                       'cancelled', count(*) FILTER (WHERE status = 'cancelled' AND hidden_at IS NULL),
                       'hidden',    count(*) FILTER (WHERE hidden_at IS NOT NULL))
                   FROM event),
        -- Totaux déjà publics manif par manif : les additionner ne révèle rien de plus
        'totals', (SELECT json_build_object(
                       'present',    coalesce(sum(present), 0),
                       'supporters', coalesce(sum(supporters), 0))
                   FROM event_count),
        'by_city', (SELECT coalesce(json_agg(r ORDER BY r.present DESC, r.city), '[]')
                    FROM (SELECT e.city, count(*) AS events,
                                 coalesce(sum(c.present), 0) AS present,
                                 coalesce(sum(c.supporters), 0) AS supporters
                          FROM event e JOIN event_count c ON c.event_id = e.id
                          WHERE e.hidden_at IS NULL
                          GROUP BY e.city) r),
        'by_cause', (SELECT coalesce(json_agg(r ORDER BY r.present DESC, r.cause), '[]')
                     FROM (SELECT e.cause, count(*) AS events,
                                  coalesce(sum(c.present), 0) AS present,
                                  coalesce(sum(c.supporters), 0) AS supporters
                           FROM event e JOIN event_count c ON c.event_id = e.id
                           WHERE e.hidden_at IS NULL
                           GROUP BY e.cause) r),
        'health', json_build_object(
            -- Jetons encore en base : un nombre, jamais les jetons eux-mêmes
            'tokens_stored',  (SELECT count(*) FROM presence) + (SELECT count(*) FROM support),
            -- La purge passe toutes les heures : au-delà de 25 h après la fin, elle est en retard
            'overdue_purges', (SELECT count(*) FROM event
                               WHERE purged_at IS NULL AND status <> 'draft'
                                 AND ends_at < now() - interval '25 hours'),
            'next_purge',     (SELECT min(ends_at) + interval '24 hours' FROM event
                               WHERE purged_at IS NULL AND status <> 'draft'),
            'last_cron',      cron,
            'database_size',  pg_size_pretty(pg_database_size(current_database())),
            'checked_at',     now())
    ) INTO result;
    RETURN result;
END $$;

-- GET /rpc/admin_events : toutes les manifs publiées ou annulées (les brouillons restent au collectif)
CREATE FUNCTION api.admin_events()
RETURNS TABLE (
    id uuid, title text, cause event_cause, city text, starts_at timestamptz, ends_at timestamptz,
    status event_status, declared boolean, organizer_id uuid, organizer text,
    hidden_at timestamptz, hidden_reason text, purged_at timestamptz, present bigint, supporters bigint
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM private.current_admin();
    RETURN QUERY
    SELECT e.id, e.title, e.cause, e.city, e.starts_at, e.ends_at, e.status, e.declared,
           o.id, o.name, e.hidden_at, e.hidden_reason, e.purged_at,
           c.present::bigint, c.supporters::bigint
    FROM event e
    JOIN organizer o ON o.id = e.organizer_id
    LEFT JOIN event_count c ON c.event_id = e.id
    WHERE e.status <> 'draft'
    ORDER BY e.starts_at DESC;
END $$;

-- GET /rpc/admin_organizers
CREATE FUNCTION api.admin_organizers()
RETURNS TABLE (
    id uuid, name text, email text, created_at timestamptz,
    suspended_at timestamptz, suspended_reason text, events bigint, drafts bigint
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM private.current_admin();
    RETURN QUERY
    SELECT o.id, o.name, o.email, o.created_at, o.suspended_at, o.suspended_reason,
           count(e.id) FILTER (WHERE e.status <> 'draft'),
           count(e.id) FILTER (WHERE e.status = 'draft')
    FROM organizer o
    LEFT JOIN event e ON e.organizer_id = o.id
    GROUP BY o.id
    ORDER BY o.name;
END $$;

-- GET /rpc/admin_log : les 200 dernières actions
CREATE FUNCTION api.admin_log()
RETURNS TABLE (
    at timestamptz, admin text, action text, target_kind text, target_id uuid, target text, reason text
)
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM private.current_admin();
    RETURN QUERY
    SELECT l.at, a.name, l.action, l.target_kind, l.target_id,
           coalesce(e.title, o.name), l.reason
    FROM private.admin_log l
    JOIN private.admin_account a ON a.id = l.admin_id
    LEFT JOIN event e     ON l.target_kind = 'event'     AND e.id = l.target_id
    LEFT JOIN organizer o ON l.target_kind = 'organizer' AND o.id = l.target_id
    ORDER BY l.at DESC, l.id DESC
    LIMIT 200;
END $$;


-- Écriture : comptes organisateurs --------------------------------------

-- POST /rpc/admin_invite_organizer {"name", "email"} → {"id", "password"}
-- Le mot de passe provisoire n'est montré qu'une fois ; le collectif le change ensuite.
CREATE FUNCTION api.admin_invite_organizer(name text, email text) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    pwd    text := private.temporary_password();
    new_id uuid;
BEGIN
    PERFORM private.current_admin();
    IF length(btrim(coalesce(name, ''))) NOT BETWEEN 2 AND 120 THEN
        RAISE EXCEPTION 'nom du collectif : 2 à 120 caractères' USING ERRCODE = '22023';
    END IF;
    IF lower(btrim(coalesce(email, ''))) !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'adresse e-mail invalide' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (SELECT 1 FROM organizer WHERE organizer.email = lower(btrim(admin_invite_organizer.email))) THEN
        RAISE EXCEPTION 'un compte existe déjà avec cette adresse' USING ERRCODE = '23505';
    END IF;
    new_id := public.create_organizer(name, email, pwd);
    PERFORM private.log_admin('invitation', 'organizer', new_id, NULL);
    RETURN json_build_object('id', new_id, 'password', pwd);
END $$;

-- POST /rpc/admin_reset_password {"id"} → {"password"}
CREATE FUNCTION api.admin_reset_password(id uuid) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    pwd text := private.temporary_password();
BEGIN
    PERFORM private.current_admin();
    UPDATE organizer SET password_hash = crypt(pwd, gen_salt('bf', 12)) WHERE organizer.id = admin_reset_password.id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'compte introuvable' USING ERRCODE = 'P0002';
    END IF;
    PERFORM private.log_admin('nouveau mot de passe', 'organizer', admin_reset_password.id, NULL);
    RETURN json_build_object('password', pwd);
END $$;

-- POST /rpc/admin_suspend_organizer {"id", "reason"}
CREATE FUNCTION api.admin_suspend_organizer(id uuid, reason text) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    why text := private.require_reason(reason);
BEGIN
    PERFORM private.current_admin();
    UPDATE organizer SET suspended_at = now(), suspended_reason = why
    WHERE organizer.id = admin_suspend_organizer.id AND suspended_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'compte introuvable ou déjà suspendu' USING ERRCODE = '55000';
    END IF;
    PERFORM private.log_admin('suspension', 'organizer', admin_suspend_organizer.id, why);
END $$;

-- POST /rpc/admin_reactivate_organizer {"id", "reason"}
CREATE FUNCTION api.admin_reactivate_organizer(id uuid, reason text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM private.current_admin();
    UPDATE organizer SET suspended_at = NULL, suspended_reason = NULL
    WHERE organizer.id = admin_reactivate_organizer.id AND suspended_at IS NOT NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'compte introuvable ou pas suspendu' USING ERRCODE = '55000';
    END IF;
    PERFORM private.log_admin('réactivation', 'organizer', admin_reactivate_organizer.id, reason);
END $$;


-- Écriture : modération des manifs --------------------------------------

-- POST /rpc/admin_hide_event {"id", "reason"} : retirée de l'app, refuse présences et soutiens.
-- Les chiffres déjà enregistrés restent (et sont purgés normalement).
CREATE FUNCTION api.admin_hide_event(id uuid, reason text) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    why text := private.require_reason(reason);
BEGIN
    PERFORM private.current_admin();
    UPDATE event SET hidden_at = now(), hidden_reason = why
    WHERE event.id = admin_hide_event.id AND status <> 'draft' AND hidden_at IS NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'manifestation introuvable ou déjà masquée' USING ERRCODE = '55000';
    END IF;
    PERFORM private.log_admin('masquage', 'event', admin_hide_event.id, why);
END $$;

-- POST /rpc/admin_unhide_event {"id", "reason"}
CREATE FUNCTION api.admin_unhide_event(id uuid, reason text DEFAULT NULL) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    PERFORM private.current_admin();
    UPDATE event SET hidden_at = NULL, hidden_reason = NULL
    WHERE event.id = admin_unhide_event.id AND hidden_at IS NOT NULL;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'manifestation introuvable ou pas masquée' USING ERRCODE = '55000';
    END IF;
    PERFORM private.log_admin('rétablissement', 'event', admin_unhide_event.id, reason);
END $$;


-- Droits --------------------------------------------------------------
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public  FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA private FROM PUBLIC;
REVOKE ALL     ON ALL TABLES    IN SCHEMA private FROM PUBLIC;
-- api.events a besoin de ST_AsGeoJSON (refermée par la ligne ci-dessus)
GRANT EXECUTE ON FUNCTION public.st_asgeojson(geometry, integer, integer) TO web_anon;

REVOKE EXECUTE ON FUNCTION api.admin_login(text, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION api.admin_login(text, text, text) TO web_anon;

DO $$
DECLARE
    f text;
BEGIN
    FOREACH f IN ARRAY ARRAY[
        'api.admin_overview()',
        'api.admin_events()',
        'api.admin_organizers()',
        'api.admin_log()',
        'api.admin_invite_organizer(text, text)',
        'api.admin_reset_password(uuid)',
        'api.admin_suspend_organizer(uuid, text)',
        'api.admin_reactivate_organizer(uuid, text)',
        'api.admin_hide_event(uuid, text)',
        'api.admin_unhide_event(uuid, text)'
    ] LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', f);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO foulala_admin', f);
    END LOOP;
END $$;
