import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../themes/theme.dart';
import '../themes/tokens.g.dart';

/// Rose du logotype « lala » sur fond clair (design/README.md).
const _lalaPink = Color(0xFFE0357C);

/// Trois bulles pour la foule, celle du milieu en repère de carte (design/logo.svg).
String _markSvg(Color background) {
  final [yellow, pink, blue] = FoulalaColors.brand;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 56">'
      '<circle cx="17" cy="26" r="14" fill="${hex(yellow)}"/>'
      '<circle cx="47" cy="26" r="14" fill="${hex(blue)}"/>'
      '<path d="M32 5c-9.4 0-17 7.4-17 16.6C15 34 32 51 32 51s17-17 17-29.4C49 12.4 41.4 5 32 5z" '
      'fill="${hex(pink)}" stroke="${hex(background)}" stroke-width="3.5" stroke-linejoin="round"/>'
      '<circle cx="32" cy="21.6" r="6" fill="#FFFFFF"/></svg>';
}

String hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

class FoulalaLogo extends StatelessWidget {
  const FoulalaLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Foulala',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.string(_markSvg(FoulalaColors.background), width: 36, height: 32),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'fou'),
              TextSpan(text: 'lala', style: TextStyle(color: _lalaPink)),
            ]),
            style: FoulalaText.display(26, letterSpacing: -0.04, color: FoulalaColors.text),
          ),
        ],
      ),
    );
  }
}
