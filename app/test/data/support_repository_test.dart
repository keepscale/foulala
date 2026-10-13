import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/repositories/presence_repository_remote.dart';
import 'package:foulala/data/repositories/support_repository_remote.dart';
import 'package:foulala/data/services/foulala_api.dart';
import 'package:foulala/domain/repositories/support_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures.dart';

void main() {
  final event = testEvent(start: DateTime.utc(2026, 10, 17, 12), end: DateTime.utc(2026, 10, 17, 15));

  late MemoryStore store;
  late FoulalaApi api;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) server;

  SupportRepositoryRemote build() {
    store = MemoryStore();
    requests = [];
    api = FoulalaApi(Uri.parse('http://api.test'), client: MockClient((req) {
      requests.add(req);
      return server(req);
    }));
    return SupportRepositoryRemote(api, store);
  }

  setUp(() => server = (_) async => http.Response('true', 200));

  test('n\'envoie que l\'id de la manif et le jeton (invariant n° 3)', () async {
    final repo = build();
    expect(await repo.support(event), SupportOutcome.sent);

    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/rpc/support');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'event_id', 'token'});
    expect(body['event_id'], 'e1');
    expect(body['token'], await store.getSupportToken('e1'));
    expect(
      req.headers.keys.map((k) => k.toLowerCase()).toSet(),
      {'content-type', 'accept', 'accept-profile', 'content-profile'},
    );
  });

  test('jeton du soutien différent de celui du « J\'y suis ! » pour la même manif', () async {
    final repo = build();
    await repo.support(event);
    final presenceToken = await PresenceRepositoryRemote(api, store).tokenFor('e1');
    expect(presenceToken.value, isNot(await store.getSupportToken('e1')));
  });

  test('reçu : la manif rejoint « Mes soutiens », sans parcours ni zone', () async {
    final repo = build();
    expect(await repo.isSupported('e1'), isFalse);
    await repo.support(event);
    expect(await repo.isSupported('e1'), isTrue);

    final saved = (await repo.supportedEvents()).single;
    expect(saved.title, 'Marche de test');
    expect(saved.startsAt, event.startsAt);
    expect(saved.route, isNull);
    expect(saved.zone, isNull);
    expect((store.values['supports'] as List<String>).single, isNot(contains('coordinates')));
  });

  test('réseau absent : rien n\'est gardé dans la liste, et le nouvel essai reprend le même jeton', () async {
    final repo = build();
    server = (_) async => throw const SocketException('pas de réseau');
    expect(await repo.support(event), SupportOutcome.offline);
    expect(await repo.isSupported('e1'), isFalse);
    final firstToken = await store.getSupportToken('e1');

    server = (_) async => http.Response('true', 200);
    expect(await repo.support(event), SupportOutcome.sent);
    expect(jsonDecode(requests.last.body)['token'], firstToken, reason: 'le serveur ne le compte qu\'une fois');
  });

  test('refus du serveur (manif annulée) : pas dans la liste', () async {
    final repo = build();
    server = (_) async => http.Response('{"message":"manifestation indisponible"}', 400);
    expect(await repo.support(event), SupportOutcome.rejected);
    expect(await repo.supportedEvents(), isEmpty);
  });

  test('soutenir deux fois ne crée pas de doublon dans la liste', () async {
    final repo = build();
    await repo.support(event);
    server = (_) async => http.Response('false', 200); // déjà compté
    expect(await repo.support(event), SupportOutcome.sent);
    expect(await repo.supportedEvents(), hasLength(1));
  });

  test('une entrée illisible est ignorée', () async {
    final repo = build();
    await store.setSupports(['pas du json']);
    expect(await repo.supportedEvents(), isEmpty);
  });
}
