import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/mappers/presence_mapper.dart';
import 'package:foulala/data/repositories/presence_repository_remote.dart';
import 'package:foulala/data/services/foulala_api.dart';
import 'package:foulala/domain/models/presence_report.dart';
import 'package:foulala/domain/models/presence_token.dart';
import 'package:foulala/domain/models/segment.dart';
import 'package:foulala/domain/models/time_slot.dart';
import 'package:foulala/domain/repositories/presence_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures.dart';

void main() {
  final report = PresenceReport(
    eventId: 'e1',
    token: PresenceToken.generate(),
    slot: TimeSlot.containing(DateTime.utc(2026, 10, 12, 13, 22)),
    segment: Segment.at(0.5, 6),
  );
  final retryUntil = DateTime.utc(2026, 10, 13, 15);

  late MemoryStore store;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) server;

  PresenceRepositoryRemote build() {
    store = MemoryStore();
    requests = [];
    final client = MockClient((req) {
      requests.add(req);
      return server(req);
    });
    return PresenceRepositoryRemote(FoulalaApi(Uri.parse('http://api.test'), client: client), store);
  }

  setUp(() => server = (_) async => http.Response('true', 200));

  test('n\'envoie que les quatre champs autorisés (invariant n° 3)', () async {
    final repo = build();
    expect(await repo.submit(report, retryUntil: retryUntil), SubmitOutcome.sent);

    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/rpc/presence');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'event_id', 'token', 'time_slot', 'segment'});
    expect(body['time_slot'], '2026-10-12T13:15:00.000Z');
    expect(body['segment'], 3);
    expect(body['token'], report.token.value);
    // Aucun en-tête qui identifierait l'appareil ou l'utilisateur.
    expect(
      req.headers.keys.map((k) => k.toLowerCase()).toSet(),
      {'content-type', 'accept', 'accept-profile', 'content-profile'},
    );
  });

  test('Supabase : seule la clé publique s\'ajoute, identique pour tous', () async {
    final seen = <Map<String, String>>[];
    final api = FoulalaApi(
      Uri.parse('https://projet.supabase.co/rest/v1'),
      apiKey: 'sb_publishable_test',
      client: MockClient((req) async {
        seen.add(req.headers);
        return http.Response('true', 200);
      }),
    );
    final repo = PresenceRepositoryRemote(api, MemoryStore());
    await repo.submit(report, retryUntil: retryUntil);

    final headers = seen.single.map((k, v) => MapEntry(k.toLowerCase(), v));
    expect(headers.keys.toSet(), {'content-type', 'accept', 'accept-profile', 'content-profile', 'apikey'});
    expect(headers['apikey'], 'sb_publishable_test');
  });

  test('PresenceMapper.toApi : mêmes quatre clés, même sans tronçon', () {
    final noSegment = PresenceReport(eventId: 'e1', token: report.token, slot: report.slot);
    expect(PresenceMapper.toApi(noSegment).keys.toSet(), {'event_id', 'token', 'time_slot', 'segment'});
  });

  test('réseau absent : mis en file, puis renvoyé au retour du réseau', () async {
    final repo = build();
    server = (_) async => throw const SocketException('pas de réseau');
    expect(await repo.submit(report, retryUntil: retryUntil), SubmitOutcome.queued);
    expect(await repo.isPending('e1'), isTrue);

    server = (_) async => http.Response('true', 200);
    await repo.flushPending(now: DateTime.utc(2026, 10, 12, 16));
    expect(await repo.isPending('e1'), isFalse);
    expect(jsonDecode(requests.last.body)['token'], report.token.value, reason: 'même jeton qu\'au premier essai');
  });

  test('serveur saturé (503) : mis en file', () async {
    final repo = build();
    server = (_) async => http.Response('', 503);
    expect(await repo.submit(report, retryUntil: retryUntil), SubmitOutcome.queued);
  });

  test('après 24 h, la file est abandonnée sans envoi', () async {
    final repo = build();
    server = (_) async => throw const SocketException('pas de réseau');
    await repo.submit(report, retryUntil: retryUntil);
    final sentBefore = requests.length;

    server = (_) async => http.Response('true', 200);
    await repo.flushPending(now: retryUntil.add(const Duration(minutes: 1)));
    expect(await repo.isPending('e1'), isFalse);
    expect(requests.length, sentBefore, reason: 'rien n\'est envoyé trop tard');
  });

  test('refus du serveur (400) : pas de nouvel essai', () async {
    final repo = build();
    server = (_) async => http.Response('{"message":"créneau hors de la manifestation"}', 400);
    expect(await repo.submit(report, retryUntil: retryUntil), SubmitOutcome.rejected);
    expect(await repo.isPending('e1'), isFalse);
  });

  test('un jeton par manif, stable pour une même manif', () async {
    final repo = build();
    final a1 = await repo.tokenFor('a');
    final a2 = await repo.tokenFor('a');
    final b = await repo.tokenFor('b');
    expect(a1, a2);
    expect(a1, isNot(b));
  });

  test('un jeton stocké abîmé est remplacé, jamais envoyé tel quel', () async {
    final repo = build();
    await store.setToken('a', 'abîmé');
    final token = await repo.tokenFor('a');
    expect(token.value, isNot('abîmé'));
    expect(await store.getToken('a'), token.value);
  });
}
