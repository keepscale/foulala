import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

/// Accès brut à l'API PostgREST (schéma `api`).
///
/// Vie privée : aucune requête ne porte d'identifiant d'appareil, de position ni d'en-tête
/// permettant de reconnaître l'utilisateur. Seul `POST /rpc/presence` envoie un jeton.
class FoulalaApi {
  FoulalaApi(this._baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final Uri _baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  static const _listColumns = 'id,title,cause,description,demands,city,starts_at,ends_at,declared,status,'
      'buffer_m,segment_count,organizer';

  /// Villes qui ont au moins une manif visible.
  Future<List<String>> getCities() async {
    final rows = await _getRows('events', {'select': 'city'});
    final cities = rows.map((r) => r['city'] as String).toSet().toList()..sort();
    return cities;
  }

  /// Manifs d'une ville, sans la géométrie (inutile pour la liste).
  Future<List<Map<String, dynamic>>> getEvents(String city) =>
      _getRows('events', {'city': 'eq.$city', 'select': _listColumns, 'order': 'starts_at'});

  /// Une manif avec son parcours et sa zone (GeoJSON).
  Future<Map<String, dynamic>> getEvent(String id) async {
    final rows = await _getRows('events', {'id': 'eq.$id', 'select': '$_listColumns,route,zone'});
    if (rows.isEmpty) throw const ApiException(404);
    return rows.single;
  }

  /// Compteurs de plusieurs manifs.
  Future<List<Map<String, dynamic>>> getCounts(Iterable<String> eventIds) {
    if (eventIds.isEmpty) return Future.value(const []);
    return _getRows('event_count', {'event_id': 'in.(${eventIds.join(',')})'});
  }

  /// `POST /rpc/presence`. Renvoie true si le jeton est nouveau, false s'il était déjà compté.
  Future<bool> postPresence(Map<String, Object?> body) async =>
      jsonDecode(await _send(() => _client.post(_uri('rpc/presence'),
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(body)))) as bool;

  Future<List<Map<String, dynamic>>> _getRows(String path, Map<String, String> query) async =>
      (jsonDecode(await _send(() => _client.get(_uri(path, query), headers: const {'Accept': 'application/json'})))
              as List)
          .cast<Map<String, dynamic>>();

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUrl.replace(path: '${_baseUrl.path}/$path', queryParameters: query);

  /// Exécute la requête. Réseau absent, délai dépassé ou serveur saturé (5xx) : [NetworkUnavailable].
  /// Refus du serveur (4xx) : [ApiException].
  Future<String> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const NetworkUnavailable();
    } on SocketException {
      throw const NetworkUnavailable();
    } on http.ClientException {
      throw const NetworkUnavailable();
    }
    if (response.statusCode >= 500) throw const NetworkUnavailable();
    if (response.statusCode >= 300) throw ApiException(response.statusCode);
    return utf8.decode(response.bodyBytes);
  }
}

/// Le serveur a refusé la requête : inutile de réessayer.
class ApiException implements Exception {
  const ApiException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode)';
}

/// Réseau absent ou saturé : on pourra réessayer plus tard.
class NetworkUnavailable implements Exception {
  const NetworkUnavailable();
}
