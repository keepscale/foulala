import 'dart:convert';

import '../../domain/models/presence_report.dart';
import '../../domain/models/presence_token.dart';
import '../../domain/repositories/presence_repository.dart';
import '../mappers/presence_mapper.dart';
import '../services/foulala_api.dart';
import '../services/local_store.dart';

class PresenceRepositoryRemote implements PresenceRepository {
  PresenceRepositoryRemote(this._api, this._store);

  final FoulalaApi _api;
  final LocalStore _store;

  /// Les opérations sur la file passent l'une après l'autre (pas de double envoi).
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<PresenceToken> tokenFor(String eventId) async {
    final stored = await _store.getToken(eventId);
    if (stored != null) {
      try {
        return PresenceToken.parse(stored);
      } on FormatException {
        // Valeur abîmée : on tire un nouveau jeton plutôt que d'envoyer n'importe quoi.
      }
    }
    final token = PresenceToken.generate();
    await _store.setToken(eventId, token.value);
    return token;
  }

  @override
  Future<SubmitOutcome> submit(PresenceReport report, {required DateTime retryUntil}) => _serial(() async {
        final outcome = await _send(report);
        final pending = await _readPending();
        pending.removeWhere((p) => p.report.eventId == report.eventId);
        if (outcome == SubmitOutcome.queued) pending.add(PendingPresence(report, retryUntil));
        await _writePending(pending);
        return outcome;
      });

  @override
  Future<void> flushPending({required DateTime now}) => _serial(() async {
        final pending = await _readPending();
        if (pending.isEmpty) return;
        final kept = <PendingPresence>[];
        for (final p in pending) {
          if (p.retryUntil.isBefore(now)) continue; // trop tard : abandonné, comme côté serveur
          if (await _send(p.report) == SubmitOutcome.queued) kept.add(p);
        }
        await _writePending(kept);
      });

  @override
  Future<bool> isPending(String eventId) async =>
      (await _readPending()).any((p) => p.report.eventId == eventId);

  Future<SubmitOutcome> _send(PresenceReport report) async {
    try {
      await _api.postPresence(PresenceMapper.toApi(report));
      return SubmitOutcome.sent;
    } on NetworkUnavailable {
      return SubmitOutcome.queued;
    } on ApiException {
      return SubmitOutcome.rejected;
    }
  }

  Future<List<PendingPresence>> _readPending() async {
    final result = <PendingPresence>[];
    for (final entry in await _store.getPending()) {
      try {
        result.add(PresenceMapper.fromStore(jsonDecode(entry) as Map<String, dynamic>));
      } on Object {
        // Entrée illisible ou invalide (créneau, jeton, tronçon) : abandonnée.
      }
    }
    return result;
  }

  Future<void> _writePending(List<PendingPresence> pending) =>
      _store.setPending([for (final p in pending) jsonEncode(PresenceMapper.toStore(p))]);
}
