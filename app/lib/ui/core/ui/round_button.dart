import 'package:flutter/material.dart';

import '../themes/tokens.g.dart';
import 'foulala_icon.dart';

/// Bouton rond blanc de 44 px (retour, partage), comme dans les maquettes.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.label, required this.onPressed});

  final FoulalaIcons icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: FoulalaColors.text.withValues(alpha: 0.16),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: 44, height: 44, child: Center(child: FoulalaIcon(icon, strokeWidth: 2.4))),
          ),
        ),
      );
}
