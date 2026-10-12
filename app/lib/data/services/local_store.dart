import 'package:shared_preferences/shared_preferences.dart';

/// Stockage local, qui ne quitte jamais le téléphone.
///
/// Vie privée : sur iOS, ces données partent dans la sauvegarde iCloud.
/// Avant d'y ranger des jetons, voir « Vie privée : points à traiter » dans app/README.md.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _cityKey = 'city';

  Future<String?> getCity() => _prefs.getString(_cityKey);

  Future<void> setCity(String city) => _prefs.setString(_cityKey, city);
}
