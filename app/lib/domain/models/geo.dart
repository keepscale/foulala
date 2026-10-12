import 'dart:math' as math;

/// Point en latitude/longitude (WGS 84).
///
/// Vie privée : une position de l'utilisateur ne quitte jamais le téléphone.
/// Aucun dépôt ni service réseau n'accepte de [GeoPoint] venant du GPS.
class GeoPoint {
  const GeoPoint(this.lat, this.lon)
      : assert(lat >= -90 && lat <= 90),
        assert(lon >= -180 && lon <= 180);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

/// Position lue par le GPS, avec sa précision. Reste en mémoire, sur l'écran de présence.
class PositionFix {
  const PositionFix(this.point, {required this.accuracyM});

  final GeoPoint point;

  /// Rayon d'incertitude en mètres.
  final double accuracyM;
}

/// Projection plane locale en mètres (équirectangulaire), suffisante à l'échelle d'une ville.
class LocalProjection {
  LocalProjection(GeoPoint origin)
      : _lat0 = origin.lat,
        _lon0 = origin.lon,
        _cosLat0 = math.cos(origin.lat * math.pi / 180);

  static const _earthRadiusM = 6371008.8;
  static const _mPerDeg = _earthRadiusM * math.pi / 180;

  final double _lat0;
  final double _lon0;
  final double _cosLat0;

  math.Point<double> project(GeoPoint p) =>
      math.Point((p.lon - _lon0) * _cosLat0 * _mPerDeg, (p.lat - _lat0) * _mPerDeg);
}

/// Distance d'un point P au segment [A, B], et position du projeté sur ce segment (0 → A, 1 → B).
({double distance, double t}) pointToSegment(math.Point<double> p, math.Point<double> a, math.Point<double> b) {
  final ab = b - a;
  final len2 = ab.x * ab.x + ab.y * ab.y;
  final t = len2 == 0 ? 0.0 : (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2).clamp(0.0, 1.0);
  final proj = math.Point(a.x + ab.x * t, a.y + ab.y * t);
  return (distance: p.distanceTo(proj), t: t);
}
