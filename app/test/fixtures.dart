import 'package:foulala/data/services/local_store.dart';
import 'package:foulala/domain/models/event.dart';
import 'package:foulala/domain/models/geo.dart';

/// Manif de test : parcours nord-sud d'environ 1,1 km à Lyon, zone de ±100 m, 6 tronçons.
Event testEvent({required DateTime start, required DateTime end, bool cancelled = false, String id = 'e1'}) => Event(
      id: id,
      title: 'Marche de test',
      cause: Cause.climat,
      city: 'Lyon',
      startsAt: start,
      endsAt: end,
      status: cancelled ? EventStatus.cancelled : EventStatus.published,
      organizer: 'Collectif',
      segmentCount: 6,
      route: EventRoute([const GeoPoint(45.760, 4.830), const GeoPoint(45.770, 4.830)]),
      zone: Zone([
        [
          const GeoPoint(45.7591, 4.8287),
          const GeoPoint(45.7591, 4.8313),
          const GeoPoint(45.7709, 4.8313),
          const GeoPoint(45.7709, 4.8287),
        ],
      ]),
    );

/// Stockage local en mémoire, pour les tests.
class MemoryStore implements LocalStore {
  final values = <String, Object>{};

  @override
  Future<String?> getCity() async => values['city'] as String?;

  @override
  Future<void> setCity(String city) async => values['city'] = city;

  @override
  Future<String?> getToken(String eventId) async => values['token.$eventId'] as String?;

  @override
  Future<void> setToken(String eventId, String token) async => values['token.$eventId'] = token;

  @override
  Future<List<String>> getPending() async => (values['pending'] as List<String>?) ?? const [];

  @override
  Future<void> setPending(List<String> entries) async => values['pending'] = List.of(entries);

  @override
  Future<String?> getSupportToken(String eventId) async => values['support_token.$eventId'] as String?;

  @override
  Future<void> setSupportToken(String eventId, String token) async => values['support_token.$eventId'] = token;

  @override
  Future<List<String>> getSupports() async => (values['supports'] as List<String>?) ?? const [];

  @override
  Future<void> setSupports(List<String> entries) async => values['supports'] = List.of(entries);
}
