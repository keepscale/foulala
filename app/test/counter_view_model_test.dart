import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/repositories/event_repository_remote.dart';
import 'package:foulala/data/services/foulala_api.dart';
import 'package:foulala/ui/counter/view_models/counter_view_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

void main() {
  // Manif de 12:00 à 13:00 UTC : créneaux acceptés de 11:30 à 13:00.
  final event = testEvent(start: DateTime.utc(2026, 10, 12, 12), end: DateTime.utc(2026, 10, 12, 13));

  late List<Map<String, Object?>> timeline;
  late List<Map<String, Object?>> density;
  late List<Uri> reads;

  CounterViewModel build(DateTime now) {
    reads = [];
    final client = MockClient((req) async {
      reads.add(req.url);
      final body = switch (req.url.path) {
        '/event_count' => [
            {'event_id': 'e1', 'present': 412, 'supporters': 1},
          ],
        '/event_timeline' => timeline,
        '/event_density' => density,
        _ => throw StateError('${req.url}'),
      };
      return http.Response(jsonEncode(body), 200);
    });
    final repo = EventRepositoryRemote(FoulalaApi(Uri.parse('http://api.test'), client: client));
    return CounterViewModel(event: event, events: repo, clock: () => now);
  }

  setUp(() {
    // Format de PostgREST : timestamptz avec décalage, sommes `numeric`.
    timeline = [
      {'event_id': 'e1', 'time_slot': '2026-10-12T11:30:00+00:00', 'arrivals': 5},
      {'event_id': 'e1', 'time_slot': '2026-10-12T11:45:00+00:00', 'arrivals': 120},
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:00:00+00:00', 'arrivals': 260},
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:15:00+00:00', 'arrivals': 27},
    ];
    density = [
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:00:00+00:00', 'segment': 1, 'n': 80},
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:15:00+00:00', 'segment': 2, 'n': 21},
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:15:00+00:00', 'segment': 4, 'n': 25.0},
    ];
  });

  test('lit seulement les vues agrégées de cette manif', () async {
    final vm = build(DateTime.utc(2026, 10, 12, 12, 20));
    await vm.load();
    expect(reads.map((u) => u.path).toSet(), {'/event_count', '/event_timeline', '/event_density'});
    for (final u in reads) {
      expect(u.query, contains('e1'));
    }
    vm.dispose();
  });

  test('en direct : barres jusqu\'au quart d\'heure en cours, moins de 20 masqué', () async {
    final vm = build(DateTime.utc(2026, 10, 12, 12, 20));
    await vm.load();
    expect(vm.live, isTrue);
    final bars = vm.bars;
    expect(bars.map((b) => b.slot.start.minute), [30, 45, 0, 15]);
    expect(bars.map((b) => b.n), [null, 120, 260, 27], reason: '5 arrivées : sous le seuil, masqué');
    expect(bars.last.current, isTrue);
    expect(bars.first.current, isFalse);
    expect(vm.stats!.count.present, 412);
    expect(vm.updatedAt, isNotNull);
    vm.dispose();
  });

  test('terminée : barres jusqu\'au dernier créneau accepté, créneaux vides masqués', () async {
    final vm = build(DateTime.utc(2026, 10, 12, 18));
    await vm.load();
    expect(vm.live, isFalse);
    final bars = vm.bars;
    expect(bars.first.slot.start, DateTime.utc(2026, 10, 12, 11, 30));
    expect(bars.last.slot.start, DateTime.utc(2026, 10, 12, 13), reason: 'le créneau de la fin est accepté');
    expect(bars.where((b) => b.current), isEmpty);
    expect(bars.sublist(4).every((b) => b.n == null), isTrue);
    vm.dispose();
  });

  test('pic : le quart d\'heure le plus chargé parmi ceux affichés', () async {
    final vm = build(DateTime.utc(2026, 10, 12, 18));
    await vm.load();
    expect(vm.peak!.slot.start, DateTime.utc(2026, 10, 12, 12));
    expect(vm.peak!.n, 260);
    vm.dispose();
  });

  test('pas de pic si tout est sous le seuil', () async {
    timeline = [
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:00:00+00:00', 'arrivals': 19},
    ];
    final vm = build(DateTime.utc(2026, 10, 12, 18));
    await vm.load();
    expect(vm.peak, isNull);
    vm.dispose();
  });

  test('densité : dernier quart d\'heure, une case par tronçon, les autres masquées', () async {
    final vm = build(DateTime.utc(2026, 10, 12, 12, 20));
    await vm.load();
    final d = vm.density!;
    expect(d.slot.start, DateTime.utc(2026, 10, 12, 12, 15));
    expect(d.cells, [null, null, 21, null, 25, null]);
    expect(d.max, 25);
    vm.dispose();
  });

  test('densité : une case sous 20 qui arriverait quand même n\'est pas affichée', () async {
    density = [
      {'event_id': 'e1', 'time_slot': '2026-10-12T12:00:00+00:00', 'segment': 0, 'n': 3},
    ];
    final vm = build(DateTime.utc(2026, 10, 12, 18));
    await vm.load();
    expect(vm.density!.cells.every((c) => c == null), isTrue);
    vm.dispose();
  });

  test('pas encore de densité : rien à montrer', () async {
    density = [];
    final vm = build(DateTime.utc(2026, 10, 12, 18));
    await vm.load();
    expect(vm.density, isNull);
    vm.dispose();
  });
}
