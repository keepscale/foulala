// GÉNÉRÉ par tool/gen_tokens.dart depuis design/tokens.json.
// Ne pas modifier à la main : changer tokens.json puis relancer le générateur.

import 'dart:ui';

import '../../../domain/models/cause.g.dart';

abstract final class FoulalaFonts {
  static const display = 'Bricolage Grotesque';
  static const body = 'Figtree';
  static const mono = 'IBM Plex Mono';
}

abstract final class FoulalaColors {
  static const text = Color(0xFF1D1A33);
  static const textMuted = Color(0xFF5D5A72);
  static const background = Color(0xFFF7F6FB);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E2EE);
  static const brand = [Color(0xFFFFC531), Color(0xFFFF5FA2), Color(0xFF49A8FF)];
}

abstract final class FoulalaRadius {
  static const double chip = 999;
  static const double button = 18;
  static const double card = 20;
  static const double sheet = 28;
}

/// Seuil d'anonymat : un groupe de moins de 20 personnes n'est jamais affiché.
const privacyThreshold = 20;

/// Thème visuel d'une cause (voir le skill theme-cause pour le rôle de chaque couleur).
class CauseTheme {
  const CauseTheme({
    required this.label,
    required this.icon,
    required this.primary,
    required this.deep,
    required this.soft,
    required this.mid,
    required this.pop,
    required this.stripe,
    required this.scale,
  });

  final String label;
  final String icon;
  final Color primary;
  final Color deep;
  final Color soft;
  final Color mid;
  final Color pop;
  final List<Color> stripe;
  final List<Color> scale;
}

extension CauseThemes on Cause {
  CauseTheme get theme => switch (this) {
        Cause.climat => const CauseTheme(
            label: 'Climat',
            icon: 'leaf',
            primary: Color(0xFF17855A),
            deep: Color(0xFF0E5C3D),
            soft: Color(0xFFE3F6EA),
            mid: Color(0xFF8EDBAE),
            pop: Color(0xFFFFC531),
            stripe: [Color(0xFF17855A), Color(0xFF3DD68C), Color(0xFFFFC531)],
            scale: [Color(0xFFCDEFD9), Color(0xFF8EDBAE), Color(0xFF3DB97A), Color(0xFF17855A)],
          ),
        Cause.fiertes => const CauseTheme(
            label: 'Fiertés',
            icon: 'rainbow',
            primary: Color(0xFF6D35D9),
            deep: Color(0xFF4A1FA0),
            soft: Color(0xFFF0E8FF),
            mid: Color(0xFFBC9BFA),
            pop: Color(0xFFFF5FA2),
            stripe: [Color(0xFFE8413C), Color(0xFFF7932E), Color(0xFFFCD535), Color(0xFF3BB26A), Color(0xFF2F7FE0), Color(0xFF7A3FD6)],
            scale: [Color(0xFFE2D4FF), Color(0xFFBC9BFA), Color(0xFF9466EE), Color(0xFF6D35D9)],
          ),
        Cause.paix => const CauseTheme(
            label: 'Paix',
            icon: 'peace',
            primary: Color(0xFF1F64D6),
            deep: Color(0xFF174DA8),
            soft: Color(0xFFE4EEFF),
            mid: Color(0xFF9DC0FF),
            pop: Color(0xFFFFB020),
            stripe: [Color(0xFF1F64D6), Color(0xFF8EC3FF), Color(0xFFFFB020)],
            scale: [Color(0xFFD3E3FF), Color(0xFF9DC0FF), Color(0xFF5B92F0), Color(0xFF1F64D6)],
          ),
        Cause.social => const CauseTheme(
            label: 'Social',
            icon: 'megaphone',
            primary: Color(0xFFD2362B),
            deep: Color(0xFFA3241C),
            soft: Color(0xFFFFE7E3),
            mid: Color(0xFFFF8A7F),
            pop: Color(0xFFFFD23F),
            stripe: [Color(0xFFD2362B), Color(0xFFFF8A7F), Color(0xFFFFD23F)],
            scale: [Color(0xFFFFD6CF), Color(0xFFFF9F94), Color(0xFFE85A4E), Color(0xFFD2362B)],
          ),
        Cause.sante => const CauseTheme(
            label: 'Santé',
            icon: 'cross',
            primary: Color(0xFF0B8291),
            deep: Color(0xFF086570),
            soft: Color(0xFFDDF4F6),
            mid: Color(0xFF6FD3DE),
            pop: Color(0xFFFF8FA3),
            stripe: [Color(0xFF0B8291), Color(0xFF6FD3DE), Color(0xFFFF8FA3)],
            scale: [Color(0xFFC9EEF2), Color(0xFF8EDDE6), Color(0xFF3BB3C1), Color(0xFF0B8291)],
          ),
        Cause.education => const CauseTheme(
            label: 'Éducation',
            icon: 'graduation',
            primary: Color(0xFFB35F00),
            deep: Color(0xFF8A4900),
            soft: Color(0xFFFFF1D6),
            mid: Color(0xFFFFB020),
            pop: Color(0xFF5BC0EB),
            stripe: [Color(0xFFB35F00), Color(0xFFFFB020), Color(0xFF5BC0EB)],
            scale: [Color(0xFFFFE4B8), Color(0xFFFFC266), Color(0xFFE08A1E), Color(0xFFB35F00)],
          ),
        Cause.autre => const CauseTheme(
            label: 'Autre',
            icon: 'flag',
            primary: Color(0xFF4D4A63),
            deep: Color(0xFF1D1A33),
            soft: Color(0xFFEDECF3),
            mid: Color(0xFFB9B6CC),
            pop: Color(0xFFFFC531),
            stripe: [Color(0xFF4D4A63), Color(0xFFB9B6CC), Color(0xFFFFC531)],
            scale: [Color(0xFFE1DFEA), Color(0xFFB9B6CC), Color(0xFF8784A0), Color(0xFF4D4A63)],
          ),
      };
}
