import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:foulala/domain/models/geo.dart';
import 'package:foulala/domain/models/presence_token.dart';
import 'package:foulala/domain/models/route.dart';
import 'package:foulala/domain/models/segment.dart';
import 'package:foulala/domain/models/time_slot.dart';
import 'package:foulala/domain/models/zone.dart';

void main() {
  group('TimeSlot', () {
    test('arrondit au quart d\'heure inférieur, en UTC', () {
      final slot = TimeSlot.containing(DateTime.utc(2026, 10, 12, 14, 29, 59, 999));
      expect(slot.start, DateTime.utc(2026, 10, 12, 14, 15));
      expect(slot.end, DateTime.utc(2026, 10, 12, 14, 30));
      expect(slot.start.isUtc, isTrue);
    });

    test('toujours un multiple de 15 min depuis l\'epoch (contrainte CHECK de presence)', () {
      final rng = Random(1);
      for (var i = 0; i < 1000; i++) {
        final t = DateTime.fromMillisecondsSinceEpoch(rng.nextInt(1 << 31) * 1000 + rng.nextInt(1000), isUtc: true);
        expect(TimeSlot.containing(t).start.millisecondsSinceEpoch % (15 * 60 * 1000), 0);
      }
    });

    test('une heure locale donne le même créneau que son équivalent UTC', () {
      final t = DateTime.utc(2026, 10, 12, 12, 7);
      expect(TimeSlot.containing(t.toLocal()), TimeSlot.containing(t));
    });

    test('parse refuse une heure exacte', () {
      expect(TimeSlot.parse(DateTime.utc(2026, 10, 12, 14, 15)).start, DateTime.utc(2026, 10, 12, 14, 15));
      expect(() => TimeSlot.parse(DateTime.utc(2026, 10, 12, 14, 16)), throwsArgumentError);
    });
  });

  group('Segment', () {
    test('découpe la position relative en tronçons de longueur égale', () {
      expect(Segment.at(0, 9).index, 0);
      expect(Segment.at(0.5, 9).index, 4);
      expect(Segment.at(0.999, 9).index, 8);
      expect(Segment.at(1, 9).index, 8, reason: 'l\'arrivée est dans le dernier tronçon');
      expect(Segment.at(0.5, 9).number, 5);
    });

    test('reste dans [0, count) même avec une valeur aberrante', () {
      expect(Segment.at(-3, 9).index, 0);
      expect(Segment.at(42, 9).index, 8);
      expect(Segment.at(double.nan, 9).index, 0);
    });

    test('parse refuse un tronçon inexistant', () {
      expect(() => Segment.parse(9, 9), throwsRangeError);
      expect(() => Segment.parse(-1, 9), throwsRangeError);
    });
  });

  group('PresenceToken', () {
    test('génère un UUID v4 valide', () {
      final token = PresenceToken.generate();
      expect(token.value, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(PresenceToken.parse(token.value), token);
    });

    test('deux jetons ne se ressemblent pas', () {
      final tokens = {for (var i = 0; i < 1000; i++) PresenceToken.generate().value};
      expect(tokens, hasLength(1000));
    });

    test('parse refuse ce qui n\'est pas un UUID v4', () {
      expect(() => PresenceToken.parse('pas-un-jeton'), throwsFormatException);
      // UUID v1 (dérivé de l'horloge et de l'adresse MAC) : refusé.
      expect(() => PresenceToken.parse('6ba7b810-9dad-11d1-80b4-00c04fd430c8'), throwsFormatException);
    });

    test('toString ne divulgue pas le jeton complet', () {
      final token = PresenceToken.generate();
      expect(token.toString(), isNot(contains(token.value)));
      expect(token.short, startsWith(token.value.substring(0, 8)));
    });
  });

  group('Zone et parcours', () {
    // Parcours nord-sud d'environ 1,1 km à Lyon, zone de ±100 m autour.
    final route = EventRoute([const GeoPoint(45.760, 4.830), const GeoPoint(45.770, 4.830)]);
    final zone = Zone([
      [
        const GeoPoint(45.7591, 4.8287),
        const GeoPoint(45.7591, 4.8313),
        const GeoPoint(45.7709, 4.8313),
        const GeoPoint(45.7709, 4.8287),
      ],
    ]);

    test('longueur du parcours', () {
      expect(route.lengthM, closeTo(1112, 5));
    });

    test('dedans, dehors', () {
      expect(zone.contains(const GeoPoint(45.765, 4.8305)), isTrue);
      expect(zone.contains(const GeoPoint(45.765, 4.8340)), isFalse);
      expect(zone.distanceM(const GeoPoint(45.765, 4.8305)), 0);
    });

    test('distance au bord de la zone', () {
      // 4.8340 - 4.8313 = 0.0027° de longitude ≈ 210 m à cette latitude.
      expect(zone.distanceM(const GeoPoint(45.765, 4.8340)), closeTo(210, 5));
    });

    test('position relative le long du parcours', () {
      expect(route.fractionAlong(const GeoPoint(45.760, 4.830)), closeTo(0, 1e-6));
      expect(route.fractionAlong(const GeoPoint(45.765, 4.8305)), closeTo(0.5, 0.01));
      expect(route.fractionAlong(const GeoPoint(45.780, 4.830)), 1, reason: 'au-delà de l\'arrivée');
    });
  });
}
