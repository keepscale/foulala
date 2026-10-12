import 'dart:math' as math;

import 'geo.dart';

/// Zone de présence : le parcours élargi de `buffer_m` mètres, calculé par le serveur.
///
/// Le test « suis-je dans la zone ? » se fait ici, sur le téléphone :
/// la position GPS n'est jamais envoyée (invariant n° 1).
class Zone {
  /// [rings] : contour extérieur puis trous éventuels, comme un Polygon GeoJSON.
  Zone(List<List<GeoPoint>> rings)
      : assert(rings.isNotEmpty && rings.every((r) => r.length >= 3), 'polygone invalide'),
        rings = List.unmodifiable(rings.map(List<GeoPoint>.unmodifiable)),
        _projection = LocalProjection(rings.first.first) {
    _projected = [
      for (final ring in this.rings) [for (final p in ring) _projection.project(p)],
    ];
  }

  final List<List<GeoPoint>> rings;
  final LocalProjection _projection;
  late final List<List<math.Point<double>>> _projected;

  List<GeoPoint> get outline => rings.first;

  bool contains(GeoPoint p) {
    final q = _projection.project(p);
    if (!_inRing(q, _projected.first)) return false;
    for (final hole in _projected.skip(1)) {
      if (_inRing(q, hole)) return false;
    }
    return true;
  }

  /// Distance en mètres jusqu'au bord de la zone, 0 si [p] est dedans.
  double distanceM(GeoPoint p) {
    if (contains(p)) return 0;
    final q = _projection.project(p);
    var best = double.infinity;
    for (final ring in _projected) {
      for (var i = 0; i < ring.length; i++) {
        final d = pointToSegment(q, ring[i], ring[(i + 1) % ring.length]).distance;
        if (d < best) best = d;
      }
    }
    return best;
  }

  /// Lancer de rayon (règle pair-impair).
  static bool _inRing(math.Point<double> p, List<math.Point<double>> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }
}
