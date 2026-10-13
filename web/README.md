# Page organisateur

Site statique (Vite + TypeScript, sans framework, Leaflet pour la carte) qui appelle directement l'API PostgREST. Publié sur GitHub Pages par `.github/workflows/web.yml`.

## Lancer en local

```bash
# 1. Serveur de dev (base + API + données de test), depuis server/
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d db api

# 2. Page organisateur
cd web
npm install
npm run dev          # http://localhost:5173, API sur http://localhost:3000
```

Compte de dev (créé par `db/seed.sql`) : `lyon@example.org` / `foulala-dev-2026`.

Autre API : copier `.env.example` en `.env.local` et changer `VITE_API_URL`.

Sur la base de test Supabase : `VITE_API_URL=https://VOTRE-PROJET.supabase.co/rest/v1` et `VITE_API_KEY=sb_publishable_…`. La page envoie alors la clé publique et le schéma `api`, et affiche un bandeau « Version de test ». Mise en place : `supabase/README.md`.

```bash
npm run typecheck    # vérification des types
npm run build        # construit dist/ (vérifie aussi les types)
```

## Écrans

### Espace organisateur

1. **Connexion** : e-mail et mot de passe. Les comptes sont créés sur invitation, depuis l'administration (ou `public.create_organizer` en SQL).
2. **Mes manifestations** : brouillons, publiées, annulées, terminées, avec le comptage. Actions : modifier, publier, supprimer un brouillon, annuler une manif publiée. Une manif masquée par la modération l'indique, avec le motif.
3. **Création et modification** : cause, informations, revendications, déclaration, tracé du parcours sur la carte, largeur de la zone. Une manif publiée ne se modifie plus : son parcours et ses horaires fondent le comptage.
4. **Mot de passe** (`#/mot-de-passe`) : remplacer le mot de passe provisoire reçu à l'invitation.

### Administration (`#/admin`)

Bandeau sombre, session séparée de celle des organisateurs, jeton d'une heure.

1. **Connexion** : e-mail, mot de passe et code à 6 chiffres d'une appli d'authentification (TOTP).
2. **Pilotage** : chiffres clés, manifs par état, par cause et par ville, santé du système (purges en retard, dernière purge automatique, jetons en base, taille de la base).
3. **Manifestations** : toutes les manifs publiées ou annulées, recherche et filtres. **Masquer** (motif obligatoire) retire la manif de l'app et bloque les nouveaux « J'y suis ! » et soutiens ; **Rétablir** l'annule.
4. **Collectifs** : inviter un collectif (mot de passe provisoire montré une fois), créer un nouveau mot de passe, suspendre (motif obligatoire) ou réactiver.
5. **Journal** : les 200 dernières actions, avec leur auteur et leur motif.

L'administration ne voit jamais un jeton, une présence ou un soutien isolé : seulement des comptes, des manifs et des totaux.

#### Créer un compte administrateur

Uniquement sur le serveur, jamais depuis la page. Dans un `psql` interactif (pour que la phrase de passe ne reste pas dans l'historique du shell) :

```bash
cd server && docker compose exec db psql -U foulala -d foulala
```
```sql
\prompt 'Phrase de passe (16 caractères au moins) : ' pwd
SELECT public.create_admin('Prénom', 'moi@example.org', :'pwd');
```

La fonction renvoie une adresse `otpauth://…`, affichée une seule fois. Dans l'appli d'authentification (Aegis, FreeOTP, Google Authenticator…), choisir « saisir une clé » et recopier la valeur de `secret=`, ou transformer l'adresse en QR code **hors ligne** (jamais avec un site web). Pour retirer un accès : `UPDATE private.admin_account SET disabled_at = now() WHERE email = '…';`, effet immédiat.

## Organisation

```
src/
  main.ts            routes (#/connexion, #/, #/nouvelle, #/manif/<id>, #/mot-de-passe, #/admin/…)
  api.ts             client PostgREST, sessions organisateur et admin séparées, dans sessionStorage
  theme.ts           thèmes par cause, lus dans design/tokens.json
  route-editor.ts    carte Leaflet : tracé, déplacement des points, aperçu de la zone
  layout.ts, dom.ts  en-tête, logo, formatage, construction du DOM sans innerHTML
  admin-layout.ts    en-tête et onglets de l'administration, formulaire de motif, mot de passe provisoire
  views/             login, list, edit, password
  views/admin/       login, overview (pilotage), events (modération), organizers (collectifs), journal
```

Les couleurs viennent de `design/tokens.json`, le logo de `design/logo.svg`, les polices de `app/assets/fonts/` : rien n'est dupliqué.

## Vie privée et sécurité

- Seuls les organisateurs visitent cette page. Les participants n'y passent jamais : l'app parle uniquement au serveur Foulala.
- Le jeton de connexion vit dans `sessionStorage` (il disparaît à la fermeture de l'onglet) et expire après 8 h côté serveur.
- Aucune donnée n'est insérée avec `innerHTML` : tout texte passe par des nœuds texte (`dom.ts`).
- Services tiers, côté organisateur uniquement : tuiles `tile.openstreetmap.org` pour la carte, et `nominatim.openstreetmap.org` quand on clique sur « Centrer la carte » (seul le nom de la ville part). GitHub voit l'adresse IP des visiteurs de la page.
- L'API n'accepte les appels de navigateur que depuis l'adresse déclarée dans `WEB_ORIGIN` (CORS).

## Publier sur GitHub Pages

1. **Le dépôt doit être public** : GitHub Pages est gratuit pour les dépôts publics seulement (sinon : compte GitHub payant, ou Netlify / Cloudflare Pages).
2. Settings › Pages › Source : **GitHub Actions**.
3. Settings › Secrets and variables › Actions › onglet Variables : `API_URL` = adresse publique de l'API.
4. Sur le serveur, dans `server/.env` : `WEB_ORIGIN=https://keepscale.github.io` (ou le domaine personnalisé), puis `docker compose up -d api`.

Le site utilise des chemins relatifs et des routes en `#/` : il fonctionne aussi bien sous `keepscale.github.io/foulala/` que sur un domaine personnalisé.
