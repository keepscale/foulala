import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/repositories/event_repository_remote.dart';
import 'package:foulala/data/repositories/presence_repository_remote.dart';
import 'package:foulala/data/repositories/support_repository_remote.dart';
import 'package:foulala/data/services/foulala_api.dart';
import 'package:foulala/domain/repositories/support_repository.dart';
import 'package:foulala/ui/event_detail/view_models/event_detail_view_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  late bool online;
  late String status;
  late int supporters;
  late List<http.Request> posts;

  EventDetailViewModel build(DateTime now) {
    posts = [];
    final client = MockClient((req) async {
      if (!online) throw const SocketException('pas de réseau');
      if (req.method == 'POST') {
        posts.add(req);
        if (status == 'cancelled') return http.Response('{"message":"manifestation indisponible"}', 400);
        supporters++;
        return http.Response('true', 200);
      }
      final body = switch (req.url.path) {
        '/events' => [
            {
              'id': 'e1', 'title': 'Marche de test', 'cause': 'climat', 'city': 'Lyon', //
              'starts_at': '2026-10-12T12:00:00Z', 'ends_at': '2026-10-12T15:00:00Z', 'status': status,
              'organizer': 'Collectif', 'segment_count': 6,
            },
          ],
        '/event_count' => [
            {'event_id': 'e1', 'present': 0, 'supporters': supporters},
          ],
        _ => throw StateError('${req.url}'),
      };
      return http.Response(jsonEncode(body), 200);
    });
    final api = FoulalaApi(Uri.parse('http://api.test'), client: client);
    final store = MemoryStore();
    return EventDetailViewModel(
      eventId: 'e1',
      events: EventRepositoryRemote(api),
      presence: PresenceRepositoryRemote(api, store),
      supports: SupportRepositoryRemote(api, store),
      clock: () => now,
    );
  }

  setUp(() {
    online = true;
    status = 'published';
    supporters = 10;
  });

  test('« Je soutiens » : envoyé, puis compteur de soutiens relu', () async {
    final vm = build(DateTime.utc(2026, 10, 11));
    await vm.load();
    expect(vm.canSupport, isTrue);
    expect(vm.supported, isFalse);

    expect(await vm.support(), SupportOutcome.sent);
    expect(vm.supported, isTrue);
    expect(vm.summary!.count.supporters, 11);
  });

  test('un second appui n\'envoie rien', () async {
    final vm = build(DateTime.utc(2026, 10, 11));
    await vm.load();
    await vm.support();
    expect(await vm.support(), isNull);
    expect(posts, hasLength(1));
  });

  test('soutien gardé : reconnu au prochain chargement', () async {
    final vm = build(DateTime.utc(2026, 10, 11));
    await vm.load();
    await vm.support();
    await vm.load();
    expect(vm.supported, isTrue);
  });

  test('hors ligne : pas marqué comme soutenu', () async {
    final vm = build(DateTime.utc(2026, 10, 11));
    await vm.load();
    online = false;
    expect(await vm.support(), SupportOutcome.offline);
    expect(vm.supported, isFalse);
    expect(vm.supporting, isFalse);
  });

  test('manif annulée : pas de bouton « Je soutiens » ni de compteur', () async {
    status = 'cancelled';
    final vm = build(DateTime.utc(2026, 10, 12, 13));
    await vm.load();
    expect(vm.canSupport, isFalse);
    expect(vm.hasCounter, isFalse);
    expect(await vm.support(), isNull);
    expect(posts, isEmpty);
  });

  test('compteur détaillé : à partir de 30 min avant le début', () async {
    final before = build(DateTime.utc(2026, 10, 12, 11, 29));
    await before.load();
    expect(before.hasCounter, isFalse);

    final open = build(DateTime.utc(2026, 10, 12, 11, 30));
    await open.load();
    expect(open.hasCounter, isTrue);

    final over = build(DateTime.utc(2026, 10, 13));
    await over.load();
    expect(over.hasCounter, isTrue);
  });
}
