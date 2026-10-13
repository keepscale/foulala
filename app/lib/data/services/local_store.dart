import 'private_file.dart';

/// Stockage local, qui ne quitte jamais le téléphone : ni serveur, ni sauvegarde (voir [PrivateFile]).
class LocalStore {
  LocalStore(this._file);

  final PrivateFile _file;

  /// Lu une fois, puis gardé en mémoire ; chaque changement réécrit le fichier.
  late final Future<Map<String, Object?>> _values = _file.read();

  /// Les écritures passent l'une après l'autre.
  Future<void> _writing = Future.value();

  static const _cityKey = 'city';
  static const _pendingKey = 'pending_presences';
  static const _supportsKey = 'supports';
  static String _tokenKey(String eventId) => 'token.$eventId';
  static String _supportTokenKey(String eventId) => 'support_token.$eventId';

  Future<String?> getCity() => _string(_cityKey);

  Future<void> setCity(String city) => _set(_cityKey, city);

  Future<String?> getToken(String eventId) => _string(_tokenKey(eventId));

  Future<void> setToken(String eventId, String token) => _set(_tokenKey(eventId), token);

  /// File d'envoi hors ligne, une entrée JSON par présence.
  Future<List<String>> getPending() => _list(_pendingKey);

  Future<void> setPending(List<String> entries) => _set(_pendingKey, entries.isEmpty ? null : List.of(entries));

  /// Jeton du « Je soutiens », distinct de celui du « J'y suis ! » pour la même manif.
  Future<String?> getSupportToken(String eventId) => _string(_supportTokenKey(eventId));

  Future<void> setSupportToken(String eventId, String token) => _set(_supportTokenKey(eventId), token);

  /// Manifs soutenues, une entrée JSON par manif.
  Future<List<String>> getSupports() => _list(_supportsKey);

  Future<void> setSupports(List<String> entries) => _set(_supportsKey, List.of(entries));

  Future<String?> _string(String key) async {
    final v = (await _values)[key];
    return v is String ? v : null;
  }

  Future<List<String>> _list(String key) async {
    final v = (await _values)[key];
    return v is List ? v.whereType<String>().toList() : const [];
  }

  Future<void> _set(String key, Object? value) async {
    final values = await _values;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
    return _writing = _writing.then((_) => _file.write(values), onError: (_) => _file.write(values));
  }
}
