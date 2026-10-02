import 'package:flutter/material.dart';

import 'lifeos_skin.dart';
import 'lifeos_tokens.dart';

/// The Material theme of the active skin, so forms, dialogs and menus that
/// still use Material controls follow the appearance like every LifeOS
/// control does. Buttons are painted with the skin's key surfaces.
ThemeData lifeOSThemeFor(LifeOSSkinData skin) {
  final t = skin.tokens;
  final type = skin.typography;
  final dark = relativeLuminance(t.paper) < 0.4;
  final scheme = ColorScheme(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: t.ink,
    onPrimary: t.paper,
    primaryContainer: t.selWash,
    onPrimaryContainer: t.selInk,
    secondary: t.head,
    onSecondary: t.headInk,
    tertiary: t.runInk,
    onTertiary: t.paper,
    error: t.negative,
    onError: t.paper,
    surface: t.paper,
    onSurface: t.ink,
    onSurfaceVariant: t.muted,
    surfaceContainerHighest: t.band,
    outline: t.muted,
    outlineVariant: t.chromeLine,
  );
  TextStyle ink(TextStyle style) => style.copyWith(color: t.ink);
  final textTheme = TextTheme(
    headlineSmall: ink(type.title.copyWith(fontSize: 20, height: 1.2)),
    titleLarge: ink(type.title),
    titleMedium: ink(type.title),
    titleSmall: ink(type.body.copyWith(fontWeight: FontWeight.w700)),
    bodyLarge: ink(type.body),
    bodyMedium: ink(type.body),
    bodySmall: type.small.copyWith(color: t.muted),
    labelLarge: ink(type.body.copyWith(fontWeight: FontWeight.w600)),
    labelMedium: ink(type.small),
    labelSmall: type.small.copyWith(color: t.muted),
  );

  ButtonStyle key(KeyKind kind) => ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => skin.painters
          .key(
            t,
            kind,
            KeyState(enabled: !states.contains(WidgetState.disabled)),
          )
          .ink,
    ),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(24, 30)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    textStyle: WidgetStatePropertyAll(
      type.body.copyWith(
        fontWeight: kind == KeyKind.primary ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
    backgroundBuilder: (context, states, child) => DecoratedBox(
      decoration: skin.painters
          .key(
            t,
            kind,
            KeyState(
              enabled: !states.contains(WidgetState.disabled),
              pressed: states.contains(WidgetState.pressed),
              hovered: states.contains(WidgetState.hovered),
            ),
          )
          .decoration,
      child: child,
    ),
  );

  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: color, width: width),
      );
  final menuShape = RoundedRectangleBorder(
    borderRadius: const BorderRadius.all(Radius.circular(4)),
    side: BorderSide(color: t.muted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    fontFamily: type.body.fontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: t.ground,
    canvasColor: t.paper,
    dividerColor: t.chromeLine,
    dividerTheme: DividerThemeData(color: t.chromeLine, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: t.ink, size: 18),
    focusColor: t.selWash,
    hoverColor: t.ink.withValues(alpha: 0.06),
    splashFactory: NoSplash.splashFactory,
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    filledButtonTheme: FilledButtonThemeData(style: key(KeyKind.primary)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: key(KeyKind.primary)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: key(KeyKind.secondary)),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled) ? t.muted : t.ink,
        ),
        overlayColor: WidgetStatePropertyAll(t.ink.withValues(alpha: 0.06)),
        textStyle: WidgetStatePropertyAll(
          type.body.copyWith(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.paper,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: type.small.copyWith(color: t.muted),
      floatingLabelStyle: type.small.copyWith(color: t.ink),
      hintStyle: type.body.copyWith(color: t.muted),
      helperStyle: type.small.copyWith(color: t.muted),
      errorStyle: type.small.copyWith(color: t.negative),
      border: outline(t.muted),
      enabledBorder: outline(t.muted),
      disabledBorder: outline(t.chromeLine),
      focusedBorder: outline(t.focus, 2),
      errorBorder: outline(t.negative),
      focusedErrorBorder: outline(t.negative, 2),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ink,
      selectionColor: t.selWash,
      selectionHandleColor: t.ink,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? t.ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(t.paper),
      side: BorderSide(color: t.muted, width: 1.5),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(t.ink)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.paper : t.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? t.ink : t.band,
      ),
      trackOutlineColor: WidgetStatePropertyAll(t.muted),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: t.muted)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.head : t.paper,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.headInk : t.ink,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.headInk : t.ink,
        ),
        textStyle: WidgetStatePropertyAll(type.body),
        visualDensity: VisualDensity.compact,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.signal),
    popupMenuTheme: PopupMenuThemeData(
      color: t.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: menuShape,
      textStyle: type.body.copyWith(color: t.ink),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => type.body.copyWith(
          color: states.contains(WidgetState.disabled) ? t.muted : t.ink,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.paper),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(menuShape),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: menuShape,
      titleTextStyle: type.title.copyWith(color: t.ink),
      contentTextStyle: type.body.copyWith(color: t.ink),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.head,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      textStyle: type.small.copyWith(color: t.headInk),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.head,
      contentTextStyle: type.body.copyWith(color: t.headInk),
      elevation: 0,
    ),
    listTileTheme: ListTileThemeData(
      textColor: t.ink,
      iconColor: t.ink,
      selectedColor: t.selInk,
      selectedTileColor: t.selWash,
    ),
  );
}

/// The Office Machine theme without a skin scope, for the app's base
/// theme and for widget tests that pump a form on its own.
ThemeData buildLifeOSTheme({required bool highContrast}) {
  const skin = OfficeMachineSkin();
  return lifeOSThemeFor(
    LifeOSSkinData(
      skin: skin,
      tokens: skin.tokensFor(Brightness.light, highContrast: highContrast),
      typography: skin.typographyFor(TextScaler.noScaling),
    ),
  );
}
