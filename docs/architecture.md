# Architecture

Comment les morceaux de Foulala s'assemblent, en **test** (Supabase) et en **production** (VPS). Les diagrammes sont en [Mermaid](https://mermaid.js.org/) : GitHub les affiche directement.

Pour les règles de vie privée qui contraignent tout ce qui suit, voir `CLAUDE.md` (invariants) et `docs/vie-privee.md`.

## Les morceaux

| Morceau | Dossier | Rôle | Qui s'en sert |
|---|---|---|---|
| App mobile | `app/` (Flutter) | Liste des manifs, « J'y suis ! », « Je soutiens », compteur | Participants, **sans compte** |
| Page web | `web/` (Vite + TypeScript) | Espace organisateur (`#/`) et administration (`#/admin`) | Collectifs invités, administrateurs |
| Base de données | `db/` (SQL) | Tables, règles métier, API, connexion, purge | Tout le monde, à travers l'API |
| Serveur | `server/` (Docker Compose) | PostgreSQL, PostgREST et Caddy sur le VPS | Production |
| Adaptation Supabase | `supabase/` | Droits et script d'installation pour la base de test | Tests |

Il n'y a **pas de code serveur applicatif** : PostgREST expose directement le schéma `api` de PostgreSQL. Toute la logique (validations, connexion, signature des jetons, purge) est en SQL, donc lisible et testée au même endroit (`db/tests/`).

```mermaid
flowchart LR
    subgraph Clients
        APP["📱 App Flutter<br/>participants, sans compte"]
        WEB["🖥️ Page web<br/>organisateurs et administration"]
    end
    subgraph Serveur["API + base"]
        API["PostgREST<br/>schéma api seulement"]
        DB[("PostgreSQL + PostGIS<br/>schémas public, api, private")]
        CRON["pg_cron<br/>purge horaire"]
    end
    APP -- "HTTPS : lectures, présence, soutien" --> API
    WEB -- "HTTPS + jeton JWT" --> API
    API --> DB
    CRON --> DB
```

## Mode test : Supabase

Pour tester entre amis sans serveur à soi : la base vit chez Supabase (offre gratuite), la page web sur GitHub Pages.

> **Supabase journalise les adresses IP** dans sa passerelle. Une IP reliée à une présence, c'est exactement ce que Foulala doit rendre impossible : ce mode sert aux **tests avec des données fictives**, jamais à une vraie manif. La page web affiche un bandeau « Version de test » dès qu'elle parle à Supabase.

```mermaid
flowchart LR
    subgraph Navigateur
        WEB["Page web<br/>foulala.keepscale.fr<br/>(GitHub Pages)"]
    end
    subgraph Téléphone
        APP["App Flutter<br/>config/supabase.json"]
    end
    subgraph Supabase["Supabase, tests"]
        GW["Passerelle API<br/>⚠️ journalise les IP<br/>vérifie la clé sb_publishable"]
        PGR["PostgREST<br/>rôles anon, organizer, foulala_admin"]
        PG[("PostgreSQL<br/>pgcrypto dans « extensions »<br/>pg_cron")]
    end
    GH["GitHub Actions<br/>build + publication"]
    APP -- "apikey + Accept-Profile: api" --> GW
    WEB -- "apikey + jeton JWT" --> GW
    GW --> PGR --> PG
    GH -- "VITE_API_URL, VITE_API_KEY" --> WEB
```

Particularités, toutes gérées par `scripts/supabase-bundle.sh` et `supabase/adapter.sql` :

- PostgREST s'y connecte avec le rôle **`anon`** (et non `web_anon`) : l'adaptateur lui donne exactement les mêmes droits.
- Supabase donne par défaut **tous les droits** sur `public` à `anon` et `authenticated` : l'adaptateur les retire, active RLS sans politique sur toutes les tables, puis vérifie que rien ne reste exposé.
- `pgcrypto` est dans le schéma `extensions` : le bundle l'ajoute au `search_path` des fonctions.
- Les jetons des organisateurs et des admins sont signés en SQL avec le **secret JWT du projet Supabase**, rangé à la main dans `private.jwt_secret` : c'est le seul moyen pour que l'API de Supabase les accepte.
- Toutes les requêtes portent la clé publique (`apikey`) et le schéma (`Accept-Profile: api`), car Supabase expose plusieurs schémas.

Installation pas à pas : `supabase/README.md`.

### Variante locale (développement au quotidien)

Sans réseau ni Supabase : `server/docker-compose.dev.yml` lance la base et l'API sur `127.0.0.1:3000`, avec les données de `db/seed.sql`. L'émulateur Android la voit en `10.0.2.2:3000`, la page web en `npm run dev` (`localhost:5173`, seule origine autorisée par CORS). Aucune IP n'est journalisée, comme en production.

```mermaid
flowchart LR
    EMU["Émulateur Android<br/>10.0.2.2:3000"] --> API
    VITE["npm run dev<br/>localhost:5173"] --> API
    subgraph Docker["Docker, 127.0.0.1"]
        API["PostgREST :3000"] --> DB[("PostgreSQL :5433<br/>+ seed.sql")]
    end
```

## Mode production : VPS

Un petit VPS en Europe (Hetzner ou OVH, 6 à 8 € par mois) fait tourner `server/` : trois conteneurs, aucun service tiers devant l'API. La page web reste un site statique sur GitHub Pages ; seuls les organisateurs la visitent.

```mermaid
flowchart TB
    subgraph Internet
        APP["📱 App Flutter<br/>participants"]
        WEB["🖥️ Navigateur<br/>organisateurs, admins"]
    end
    subgraph DNS["DNS (IONOS)"]
        D1["foulala.keepscale.fr<br/>CNAME → keepscale.github.io"]
        D2["api.foulala.keepscale.fr<br/>A / AAAA → IP du VPS"]
    end
    PAGES["GitHub Pages<br/>page statique"]
    subgraph VPS["VPS en Europe (server/)"]
        CADDY["Caddy<br/>HTTPS automatique<br/>❌ aucun journal d'accès<br/>X-Forwarded-For retiré<br/>limite de débit en mémoire (à faire)"]
        PGR["PostgREST<br/>journal au niveau crit<br/>CORS : WEB_ORIGIN seulement"]
        PG[("PostgreSQL 16 + PostGIS<br/>pas de journal de connexions")]
        CRON["pg_cron<br/>purge toutes les heures"]
    end
    WEB --> D1 --> PAGES
    WEB -- "appels API" --> D2
    APP --> D2 --> CADDY --> PGR --> PG
    CRON --> PG
```

Ce qui garantit l'absence de journal d'IP sur la chaîne participant (invariant n° 4) :

| Maillon | Réglage |
|---|---|
| Caddy | pas de directive `log`, en-têtes `X-Forwarded-For` et `X-Real-IP` retirés avant PostgREST |
| PostgREST | `PGRST_LOG_LEVEL=crit` |
| PostgreSQL | `log_connections` et `log_statement` désactivés |
| Réseau | pas de CDN ni de proxy tiers (Cloudflare…) devant l'API |

## Test et production côte à côte

| | Test (Supabase) | Production (VPS) |
|---|---|---|
| Hébergement de la base | Supabase, offre gratuite | VPS européen, `server/` |
| Adresse de l'API | `https://<projet>.supabase.co/rest/v1` | `https://api.foulala.keepscale.fr` |
| Journal des adresses IP | **oui** (passerelle Supabase) | **non**, sur toute la chaîne |
| Rôle anonyme de l'API | `anon` | `web_anon` |
| Clé dans les requêtes | `apikey: sb_publishable_…` | aucune |
| Secret des jetons JWT | secret du projet Supabase, copié dans `private.jwt_secret` | `JWT_SECRET` de `server/.env`, chargé au premier démarrage |
| CORS | toutes origines (Supabase) | `WEB_ORIGIN` seulement |
| Purge horaire | pg_cron de Supabase | pg_cron du conteneur |
| Installation de la base | coller `supabase/build/setup.sql` | automatique au premier `docker compose up` |
| Données | fictives uniquement | réelles |
| Bandeau « Version de test » | oui | non |

Configuration de chaque client :

| | App Flutter | Page web |
|---|---|---|
| Test | `--dart-define-from-file=config/supabase.json` (`API_URL`, `API_KEY`) | variables GitHub `API_URL`, `API_KEY` |
| Production | `--dart-define=API_URL=https://api.foulala.keepscale.fr` | variable GitHub `API_URL` seule |
| Local | par défaut (`10.0.2.2:3000`) | `npm run dev` (`localhost:3000`) |

## Dans la base : schémas et rôles

```mermaid
flowchart LR
    subgraph Rôles["Rôle selon le jeton"]
        ANON["web_anon / anon<br/>sans jeton"]
        ORG["organizer<br/>jeton 8 h"]
        ADM["foulala_admin<br/>jeton 1 h, TOTP"]
    end
    subgraph API["schéma api (exposé)"]
        V["vues : events, event_count,<br/>event_timeline, event_density"]
        F1["rpc : presence, support,<br/>login, admin_login"]
        F2["my_events, create_event,<br/>update_event, publish_event,<br/>cancel_event, change_password"]
        F3["admin_overview, admin_events,<br/>admin_organizers, admin_log,<br/>admin_hide_event, admin_suspend…"]
    end
    subgraph PUB["schéma public (interne)"]
        T["tables : organizer, event,<br/>presence, support, event_tally"]
    end
    subgraph PRIV["schéma private (interne)"]
        S["jwt_secret, admin_account,<br/>admin_log"]
    end
    ANON --> V & F1
    ORG --> V & F1 & F2
    ADM --> F3
    API -- "fonctions SECURITY DEFINER" --> PUB
    API --> PRIV
```

- Les rôles n'ont **aucun droit sur les tables** : tout passe par des vues et des fonctions du schéma `api`, qui vérifient l'organisateur (`sub` du jeton) ou l'administrateur à chaque appel.
- Un compte suspendu ou un admin désactivé perd ses droits **immédiatement**, même avec un jeton encore valide.
- L'administration ne lit jamais `presence` ni `support` ligne par ligne : seulement des totaux.

### Modèle de données

```mermaid
erDiagram
    organizer ||--o{ event : "déclare"
    event ||--o{ presence : "J'y suis !"
    event ||--o{ support : "Je soutiens"
    event ||--o{ event_tally : "totaux après purge"
    admin_account ||--o{ admin_log : "agit"

    organizer {
        uuid id
        text name
        text email
        text password_hash "bcrypt"
        timestamptz suspended_at
    }
    event {
        uuid id
        text title
        event_cause cause
        geometry route "LineString"
        geometry zone "calculée"
        smallint segment_count "calculé"
        event_status status "draft, published, cancelled"
        timestamptz hidden_at "modération"
        timestamptz purged_at
    }
    presence {
        uuid event_id
        uuid token "aléatoire, propre à la manif"
        timestamptz time_slot "quart d'heure"
        smallint segment "optionnel"
    }
    support {
        uuid event_id
        uuid token
    }
    event_tally {
        uuid event_id
        text kind
        timestamptz time_slot
        smallint segment
        integer n
    }
    admin_account {
        uuid id
        text email
        text password_hash "bcrypt"
        bytea totp_secret
    }
    admin_log {
        timestamptz at
        text action
        uuid target_id
        text reason
    }
```

`presence` et `support` n'ont volontairement **ni heure exacte, ni `created_at`, ni identifiant d'appareil**. `admin_account` et `admin_log` sont dans le schéma `private`.

## Les parcours

### « J'y suis ! »

La position est lue **une fois** et ne quitte jamais le téléphone. Le serveur ne reçoit que quatre champs.

```mermaid
sequenceDiagram
    autonumber
    actor P as Participant
    participant T as App (téléphone)
    participant A as API
    participant B as Base
    T->>A: GET /events?id=eq.… (parcours + zone GeoJSON)
    A-->>T: zone, tronçons, horaires
    P->>T: appuie sur « J'y suis ! »
    T->>T: lit la position une fois (précision ≤ 50 m)
    T->>T: dans la zone ? dans le créneau ? (calcul local)
    T->>T: jeton de cette manif (tiré au hasard, gardé localement)
    T->>A: POST /rpc/presence {event_id, token, time_slot, segment}
    A->>B: record_presence : manif publiée, créneau, tronçon, doublon ignoré
    B-->>A: compté
    A-->>T: OK (sinon : file d'attente, nouvel essai jusqu'à 24 h après la fin)
```

### Connexion d'un organisateur

```mermaid
sequenceDiagram
    autonumber
    actor O as Collectif
    participant W as Page web
    participant A as PostgREST
    participant B as Base
    O->>W: e-mail + mot de passe
    W->>A: POST /rpc/login (rôle anonyme)
    A->>B: api.login : bcrypt, compte non suspendu
    B->>B: signe un JWT HS256 {role: organizer, sub, exp: 8 h}
    B-->>W: jeton
    W->>A: GET /my_events + Authorization: Bearer jeton
    A->>A: vérifie la signature, SET ROLE organizer
    A->>B: my_events filtré sur le sub du jeton
    B-->>W: ses manifs seulement
```

### Connexion d'un administrateur

Même mécanisme, avec un **code TOTP** (appli d'authentification) calculé et vérifié en SQL ; un code ne sert qu'une fois, le jeton dure une heure. Les comptes admin se créent uniquement en ligne de commande (`public.create_admin`).

```mermaid
sequenceDiagram
    autonumber
    actor X as Admin
    participant W as Page web (#/admin)
    participant B as Base
    X->>W: e-mail + mot de passe + code à 6 chiffres
    W->>B: POST /rpc/admin_login
    B->>B: bcrypt, puis TOTP (pas courant ± 30 s, jamais un code déjà servi)
    B-->>W: JWT {role: foulala_admin, exp: 1 h}
    X->>W: masque une manif (motif obligatoire)
    W->>B: POST /rpc/admin_hide_event
    B->>B: hidden_at, journal (auteur, motif)
    Note over B: retirée de l'app, plus de présence ni de soutien
```

## Cycle de vie d'une manif et de ses données

```mermaid
stateDiagram-v2
    [*] --> Brouillon: create_event
    Brouillon --> Brouillon: update_event
    Brouillon --> [*]: delete_draft
    Brouillon --> Publiée: publish_event
    Publiée --> Annulée: cancel_event
    Publiée --> EnCours: 30 min avant le début
    EnCours --> Terminée: fin
    Terminée --> Purgée: 24 h après la fin (pg_cron)
    Annulée --> Purgée: 24 h après la fin
    Purgée --> [*]

    state "En cours : « J'y suis ! » ouvert" as EnCours
    state "Purgée : jetons supprimés, totaux gardés (event_tally)" as Purgée
```

À tout moment après la publication, l'administration peut **masquer** une manif (retirée de l'app, plus de présence ni de soutien, motif visible du collectif) puis la **rétablir**. Le masquage ne change pas le cycle de purge.

Ce que deviennent les données d'un participant :

| Moment | Sur le téléphone | Sur le serveur |
|---|---|---|
| « J'y suis ! » | position lue une fois, jamais gardée ; jeton de la manif | jeton, quart d'heure, tronçon |
| Pas de réseau | présence en file d'attente | rien |
| 24 h après la fin | file abandonnée | jetons supprimés, remplacés par des totaux |
| Affichage | — | aucun groupe de moins de 20 personnes (tronçon × quart d'heure) |
