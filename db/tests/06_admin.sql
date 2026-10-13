-- Tests de l'administration : TOTP, connexion, droits, modération, comptes, journal, vie privée.
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO private.jwt_secret (secret) VALUES ('secret-de-test-assez-long-pour-hs256-0123456789');

-- TOTP et base32 : vecteurs officiels -----------------------------------
DO $$
DECLARE
    rfc constant bytea := convert_to('12345678901234567890', 'utf8');   -- secret de la RFC 6238 (SHA-1)
BEGIN
    -- Les codes à 8 chiffres de la RFC, tronqués à 6 (même calcul, modulo 10^6)
    ASSERT private.totp(rfc, 1)        = '287082', 'RFC 6238, T = 59';
    ASSERT private.totp(rfc, 37037036) = '081804', 'RFC 6238, T = 1111111109';
    ASSERT private.totp(rfc, 37037037) = '050471', 'RFC 6238, T = 1111111111';
    ASSERT private.totp(rfc, 41152263) = '005924', 'RFC 6238, T = 1234567890';
    ASSERT private.totp(rfc, 66666666) = '279037', 'RFC 6238, T = 2000000000';

    ASSERT private.base32(convert_to('f', 'utf8'))      = 'MY',         'base32, RFC 4648';
    ASSERT private.base32(convert_to('foobar', 'utf8')) = 'MZXW6YTBOI', 'base32, RFC 4648';

    ASSERT private.temporary_password() ~ '^[a-zA-Z2-9]{16}$', 'mot de passe provisoire lisible';
    ASSERT private.temporary_password() <> private.temporary_password(), 'mot de passe provisoire aléatoire';
END $$;


-- Données : un admin, un collectif, une manif publiée, un brouillon, une présence --
SELECT set_config('test.uri', public.create_admin('Admin Test', ' Admin@Example.org', 'phrase-de-passe-tres-longue'), true) \g /dev/null
SELECT set_config('test.admin', (SELECT id::text FROM private.admin_account WHERE email = 'admin@example.org'), true) \g /dev/null
SELECT set_config('test.orgA', public.create_organizer('Collectif A', 'a@example.org', 'mot-de-passe-solide')::text, true) \g /dev/null

INSERT INTO event (id, organizer_id, title, city, route, starts_at, ends_at, status)
SELECT v.id, current_setting('test.orgA')::uuid, v.title, 'Lyon',
       ST_SetSRID(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[4.8357,45.7640],[4.8320,45.7578]]}'), 4326),
       now() - interval '1 hour', now() + interval '2 hours', v.status::event_status
FROM (VALUES ('00000000-0000-0000-0000-0000000000a1'::uuid, 'Manif publiée', 'published'),
             ('00000000-0000-0000-0000-0000000000a2'::uuid, 'Brouillon de A', 'draft')) AS v(id, title, status);

SELECT record_presence('00000000-0000-0000-0000-0000000000a1', '99999999-9999-4999-8999-999999999999',
                       date_bin('15 minutes', now(), 'epoch')) \g /dev/null

DO $$
DECLARE
    a      private.admin_account%ROWTYPE;
    failed boolean;
BEGIN
    SELECT * INTO a FROM private.admin_account WHERE email = 'admin@example.org';
    ASSERT a.password_hash LIKE '$2a$12$%', 'hash bcrypt attendu';
    ASSERT current_setting('test.uri') =
           'otpauth://totp/Foulala:admin%40example.org?secret=' || private.base32(a.totp_secret)
           || '&issuer=Foulala&algorithm=SHA1&digits=6&period=30', 'adresse otpauth';

    BEGIN
        PERFORM public.create_admin('Court', 'court@example.org', 'trop-court');
        failed := false;
    EXCEPTION WHEN OTHERS THEN failed := true;
    END;
    ASSERT failed, 'mot de passe administrateur de moins de 16 caractères accepté';

    -- Code valide maintenant (now() est figé dans la transaction)
    PERFORM set_config('test.code',
        private.totp(a.totp_secret, floor(extract(epoch FROM now()) / 30)::bigint), true);
END $$;


-- Connexion, avec le rôle anonyme de l'API ------------------------------
SET LOCAL ROLE web_anon;

DO $$
DECLARE
    code   constant text := current_setting('test.code');
    r      json;
    failed boolean;
BEGIN
    BEGIN
        PERFORM api.admin_login('admin@example.org', 'mauvais-mot-de-passe', code);
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'mauvais mot de passe accepté';

    BEGIN
        PERFORM api.admin_login('admin@example.org', 'phrase-de-passe-tres-longue', '000000');
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed OR code = '000000', 'mauvais code accepté';

    BEGIN
        PERFORM api.admin_login('admin@example.org', 'phrase-de-passe-tres-longue', NULL);
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'connexion sans code acceptée';

    BEGIN
        PERFORM api.admin_login('inconnu@example.org', 'phrase-de-passe-tres-longue', code);
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'e-mail inconnu accepté';

    r := api.admin_login(' ADMIN@example.org', 'phrase-de-passe-tres-longue', code);
    ASSERT r->>'name' = 'Admin Test', 'login admin : nom';
    ASSERT (r->>'expires_at')::timestamptz <= now() + interval '1 hour', 'jeton admin : une heure au plus';
    PERFORM set_config('test.token', r->>'token', true);

    BEGIN
        PERFORM api.admin_login('admin@example.org', 'phrase-de-passe-tres-longue', code);
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'un code TOTP déjà servi ne doit pas resservir';

    -- Le rôle anonyme n'atteint ni l'administration ni ses tables
    BEGIN
        PERFORM api.admin_overview();
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas lire le pilotage';

    BEGIN
        PERFORM 1 FROM private.admin_account;
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas lire les comptes admin';

    BEGIN
        PERFORM public.create_admin('Pirate', 'pirate@example.org', 'phrase-de-passe-tres-longue');
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'web_anon ne doit pas créer de compte admin';
END $$;

RESET ROLE;

DO $$
DECLARE
    p      text := split_part(current_setting('test.token'), '.', 2);
    claims json;
BEGIN
    claims := convert_from(decode(translate(p, '-_', '+/') || repeat('=', (4 - length(p) % 4) % 4), 'base64'), 'utf8')::json;
    ASSERT claims->>'role' = 'foulala_admin', 'claim role admin';
    ASSERT claims->>'sub' = current_setting('test.admin'), 'claim sub admin';
END $$;


-- Un organisateur n'atteint pas l'administration -------------------------
SET LOCAL ROLE organizer;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.orgA'))::text, true) \g /dev/null
DO $$
DECLARE
    failed boolean;
BEGIN
    BEGIN
        PERFORM api.admin_hide_event('00000000-0000-0000-0000-0000000000a1', 'Je me masque moi-même');
        failed := false;
    EXCEPTION WHEN insufficient_privilege THEN failed := true;
    END;
    ASSERT failed, 'un organisateur ne doit pas modérer';
END $$;
RESET ROLE;

-- Le rôle admin sans jeton admin valide : rien
SET LOCAL ROLE foulala_admin;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.admin'))::text, true) \g /dev/null
DO $$
DECLARE
    failed boolean;
BEGIN
    BEGIN
        PERFORM api.admin_overview();
        failed := false;
    EXCEPTION WHEN invalid_authorization_specification THEN failed := true;
    END;
    ASSERT failed, 'jeton sans le rôle admin accepté';
END $$;


-- Pilotage et actions, en administrateur ----------------------------------
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'foulala_admin', 'sub', current_setting('test.admin'))::text, true) \g /dev/null

DO $$
DECLARE
    a1     constant uuid := '00000000-0000-0000-0000-0000000000a1';
    a2     constant uuid := '00000000-0000-0000-0000-0000000000a2';
    o      json;
    r      json;
    failed boolean;
BEGIN
    o := api.admin_overview();
    ASSERT (o->'events'->>'live')::int = 1, 'une manif en cours';
    ASSERT (o->'events'->>'draft')::int = 1, 'un brouillon';
    ASSERT (o->'totals'->>'present')::int = 1, 'total des présents';
    ASSERT (o->'organizers'->>'active')::int >= 1, 'collectifs actifs';
    ASSERT (o->'health'->>'tokens_stored')::int = 1, 'jetons en base : un nombre';
    ASSERT (o->'by_city'->0->>'city') IS NOT NULL, 'répartition par ville';
    -- Vie privée : jamais un jeton dans ce que voit l'administration
    ASSERT position('99999999-9999' IN o::text) = 0, 'un jeton apparaît dans le pilotage';

    ASSERT EXISTS (SELECT 1 FROM api.admin_events() WHERE id = a1), 'manif publiée listée';
    ASSERT NOT EXISTS (SELECT 1 FROM api.admin_events() WHERE id = a2), 'les brouillons restent au collectif';
    ASSERT (SELECT drafts FROM api.admin_organizers() WHERE email = 'a@example.org') = 1, 'brouillons comptés';

    -- Masquage : motif obligatoire, brouillon impossible
    BEGIN
        PERFORM api.admin_hide_event(a1, 'non');
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'masquage sans vrai motif accepté';

    PERFORM api.admin_hide_event(a1, '  Fausse manif signalée  ');
    ASSERT (SELECT hidden_reason FROM api.admin_events() WHERE id = a1) = 'Fausse manif signalée', 'motif enregistré';

    BEGIN
        PERFORM api.admin_hide_event(a2, 'Brouillon gênant');
        failed := false;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN failed := true;
    END;
    ASSERT failed, 'un brouillon ne se masque pas';

    -- Invitation : mot de passe provisoire montré une fois
    r := api.admin_invite_organizer('Collectif B', ' B@Example.org ');
    ASSERT r->>'password' ~ '^[a-zA-Z2-9]{16}$', 'mot de passe provisoire';
    PERFORM set_config('test.orgB', r->>'id', true);
    PERFORM set_config('test.pwdB1', r->>'password', true);

    BEGIN
        PERFORM api.admin_invite_organizer('Doublon', 'b@example.org');
        failed := false;
    EXCEPTION WHEN unique_violation THEN failed := true;
    END;
    ASSERT failed, 'deux comptes pour une même adresse';

    BEGIN
        PERFORM api.admin_invite_organizer('Sans adresse', 'pas-une-adresse');
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'adresse invalide acceptée';

    PERFORM set_config('test.pwdB2', api.admin_reset_password(current_setting('test.orgB')::uuid)->>'password', true);

    -- Suspension
    PERFORM api.admin_suspend_organizer(current_setting('test.orgA')::uuid, 'Usurpation d''un collectif');
    BEGIN
        PERFORM api.admin_suspend_organizer(current_setting('test.orgA')::uuid, 'Encore une fois');
        failed := false;
    EXCEPTION WHEN object_not_in_prerequisite_state THEN failed := true;
    END;
    ASSERT failed, 'double suspension acceptée';

    -- Journal : chaque action, avec son auteur et son motif
    ASSERT (SELECT count(*) FROM api.admin_log()) = 4, 'quatre actions au journal';
    ASSERT (SELECT reason FROM api.admin_log() WHERE action = 'masquage') = 'Fausse manif signalée', 'motif au journal';
    ASSERT (SELECT target FROM api.admin_log() WHERE action = 'masquage') = 'Manif publiée', 'cible au journal';
    ASSERT (SELECT admin FROM api.admin_log() WHERE action = 'suspension') = 'Admin Test', 'auteur au journal';
END $$;
RESET ROLE;


-- Effets côté public ------------------------------------------------------
SET LOCAL ROLE web_anon;

DO $$
DECLARE
    a1     constant uuid := '00000000-0000-0000-0000-0000000000a1';
    failed boolean;
BEGIN
    ASSERT NOT EXISTS (SELECT 1 FROM api.events WHERE id = a1), 'manif masquée encore listée';
    ASSERT NOT EXISTS (SELECT 1 FROM api.event_count WHERE event_id = a1), 'compteur d''une manif masquée encore visible';

    BEGIN
        PERFORM api.presence(a1, gen_random_uuid(), date_bin('15 minutes', now(), 'epoch'));
        failed := false;
    EXCEPTION WHEN raise_exception THEN failed := true;
    END;
    ASSERT failed, 'présence acceptée sur une manif masquée';

    BEGIN
        PERFORM api.support(a1, gen_random_uuid());
        failed := false;
    EXCEPTION WHEN raise_exception THEN failed := true;
    END;
    ASSERT failed, 'soutien accepté sur une manif masquée';

    -- Compte suspendu : refusé, mais seulement avec le bon mot de passe (sinon rien n'est révélé)
    BEGIN
        PERFORM api.login('a@example.org', 'mot-de-passe-solide');
        failed := false;
    EXCEPTION WHEN invalid_authorization_specification THEN failed := true;
    END;
    ASSERT failed, 'compte suspendu connecté';

    BEGIN
        PERFORM api.login('a@example.org', 'mauvais-mot-de-passe');
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'un mauvais mot de passe doit donner l''erreur habituelle';

    -- Nouveau mot de passe : l'ancien provisoire ne marche plus
    BEGIN
        PERFORM api.login('b@example.org', current_setting('test.pwdB1'));
        failed := false;
    EXCEPTION WHEN invalid_password THEN failed := true;
    END;
    ASSERT failed, 'ancien mot de passe provisoire accepté';
    ASSERT api.login('b@example.org', current_setting('test.pwdB2')) IS NOT NULL, 'nouveau mot de passe provisoire';
END $$;
RESET ROLE;


-- Organisateurs : suspendu sans droits, changement de mot de passe ---------
SET LOCAL ROLE organizer;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.orgA'))::text, true) \g /dev/null
DO $$
DECLARE
    failed boolean;
BEGIN
    ASSERT NOT EXISTS (SELECT 1 FROM api.my_events), 'un compte suspendu ne voit plus ses manifs';
    BEGIN
        PERFORM api.publish_event('00000000-0000-0000-0000-0000000000a2');
        failed := false;
    EXCEPTION WHEN invalid_authorization_specification THEN failed := true;
    END;
    ASSERT failed, 'un compte suspendu publie encore avec un jeton en cours';
END $$;

SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.orgB'))::text, true) \g /dev/null
DO $$
DECLARE
    failed boolean;
BEGIN
    BEGIN
        PERFORM api.change_password('pas-le-bon', 'nouveau-mot-de-passe-solide');
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'changement sans le mot de passe actuel';

    BEGIN
        PERFORM api.change_password(current_setting('test.pwdB2'), 'court');
        failed := false;
    EXCEPTION WHEN invalid_parameter_value THEN failed := true;
    END;
    ASSERT failed, 'nouveau mot de passe trop court accepté';

    PERFORM api.change_password(current_setting('test.pwdB2'), 'nouveau-mot-de-passe-solide');
END $$;
RESET ROLE;

SET LOCAL ROLE web_anon;
DO $$
BEGIN
    ASSERT api.login('b@example.org', 'nouveau-mot-de-passe-solide') IS NOT NULL, 'mot de passe changé';
END $$;
RESET ROLE;


-- Réactivation : le collectif voit le motif du masquage, puis le rétablissement --
SET LOCAL ROLE foulala_admin;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'foulala_admin', 'sub', current_setting('test.admin'))::text, true) \g /dev/null
DO $$ BEGIN PERFORM api.admin_reactivate_organizer(current_setting('test.orgA')::uuid); END $$;
RESET ROLE;

SET LOCAL ROLE organizer;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'organizer', 'sub', current_setting('test.orgA'))::text, true) \g /dev/null
DO $$
BEGIN
    ASSERT (SELECT hidden_reason FROM api.my_events WHERE id = '00000000-0000-0000-0000-0000000000a1')
           = 'Fausse manif signalée', 'le collectif voit pourquoi sa manif est masquée';
END $$;
RESET ROLE;

SET LOCAL ROLE foulala_admin;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'foulala_admin', 'sub', current_setting('test.admin'))::text, true) \g /dev/null
DO $$
BEGIN
    PERFORM api.admin_unhide_event('00000000-0000-0000-0000-0000000000a1', 'Vérifiée auprès du collectif');
    ASSERT (SELECT count(*) FROM api.admin_log()) = 6, 'six actions au journal';
END $$;
RESET ROLE;

SET LOCAL ROLE web_anon;
DO $$
BEGIN
    ASSERT EXISTS (SELECT 1 FROM api.events WHERE id = '00000000-0000-0000-0000-0000000000a1'), 'manif rétablie';
END $$;
RESET ROLE;


-- Compte admin désactivé : son jeton ne sert plus à rien --------------------
UPDATE private.admin_account SET disabled_at = now() WHERE email = 'admin@example.org';

SET LOCAL ROLE foulala_admin;
SELECT set_config('request.jwt.claims',
                  json_build_object('role', 'foulala_admin', 'sub', current_setting('test.admin'))::text, true) \g /dev/null
DO $$
DECLARE
    failed boolean;
BEGIN
    BEGIN
        PERFORM api.admin_overview();
        failed := false;
    EXCEPTION WHEN invalid_authorization_specification THEN failed := true;
    END;
    ASSERT failed, 'compte admin désactivé encore actif';

    RAISE NOTICE '06_admin : OK';
END $$;

ROLLBACK;
