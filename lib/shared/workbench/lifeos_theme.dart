import 'package:flutter/material.dart';

abstract final class LifeOSColors {
  static const ground = Color(0xffeef0f2);
  static const surface = Color(0xfffafbfc);
  static const rail = Color(0xffe2e6ea);
  static const ink = Color(0xff20272f);
  static const muted = Color(0xff596674);
  static const boundary = Color(0xff8995a2);
  static const selection = Color(0xff245f96);
  static const selectionWash = Color(0xffdce9f5);
  static const warning = Color(0xffa85216);
  static const focus = Color(0xff174f84);
}

abstract final class LifeOSMetrics {
  static const railWidth = 216.0;
  static const minimumRegisterWidth = 560.0;
  static const inspectorWidth = 400.0;
  static const sequentialThreshold = 1138.0;
  static const separatorWidth = 1.0;
  static const controlHeight = 40.0;
}

ThemeData buildLifeOSTheme({required bool highContrast}) {
  final boundary = highContrast
      ? const Color(0xff33404d)
      : LifeOSColors.boundary;
  final scheme = ColorScheme.fromSeed(
    seedColor: LifeOSColors.selection,
    brightness: Brightness.light,
    surface: LifeOSColors.surface,
    error: const Color(0xff9f2432),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LifeOSColors.ground,
    dividerColor: boundary,
    dividerTheme: DividerThemeData(color: boundary, thickness: 1, space: 1),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: LifeOSColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      titleMedium: TextStyle(
        color: LifeOSColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyMedium: TextStyle(color: LifeOSColors.ink, fontSize: 14, height: 1.4),
      labelLarge: TextStyle(
        color: LifeOSColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    focusColor: LifeOSColors.focus,
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    splashFactory: NoSplash.splashFactory,
  );
}

Duration lifeOSTransitionDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 120);
