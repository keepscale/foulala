# Foulala

Application pour les manifestations :
- les **organisateurs** déclarent une manif (cause, parcours, horaires, revendications) ;
- les **participants** disent qu'ils la soutiennent, ou qu'ils y sont via le bouton **« J'y suis ! »** ;
- l'app affiche un **comptage anonyme et vérifiable** : « au moins X présents vérifiés ».

Le but est de proposer un chiffre plancher crédible face aux chiffres de la police et des organisateurs. Projet perso, open source, français d'abord. Toute l'interface et la doc sont en français.

## Invariants de vie privée (NON NÉGOCIABLES)

Les données touchent aux opinions politiques (données sensibles au sens de l'article 9 du RGPD). Une fuite ou un soupçon de pistage tue le projet. Toute modification doit respecter ces règles. En cas de doute, demander avant de coder.

1. **La position GPS ne quitte jamais le téléphone.** Le test « suis-je dans la zone ? » se fait sur l'appareil, à partir de la zone envoyée par le serveur.
2. **Aucun compte participant.** Le participant n'est identifié que par un jeton aléatoire (UUID v4), **différent pour chaque manif**, généré et gardé sur le téléphone.
3. **Le serveur ne reçoit que** : l'id de la manif, le jeton, le créneau (arrondi au quart d'heure) et le numéro de tronçon (optionnel). Jamais de coordonnées, d'heure exacte, d'identifiant d'appareil ni de compte.
4. **Aucun journal d'adresses IP** sur la chaîne participant : pas de journal d'accès dans Caddy, `X-Forwarded-For` retiré, PostgREST en niveau `crit`, PostgreSQL sans log de connexions. Pas de proxy tiers (Cloudflare, etc.) devant l'API.
5. **Purge** : 24 h après la fin d'une manif, les jetons sont supprimés et remplacés par des totaux agrégés (`event_tally`).
6. **Seuil d'anonymat** : un groupe de moins de **20 personnes** (tronçon × créneau) n'est jamais affiché.
7. **Pas de pub, pas de revente de données, pas de SDK d'analytics ou de tracking** (Firebase Analytics, Sentry avec IP, etc.) dans l'app.
8. La limite de débit anti-abus se fait **en mémoire uniquement**, jamais persistée.

Le skill `revue-vie-privee` détaille la checklist à appliquer avant tout changement qui touche aux données des participants.

## Architecture

```
Téléphone (Flutter)                        Serveur (VPS en Europe)
─────────────────────                      ─────────────────────────────
GET /events?city=eq.Lyon        ─────────► Caddy (HTTPS, sans logs)
GET /events?id=eq.… (zone GeoJSON)            │
position lue 1 fois, test local               ▼
POST /rpc/presence {event_id, token,      PostgREST (schéma `api` seulement)
      time_slot, segment}                     │
POST /rpc/support  {event_id, token}          ▼
GET /event_count, /event_timeline,        PostgreSQL 16 + PostGIS + pg_cron
    /event_density                         (schéma `public`, purge horaire)
```

- **Pas de code serveur applicatif** : PostgREST expose directement les vues et fonctions du schéma `api`. La logique métier et les validations vivent en SQL (`db/`).
- Le rôle anonyme `web_anon` ne voit que le schéma `api`. Les tables de `public` ne sont jamais exposées.
- Rôle `organizer` (`db/organizer.sql`) : `api.login` vérifie le mot de passe (bcrypt, `pgcrypto`) et signe un JWT HS256 en SQL avec le secret de `private.jwt_secret` (même valeur que `PGRST_JWT_SECRET`). PostgREST bascule alors sur `organizer`, et chaque fonction vérifie que la manif appartient au `sub` du jeton. Comptes **sur invitation** uniquement (`public.create_organizer`, jamais exposé).
- Une manif publiée ne se modifie plus (parcours et horaires fondent le comptage) : elle s'annule. Seul un brouillon se modifie ou se supprime.
- Rôle `foulala_admin` (`db/admin.sql`) : pilotage, modération (masquer une manif, suspendre un collectif), invitations. Connexion par mot de passe **et** code TOTP (calculé en SQL, un code ne sert qu'une fois), jeton d'une heure. Comptes créés en ligne de commande seulement (`public.create_admin`). Chaque action va au journal `private.admin_log` avec son motif. **L'administration ne voit jamais un jeton ni une présence isolée** : comptes, manifs et totaux seulement.

### Modèle de données (`db/schema.sql`)

| Table | Contenu |
|---|---|
| `organizer` | Comptes des collectifs (nom, e-mail en minuscules, hash bcrypt), `suspended_at` et motif si suspendu par l'administration |
| `event` | Manif : titre, `cause` (type `event_cause`, mêmes identifiants que `design/tokens.json`, défaut `autre`), revendications (`text[]`), ville, `route` (LineString 4326), `buffer_m` (20 à 500, défaut 100), `zone` et `segment_count` calculés par trigger, horaires, `declared`, `status` (draft, published, cancelled), `purged_at`, `hidden_at` et `hidden_reason` (masquée par la modération : retirée de l'app, plus de présence ni de soutien) |
| `presence` | `(event_id, token)` en clé primaire, `time_slot` (multiple de 15 min), `segment`. Volontairement **sans** `created_at` |
| `support` | `(event_id, token)`, sans GPS ni heure |
| `event_tally` | Totaux conservés après purge |

- Fonctions : `record_presence`, `record_support` (validations : manif publiée, créneau entre 30 min avant le début et la fin, tronçon existant, doublon ignoré), `purge_event`, `purge_due_events`.
- Vues : `event_count`, `event_timeline`, `event_density` (seuil de 20).
- Tronçons : environ 200 m, 100 au maximum. Le téléphone calcule sa position relative le long du parcours (0 à 1) et en déduit le numéro.

### Côté téléphone (au « J'y suis ! »)

1. Lire la position **une fois**, et refuser si la précision dépasse 50 m.
2. Vérifier qu'elle est dans la zone et qu'on est dans le créneau.
3. Reprendre le jeton de cette manif ou en tirer un nouveau, stocké localement.
4. Arrondir l'heure au quart d'heure et calculer le tronçon.
5. Mettre l'envoi en file d'attente et réessayer si le réseau sature, jusqu'à 24 h après la fin.

Les trois états de l'écran : présence envoyée, en attente de réseau, hors de la zone.

## Organisation du dépôt (monorepo)

```
db/        schema.sql, api.sql, organizer.sql, admin.sql, tests/*.sql → la source de vérité ; seed.sql (données de dev)
server/    docker-compose (PostGIS+pg_cron, PostgREST, Caddy), docker-compose.dev.yml, Caddyfile, initdb/
supabase/  adapter.sql (droits Supabase), README : base de TEST seulement (journal d'IP), page web comprise
app/       app Flutter participants (MVVM officiel de Flutter, voir app/README.md)
web/       page organisateur et administration (#/admin) : Vite + TypeScript sans framework, Leaflet, publiée sur GitHub Pages (voir web/README.md)
design/    tokens.json (couleurs par cause, typo), lien vers les maquettes
docs/      architecture (test Supabase / production VPS, diagrammes), méthode de comptage, vie privée, décisions
scripts/   db-test.sh
```

Pas d'outil de monorepo (Nx, Turborepo…) : les langages diffèrent, des dossiers suffisent.

## Commandes

```bash
# Tests SQL (PostgreSQL 14+ avec PostGIS en local)
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres ./scripts/db-test.sh

# Serveur complet
cd server && cp .env.example .env && docker compose up -d

# Serveur de dev : base + API sur 127.0.0.1:3000 (10.0.2.2:3000 depuis l'émulateur), avec db/seed.sql
cd server && docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d db api

# App : tests, et régénération des couleurs après un changement de design/tokens.json
cd app && flutter test && flutter analyze
cd app && dart run tool/gen_tokens.dart

# Page organisateur (compte de dev : lyon@example.org / foulala-dev-2026)
cd web && npm install && npm run dev      # http://localhost:5173
cd web && npm run build                   # vérifie les types et construit dist/

# Supabase (tests) : script unique à coller dans le SQL Editor → supabase/build/setup.sql (reset.sql pour repartir de zéro)
./scripts/supabase-bundle.sh

# Tests SQL dans le conteneur de dev (sans psql local)
docker compose -f docker-compose.yml -f docker-compose.dev.yml exec -T -e PGUSER=foulala db bash /repo/scripts/db-test.sh
```

`db/seed.sql` crée des manifs fictives à Lyon et Paris, dont deux en cours. Ses dates partent de `now()` : le rejouer remet des manifs en cours (commande dans son en-tête). Il n'est **jamais** chargé en production.

Sous Windows, `.gitattributes` force les fins de ligne LF pour `*.sh`, `*.sql` et le Caddyfile : en CRLF, l'initialisation de la base échoue.

La CI lance les tests SQL (`db.yml`) quand `db/` ou `server/` change, et construit la page organisateur (`web.yml`) quand `web/` ou `design/` change ; sur `main`, `web.yml` la publie sur GitHub Pages si la variable `API_URL` est définie. Un tag `app-vX.Y.Z` lance `app-release.yml`, qui publie un APK de test signé (base Supabase) dans une Release GitHub (voir `app/README.md`).

Variables du serveur (`server/.env`) : `JWT_SECRET` (32 caractères au moins, signe les jetons organisateurs) et `WEB_ORIGIN` (adresse de la page organisateur, seule origine autorisée par CORS).

## Conventions

- **Tout changement de schéma** passe par `db/` et s'accompagne d'un test dans `db/tests/` (voir le skill `changement-db`). Les tests utilisent `ASSERT` dans des blocs `DO`, à l'intérieur d'un `BEGIN … ROLLBACK`.
- Pas encore de migrations : tant que rien n'est en production, on modifie `schema.sql` directement. Ensuite, on passera à des fichiers `db/migrations/NNNN_description.sql`.
- Commits courts en français, à l'impératif (« Ajoute le rôle organisateur »).
- Code (noms de tables, variables) en anglais, commentaires et textes d'interface en français.

## Design

Maquettes : canevas « Foulala · maquettes » sur claude.ai (privé), sources copiées dans `design/maquettes/` (format du canevas, référence pour l'implémentation). Logo : `design/logo.svg`.

- Ton : coloré, chaleureux, coins arrondis, boutons en pilule, jamais austère.
- Polices : **Bricolage Grotesque** (titres, 800), **Figtree** (texte), IBM Plex Mono (jeton uniquement).
- Texte `#1D1A33`, texte secondaire `#5D5A72`, fond `#F7F6FB`.
- **Un thème par cause**, choisi par l'organisateur : Climat, Fiertés, Paix, Social, Santé, Éducation, Autre (neutre). Couleurs dans `design/tokens.json`. Pour ajouter une cause, voir le skill `theme-cause`.
- Le ton de la manif (titre, cause) prime sur le ton léger du nom. Les actions restent sobres : « J'y suis ! », « Je soutiens ».
- Logo : trois bulles (jaune `#FFC531`, rose `#FF5FA2`, bleu `#49A8FF`), celle du milieu en repère de carte. Logotype « foulala » en minuscules, « lala » en rose.
- Accessibilité : contraste 4,5:1 minimum, cibles tactiles de 44 px minimum, jamais la couleur seule pour porter un sens.

## Nom et marque

- **Foulala** : « foule » + « oh là là », avec un « la la » qui évoque un chant. Bouton principal : **« J'y suis ! »**.
- Phrase type : « Télécharge Foulala et appuie sur J'y suis. »
- À vérifier : INPI (classes 9 et 42), domaines foulala.fr, .app, .org.

## Hébergement prévu

- Développement : base locale, ou Supabase gratuit **pour les tests uniquement** (sa passerelle journalise les IP).
- Production : petit VPS en Europe (Hetzner CX23 ou OVH VPS-1, 6 à 8 € par mois) avec `server/`.
- Page organisateur : hébergement statique gratuit.

## Modèle économique envisagé

Gratuit pour les participants, toujours. Dons (Liberapay, Open Collective), subventions pour logiciels libres respectueux de la vie privée (NLnet…), puis éventuellement des options payantes pour les grosses organisations (export, rapport, plusieurs comptes). Structure : association loi 1901 quand le projet décolle.

## Feuille de route

1. ✅ Schéma SQL, API PostgREST, tests, docker-compose
2. ✅ Rôle organisateur (JWT) : connexion, création, modification d'un brouillon, publication, annulation
3. ✅ App Flutter : liste par ville, détail, « J'y suis ! » (vérification locale, file d'attente hors ligne), « Je soutiens », compteur
4. ✅ Page web organisateur : formulaire et tracé du parcours sur une carte OpenStreetMap (à publier : dépôt public + variable `API_URL`)
   ✅ Administration : pilotage, santé, modération, comptes des collectifs, journal (TOTP)
5. Limite de débit en mémoire (en priorité sur `/rpc/login` et `/rpc/admin_login`), attestation d'appareil (Play Integrity, App Attest)
6. Fausse marche de test avec des amis
7. Avant toute vraie manif : politique de confidentialité, analyse d'impact (AIPD), méthode de comptage publiée

## Contexte marché

Aucun équivalent sérieux. ProtestCount (iOS, 2023) fait un comptage basique, sans suivi ni réelle anonymisation. Les tentatives de comptage par les opérateurs (France, 2013) ou par capteurs Wi-Fi (Brésil, 2016) ont échoué faute de base légale ou de transparence. Mobilizon gère des événements militants sans comptage. **Nos atouts : code ouvert, méthode publiée, neutralité.** L'app doit rester utilisable par toutes les causes, sans parti pris.
