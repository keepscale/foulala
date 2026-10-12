# Page organisateur

Site statique (hébergement gratuit : GitHub Pages, Netlify ou Cloudflare Pages) qui appelle l'API PostgREST.

## Fonctions prévues

1. Connexion de l'organisateur (JWT, rôle `organizer`, à créer dans `db/api.sql`)
2. Création d'une manif : cause, titre, ville, date, horaires, description, revendications, case « déclarée en mairie ou en préfecture »
3. Tracé du parcours sur une carte OpenStreetMap (MapLibre GL ou Leaflet), réglage de la largeur de la zone (20 à 500 m)
4. Publication, annulation, suivi du compteur

Rappel légal à afficher : en France, une manifestation se déclare en mairie ou en préfecture 3 à 15 jours francs avant la date. Foulala ne fait pas la déclaration à la place de l'organisateur.

Le choix du framework est encore ouvert.
