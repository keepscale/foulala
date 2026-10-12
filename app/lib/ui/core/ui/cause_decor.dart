import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/models/cause.g.dart';
import '../themes/tokens.g.dart';
import 'logo.dart' show hex;

/// Motif décoratif en haut à droite des cartes colorées, repris de design/maquettes/Themes.dc.html.
/// Les couleurs viennent du thème de la cause, jamais recopiées à la main.
class CauseDecor extends StatelessWidget {
  const CauseDecor(this.cause, {super.key});

  final Cause cause;

  @override
  Widget build(BuildContext context) {
    final (width, height, body) = _decor(cause);
    return ExcludeSemantics(
      child: SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height">$body</svg>',
        width: width * 0.8,
        height: height * 0.8,
      ),
    );
  }
}

(double, double, String) _decor(Cause cause) {
  final t = cause.theme;
  final pop = hex(t.pop);
  const white = 'fill="#FFFFFF" fill-opacity="0.22"';
  return switch (cause) {
    Cause.climat => (
        190,
        140,
        '<circle cx="120" cy="56" r="42" fill="$pop"/>'
            '<ellipse cx="60" cy="96" rx="13" ry="30" transform="rotate(-40 60 96)" fill="${hex(t.stripe[1])}"/>'
            '<ellipse cx="96" cy="118" rx="11" ry="24" transform="rotate(20 96 118)" fill="${hex(t.mid)}"/>',
      ),
    Cause.fiertes => (
        200,
        130,
        '<g fill="none" stroke-width="10">'
            '${[for (var i = 0; i < t.stripe.length; i++) '<path d="M${10 + 12 * i} 130a${90 - 12 * i} ${90 - 12 * i} 0 0 1 ${180 - 24 * i} 0" stroke="${hex(t.stripe[i])}"/>'].join()}'
            '</g>',
      ),
    Cause.paix => (
        180,
        180,
        '<g fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="12" stroke-linecap="round">'
            '<circle cx="90" cy="90" r="62"/><path d="M90 28v124M90 90l-44 44M90 90l44 44"/></g>'
            '<circle cx="30" cy="150" r="16" fill="$pop"/>',
      ),
    Cause.social => (
        200,
        140,
        '<path d="M60 -10 L100 -10 L40 150 L0 150 Z" $white/>'
            '<path d="M130 -10 L170 -10 L110 150 L70 150 Z" $white/>'
            '<circle cx="150" cy="40" r="26" fill="$pop"/>',
      ),
    Cause.sante => (
        200,
        140,
        '<path d="M120 20h22v22h22v22h-22v22h-22V64H98V42h22z" $white/>'
            '<path d="M60 80h12v12h12v12H72v12H60v-12H48V92h12z" $white/>'
            '<circle cx="176" cy="104" r="20" fill="$pop"/>',
      ),
    Cause.education => (
        200,
        140,
        '<g $white>${[
          for (final y in [20, 50, 80, 110])
            for (final x in [70, 100, 130])
              if (!(y == 50 && x == 130)) '<circle cx="$x" cy="$y" r="6"/>'
        ].join()}</g>'
            '<circle cx="160" cy="50" r="24" fill="$pop"/>',
      ),
    Cause.autre => (
        200,
        140,
        '<circle cx="80" cy="40" r="30" $white/><circle cx="130" cy="90" r="22" $white/>'
            '<circle cx="160" cy="36" r="24" fill="$pop"/>',
      ),
  };
}
