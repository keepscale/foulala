import 'package:flutter/material.dart';

import '../../../domain/models/event.dart';
import '../../core/themes/theme.dart';
import '../../core/themes/tokens.g.dart';
import '../../core/ui/foulala_icon.dart';

/// Filtre par cause : « Toutes » puis les causes présentes dans la ville.
class CauseFilterBar extends StatelessWidget {
  const CauseFilterBar({super.key, required this.causes, required this.selected, required this.onSelected});

  final List<Cause> causes;
  final Cause? selected;
  final ValueChanged<Cause?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Filtrer par cause',
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _Chip(
              label: 'Toutes',
              selected: selected == null,
              background: FoulalaColors.surface,
              color: FoulalaColors.text,
              onTap: () => onSelected(null),
            ),
            for (final cause in causes) ...[
              const SizedBox(width: 8),
              _Chip(
                label: cause.theme.label,
                icon: FoulalaIcons.forCause(cause),
                iconColor: cause.theme.primary,
                selected: selected == cause,
                background: cause.theme.soft,
                color: cause.theme.deep,
                onTap: () => onSelected(selected == cause ? null : cause),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.background,
    required this.color,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final Color background;
  final Color color;
  final VoidCallback onTap;
  final FoulalaIcons? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    // Sélectionné : fond foncé, texte blanc. L'état est aussi annoncé (jamais la couleur seule).
    final fg = selected ? FoulalaColors.surface : color;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? FoulalaColors.text : background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(left: icon == null ? 16 : 10, right: icon == null ? 16 : 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected && icon != null) ...[
                  FoulalaIcon(FoulalaIcons.check, size: 18, color: fg, strokeWidth: 2.6),
                  const SizedBox(width: 6),
                ] else if (icon != null) ...[
                  FoulalaIcon(icon!, size: 18, color: iconColor ?? fg),
                  const SizedBox(width: 6),
                ],
                Text(label, style: FoulalaText.body(15, weight: 700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
