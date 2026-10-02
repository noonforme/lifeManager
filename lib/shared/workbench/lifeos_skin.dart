import 'package:flutter/widgets.dart';

import 'lifeos_tokens.dart';
import 'skins/millennium_skin.dart';

/// Text styles of one skin. Colours are applied by the widget from tokens.
@immutable
final class LifeOSTypography {
  const LifeOSTypography({
    required this.title,
    required this.label,
    required this.body,
    required this.small,
    required this.figure,
    required this.counter,
  });

  /// Inspector record title.
  final TextStyle title;

  /// Column headers, section labels and the tree header (uppercase).
  final TextStyle label;

  /// Controls, entries and menus.
  final TextStyle body;

  /// Secondary lines and hints.
  final TextStyle small;

  /// Dates, times, durations, money and counts (tabular).
  final TextStyle figure;

  /// Counter tiles.
  final TextStyle counter;
}

/// How a skin marks the four areas.
enum AreaMarkerStyle { colour, pattern }

/// The kinds of key button a skin paints.
enum KeyKind { primary, secondary, small }

/// Interaction state a key is painted in.
@immutable
final class KeyState {
  const KeyState({
    this.enabled = true,
    this.pressed = false,
    this.hovered = false,
  });

  final bool enabled;
  final bool pressed;
  final bool hovered;
}

/// What a skin paints for one key: its face, text colour and the pressable
/// edge under the face. [topInset] plus [edgeWidth] stays constant, so
/// pressing a key lowers its face without moving anything around it.
@immutable
final class KeySurface {
  const KeySurface({
    required this.decoration,
    required this.ink,
    required this.edgeColor,
    required this.edgeWidth,
    required this.topInset,
    required this.radius,
  });

  final BoxDecoration decoration;
  final Color ink;
  final Color edgeColor;
  final double edgeWidth;
  final double topInset;
  final BorderRadius radius;
}

/// How the status line is painted.
@immutable
final class StatusLineStyle {
  const StatusLineStyle({
    required this.fill,
    required this.ink,
    required this.alertInk,
    required this.indicator,
    required this.divider,
  });

  final Decoration fill;
  final Color ink;

  /// Text of an uncertain save.
  final Color alertInk;

  /// The running-shift dot.
  final Color indicator;
  final Color divider;
}

/// The painting a skin supplies for LifeOS-owned controls. Widgets ask the
/// skin how to look; they never branch on which skin is active. No painter
/// may change a control's size: borders keep the widths the Office Machine
/// painters use.
abstract interface class SkinPainters {
  KeySurface key(LifeOSTokens tokens, KeyKind kind, KeyState state);

  BoxDecoration areaMarker(LifeOSTokens tokens, LifeOSArea area);

  BoxDecoration countBadge(LifeOSTokens tokens);

  /// The count's text on [countBadge].
  Color countBadgeInk(LifeOSTokens tokens);

  /// The keyboard focus ring drawn around a focused control.
  Decoration focusRing(LifeOSTokens tokens);

  /// The toolbar under the menu bar, with its 1-pixel bottom line.
  Decoration toolbar(LifeOSTokens tokens);

  /// Behind the book tree's rows.
  Color treeBackground(LifeOSTokens tokens);

  StatusLineStyle statusLine(LifeOSTokens tokens);

  /// The outline of the register's selected cell, drawn on [selWash].
  Color cellCursor(LifeOSTokens tokens);

  BoxDecoration segment(
    LifeOSTokens tokens, {
    required bool selected,
    required bool first,
    required bool last,
  });

  Color segmentInk(LifeOSTokens tokens, {required bool selected});
}

/// One appearance of LifeOS: tokens, typography and painters. Layout,
/// behaviour, copy and data never depend on the skin.
abstract interface class LifeOSSkin {
  String get name;

  LifeOSTokens tokensFor(Brightness brightness, {required bool highContrast});

  LifeOSTypography typographyFor(TextScaler textScaler);

  AreaMarkerStyle get areaMarkers;

  SkinPainters get painters;
}

/// The default appearance (spec section 4).
final class OfficeMachineSkin implements LifeOSSkin {
  const OfficeMachineSkin();

  static const uiFamily = 'Archivo';
  static const figureFamily = 'AzeretMono';

  static const _typography = LifeOSTypography(
    title: TextStyle(
      fontFamily: uiFamily,
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w600,
    ),
    label: TextStyle(
      fontFamily: uiFamily,
      fontSize: 10.5,
      height: 14 / 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.84,
    ),
    body: TextStyle(
      fontFamily: uiFamily,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
    ),
    small: TextStyle(
      fontFamily: uiFamily,
      fontSize: 11.5,
      height: 16 / 11.5,
      fontWeight: FontWeight.w400,
    ),
    figure: TextStyle(
      fontFamily: figureFamily,
      fontSize: 12.5,
      height: 18 / 12.5,
      fontWeight: FontWeight.w400,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    counter: TextStyle(
      fontFamily: figureFamily,
      fontSize: 20,
      height: 22 / 20,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  @override
  String get name => 'Office Machine';

  @override
  LifeOSTokens tokensFor(Brightness brightness, {required bool highContrast}) {
    if (highContrast) return LifeOSTokens.highContrast;
    return brightness == Brightness.dark
        ? LifeOSTokens.night
        : LifeOSTokens.day;
  }

  @override
  LifeOSTypography typographyFor(TextScaler textScaler) => _typography;

  @override
  AreaMarkerStyle get areaMarkers => AreaMarkerStyle.colour;

  @override
  SkinPainters get painters => const _OfficeMachinePainters();
}

final class _OfficeMachinePainters implements SkinPainters {
  const _OfficeMachinePainters();

  static const _radius = BorderRadius.all(Radius.circular(4));
  static const _edge = 2.0;

  @override
  KeySurface key(LifeOSTokens tokens, KeyKind kind, KeyState state) {
    if (!state.enabled) {
      return KeySurface(
        decoration: BoxDecoration(
          color: tokens.chrome,
          borderRadius: _radius,
          border: Border.all(color: tokens.chromeLine),
        ),
        ink: tokens.muted,
        edgeColor: tokens.chromeLine,
        edgeWidth: 0,
        topInset: _edge,
        radius: _radius,
      );
    }
    final primary = kind == KeyKind.primary;
    final fill = primary ? tokens.actionFill : tokens.paper;
    final outline = primary ? tokens.actionFill : tokens.muted;
    final face = state.hovered && !state.pressed
        ? Color.lerp(fill, tokens.ink, 0.06)!
        : fill;
    final edgeColor = Color.lerp(outline, const Color(0xff000000), 0.35)!;
    // The pressable bottom edge is the only depth in the system.
    return KeySurface(
      decoration: BoxDecoration(
        color: face,
        borderRadius: _radius,
        border: Border.all(color: outline),
      ),
      ink: primary ? tokens.actionInk : tokens.ink,
      edgeColor: edgeColor,
      edgeWidth: state.pressed ? 1 : _edge,
      topInset: state.pressed ? 1 : 0,
      radius: _radius,
    );
  }

  @override
  BoxDecoration areaMarker(LifeOSTokens tokens, LifeOSArea area) =>
      BoxDecoration(color: tokens.areaKeys[area]!.fill, borderRadius: _radius);

  @override
  BoxDecoration countBadge(LifeOSTokens tokens) =>
      BoxDecoration(color: tokens.actionFill, borderRadius: _radius);

  @override
  Color countBadgeInk(LifeOSTokens tokens) => tokens.actionInk;

  @override
  BoxDecoration focusRing(LifeOSTokens tokens) => BoxDecoration(
    borderRadius: const BorderRadius.all(Radius.circular(6)),
    border: Border.all(color: tokens.focus, width: 2),
  );

  @override
  Decoration toolbar(LifeOSTokens tokens) => BoxDecoration(
    color: tokens.chrome,
    border: Border(bottom: BorderSide(color: tokens.chromeLine)),
  );

  @override
  Color treeBackground(LifeOSTokens tokens) => tokens.paper;

  @override
  StatusLineStyle statusLine(LifeOSTokens tokens) => StatusLineStyle(
    fill: BoxDecoration(color: tokens.head),
    ink: tokens.headInk,
    alertInk: tokens.negative,
    indicator: tokens.signal,
    divider: tokens.headInk.withValues(alpha: 0.25),
  );

  @override
  Color cellCursor(LifeOSTokens tokens) => tokens.signal;

  @override
  BoxDecoration segment(
    LifeOSTokens tokens, {
    required bool selected,
    required bool first,
    required bool last,
  }) => BoxDecoration(
    color: selected ? tokens.head : tokens.paper,
    borderRadius: BorderRadius.horizontal(
      left: first ? const Radius.circular(4) : Radius.zero,
      right: last ? const Radius.circular(4) : Radius.zero,
    ),
    border: Border.all(color: tokens.muted),
  );

  @override
  Color segmentInk(LifeOSTokens tokens, {required bool selected}) =>
      selected ? tokens.headInk : tokens.ink;
}

/// The active skin and its resolved tokens and typography.
@immutable
final class LifeOSSkinData {
  const LifeOSSkinData({
    required this.skin,
    required this.tokens,
    required this.typography,
  });

  final LifeOSSkin skin;
  final LifeOSTokens tokens;
  final LifeOSTypography typography;

  SkinPainters get painters => skin.painters;
}

/// Resolves the owner's appearance against the platform and provides the
/// active skin to every LifeOS-owned widget below it.
final class LifeOSSkinScope extends StatelessWidget {
  const LifeOSSkinScope({required this.child, this.appearance, super.key});

  /// The appearance to resolve. Null uses the nearest
  /// [LifeOSAppearanceScope], or [LifeOSAppearance.system] without one.
  final LifeOSAppearance? appearance;
  final Widget child;

  static LifeOSSkinData of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_InheritedLifeOSSkin>();
    assert(scope != null, 'No LifeOSSkinScope above this widget.');
    return scope!.data;
  }

  /// The skin, brightness and contrast an appearance resolves to. The
  /// system's high-contrast setting wins over every skin (spec 4.7).
  static (LifeOSSkin, Brightness, bool) resolve(
    LifeOSAppearance appearance, {
    required Brightness platformBrightness,
    required bool platformHighContrast,
  }) {
    const office = OfficeMachineSkin();
    return switch (appearance) {
      LifeOSAppearance.system => (
        office,
        platformBrightness,
        platformHighContrast,
      ),
      LifeOSAppearance.day => (office, Brightness.light, platformHighContrast),
      LifeOSAppearance.night => (office, Brightness.dark, platformHighContrast),
      LifeOSAppearance.highContrast => (office, Brightness.light, true),
      LifeOSAppearance.millennium when platformHighContrast => (
        office,
        Brightness.light,
        true,
      ),
      LifeOSAppearance.millennium => (
        const MillenniumSkin(),
        Brightness.light,
        false,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final chosen =
        appearance ??
        LifeOSAppearanceScope.maybeOf(context)?.value ??
        LifeOSAppearance.system;
    final (skin, brightness, highContrast) = resolve(
      chosen,
      platformBrightness: MediaQuery.platformBrightnessOf(context),
      platformHighContrast: MediaQuery.highContrastOf(context),
    );
    return _InheritedLifeOSSkin(
      data: LifeOSSkinData(
        skin: skin,
        tokens: skin.tokensFor(brightness, highContrast: highContrast),
        typography: skin.typographyFor(MediaQuery.textScalerOf(context)),
      ),
      child: child,
    );
  }
}

final class _InheritedLifeOSSkin extends InheritedWidget {
  const _InheritedLifeOSSkin({required this.data, required super.child});

  final LifeOSSkinData data;

  @override
  bool updateShouldNotify(_InheritedLifeOSSkin oldWidget) =>
      data.skin != oldWidget.data.skin ||
      data.tokens != oldWidget.data.tokens ||
      data.typography != oldWidget.data.typography;
}

/// Holds the owner's appearance choice for the running app.
final class LifeOSAppearanceController extends ValueNotifier<LifeOSAppearance> {
  LifeOSAppearanceController([super.value = LifeOSAppearance.system]);
}

/// Provides the appearance controller to the View menu and the skin scope.
final class LifeOSAppearanceScope
    extends InheritedNotifier<LifeOSAppearanceController> {
  const LifeOSAppearanceScope({
    required LifeOSAppearanceController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LifeOSAppearanceController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LifeOSAppearanceScope>()
      ?.notifier;
}
