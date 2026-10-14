# Foulala

**Compter les manifestants, sans ficher personne.**

Foulala permet aux organisateurs de déclarer une manifestation (cause, parcours, horaires, revendications) et aux participants de dire « J'y suis ! ». L'app affiche alors un chiffre plancher vérifiable : *au moins X présents*.

> Télécharge Foulala et appuie sur J'y suis.

## Comment ça protège les participants

- Ta position GPS **ne quitte jamais ton téléphone** : c'est lui qui vérifie que tu es bien dans le cortège.
- Il envoie seulement un **jeton aléatoire**, différent à chaque manif, avec le quart d'heure et le tronçon du parcours.
- **Pas de compte, pas d'adresse IP enregistrée**, pas de pub, pas de pistage.
- 24 h après la manif, les jetons sont **supprimés** : seuls les totaux restent.

Le détail est dans [docs/vie-privee.md](docs/vie-privee.md) et [docs/methode-comptage.md](docs/methode-comptage.md).

## Le dépôt

| Dossier | Contenu |
|---|---|
| [`db/`](db) | Schéma PostgreSQL + PostGIS, API, tests |
| [`server/`](server) | Déploiement : PostgreSQL, PostgREST, Caddy (docker compose) |
| [`supabase/`](supabase) | Base de test sur Supabase (tests uniquement : journal des adresses IP) |
| [`app/`](app) | App mobile Flutter des participants, [APK de test](https://github.com/keepscale/foulala/releases) |
| [`web/`](web) | Page organisateur et administration, [version de test](https://foulala.keepscale.fr/) |
| [`design/`](design) | Couleurs par cause, typographie |
| [`docs/`](docs) | [Architecture](docs/architecture.md) (test et production, diagrammes), méthode, vie privée, décisions, [idées pour plus tard](docs/idees.md) |

## Démarrer

```bash
# Tests de la base (PostgreSQL 14+ avec PostGIS)
PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres ./scripts/db-test.sh

# Serveur complet
cd server
cp .env.example .env   # puis remplir
docker compose up -d
```

## État

Projet en cours de construction, pas encore utilisable en manif réelle.
