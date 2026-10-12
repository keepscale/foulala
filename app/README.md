# App mobile (Flutter)

À initialiser :

```bash
cd app
flutter create --org org.foulala --project-name foulala --platforms android,ios .
```

## Paquets prévus

- `flutter_map` : carte OpenStreetMap
- `geolocator` : lecture **ponctuelle** de la position (jamais en continu, jamais en arrière-plan)
- `uuid` : jetons v4
- un stockage local (par exemple `shared_preferences`) pour les jetons et la file d'envoi hors ligne

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
