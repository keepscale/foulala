import 'package:flutter/material.dart';

import '../core/themes/theme.dart';
import '../core/themes/tokens.g.dart';

/// Manifs soutenues : à venir (les soutiens seront gardés sur le téléphone, avec leur jeton).
class SupportsScreen extends StatelessWidget {
  const SupportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Mes soutiens', style: FoulalaText.display(38, height: 1, letterSpacing: -0.03)),
        const SizedBox(height: 12),
        Text(
          'Les manifs que vous soutenez apparaîtront ici. Cette liste reste sur votre téléphone : '
          'le serveur ne sait pas qui soutient quoi.',
          style: FoulalaText.body(15, height: 1.4, color: FoulalaColors.textMuted),
        ),
      ],
    );
  }
}
