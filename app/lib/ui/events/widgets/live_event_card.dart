import 'package:flutter/material.dart';

import '../../../domain/models/event.dart';
import '../../core/format.dart';
import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/cause_decor.dart';
import '../../core/ui/foulala_icon.dart';

/// Grande carte colorée d'une manif en cours (maquette Main, « En ce moment »).
class LiveEventCard extends StatelessWidget {
  const LiveEventCard({super.key, required this.summary, this.onTap});

  final EventSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final event = summary.event;
    final count = summary.count;
    final t = event.cause.theme;
    const white = Colors.white;

    return Semantics(
      button: onTap != null,
      label: '${event.title}, ${t.label}, en direct. '
          '${plural(count.present, 'présent vérifié', 'présents vérifiés')}, ${plural(count.supporters, 'soutien')}.',
      excludeSemantics: true,
      child: Material(
        color: t.primary,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(top: -18, right: -22, child: CauseDecor(event.cause)),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _Pill(
                        background: white,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          FoulalaIcon(FoulalaIcons.forCause(event.cause), size: 15, color: t.primary, strokeWidth: 2.4),
                          const SizedBox(width: 6),
                          Text(t.label, style: FoulalaText.body(13, weight: 800, color: t.deep)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        background: t.deep,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: t.pop, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('En direct', style: FoulalaText.body(13, weight: 800, color: white)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Text(event.title, style: FoulalaText.display(28, color: white)),
                    const SizedBox(height: 3),
                    Text(
                      '${formatTime(event.startsAt)} – ${formatTime(event.endsAt)} · ${event.organizer}',
                      style: FoulalaText.body(15, color: white),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: white.withValues(alpha: 0.3)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatCount(count.present), style: FoulalaText.display(34, color: white)),
                              Text(
                                '${count.present > 1 ? 'présents vérifiés' : 'présent vérifié'} · ${plural(count.supporters, 'soutien')}',
                                style: FoulalaText.body(14, color: white),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: white, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: FoulalaIcon(FoulalaIcons.arrowRight, color: t.primary, strokeWidth: 2.6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(FoulalaRadius.chip)),
        alignment: Alignment.center,
        child: child,
      );
}
