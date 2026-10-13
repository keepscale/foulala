import 'package:flutter/material.dart';

import '../../../domain/models/event.dart';
import '../../core/format.dart';
import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';
import '../../core/ui/round_button.dart';
import '../view_models/counter_view_model.dart';

/// Compteur détaillé (maquette design/maquettes/Compteur.dc.html) : total, arrivées par quart d'heure,
/// densité par tronçon. Tout groupe de moins de 20 personnes est masqué.
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key, required this.viewModel});

  final CounterViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final event = viewModel.event;
    final t = event.cause.theme;
    final stats = viewModel.stats;
    final updatedAt = viewModel.updatedAt;

    return Scaffold(
      backgroundColor: t.soft,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
            child: SizedBox(
              height: 52,
              child: Row(children: [
                RoundButton(
                  icon: FoulalaIcons.arrowLeft,
                  label: 'Retour à la manif',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                _StateChip(live: viewModel.live, dot: t.primary),
                const Spacer(),
                if (updatedAt != null)
                  Text('mis à jour à ${formatTime(updatedAt)}', style: FoulalaText.body(13, color: FoulalaColors.textMuted)),
              ]),
            ),
          ),
          Expanded(
            child: stats == null
                ? Center(
                    child: viewModel.failed
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('Impossible de charger le compteur.', style: FoulalaText.body(16)),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: viewModel.load, child: const Text('Réessayer')),
                          ])
                        : const CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    onRefresh: viewModel.load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      children: [
                        _Total(event: event, present: stats.count.present),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: _Figure(
                              t: t,
                              value: formatCount(stats.count.supporters),
                              label: stats.count.supporters > 1 ? 'soutiens, sans GPS' : 'soutien, sans GPS',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _peakFigure(t)),
                        ]),
                        const SizedBox(height: 12),
                        _Arrivals(viewModel: viewModel, t: t),
                        const SizedBox(height: 12),
                        _Density(viewModel: viewModel, t: t),
                        const SizedBox(height: 12),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: FoulalaIcon(FoulalaIcons.lock, size: 15, color: FoulalaColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Jetons anonymes supprimés 24 h après la fin. Seuls les totaux restent.',
                              style: FoulalaText.body(13, height: 1.4, color: FoulalaColors.textMuted),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _peakFigure(CauseTheme t) {
    final peak = viewModel.peak;
    if (peak == null) return _Figure(t: t, value: '—', label: 'pic : pas encore visible');
    return _Figure(t: t, value: formatTime(peak.slot.start), label: 'pic : ${plural(peak.n!, 'arrivée')}');
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.live, required this.dot});

  final bool live;
  final Color dot;

  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: EdgeInsets.only(left: live ? 10 : 12, right: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(FoulalaRadius.chip)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (live) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(live ? 'En direct' : 'Terminée', style: FoulalaText.body(14, weight: 800)),
        ]),
      );
}

/// Grand chiffre : présents vérifiés.
class _Total extends StatelessWidget {
  const _Total({required this.event, required this.present});

  final Event event;
  final int present;

  @override
  Widget build(BuildContext context) {
    final t = event.cause.theme;
    return Semantics(
      container: true,
      label: '${event.title} : au moins ${plural(present, 'présent vérifié', 'présents vérifiés')}.',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FoulalaRadius.sheet),
        child: Container(
          color: t.primary,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Stack(clipBehavior: Clip.none, children: [
            // Bulles décoratives, comme dans la maquette.
            Positioned(top: -60, right: -60, child: _bubble(92, t.pop)),
            Positioned(top: 30, right: 80, child: _bubble(44, t.mid.withValues(alpha: 0.7))),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: Text(event.title, style: FoulalaText.body(15, weight: 700, color: Colors.white)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatCount(present),
                  style: FoulalaText.display(84, height: 0.98, letterSpacing: -0.04, color: Colors.white),
                ),
              ),
              Text(
                present > 1 ? 'présents vérifiés, au minimum' : 'présent vérifié, au minimum',
                style: FoulalaText.body(18, weight: 800, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Seuls les téléphones qui ont signalé leur présence sont comptés : le cortège réel est plus nombreux.',
                style: FoulalaText.body(14, height: 1.4, color: Colors.white),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  static Widget _bubble(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _Figure extends StatelessWidget {
  const _Figure({required this.t, required this.value, required this.label});

  final CauseTheme t;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: FoulalaText.display(28, height: 1.05, color: t.deep)),
          ),
          const SizedBox(height: 2),
          Text(label, style: FoulalaText.body(13, color: FoulalaColors.textMuted)),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.t, required this.children, this.trailing, this.subtitle});

  final String title;
  final CauseTheme t;
  final Widget? trailing;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(FoulalaRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  style: FoulalaText.body(13, weight: 800, letterSpacing: 13 * 0.08, color: t.deep),
                ),
              ),
            ),
            ?trailing,
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: FoulalaText.body(13, color: FoulalaColors.textMuted)),
          ],
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

/// Arrivées par quart d'heure, en barres.
class _Arrivals extends StatelessWidget {
  const _Arrivals({required this.viewModel, required this.t});

  final CounterViewModel viewModel;
  final CauseTheme t;

  @override
  Widget build(BuildContext context) {
    final bars = viewModel.bars;
    final max = bars.fold<int>(0, (m, b) => b.n != null && b.n! > m ? b.n! : m);
    final gap = bars.length > 24 ? 1.0 : (bars.length > 12 ? 3.0 : 6.0);
    final description = bars.isEmpty
        ? 'Pas encore d’arrivées.'
        : 'Arrivées par quart d’heure : ${bars.map((b) => '${formatTime(b.slot.start)}, '
            '${b.n == null ? 'masqué' : formatCount(b.n!)}${b.current ? ' (en cours)' : ''}').join(' ; ')}';

    return _Section(
      title: 'Arrivées par quart d’heure',
      t: t,
      trailing: viewModel.live ? _LegendSwatch(color: t.pop, label: 'en cours') : null,
      children: [
        Semantics(
          label: description,
          excludeSemantics: true,
          child: Column(children: [
            Container(
              height: 100,
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: FoulalaColors.border, width: 2))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < bars.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: _bar(bars[i], max)),
                ],
              ]),
            ),
            const SizedBox(height: 6),
            _labels(bars, gap),
          ]),
        ),
        const SizedBox(height: 10),
        const _MaskedLegend(),
      ],
    );
  }

  Widget _bar(ArrivalBar b, int max) {
    final radius = BorderRadius.vertical(top: Radius.circular(b.n == null ? 3 : 6));
    if (b.n == null) return SizedBox(height: 10, child: _Hatched(borderRadius: radius));
    return Container(
      height: (b.n! / max * 100).clamp(4, 100).toDouble(),
      decoration: BoxDecoration(color: b.current ? t.pop : t.primary, borderRadius: radius),
    );
  }

  /// Une heure sur deux sous les barres quand il y en a peu, sinon la première et la dernière.
  Widget _labels(List<ArrivalBar> bars, double gap) {
    final style = FoulalaText.body(12, weight: 600, color: FoulalaColors.textMuted);
    if (bars.isEmpty) return const SizedBox.shrink();
    if (bars.length > 8) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(formatTime(bars.first.slot.start), style: style),
        Text(formatTime(bars.last.slot.start), style: style),
      ]);
    }
    return Row(children: [
      for (var i = 0; i < bars.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(
          child: Text(
            i.isEven ? formatTime(bars[i].slot.start) : '',
            style: style,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),
      ],
    ]);
  }
}

/// Où les présences sont signalées : une case par tronçon, pour un quart d'heure.
class _Density extends StatelessWidget {
  const _Density({required this.viewModel, required this.t});

  final CounterViewModel viewModel;
  final CauseTheme t;

  @override
  Widget build(BuildContext context) {
    final event = viewModel.event;
    final density = viewModel.density;
    final count = event.segmentCount;
    final route = event.route;
    final length = route == null ? '' : ' d’environ ${formatDistance(route.lengthM / count)}';
    final segments = '$count tronçon${count > 1 ? 's' : ''}$length';

    if (density == null) {
      return _Section(
        title: 'Où les présences sont signalées',
        t: t,
        subtitle: segments,
        children: [
          Text(
            'Aucun tronçon ne compte encore $privacyThreshold personnes sur un même quart d’heure : '
            'rien n’est affiché en dessous.',
            style: FoulalaText.body(14, height: 1.4),
          ),
        ],
      );
    }

    final max = density.max;
    final gap = count > 30 ? 1.0 : 3.0;
    final description = 'Présences signalées par tronçon, du départ à l’arrivée, '
        '${formatRange(density.slot.start, density.slot.end)} : '
        '${density.cells.map((v) => v == null ? 'masqué' : formatCount(v)).join(', ')}';

    return _Section(
      title: 'Où les présences sont signalées',
      t: t,
      subtitle: '${formatRange(density.slot.start, density.slot.end)} · $segments',
      children: [
        Semantics(
          label: description,
          excludeSemantics: true,
          child: Column(children: [
            SizedBox(
              height: 34,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(child: _cell(density.cells[i], max, first: i == 0, last: i == count - 1)),
                ],
              ]),
            ),
            if (count <= 12) ...[
              const SizedBox(height: 5),
              Row(children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    child: Text(
                      density.cells[i] == null ? '—' : formatCount(density.cells[i]!),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: FoulalaText.body(12, weight: 600, color: const Color(0xFF3D3A52)),
                    ),
                  ),
                ],
              ]),
            ],
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Départ', style: FoulalaText.body(13, weight: 700)),
              Text('Arrivée', style: FoulalaText.body(13, weight: 700)),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('moins', style: FoulalaText.body(12, color: FoulalaColors.textMuted)),
              const SizedBox(width: 6),
              for (final c in t.scale)
                Container(
                  width: 14,
                  height: 10,
                  margin: const EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
                ),
              const SizedBox(width: 4),
              Text('plus', style: FoulalaText.body(12, color: FoulalaColors.textMuted)),
            ]),
            const _MaskedLegend(),
          ],
        ),
      ],
    );
  }

  Widget _cell(int? n, int max, {required bool first, required bool last}) {
    final radius = BorderRadius.horizontal(
      left: Radius.circular(first ? 10 : 3),
      right: Radius.circular(last ? 10 : 3),
    );
    if (n == null) return _Hatched(borderRadius: radius);
    final r = n / max;
    final level = r < 0.3 ? 0 : (r < 0.55 ? 1 : (r < 0.8 ? 2 : 3));
    return Container(decoration: BoxDecoration(color: t.scale[level], borderRadius: radius));
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: FoulalaText.body(12, color: FoulalaColors.textMuted)),
      ]);
}

class _MaskedLegend extends StatelessWidget {
  const _MaskedLegend();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 14, height: 10, child: _Hatched(borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('masqué sous $privacyThreshold personnes', style: FoulalaText.body(12, color: FoulalaColors.textMuted)),
      ]);
}

/// Hachures des cases masquées : jamais une couleur seule pour porter le sens.
class _Hatched extends StatelessWidget {
  const _Hatched({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius,
        child: const CustomPaint(painter: _HatchPainter(), child: SizedBox.expand()),
      );
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = FoulalaColors.background);
    final stroke = Paint()
      ..color = const Color(0xFFDCDAE6)
      ..strokeWidth = 3;
    // Rayures à 45°, espacées de 7 px comme dans la maquette.
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stroke);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}
