---
name: changement-db
description: Marche à suivre pour modifier le schéma SQL, les fonctions ou l'API PostgREST de Foulala (db/schema.sql, db/api.sql), avec les tests associés.
---

# Changer la base de données

La base est la source de vérité : la logique métier et les validations vivent en SQL, et PostgREST expose le schéma `api`.

## Étapes

1. **Modifier le bon fichier**
   - Tables, fonctions métier, vues internes : `db/schema.sql` (schéma `public`).
   - Ce que l'app peut lire ou appeler : `db/api.sql` (schéma `api`). Une vue ou une fonction par besoin, puis `GRANT` explicite à `web_anon`.
   - Les fonctions d'écriture exposées sont des wrappers `SECURITY DEFINER` avec `SET search_path = public, pg_temp`.
2. **Ne jamais exposer une table de `public` directement**, ni donner à `web_anon` un droit sur `public`.
3. **Écrire un test** dans `db/tests/NN_sujet.sql` :
   - `\set ON_ERROR_STOP on`, `BEGIN;` … `ROLLBACK;`
   - assertions avec `ASSERT condition, 'message'` dans un bloc `DO $$ … $$` ;
   - pour un cas qui doit échouer : `BEGIN … failed := false; EXCEPTION WHEN OTHERS THEN failed := true; END;` puis `ASSERT failed`.
   - Tester les droits avec `SET LOCAL ROLE web_anon` (voir `02_api.sql`).
4. **Lancer** `./scripts/db-test.sh` (PostgreSQL 14+ avec PostGIS) et vérifier que tout passe.
5. Si le changement touche aux données des participants, appliquer le skill `revue-vie-privee`.
6. Mettre à jour la section « Modèle de données » de `CLAUDE.md` si la structure change.

## Rappels

- `presence.time_slot` est toujours un multiple de 15 minutes (contrainte `CHECK`).
- Le seuil d'affichage de 20 personnes s'applique à toute nouvelle vue agrégée.
- Toute nouvelle table contenant des jetons doit être vidée par `purge_event`.
- Tant que rien n'est en production : on modifie `schema.sql` directement. Ensuite, migrations numérotées dans `db/migrations/`.
