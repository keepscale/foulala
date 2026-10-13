# App mobile (Flutter)

## Lancer

```bash
# Serveur de dev (base + API + données de test), depuis la racine du dépôt
cd server && docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d db api

# App sur l'émulateur Android (l'API de dev est vue en http://10.0.2.2:3000)
cd app && flutter run
# Autre serveur : flutter run --dart-define=API_URL=https://api.exemple.fr

flutter test      # tests
flutter analyze   # analyse statique
```

Le HTTP en clair n'est autorisé qu'en debug, et seulement vers `10.0.2.2` et `localhost` (`android/app/src/debug/res/xml/network_security_config.xml`).

## Architecture

Architecture officielle de Flutter (MVVM), voir `docs/decisions.md` :

```
lib/
  config.dart                 adresse de l'API (--dart-define=API_URL)
  domain/models/              Event, EventCount, EventStats, Cause : Dart pur, sans Flutter ni JSON
  domain/repositories/        interfaces : EventRepository, CityRepository, PresenceRepository, SupportRepository
  data/services/              FoulalaApi (HTTP), LocalStore (stockage local)
  data/mappers/               JSON de l'API → modèles du domaine
  data/repositories/          implémentations : EventRepositoryRemote, CityRepositoryLocal, …Remote
  ui/core/themes/             thème, tokens.g.dart (généré)
  ui/core/ui/                 icônes, logo, décors par cause
  ui/<écran>/view_models/     un ChangeNotifier par écran
  ui/<écran>/widgets/         les vues
```

Le domaine définit les contrats des dépôts, la couche `data` les implémente, et `main.dart` les injecte avec `provider`. Les ViewModels ne connaissent que les interfaces : un test peut leur passer un faux dépôt.

La logique sensible vit dans `domain/`, sous forme d'objets valeur qui portent leurs invariants : une valeur invalide ne peut pas exister, donc pas être envoyée.

- `TimeSlot` : toujours un multiple de 15 min depuis l'epoch, en UTC.
- `PresenceToken` : UUID v4 aléatoire, un par manif ; `toString()` n'affiche jamais le jeton complet.
- `Segment` : 0 ≤ index < nombre de tronçons.
- `Zone` et `EventRoute` : test « suis-je dedans ? », distance au bord, position le long du parcours, calculés sur le téléphone.
- `PresenceReport` : le seul message qui part au « J'y suis ! » (manif, jeton, créneau, tronçon).
- `checkPresence()` : créneau, précision ≤ 50 m, zone, dans cet ordre.

## Thème et polices

- `lib/domain/models/cause.g.dart` et `lib/ui/core/themes/tokens.g.dart` sont **générés** depuis `design/tokens.json` : `dart run tool/gen_tokens.dart`. Un test échoue s'ils ne sont plus à jour.
- Polices embarquées dans `assets/fonts/` (licence OFL), jamais téléchargées. Bricolage Grotesque et Figtree sont variables : utiliser `FoulalaText.display()` et `FoulalaText.body()`, qui règlent la graisse avec `FontVariation`.
- Textes de l'interface au vouvoiement, comme dans les maquettes.

## Paquets

- `flutter_map`, `latlong2` : carte OpenStreetMap
- `geolocator` : lecture **ponctuelle** de la position (jamais en continu, jamais en arrière-plan)
- `shared_preferences` : ville choisie, jetons par manif (présence et soutien), file d'envoi hors ligne, liste « Mes soutiens »

Les jetons UUID v4 sont tirés par `PresenceToken.generate()` avec `Random.secure()` de Dart, sans paquet : une dépendance de moins sur le code le plus sensible.
- `provider`, `http`, `flutter_svg` : injection, appels à l'API, icônes des maquettes

## Interdits

Aucun SDK d'analytics, de publicité ou de crash reporting qui envoie des données à un tiers. Voir les invariants de vie privée dans `CLAUDE.md`.

## Vie privée : points à traiter

Relevés lors de l'ajout des paquets. Ils sont à régler avant la première vraie manif.

- [ ] **Sauvegarde iCloud.** Sur iOS, `shared_preferences` (NSUserDefaults) part dans la sauvegarde iCloud : les jetons par manif, la file d'envoi et la liste des manifs soutenues y sont maintenant stockés. Les ranger dans un fichier exclu de la sauvegarde (`isExcludedFromBackup`) ou dans le trousseau avec `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. **Bloquant avant toute diffusion iOS.**
- [ ] **Tuiles de carte**, si on ajoute un vrai fond de carte. Pour l'instant le parcours est un schéma dessiné sur le téléphone (`RouteSketch`), sans aucune tuile. Avec `flutter_map`, `tile.openstreetmap.org` verrait l'adresse IP et la zone affichée, donc quelle manif on consulte : servir les tuiles derrière notre Caddy sans journal, ou choisir un fournisseur qui ne journalise pas. `flutter_map` envoie aussi un `User-Agent` qui contient le nom du paquet de l'app.
- [x] **Position sur Android.** `GeolocatorLocationReader` appelle `getCurrentPosition` avec `AndroidSettings(forceLocationManager: true)` : GPS seul, sans le service de localisation de Google Play. La bibliothèque Play Services reste incluse dans l'app.

Déjà fait : la sauvegarde automatique Android est coupée (`allowBackup="false"` dans `AndroidManifest.xml`), la localisation en arrière-plan n'est pas demandée, et la position n'est lue qu'une fois par appui sur « J'y suis ! ».

## Écrans (voir les maquettes)

1. ✅ Liste des manifs par ville, avec filtres par cause
2. ✅ Détail : schéma du parcours et de la zone, revendications, boutons « Je soutiens » et « J'y suis ! »
3. ✅ « J'y suis ! » : envoyée, en attente de réseau, hors de la zone, position imprécise ou refusée
4. ✅ Compteur : total, arrivées par quart d'heure, densité par tronçon. En direct, relu chaque minute
5. ✅ Mes soutiens : liste gardée sur le téléphone

### « Je soutiens »

- Jeton à part, différent de celui du « J'y suis ! » pour la même manif : le serveur ne peut pas relier un soutien à une présence. Il est gardé avant l'envoi, pour qu'un nouvel essai ne compte pas deux fois.
- Seuls `event_id` et `token` partent. Sans réseau, rien n'est mis en file : l'utilisateur réessaie.
- Un soutien ne se retire pas : il est anonyme.
- « Mes soutiens » affiche une copie locale de chaque manif, sans chiffres : lire les compteurs demanderait d'envoyer au serveur la liste des manifs soutenues.

### Compteur

- Toute barre d'arrivées sous 20 est hachurée, comme les cases de densité. La vue `event_density` applique déjà le seuil côté serveur, et l'app le réapplique. `event_timeline` ne l'applique pas encore : à corriger côté SQL.

Pour tester « J'y suis ! » sur l'émulateur : `adb emu geo fix 4.8320 45.7578` (Bellecour, sur le parcours de la marche en cours de `db/seed.sql`), ou le menu **⋯ › Location** de l'émulateur.

Thèmes par cause : générés depuis `design/tokens.json`.
