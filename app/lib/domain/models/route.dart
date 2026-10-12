import 'dart:math' as math;

import 'geo.dart';

/// Parcours d'une manif (LineString). Sert à situer l'utilisateur le long du parcours,
/// sur le téléphone, pour en déduire son tronçon.
class EventRoute {
  EventRoute(List<GeoPoint> points)
      : assert(points.length >= 2, 'un parcours a au moins deux points'),
        points = List.unmodifiable(points),
        _projection = LocalProjection(points.first) {
    _projected = [for (final p in this.points) _projection.project(p)];
    var acc = 0.0;
    _cumulative = [0.0];
    for (var i = 1; i < _projected.length; i++) {
      acc += _projected[i - 1].distanceTo(_projected[i]);
      _cumulative.add(acc);
    }
  }

  final List<GeoPoint> points;
  final LocalProjection _projection;
  late final List<math.Point<double>> _projected;
  late final List<double> _cumulative;

  double get lengthM => _cumulative.last;

  /// Position relative le long du parcours, de 0 (départ) à 1 (arrivée),
  /// du point du parcours le plus proche de [p].
  double fractionAlong(GeoPoint p) {
    if (lengthM == 0) return 0;
    final q = _projection.project(p);
    var best = double.infinity;
    var bestAlong = 0.0;
    for (var i = 1; i < _projected.length; i++) {
      final r = pointToSegment(q, _projected[i - 1], _projected[i]);
      if (r.distance < best) {
        best = r.distance;
        bestAlong = _cumulative[i - 1] + r.t * (_cumulative[i] - _cumulative[i - 1]);
      }
    }
    return (bestAlong / lengthM).clamp(0.0, 1.0);
  }
}
