/// Adresse de l'API PostgREST.
///
/// Par défaut, le serveur de dev (server/docker-compose.dev.yml) vu depuis l'émulateur Android.
/// Autre serveur : flutter run --dart-define=API_URL=https://api.exemple.fr
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');
