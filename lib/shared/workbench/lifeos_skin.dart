import 'package:flutter/widgets.dart';

import 'lifeos_tokens.dart';
import 'millennium_style.dart';

/// LifeOS text styles. Colours are applied by the widget from tokens.
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

  /// Column headers and group-box legends.
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

/// Interaction state a key is painted in.
@immutable
final class KeyState {
  const KeyState({
    this.enabled = true,
    this.pressed = false,
    this.hovered = false,
    this.focused = false,
  });

  final bool enabled;
  final bool pressed;
  final bool hovered;
  final bool focused;
}

/// The kinds of key LifeOS paints: [primary] is the default push button,
/// [secondary] an ordinary push button, [small] a compact push button and
/// [toolbar] a flat key that rises when hovered, focused or pressed.
enum KeyKind { primary, secondary, small, toolbar }

/// What one key looks like: its face, text colour and optional inner rings.
@immutable
final class KeySurface {
  const KeySurface({required this.decoration, required this.ink, this.rings});

  final BoxDecoration decoration;
  final Color ink;

  /// (outer, inner) 1-pixel rings inside the outline, or none.
  final (Color, Color)? rings;
}

/// The LifeOS style: tokens, typography and painters.
@immutable
final class LifeOSSkinData {
  const LifeOSSkinData({
    required this.tokens,
    required this.typography,
    required this.painters,
  });

  /// The one LifeOS style.
  static const standard = LifeOSSkinData(
    tokens: LifeOSTokens.millennium,
    typography: lifeOSTypography,
    painters: LifeOSPainters(),
  );

  final LifeOSTokens tokens;
  final LifeOSTypography typography;
  final LifeOSPainters painters;
}

/// Provides the LifeOS style to every LifeOS-owned widget below it.
final class LifeOSSkinScope extends StatelessWidget {
  const LifeOSSkinScope({required this.child, super.key});

  final Widget child;

  /// The style above [context]. There is one style, so a dialog or popup
  /// route pushed above a scope still gets it.
  static LifeOSSkinData of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_InheritedLifeOSSkin>()
          ?.data ??
      LifeOSSkinData.standard;

  @override
  Widget build(BuildContext context) =>
      _InheritedLifeOSSkin(data: LifeOSSkinData.standard, child: child);
}

final class _InheritedLifeOSSkin extends InheritedWidget {
  const _InheritedLifeOSSkin({required this.data, required super.child});

  final LifeOSSkinData data;

  @override
  bool updateShouldNotify(_InheritedLifeOSSkin oldWidget) =>
      data != oldWidget.data;
}
