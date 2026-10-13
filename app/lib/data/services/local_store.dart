import 'package:shared_preferences/shared_preferences.dart';

/// Stockage local, qui ne quitte jamais le téléphone.
///
/// Vie privée : la sauvegarde Android est coupée (allowBackup="false"), mais sur iOS
/// ces données partent dans la sauvegarde iCloud. À régler avant la première vraie manif :
/// voir « Vie privée : points à traiter » dans app/README.md.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _cityKey = 'city';
  static const _pendingKey = 'pending_presences';
  static const _supportsKey = 'supports';
  static String _tokenKey(String eventId) => 'token.$eventId';
  static String _supportTokenKey(String eventId) => 'support_token.$eventId';

  Future<String?> getCity() => _prefs.getString(_cityKey);

  Future<void> setCity(String city) => _prefs.setString(_cityKey, city);

  Future<String?> getToken(String eventId) => _prefs.getString(_tokenKey(eventId));

  Future<void> setToken(String eventId, String token) => _prefs.setString(_tokenKey(eventId), token);

  /// File d'envoi hors ligne, une entrée JSON par présence.
  Future<List<String>> getPending() async => await _prefs.getStringList(_pendingKey) ?? const [];

  Future<void> setPending(List<String> entries) =>
      entries.isEmpty ? _prefs.remove(_pendingKey) : _prefs.setStringList(_pendingKey, entries);

  /// Jeton du « Je soutiens », distinct de celui du « J'y suis ! » pour la même manif.
  Future<String?> getSupportToken(String eventId) => _prefs.getString(_supportTokenKey(eventId));

  Future<void> setSupportToken(String eventId, String token) => _prefs.setString(_supportTokenKey(eventId), token);

  /// Manifs soutenues, une entrée JSON par manif.
  Future<List<String>> getSupports() async => await _prefs.getStringList(_supportsKey) ?? const [];

  Future<void> setSupports(List<String> entries) => _prefs.setStringList(_supportsKey, entries);
}
