// Génère, depuis design/tokens.json :
//   - lib/domain/models/cause.g.dart : l'énumération des causes (Dart pur) ;
//   - lib/ui/core/themes/tokens.g.dart : polices, couleurs, rayons et thème de chaque cause.
//
//   cd app && dart run tool/gen_tokens.dart
//
// Le test test/tokens_test.dart échoue si les fichiers générés ne sont plus à jour.
import 'dart:convert';
import 'dart:io';

const tokensPath = '../design/tokens.json';
const causePath = 'lib/domain/models/cause.g.dart';
const themePath = 'lib/ui/core/themes/tokens.g.dart';

void main() {
  final json = jsonDecode(File(tokensPath).readAsStringSync()) as Map<String, dynamic>;
  File(causePath).writeAsStringSync(generateCause(json));
  File(themePath).writeAsStringSync(generateTheme(json));
  stdout.writeln('$causePath et $themePath générés depuis $tokensPath');
}

const _header = '// GÉNÉRÉ par tool/gen_tokens.dart depuis design/tokens.json.\n'
    '// Ne pas modifier à la main : changer tokens.json puis relancer le générateur.\n';

String generateCause(Map<String, dynamic> json) {
  final ids = (json['causes'] as Map<String, dynamic>).keys;
  return '$_header\n'
      '/// Cause d\'une manif : mêmes identifiants que le type SQL `event_cause`.\n'
      'enum Cause { ${ids.join(', ')} }\n';
}

String generateTheme(Map<String, dynamic> json) {
  final fonts = json['fonts'] as Map<String, dynamic>;
  final colors = json['colors'] as Map<String, dynamic>;
  final radius = json['radius'] as Map<String, dynamic>;
  final causes = json['causes'] as Map<String, dynamic>;

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln("import 'dart:ui';")
    ..writeln()
    ..writeln("import '../../../domain/models/cause.g.dart';")
    ..writeln()
    ..writeln('abstract final class FoulalaFonts {');
  fonts.forEach((k, v) => b.writeln("  static const $k = '$v';"));
  b
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class FoulalaColors {');
  colors.forEach((k, v) {
    if (v is List) {
      b.writeln('  static const $k = [${v.map(_color).join(', ')}];');
    } else {
      b.writeln('  static const $k = ${_color(v)};');
    }
  });
  b
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class FoulalaRadius {');
  radius.forEach((k, v) => b.writeln('  static const double $k = $v;'));
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// Seuil d\'anonymat : un groupe de moins de ${json['privacyThreshold']} personnes n\'est jamais affiché.')
    ..writeln('const privacyThreshold = ${json['privacyThreshold']};')
    ..writeln()
    ..writeln('/// Thème visuel d\'une cause (voir le skill theme-cause pour le rôle de chaque couleur).')
    ..writeln('class CauseTheme {')
    ..writeln('  const CauseTheme({')
    ..writeln('    required this.label,')
    ..writeln('    required this.icon,')
    ..writeln('    required this.primary,')
    ..writeln('    required this.deep,')
    ..writeln('    required this.soft,')
    ..writeln('    required this.mid,')
    ..writeln('    required this.pop,')
    ..writeln('    required this.stripe,')
    ..writeln('    required this.scale,')
    ..writeln('  });')
    ..writeln()
    ..writeln('  final String label;')
    ..writeln('  final String icon;')
    ..writeln('  final Color primary;')
    ..writeln('  final Color deep;')
    ..writeln('  final Color soft;')
    ..writeln('  final Color mid;')
    ..writeln('  final Color pop;')
    ..writeln('  final List<Color> stripe;')
    ..writeln('  final List<Color> scale;')
    ..writeln('}')
    ..writeln()
    ..writeln('extension CauseThemes on Cause {')
    ..writeln('  CauseTheme get theme => switch (this) {');
  causes.forEach((id, value) {
    final c = value as Map<String, dynamic>;
    b
      ..writeln('        Cause.$id => const CauseTheme(')
      ..writeln("            label: '${c['label']}',")
      ..writeln("            icon: '${c['icon']}',")
      ..writeln('            primary: ${_color(c['primary'])},')
      ..writeln('            deep: ${_color(c['deep'])},')
      ..writeln('            soft: ${_color(c['soft'])},')
      ..writeln('            mid: ${_color(c['mid'])},')
      ..writeln('            pop: ${_color(c['pop'])},')
      ..writeln('            stripe: [${(c['stripe'] as List).map(_color).join(', ')}],')
      ..writeln('            scale: [${(c['scale'] as List).map(_color).join(', ')}],')
      ..writeln('          ),');
  });
  b
    ..writeln('      };')
    ..writeln('}');
  return b.toString();
}

String _color(dynamic hex) {
  final h = (hex as String).replaceFirst('#', '').toUpperCase();
  return 'Color(0xFF$h)';
}
