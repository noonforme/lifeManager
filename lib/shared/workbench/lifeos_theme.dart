import 'package:flutter/material.dart';

import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// The Material theme of the LifeOS style, so forms, dialogs and menus that
/// use Material controls look like every LifeOS control. Buttons are
/// painted with the style's key surfaces.
ThemeData lifeOSThemeFor(LifeOSSkinData skin) {
  final t = skin.tokens;
  final type = skin.typography;
  final scheme = ColorScheme(
    brightness: Brightness.light,
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
    headlineSmall: ink(type.strong),
    titleLarge: ink(type.strong),
    titleMedium: ink(type.strong),
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
    minimumSize: const WidgetStatePropertyAll(Size(24, 24)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(type.body),
    // The same face and rings as a KeyButton, so a form's keys match the
    // property sheet's.
    backgroundBuilder: (context, states, child) {
      final surface = skin.painters.key(
        t,
        kind,
        KeyState(
          enabled: !states.contains(WidgetState.disabled),
          pressed: states.contains(WidgetState.pressed),
          hovered: states.contains(WidgetState.hovered),
          focused: states.contains(WidgetState.focused),
        ),
      );
      final rings = surface.rings;
      return DecoratedBox(
        decoration: surface.decoration,
        child: rings == null
            ? child
            : DecoratedBox(
                decoration: InsetRings(rings.$1, rings.$2),
                position: DecorationPosition.foreground,
                child: child,
              ),
      );
    },
  );

  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        borderSide: BorderSide(color: color, width: width),
      );
  // Era menus are square with a thin grey outline.
  final menuShape = RoundedRectangleBorder(side: BorderSide(color: t.muted));

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    fontFamily: type.body.fontFamily,
    fontFamilyFallback: type.body.fontFamilyFallback,
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
      // A disabled box sits on the face colour, as the era greyed one.
      fillColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? t.chrome : t.paper,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: type.small.copyWith(color: t.muted),
      floatingLabelStyle: type.small.copyWith(color: t.ink),
      hintStyle: type.body.copyWith(color: t.muted),
      helperStyle: type.small.copyWith(color: t.muted),
      errorStyle: type.small.copyWith(color: t.negative),
      border: outline(MillenniumColors.fieldLine),
      enabledBorder: outline(MillenniumColors.fieldLine),
      disabledBorder: outline(t.chromeLine),
      // Keyboard focus turns the border key-outline blue (spec 5.6).
      focusedBorder: outline(MillenniumColors.keyLine),
      errorBorder: outline(t.negative),
      focusedErrorBorder: outline(t.negative),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ink,
      selectionColor: t.selWash,
      selectionHandleColor: t.ink,
    ),
    // A white box with a green tick, and a green radio dot (spec 5.6).
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStatePropertyAll(t.paper),
      checkColor: const WidgetStatePropertyAll(MillenniumColors.orbGreen),
      side: const BorderSide(color: MillenniumColors.fieldLine),
      shape: const RoundedRectangleBorder(),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MillenniumColors.orbGreen
            : MillenniumColors.fieldLine,
      ),
    ),
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
      // An era modal left the window behind as it was; nothing dims it.
      barrierColor: Colors.transparent,
      backgroundColor: t.chrome,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: MillenniumColors.keyLine),
      ),
      titleTextStyle: type.strong.copyWith(color: t.ink),
      contentTextStyle: type.body.copyWith(color: t.ink),
    ),
    // The era's tooltip: black text on pale yellow, a black edge, square
    // corners, shown after a short rest and gone the moment the pointer
    // leaves.
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: MillenniumColors.tooltip,
        border: Border.all(color: t.ink),
      ),
      textStyle: type.body.copyWith(color: t.ink),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: EdgeInsets.zero,
      verticalOffset: 14,
      waitDuration: const Duration(milliseconds: 500),
      exitDuration: Duration.zero,
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

/// The LifeOS Material theme without a skin scope, for the app's base theme
/// and for widget tests that pump a form on its own.
ThemeData buildLifeOSTheme() => lifeOSThemeFor(LifeOSSkinData.standard);
