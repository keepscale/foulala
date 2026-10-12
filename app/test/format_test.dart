import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/ui/core/format.dart';

void main() {
  test('formatCount groupe par milliers avec une espace fine insécable', () {
    expect(formatCount(0), '0');
    expect(formatCount(999), '999');
    expect(formatCount(8412), '8 412');
    expect(formatCount(1234567), '1 234 567');
  });

  test('plural', () {
    expect(plural(0, 'soutien'), '0 soutien');
    expect(plural(1, 'soutien'), '1 soutien');
    expect(plural(350, 'soutien'), '350 soutiens');
    expect(plural(2, 'présent vérifié', 'présents vérifiés'), '2 présents vérifiés');
  });

  test('formatDay : relatif autour du jour même, sinon jour abrégé', () {
    final now = DateTime(2026, 10, 12, 22);
    expect(formatDay(DateTime(2026, 10, 12, 14), now: now), "Aujourd'hui");
    expect(formatDay(DateTime(2026, 10, 13, 9), now: now), 'Demain');
    expect(formatDay(DateTime(2026, 10, 11, 9), now: now), 'Hier');
    expect(formatDay(DateTime(2026, 10, 20, 18), now: now), 'Mar. 20 oct.');
  });

  test('formatDay : « Demain » reste juste au passage à l\'heure d\'hiver', () {
    // Nuit du 24 au 25 octobre 2026 : une journée de 25 h en France.
    expect(formatDay(DateTime(2026, 10, 25, 14), now: DateTime(2026, 10, 24, 23)), 'Demain');
  });

  test('formatTime', () {
    expect(formatTime(DateTime(2026, 10, 12, 9, 5)), '09:05');
  });
}
