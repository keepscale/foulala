# Supabase (tests uniquement)

> **La passerelle de Supabase journalise les adresses IP.** Une IP reliée à une présence dans une manif, c'est exactement ce que Foulala doit rendre impossible. Ce projet Supabase sert aux **tests entre amis**, jamais pour une vraie manif. Pour la production : `server/` sur un VPS européen (voir `docs/decisions.md`).

## Mettre en place

1. **Générer le script** depuis la racine du dépôt :

   ```bash
   ./scripts/supabase-bundle.sh
   ```

   Il assemble `db/schema.sql`, `db/api.sql`, la purge horaire, `supabase/adapter.sql` et `db/seed.sql` dans `supabase/build/setup.sql` (ignoré par git).

2. **Supabase › SQL Editor** : coller tout `supabase/build/setup.sql` dans une base **vide**, puis *Run*. Le script finit par la notice « Supabase : droits vérifiés, seul le schéma api est accessible. ». S'il s'arrête sur une erreur de droits, **ne pas aller plus loin**. Si pg_cron est refusé, l'activer dans *Database › Extensions* et relancer.

3. **Project Settings › Data API › Exposed schemas** : ajouter `api`. Retirer `public` et `graphql_public` si possible. Les droits sont déjà fermés, mais autant ne rien exposer d'autre.

4. **Project Settings › API Keys** : noter l'URL du projet et la clé publique (`sb_publishable_…`, ou l'ancienne clé `anon`). Ne jamais utiliser la clé `secret` / `service_role` dans l'app.

5. **Vérifier** (remplacer l'URL et la clé) :

   ```bash
   curl "https://VOTRE-PROJET.supabase.co/rest/v1/events?select=title,city" \
     -H "apikey: VOTRE-CLÉ" -H "Accept-Profile: api"
   # → 7 manifs fictives

   curl "https://VOTRE-PROJET.supabase.co/rest/v1/organizer?select=email" \
     -H "apikey: VOTRE-CLÉ" -H "Accept-Profile: public"
   # → doit être refusé (erreur 4xx), jamais une liste d'e-mails
   ```

## Lancer l'app sur Supabase

```bash
cd app
cp config/supabase.example.json config/supabase.json   # puis remplir l'URL et la clé
flutter run --dart-define-from-file=config/supabase.json
```

`config/supabase.json` est ignoré par git. La clé publique est la même pour tous les téléphones : elle n'identifie personne, mais inutile d'ouvrir la base de test à tout le monde.

## Recharger les données de test

Les dates du seed partent de l'heure du chargement : les deux marches « en cours » durent 3 h. Pour en avoir de nouvelles, coller `supabase/build/reseed.sql` dans le SQL Editor (après `./scripts/supabase-bundle.sh`).

## Ce que fait `adapter.sql`

Supabase donne par défaut aux rôles `anon` et `authenticated` **tous les droits** sur ce qui est créé dans `public`. Sans l'adaptateur, la clé publique suffirait à lire les e-mails des organisateurs et les jetons, ou à appeler `purge_event` (vérifié sur une base qui imite ces droits par défaut). L'adaptateur :

- révoque tout sur `public` pour `anon` et `authenticated`, y compris pour les objets créés plus tard ;
- active RLS sans politique sur toutes les tables, au cas où un droit reviendrait par erreur ;
- donne à `anon` exactement les droits de `web_anon` : lecture des vues `api.*`, appel de `api.presence` et `api.support` ;
- vérifie le résultat et s'arrête si quelque chose reste exposé.

Le *Security Advisor* de Supabase signalera PostGIS installé dans `public` : c'est voulu, pour rester identique à `server/`.

## Espace organisateur

`db/organizer.sql` (connexion des organisateurs, création de manifs) et `db/admin.sql` (administration) ne sont **pas** inclus dans le script Supabase : il signe ses propres jetons, alors que Supabase gère les siens. Pour tester la page organisateur, utiliser le serveur de dev local (`server/docker-compose.dev.yml`).
