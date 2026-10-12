import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Styles de texte. Bricolage Grotesque et Figtree sont des polices variables :
/// `fontWeight` seul ne change pas leur graisse, il faut passer par [FontVariation].
abstract final class FoulalaText {
  /// Titres : Bricolage Grotesque 800, taille optique calée sur la taille du texte.
  static TextStyle display(double size, {Color? color, double height = 1.05, double letterSpacing = -0.02}) =>
      TextStyle(
        fontFamily: FoulalaFonts.display,
        fontSize: size,
        fontWeight: FontWeight.w800,
        fontVariations: [
          const FontVariation.weight(800),
          FontVariation.opticalSize(size.clamp(12, 96).toDouble()),
        ],
        height: height,
        letterSpacing: size * letterSpacing,
        color: color,
      );

  /// Texte courant : Figtree.
  static TextStyle body(double size, {int weight = 400, Color? color, double? height, double? letterSpacing}) =>
      TextStyle(
        fontFamily: FoulalaFonts.body,
        fontSize: size,
        fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
        fontVariations: [FontVariation.weight(weight.toDouble())],
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  /// Jeton : IBM Plex Mono.
  static TextStyle mono(double size, {Color? color}) =>
      TextStyle(fontFamily: FoulalaFonts.mono, fontSize: size, fontWeight: FontWeight.w500, color: color);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: FoulalaColors.text,
    onPrimary: FoulalaColors.surface,
    secondary: Color(0xFFE0357C), // rose du logotype
    surface: FoulalaColors.surface,
    onSurface: FoulalaColors.text,
    onSurfaceVariant: FoulalaColors.textMuted,
    outline: FoulalaColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FoulalaColors.background,
    fontFamily: FoulalaFonts.body,
    textTheme: TextTheme(
      displayLarge: FoulalaText.display(38, height: 1, letterSpacing: -0.03),
      headlineMedium: FoulalaText.display(28),
      titleLarge: FoulalaText.display(22),
      titleMedium: FoulalaText.body(17, weight: 700, height: 1.2),
      bodyLarge: FoulalaText.body(16),
      bodyMedium: FoulalaText.body(15, height: 1.4),
      bodySmall: FoulalaText.body(14, color: FoulalaColors.textMuted),
      labelLarge: FoulalaText.body(15, weight: 700),
      labelMedium: FoulalaText.body(13, weight: 800),
      labelSmall: FoulalaText.body(12, weight: 700),
    ).apply(bodyColor: FoulalaColors.text, displayColor: FoulalaColors.text),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: FoulalaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(FoulalaRadius.sheet))),
    ),
  );
}
