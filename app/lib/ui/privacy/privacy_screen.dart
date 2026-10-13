import 'package:flutter/material.dart';

import '../core/themes/theme.dart';
import '../core/themes/tokens.g.dart';
import '../core/ui/foulala_icon.dart';

/// Ce que Foulala sait et ne sait pas (résumé de docs/vie-privee.md).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sent = [
    ('Identifiant de la manif', 'Pour savoir quelle manif compter.'),
    ('Un jeton tiré au hasard', 'Différent pour chaque manif : vos participations ne peuvent pas être reliées.'),
    ("Le quart d'heure", "Jamais l'heure exacte."),
    ('Le tronçon du parcours', 'Calculé sur votre téléphone, optionnel.'),
  ];

  static const _never = [
    'Votre position GPS : la vérification se fait sur votre téléphone.',
    "Votre nom, votre e-mail, votre numéro : il n'y a pas de compte.",
    "Votre adresse IP : le serveur n'a aucun journal d'accès.",
    'Un identifiant de votre téléphone.',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text('Vie privée', style: FoulalaText.display(38, height: 1, letterSpacing: -0.03)),
        const SizedBox(height: 12),
        Text(
          'Participer à une manif révèle une opinion. Foulala est conçu pour ne jamais pouvoir '
          'relier une personne à une manif.',
          style: FoulalaText.body(15, height: 1.4, color: FoulalaColors.textMuted),
        ),
        const SizedBox(height: 24),
        Text('Ce que le serveur reçoit', style: FoulalaText.display(22)),
        const SizedBox(height: 8),
        for (final (title, text) in _sent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FoulalaIcon(FoulalaIcons.check, size: 20, strokeWidth: 2.6),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$title. ', style: FoulalaText.body(16, weight: 700)),
                    TextSpan(text: text),
                  ]),
                  style: FoulalaText.body(16, height: 1.35),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        Text(
          "Pour « Je soutiens » : seulement l'identifiant de la manif et un autre jeton, "
          "sans heure ni position. La liste de vos soutiens reste sur votre téléphone.",
          style: FoulalaText.body(15, height: 1.4, color: FoulalaColors.textMuted),
        ),
        const SizedBox(height: 20),
        Text("Ce qu'il ne reçoit jamais", style: FoulalaText.display(22)),
        const SizedBox(height: 8),
        for (final text in _never)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FoulalaIcon(FoulalaIcons.shield, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: FoulalaText.body(16, height: 1.35))),
            ]),
          ),
        const SizedBox(height: 20),
        Text(
          '24 h après la fin de chaque manif, les jetons sont supprimés : seuls les totaux restent. '
          "Un groupe de moins de $privacyThreshold personnes n'est jamais affiché.",
          style: FoulalaText.body(15, height: 1.4, color: FoulalaColors.textMuted),
        ),
      ],
    );
  }
}
