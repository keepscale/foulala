/// Adresse de l'API PostgREST.
///
/// Par défaut, le serveur de dev (server/docker-compose.dev.yml) vu depuis l'émulateur Android.
/// Autre serveur : flutter run --dart-define=API_URL=https://api.exemple.fr
/// Supabase (tests) : flutter run --dart-define-from-file=config/supabase.json (voir supabase/README.md)
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

/// Clé publique de l'API, seulement pour Supabase (vide pour notre serveur).
/// La même pour tous les téléphones : elle n'identifie personne.
const apiKey = String.fromEnvironment('API_KEY');
