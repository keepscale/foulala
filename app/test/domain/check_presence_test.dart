import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/domain/models/geo.dart';
import 'package:foulala/domain/presence/check_presence.dart';

import '../fixtures.dart';

void main() {
  final event = testEvent(start: DateTime.utc(2026, 10, 12, 12), end: DateTime.utc(2026, 10, 12, 15));
  const inside = PositionFix(GeoPoint(45.765, 4.8305), accuracyM: 12);

  PresenceCheck check(PositionFix fix, DateTime now) =>
      checkPresence(event: event, zone: event.zone!, route: event.route!, fix: fix, now: now);

  test('dans la zone, pendant la manif : créneau arrondi et tronçon', () {
    final result = check(inside, DateTime.utc(2026, 10, 12, 13, 22, 41));
    expect(result, isA<InZone>());
    final ok = result as InZone;
    expect(ok.slot.start, DateTime.utc(2026, 10, 12, 13, 15));
    expect(ok.segment.count, event.segmentCount);
    expect(ok.segment.index, 3, reason: 'milieu d\'un parcours de 6 tronçons');
  });

  test('ouvert 30 min avant le début', () {
    expect(check(inside, DateTime.utc(2026, 10, 12, 11, 31)), isA<InZone>());
    expect(check(inside, DateTime.utc(2026, 10, 12, 11, 29)), isA<OutsideWindow>());
  });

  test('fermé après la fin', () {
    expect(check(inside, DateTime.utc(2026, 10, 12, 15, 0, 1)), isA<OutsideWindow>());
  });

  test('annulée : fermé', () {
    final cancelled = testEvent(start: DateTime.utc(2026, 10, 12, 12), end: DateTime.utc(2026, 10, 12, 15), cancelled: true);
    final result = checkPresence(
      event: cancelled,
      zone: cancelled.zone!,
      route: cancelled.route!,
      fix: inside,
      now: DateTime.utc(2026, 10, 12, 13),
    );
    expect(result, isA<OutsideWindow>());
  });

  test('précision au-delà de 50 m : refusé, même dans la zone', () {
    final result = check(const PositionFix(GeoPoint(45.765, 4.8305), accuracyM: 65), DateTime.utc(2026, 10, 12, 13));
    expect(result, isA<TooImprecise>());
    expect((result as TooImprecise).accuracyM, 65);
    expect(check(const PositionFix(GeoPoint(45.765, 4.8305), accuracyM: 50), DateTime.utc(2026, 10, 12, 13)), isA<InZone>());
  });

  test('hors de la zone : distance au bord', () {
    final result = check(const PositionFix(GeoPoint(45.765, 4.8340), accuracyM: 12), DateTime.utc(2026, 10, 12, 13));
    expect(result, isA<OutOfZone>());
    expect((result as OutOfZone).distanceM, closeTo(210, 5));
  });
}
