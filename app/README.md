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
  domain/models/              Event, EventCount, Cause : Dart pur, sans Flutter ni JSON
  domain/repositories/        interfaces : EventRepository, CityRepository
  data/services/              FoulalaApi (HTTP), LocalStore (stockage local)
  data/mappers/               JSON de l'API → modèles du domaine
  data/repositories/          implémentations : EventRepositoryRemote, CityRepositoryLocal
  ui/core/themes/             thème, tokens.g.dart (généré)
  ui/core/ui/                 icônes, logo, décors par cause
  ui/<écran>/view_models/     un ChangeNotifier par écran
  ui/<écran>/widgets/         les vues
```

Le domaine définit les contrats des dépôts, la couche `data` les implémente, et `main.dart` les injecte avec `provider`. Les ViewModels ne connaissent que les interfaces : un test peut leur passer un faux dépôt.

La logique sensible ira dans `domain/` sous forme d'objets valeur qui portent leurs invariants (`TimeSlot` multiple de 15 min, `PresenceToken` propre à une manif, `Segment`, `Zone`) : une valeur invalide ne doit pas pouvoir exister, donc pas pouvoir être envoyée.

## Thème et polices

- `lib/domain/models/cause.g.dart` et `lib/ui/core/themes/tokens.g.dart` sont **générés** depuis `design/tokens.json` : `dart run tool/gen_tokens.dart`. Un test échoue s'ils ne sont plus à jour.
- Polices embarquées dans `assets/fonts/` (licence OFL), jamais téléchargées. Bricolage Grotesque et Figtree sont variables : utiliser `FoulalaText.display()` et `FoulalaText.body()`, qui règlent la graisse avec `FontVariation`.
- Textes de l'interface au vouvoiement, comme dans les maquettes.

## Paquets

- `flutter_map`, `latlong2` : carte OpenStreetMap
- `geolocator` : lecture **ponctuelle** de la position (jamais en continu, jamais en arrière-plan)
- `uuid` : jetons v4 (générateur cryptographique par défaut)
- `shared_preferences` : ville choisie, puis jetons et file d'envoi hors ligne
- `provider`, `http`, `flutter_svg` : injection, appels à l'API, icônes des maquettes

## Interdits

Aucun SDK d'analytics, de publicité ou de crash reporting qui envoie des données à un tiers. Voir les invariants de vie privée dans `CLAUDE.md`.

## Vie privée : points à traiter

Relevés lors de l'ajout des paquets. Ils sont à régler avant la première vraie manif.

- [ ] **Tuiles de carte.** `tile.openstreetmap.org` voit l'adresse IP et la zone affichée, donc quelle manif on consulte. Il faut servir les tuiles derrière notre Caddy sans journal, ou choisir un fournisseur qui ne journalise pas. `flutter_map` envoie aussi un `User-Agent` qui contient le nom du paquet de l'app.
- [ ] **Position sur Android.** Par défaut, `geolocator` passe par le service de localisation de Google Play, qui peut envoyer à Google les Wi-Fi et antennes alentour. Appeler `getCurrentPosition` avec `AndroidSettings(forceLocationManager: true)` pour n'utiliser que le GPS. La bibliothèque Play Services reste incluse dans l'app.
- [ ] **Sauvegarde iCloud.** Sur iOS, `shared_preferences` (NSUserDefaults) part dans la sauvegarde iCloud. Ranger les jetons dans un fichier exclu de la sauvegarde (`isExcludedFromBackup`) ou dans le trousseau avec `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

Déjà fait : la sauvegarde automatique Android est coupée (`allowBackup="false"` dans `AndroidManifest.xml`), et la localisation en arrière-plan n'est pas demandée.

## Écrans (voir les maquettes)

1. Liste des manifs par ville, avec filtres par cause
2. Détail : carte, zone, revendications, boutons « Je soutiens » et « J'y suis ! »
3. Confirmation : envoyée, en attente de réseau, ou hors de la zone
4. Compteur en direct : total, arrivées par quart d'heure, densité par tronçon

Thèmes par cause : générés depuis `design/tokens.json`.
