# Idées pour plus tard

Pistes validées sur le principe mais **pas prévues pour l'instant**. Les étapes en cours sont dans la feuille de route de [`CLAUDE.md`](../CLAUDE.md). Chaque idée doit respecter les invariants de vie privée, comme le reste du code.

## Fond de carte hors ligne, par ville

**Problème.** L'app dessine aujourd'hui le parcours sur un schéma (`RouteSketch`), sans fond de carte. Les tuiles de `tile.openstreetmap.org` feraient voir à un tiers l'adresse IP du participant et la zone affichée, donc la manif qu'il consulte (voir `app/README.md`, « Vie privée : points à traiter »).

**Idée.** Un « pack ville » en tuiles vectorielles : un fichier [PMTiles](https://docs.protomaps.com/pmtiles/) par agglomération, découpé dans OpenStreetMap avec les outils de Protomaps.

- Le téléphone le télécharge **une fois**, quand on choisit sa ville, depuis notre serveur (Caddy, sans journal). Le serveur n'apprend rien de plus qu'avec `GET /events?city=eq.…`.
- Ensuite, la carte s'affiche **sans aucune requête**, y compris quand le réseau sature pendant la manif.
- Pour les tests, un pack embarqué dans l'APK suffit.

**Pistes écartées.** Une image par ville ou des tuiles raster (PNG) : trop lourdes. Paris intra-muros au niveau des rues pèse de l'ordre de 100 Mo en PNG.

**Points d'attention.**

- Flutter : `flutter_map` est déjà là ; ajouter la lecture des tuiles vectorielles (`vector_map_tiles` et PMTiles). Le style et les polices des étiquettes sont embarqués eux aussi, sinon on retombe sur un téléchargement.
- Licence ODbL : afficher « © les contributeurs d'OpenStreetMap ».
- Régénérer les packs tous les quelques mois.
- Garder `RouteSketch` en secours, tant que le pack n'est pas téléchargé.

**Premier pas.** Générer le pack de Lyon, mesurer sa taille (estimée à quelques dizaines de Mo, à vérifier) et afficher un parcours par-dessus.

## Inscription des collectifs

Les comptes organisateurs sont aujourd'hui créés sur invitation (voir [`decisions.md`](decisions.md)). Ouvrir l'inscription demandera une façon de vérifier les collectifs, pour éviter les fausses manifs.
