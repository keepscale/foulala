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

## Écrans (voir les maquettes)

1. Liste des manifs par ville, avec filtres par cause
2. Détail : carte, zone, revendications, boutons « Je soutiens » et « J'y suis ! »
3. Confirmation : envoyée, en attente de réseau, ou hors de la zone
4. Compteur en direct : total, arrivées par quart d'heure, densité par tronçon

Thèmes par cause : générés depuis `design/tokens.json`.
