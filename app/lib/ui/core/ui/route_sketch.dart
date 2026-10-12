import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/event.dart';
import '../../../domain/models/geo.dart';
import '../themes/tokens.g.dart';

/// Schéma du parcours : zone de présence, tracé, départ, arrivée et, sur l'écran de présence,
/// le point « Vous ». Dessiné sur le téléphone, sans fond de carte : aucune tuile n'est
/// téléchargée, donc aucun serveur tiers ne voit quelle manif on regarde.
class RouteSketch extends StatelessWidget {
  const RouteSketch({
    super.key,
    required this.route,
    required this.zone,
    required this.theme,
    this.you,
    this.padding = const EdgeInsets.all(24),
    this.semanticLabel,
  });

  final EventRoute route;
  final Zone? zone;
  final CauseTheme theme;
  final GeoPoint? you;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel ?? 'Schéma du parcours et de la zone de présence',
      child: CustomPaint(
        painter: _SketchPainter(route: route, zone: zone, theme: theme, you: you, padding: padding),
        size: Size.infinite,
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter({required this.route, required this.zone, required this.theme, required this.you, required this.padding});

  final EventRoute route;
  final Zone? zone;
  final CauseTheme theme;
  final GeoPoint? you;
  final EdgeInsets padding;

  @override
  void paint(Canvas canvas, Size size) {
    final projection = LocalProjection(route.points.first);
    final routePts = route.points.map(projection.project).toList();
    final zonePts = zone?.outline.map(projection.project).toList() ?? const <math.Point<double>>[];
    final youPt = you == null ? null : projection.project(you!);

    // Cadrage : tout ce qu'on dessine doit tenir dans la zone utile.
    final all = [...routePts, ...zonePts, ?youPt];
    var minX = all.map((p) => p.x).reduce(math.min), maxX = all.map((p) => p.x).reduce(math.max);
    var minY = all.map((p) => p.y).reduce(math.min), maxY = all.map((p) => p.y).reduce(math.max);
    final inner = padding.deflateRect(Offset.zero & size);
    final spanX = math.max(maxX - minX, 1.0), spanY = math.max(maxY - minY, 1.0);
    final scale = math.min(inner.width / spanX, inner.height / spanY);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    // Le nord en haut : y projeté croît vers le nord, l'écran vers le bas.
    Offset toScreen(math.Point<double> p) =>
        Offset(inner.center.dx + (p.x - cx) * scale, inner.center.dy - (p.y - cy) * scale);

    if (zonePts.isNotEmpty) {
      final path = Path()..addPolygon(zonePts.map(toScreen).toList(), true);
      canvas.drawPath(path, Paint()..color = theme.mid.withValues(alpha: 0.45));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = theme.primary.withValues(alpha: 0.35),
      );
    }

    final line = Path()..addPolygon(routePts.map(toScreen).toList(), false);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(line, stroke(Colors.white, 9));
    canvas.drawPath(line, stroke(theme.primary, 5));

    // Départ (rond plein) et arrivée (rond creux) : formes différentes, pas seulement la couleur.
    final start = toScreen(routePts.first), end = toScreen(routePts.last);
    canvas.drawCircle(start, 7, Paint()..color = Colors.white);
    canvas.drawCircle(start, 5, Paint()..color = theme.deep);
    canvas.drawCircle(end, 7, Paint()..color = theme.deep);
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);

    if (youPt != null) {
      final y = toScreen(youPt);
      canvas.drawCircle(y, 13, Paint()..color = theme.pop.withValues(alpha: 0.45));
      canvas.drawCircle(y, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(y, 4.5, Paint()..color = FoulalaColors.text);
    }
  }

  @override
  bool shouldRepaint(_SketchPainter old) =>
      old.route != route || old.zone != zone || old.you != you || old.theme != theme;
}
