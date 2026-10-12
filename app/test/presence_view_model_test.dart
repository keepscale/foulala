import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/repositories/event_repository_remote.dart';
import 'package:foulala/data/repositories/presence_repository_remote.dart';
import 'package:foulala/data/services/foulala_api.dart';
import 'package:foulala/domain/models/geo.dart';
import 'package:foulala/domain/repositories/location_reader.dart';
import 'package:foulala/ui/presence/view_models/presence_view_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

class FakeLocation implements LocationReader {
  FakeLocation(this.result);

  Object result;
  int reads = 0;

  @override
  Future<PositionFix> readOnce() async {
    reads++;
    final r = result;
    if (r is PositionFix) return r;
    throw r;
  }

  @override
  Future<void> openSettings() async {}
}

void main() {
  final now = DateTime.utc(2026, 10, 12, 13, 22);
  final event = testEvent(start: DateTime.utc(2026, 10, 12, 12), end: DateTime.utc(2026, 10, 12, 15));
  const inside = PositionFix(GeoPoint(45.765, 4.8305), accuracyM: 12);

  late bool online;
  late List<http.Request> posts;

  PresenceViewModel build(LocationReader location) {
    posts = [];
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        if (!online) throw const SocketException('pas de réseau');
        posts.add(req);
        return http.Response('true', 200);
      }
      final body = switch (req.url.path) {
        '/events' => [
            {
              'id': 'e1', 'title': 'Marche de test', 'cause': 'climat', 'city': 'Lyon', //
              'starts_at': '2026-10-12T12:00:00Z', 'ends_at': '2026-10-12T15:00:00Z', 'status': 'published',
              'organizer': 'Collectif', 'segment_count': 6,
            },
          ],
        '/event_count' => [
            {'event_id': 'e1', 'present': 2501, 'supporters': 800},
          ],
        _ => throw StateError('${req.url}'),
      };
      return http.Response(jsonEncode(body), 200);
    });
    final api = FoulalaApi(Uri.parse('http://api.test'), client: client);
    return PresenceViewModel(
      event: event,
      presence: PresenceRepositoryRemote(api, MemoryStore()),
      location: location,
      events: EventRepositoryRemote(api),
      clock: () => now,
    );
  }

  setUp(() => online = true);

  test('dans la zone : envoyé, puis compteur relu', () async {
    final vm = build(FakeLocation(inside));
    await vm.run();
    final state = vm.state as Sent;
    expect(state.present, 2501);
    expect(state.report.slot.start, DateTime.utc(2026, 10, 12, 13, 15));
    expect(state.report.segment!.index, 3);
    expect(posts, hasLength(1));
  });

  test('la position reste sur le téléphone : absente de la requête', () async {
    final vm = build(FakeLocation(inside));
    await vm.run();
    final body = posts.single.body;
    for (final leak in ['45.765', '4.8305', 'accuracy', 'lat', 'lon', '13:22']) {
      expect(body, isNot(contains(leak)));
    }
  });

  test('sans réseau : en attente, puis envoyé au nouvel essai', () async {
    online = false;
    final vm = build(FakeLocation(inside));
    await vm.run();
    expect(vm.state, isA<Queued>());

    online = true;
    await vm.retrySending();
    expect(vm.state, isA<Sent>());
    expect(posts, hasLength(1));
  });

  test('hors zone : rien n\'est envoyé', () async {
    final vm = build(FakeLocation(const PositionFix(GeoPoint(45.765, 4.8340), accuracyM: 12)));
    await vm.run();
    expect(vm.state, isA<NotInZone>());
    expect(posts, isEmpty);
  });

  test('position refusée : rien n\'est envoyé', () async {
    final vm = build(FakeLocation(const LocationUnavailable(LocationProblem.denied)));
    await vm.run();
    expect((vm.state as NoLocation).problem, LocationProblem.denied);
    expect(posts, isEmpty);
  });

  test('la position n\'est lue qu\'une fois par essai', () async {
    final location = FakeLocation(inside);
    final vm = build(location);
    await vm.run();
    expect(location.reads, 1);
  });
}
