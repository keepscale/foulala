import 'dart:convert';

import 'package:http/http.dart' as http;

/// Accès brut à l'API PostgREST (schéma `api`).
///
/// Vie privée : aucune requête ne porte d'identifiant d'appareil, de position ni d'en-tête
/// permettant de reconnaître l'utilisateur. Seuls `presence` et `support` enverront un jeton.
class FoulalaApi {
  FoulalaApi(this._baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final Uri _baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  /// Villes qui ont au moins une manif visible.
  Future<List<String>> getCities() async {
    final rows = await _get('events', {'select': 'city'});
    final cities = rows.map((r) => r['city'] as String).toSet().toList()..sort();
    return cities;
  }

  /// Manifs d'une ville, sans la géométrie (inutile pour la liste).
  Future<List<Map<String, dynamic>>> getEvents(String city) => _get('events', {
        'city': 'eq.$city',
        'select': 'id,title,cause,description,demands,city,starts_at,ends_at,declared,status,'
            'buffer_m,segment_count,organizer',
        'order': 'starts_at',
      });

  /// Compteurs de plusieurs manifs.
  Future<List<Map<String, dynamic>>> getCounts(Iterable<String> eventIds) {
    if (eventIds.isEmpty) return Future.value(const []);
    return _get('event_count', {'event_id': 'in.(${eventIds.join(',')})'});
  }

  Future<List<Map<String, dynamic>>> _get(String path, Map<String, String> query) async {
    final uri = _baseUrl.replace(path: '${_baseUrl.path}/$path', queryParameters: query);
    final response = await _client.get(uri, headers: const {'Accept': 'application/json'}).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode);
    }
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List).cast<Map<String, dynamic>>();
  }
}

class ApiException implements Exception {
  const ApiException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode)';
}
