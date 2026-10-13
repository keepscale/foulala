import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

/// Accès brut à l'API PostgREST (schéma `api`).
///
/// Vie privée : aucune requête ne porte d'identifiant d'appareil, de position ni d'en-tête
/// permettant de reconnaître l'utilisateur. Seuls `POST /rpc/presence` et `POST /rpc/support`
/// envoient un jeton. Aucune lecture ne porte la liste des manifs soutenues.
class FoulalaApi {
  FoulalaApi(Uri baseUrl, {http.Client? client, String apiKey = ''})
      // « …/rest/v1/ » et « …/rest/v1 » : même adresse, sans double barre oblique.
      : _baseUrl = baseUrl.replace(path: baseUrl.path.replaceFirst(RegExp(r'/+$'), '')),
        _client = client ?? http.Client(),
        _commonHeaders = {
          // Le schéma `api`, même si le serveur en expose d'autres (Supabase).
          'Accept-Profile': 'api',
          'Content-Profile': 'api',
          // Supabase : clé publique, la même pour tous les téléphones.
          if (apiKey.isNotEmpty) 'apikey': apiKey,
          // Ancienne clé « anon » (un JWT) : la passerelle l'attend aussi ici.
          if (apiKey.startsWith('eyJ')) 'Authorization': 'Bearer $apiKey',
        };

  final Uri _baseUrl;
  final http.Client _client;

  /// En-têtes envoyés avec chaque requête : aucun ne dépend de l'appareil ni de l'utilisateur.
  final Map<String, String> _commonHeaders;

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

  /// Arrivées par quart d'heure d'une manif.
  Future<List<Map<String, dynamic>>> getTimeline(String eventId) =>
      _getRows('event_timeline', {'event_id': 'eq.$eventId', 'order': 'time_slot'});

  /// Présences par tronçon et par quart d'heure (cases de 20 personnes ou plus seulement).
  Future<List<Map<String, dynamic>>> getDensity(String eventId) =>
      _getRows('event_density', {'event_id': 'eq.$eventId', 'order': 'time_slot,segment'});

  /// `POST /rpc/presence`. Renvoie true si le jeton est nouveau, false s'il était déjà compté.
  Future<bool> postPresence(Map<String, Object?> body) => _rpc('presence', body);

  /// `POST /rpc/support`. Renvoie true si le jeton est nouveau, false s'il était déjà compté.
  Future<bool> postSupport(Map<String, Object?> body) => _rpc('support', body);

  Future<bool> _rpc(String name, Map<String, Object?> body) async =>
      jsonDecode(await _send(() => _client.post(_uri('rpc/$name'),
          headers: {..._commonHeaders, 'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(body)))) as bool;

  Future<List<Map<String, dynamic>>> _getRows(String path, Map<String, String> query) async =>
      (jsonDecode(await _send(
                  () => _client.get(_uri(path, query), headers: {..._commonHeaders, 'Accept': 'application/json'})))
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
