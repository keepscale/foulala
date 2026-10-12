import 'package:flutter/material.dart';

import '../../../domain/models/event.dart';
import '../../core/format.dart';
import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';

/// Ligne d'une manif à venir ou terminée (maquette Main, « À venir »).
class EventRow extends StatelessWidget {
  const EventRow({super.key, required this.summary, required this.now, this.onTap});

  final EventSummary summary;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final event = summary.event;
    final count = summary.count;
    final t = event.cause.theme;
    final over = event.isOver(now);

    final when = '${formatDay(event.startsAt, now: now)} · ${formatTime(event.startsAt)} · ${event.organizer}';
    // Une manif terminée affiche ses présents, une manif à venir ses soutiens.
    final figure = over
        ? 'au moins ${plural(count.present, 'présent')}'
        : plural(count.supporters, 'soutien');

    return Semantics(
      button: onTap != null,
      label: '${event.title}, ${t.label}${event.isCancelled ? ', annulée' : ''}. $when. $figure.',
      excludeSemantics: true,
      child: Material(
        color: FoulalaColors.surface,
        borderRadius: BorderRadius.circular(FoulalaRadius.card),
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shadowColor: FoulalaColors.text.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: FoulalaIcon(FoulalaIcons.forCause(event.cause), size: 28, color: t.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: FoulalaText.body(17, weight: 700, height: 1.2).copyWith(
                          decoration: event.isCancelled ? TextDecoration.lineThrough : null,
                          color: event.isCancelled ? FoulalaColors.textMuted : FoulalaColors.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(when, style: FoulalaText.body(14, color: FoulalaColors.textMuted)),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Tag(label: t.label, background: t.soft, color: t.deep),
                          if (event.isCancelled)
                            const _Tag(label: 'Annulée', background: FoulalaColors.text, color: FoulalaColors.surface)
                          else
                            Text(figure, style: FoulalaText.body(13, color: FoulalaColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.background, required this.color});

  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(FoulalaRadius.chip)),
        child: Text(label, style: FoulalaText.body(12, weight: 700, color: color)),
      );
}
