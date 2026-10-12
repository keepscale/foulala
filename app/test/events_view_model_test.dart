import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/data/repositories/event_repository_remote.dart';
import 'package:foulala/data/services/foulala_api.dart';
import 'package:foulala/domain/models/event.dart';
import 'package:foulala/domain/repositories/city_repository.dart';
import 'package:foulala/ui/events/view_models/events_view_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final now = DateTime.utc(2026, 10, 12, 15);

class FakeCityRepository implements CityRepository {
  FakeCityRepository(this.city);

  String? city;

  @override
  Future<String?> getCity() async => city;

  @override
  Future<void> setCity(String city) async => this.city = city;
}

Map<String, dynamic> event(String id, String cause, DateTime start, {String status = 'published', String city = 'Lyon'}) => {
      'id': id,
      'title': 'Manif $id',
      'cause': cause,
      'description': null,
      'demands': <String>[],
      'city': city,
      'starts_at': start.toIso8601String(),
      'ends_at': start.add(const Duration(hours: 3)).toIso8601String(),
      'declared': true,
      'status': status,
      'buffer_m': 100,
      'segment_count': 5,
      'organizer': 'Collectif',
    };

void main() {
  late List<Uri> requests;
  late FakeCityRepository cities;

  final events = [
    event('live', 'climat', now.subtract(const Duration(hours: 1))),
    event('soon', 'social', now.add(const Duration(days: 2))),
    event('cancelled', 'paix', now.add(const Duration(days: 4)), status: 'cancelled'),
    event('old', 'autre', now.subtract(const Duration(days: 3))),
    event('older', 'climat', now.subtract(const Duration(days: 9))),
    event('paris', 'sante', now, city: 'Paris'),
  ];

  EventsViewModel build({String? savedCity}) {
    requests = [];
    final client = MockClient((req) async {
      requests.add(req.url);
      final body = switch (req.url.path) {
        '/events' when req.url.queryParameters['select'] == 'city' => events.map((e) => {'city': e['city']}).toList(),
        '/events' => events.where((e) => 'eq.${e['city']}' == req.url.queryParameters['city']).toList(),
        '/event_count' => [
            {'event_id': 'live', 'present': 2500, 'supporters': 800},
            {'event_id': 'old', 'present': 900, 'supporters': 150},
          ],
        _ => throw StateError('requête inattendue : ${req.url}'),
      };
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    cities = FakeCityRepository(savedCity);
    return EventsViewModel(
      events: EventRepositoryRemote(FoulalaApi(Uri.parse('http://api.test'), client: client)),
      cities: cities,
      clock: () => now,
    );
  }

  test('sans ville enregistrée : liste les villes et demande d\'en choisir une', () async {
    final vm = build();
    await vm.load();
    expect(vm.needsCity, isTrue);
    expect(vm.availableCities, ['Lyon', 'Paris']);
  });

  test('range les manifs en cours, à venir et terminées', () async {
    final vm = build(savedCity: 'Lyon');
    await vm.load();

    expect(vm.live.map((s) => s.event.id), ['live']);
    expect(vm.upcoming.map((s) => s.event.id), ['soon', 'cancelled']);
    expect(vm.past.map((s) => s.event.id), ['old', 'older'], reason: 'la plus récente d\'abord');
    expect(vm.live.single.count.present, 2500);
    expect(vm.upcoming.first.count.present, 0, reason: 'compteur absent : zéro');
    expect(vm.causes, [Cause.climat, Cause.paix, Cause.social, Cause.autre], reason: 'ordre de tokens.json');
  });

  test('le filtre par cause ne garde que cette cause', () async {
    final vm = build(savedCity: 'Lyon');
    await vm.load();
    vm.setFilter(Cause.climat);
    expect([...vm.live, ...vm.upcoming, ...vm.past].map((s) => s.event.id), ['live', 'older']);
  });

  test('changer de ville enregistre le choix et recharge', () async {
    final vm = build(savedCity: 'Lyon');
    await vm.load();
    await vm.selectCity('Paris');
    expect(vm.city, 'Paris');
    expect(vm.live.map((s) => s.event.id), ['paris']);
    expect(cities.city, 'Paris');
  });

  test('aucune requête ne porte de position ni d\'identifiant', () async {
    final vm = build(savedCity: 'Lyon');
    await vm.load();
    for (final uri in requests) {
      expect(uri.queryParameters.keys, everyElement(isIn(['select', 'city', 'order', 'event_id'])));
    }
  });
}
