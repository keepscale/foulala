import 'dart:convert';

import '../../domain/models/event.dart';
import '../../domain/models/presence_token.dart';
import '../../domain/repositories/support_repository.dart';
import '../mappers/event_mapper.dart';
import '../services/foulala_api.dart';
import '../services/local_store.dart';

class SupportRepositoryRemote implements SupportRepository {
  SupportRepositoryRemote(this._api, this._store);

  final FoulalaApi _api;
  final LocalStore _store;

  @override
  Future<SupportOutcome> support(Event event) async {
    // Jeton gardé AVANT l'envoi : un nouvel essai après une coupure réseau
    // renvoie le même, et le serveur ne compte le soutien qu'une fois.
    final token = await _tokenFor(event.id);
    try {
      // Seuls l'id de la manif et le jeton : ni heure, ni position (invariant n° 3).
      await _api.postSupport({'event_id': event.id, 'token': token.value});
    } on NetworkUnavailable {
      return SupportOutcome.offline;
    } on ApiException {
      return SupportOutcome.rejected;
    }
    final events = await supportedEvents()
      ..removeWhere((e) => e.id == event.id)
      ..add(event);
    await _store.setSupports([for (final e in events) jsonEncode(EventMapper.snapshot(e))]);
    return SupportOutcome.sent;
  }

  @override
  Future<bool> isSupported(String eventId) async => (await supportedEvents()).any((e) => e.id == eventId);

  @override
  Future<List<Event>> supportedEvents() async {
    final result = <Event>[];
    for (final entry in await _store.getSupports()) {
      try {
        result.add(EventMapper.event(jsonDecode(entry) as Map<String, dynamic>));
      } on Object {
        // Entrée illisible : ignorée.
      }
    }
    return result;
  }

  /// Un jeton par manif, tiré au hasard, différent de celui du « J'y suis ! » :
  /// le serveur ne peut pas relier un soutien à une présence.
  Future<PresenceToken> _tokenFor(String eventId) async {
    final stored = await _store.getSupportToken(eventId);
    if (stored != null) {
      try {
        return PresenceToken.parse(stored);
      } on FormatException {
        // Valeur abîmée : on tire un nouveau jeton.
      }
    }
    final token = PresenceToken.generate();
    await _store.setSupportToken(eventId, token.value);
    return token;
  }
}
