import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/models/cause.g.dart';
import '../themes/tokens.g.dart';

/// Icônes en trait, reprises des maquettes (design/maquettes). Jamais d'emoji.
/// Les noms des icônes de cause sont ceux de design/tokens.json.
enum FoulalaIcons {
  // Causes
  leaf('<path d="M5 19c0-8 5-14 15-14 0 10-6 15-14 15"/><path d="M5 19c3-4 6-7 10-9"/>'),
  rainbow('<path d="M2 20a10 10 0 0 1 20 0"/><path d="M6 20a6 6 0 0 1 12 0"/><path d="M10 20a2 2 0 0 1 4 0"/>'),
  peace('<circle cx="12" cy="12" r="9"/><path d="M12 3v18M12 12l-6.4 6.4M12 12l6.4 6.4"/>'),
  megaphone('<path d="M3 10v4h3l8 4.5V5.5L6 10H3z"/><path d="M17.5 9a4 4 0 0 1 0 6"/>'),
  cross('<path d="M9.5 3.5h5v6h6v5h-6v6h-5v-6h-6v-5h6z"/>'),
  graduation('<path d="M2 9l10-5 10 5-10 5z"/><path d="M6 11v5c3 2 9 2 12 0v-5"/>'),
  flag('<path d="M5 21V4"/><path d="M5 4h12l-2.5 4L17 12H5"/>'),
  // Interface
  pin('<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>'),
  chevronDown('<path d="M6 9l6 6 6-6"/>'),
  arrowRight('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  list('<path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>'),
  heart('<path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/>'),
  shield('<path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6l8-3z"/>'),
  check('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  arrowLeft('<path d="M19 12H5M11 6l-6 6 6 6"/>'),
  clock('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'),
  route('<circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="6" r="2.5"/><path d="M8.5 18H15a3 3 0 0 0 0-6H9a3 3 0 0 1 0-6h6.5"/>'),
  people('<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.5-3.5 3.2-5.5 6.5-5.5s6 2 6.5 5.5"/>'
      '<path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c2 .7 3.3 2.5 3.5 5.2"/>'),
  lock('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'),
  locate('<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>'),
  refresh('<path d="M20 11a8 8 0 1 0-2.3 5.7"/><path d="M20 5v6h-6"/>'),
  wifiOff('<path d="M2 8.5a15 15 0 0 1 20 0M5 12a10 10 0 0 1 14 0M8.5 15.5a5 5 0 0 1 7 0M12 19h.01"/><path d="M3 3l18 18"/>');

  const FoulalaIcons(this.paths);
  final String paths;

  static FoulalaIcons forCause(Cause cause) => FoulalaIcons.values.byName(cause.theme.icon);
}

class FoulalaIcon extends StatelessWidget {
  const FoulalaIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color = FoulalaColors.text,
    this.strokeWidth = 2.2,
    this.filled = false,
  });

  final FoulalaIcons icon;
  final double size;
  final Color color;
  final double strokeWidth;

  /// Forme pleine (cœur « Soutenu »), en plus du trait.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${filled ? '#000' : 'none'}" stroke="#000" '
        'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">${icon.paths}</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
