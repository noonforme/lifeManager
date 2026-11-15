import 'package:flutter/material.dart';

abstract final class LifeOsColors {
  static const graphite = Color(0xff20262d);
  static const paper = Color(0xfff4f5f5);
  static const surface = Color(0xffe8ebed);
  static const rule = Color(0xffc5cbd0);
  static const measuredBlue = Color(0xff315e8a);
  static const signalOrange = Color(0xffb65d24);
}

ThemeData buildLifeOsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LifeOsColors.measuredBlue,
    brightness: Brightness.light,
    surface: LifeOsColors.paper,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: LifeOsColors.paper,
    dividerColor: LifeOsColors.rule,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    visualDensity: VisualDensity.compact,
    splashFactory: NoSplash.splashFactory,
  );
}
