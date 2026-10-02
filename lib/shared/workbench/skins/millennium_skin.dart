import 'package:flutter/widgets.dart';

import '../lifeos_skin.dart';
import '../lifeos_tokens.dart';

/// Millennium: a friendly, glossy office PC, inspired by the 2001 desktop
/// era (shell spec 4.7). It changes painting only; every control keeps its
/// place, size and behaviour. It uses no vendor names, logos, icons,
/// wallpapers or sounds.
final class MillenniumSkin implements LifeOSSkin {
  const MillenniumSkin();

  static const family = 'NotoSans';

  /// The Millennium palette. It has no night variant. `runInk`,
  /// `positive` and `signal` are a shade darker than the spec's table so
  /// every text pair meets 4.5:1 and every indicator 3:1.
  static const tokens = LifeOSTokens(
    ground: Color(0xffece9d8),
    paper: Color(0xffffffff),
    ink: Color(0xff000000),
    muted: Color(0xff555555),
    rule: Color(0xffecebe5),
    band: Color(0xfff1efe2),
    chrome: Color(0xffece9d8),
    chromeLine: Color(0xffc5c2b2),
    head: Color(0xff0046d5),
    headInk: Color(0xffffffff),
    signal: Color(0xffd9500b),
    actionFill: Color(0xffffffff),
    actionInk: Color(0xff000000),
    runInk: Color(0xffb83d0b),
    selWash: Color(0xff316ac5),
    selInk: Color(0xffffffff),
    negative: Color(0xffcc0000),
    positive: Color(0xff2a752d),
    focus: Color(0xff000000),
    areaKeys: LifeOSTokens.dayAreaKeys,
  );

  /// Task-pane links, 5.5:1 on [paneBody].
  static const link = Color(0xff1c50b0);
  static const paneTop = Color(0xff7ba2e7);
  static const paneBottom = Color(0xff6375d6);
  static const paneBody = Color(0xffd6dff7);

  /// The top edge of the active desk tab, and the selected-cell outline.
  static const tabAccent = Color(0xffffc83c);
  static const progress = Color(0xff2fbf2f);

  /// The dark blue outline of keys.
  static const keyLine = Color(0xff003c74);

  static const _typography = LifeOSTypography(
    title: TextStyle(
      fontFamily: family,
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w600,
    ),
    label: TextStyle(
      fontFamily: family,
      fontSize: 10.5,
      height: 14 / 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.84,
    ),
    body: TextStyle(
      fontFamily: family,
      fontSize: 13,
      height: 18 / 13,
      fontWeight: FontWeight.w500,
    ),
    small: TextStyle(
      fontFamily: family,
      fontSize: 11.5,
      height: 16 / 11.5,
      fontWeight: FontWeight.w400,
    ),
    figure: TextStyle(
      fontFamily: family,
      fontSize: 12.5,
      height: 18 / 12.5,
      fontWeight: FontWeight.w400,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    counter: TextStyle(
      fontFamily: family,
      fontSize: 20,
      height: 22 / 20,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  @override
  String get name => 'Millennium';

  /// Millennium keeps its own palette whatever the system brightness. The
  /// skin scope switches to Office Machine when high contrast is on.
  @override
  LifeOSTokens tokensFor(Brightness brightness, {required bool highContrast}) =>
      highContrast ? LifeOSTokens.highContrast : tokens;

  @override
  LifeOSTypography typographyFor(TextScaler textScaler) => _typography;

  @override
  AreaMarkerStyle get areaMarkers => AreaMarkerStyle.colour;

  @override
  SkinPainters get painters => const _MillenniumPainters();
}

final class _MillenniumPainters implements SkinPainters {
  const _MillenniumPainters();

  static const _radius = BorderRadius.all(Radius.circular(3));

  // The same edge arithmetic as Office Machine keeps every key the same
  // size: [topInset] plus [edgeWidth] is always 2.
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
    final hot = state.hovered && !state.pressed;
    // A white-to-face gloss; the default (primary) key carries a blue ring
    // painted inside the face as the gradient's outer stops.
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        if (primary) const Color(0xffcedcf6),
        if (hot) const Color(0xfffff4d6) else tokens.paper,
        state.pressed ? const Color(0xffe3e1d6) : const Color(0xfff6f5ef),
        tokens.chrome,
        if (primary) const Color(0xff9db7ec),
      ],
      stops: primary ? const [0, 0.14, 0.5, 0.86, 1] : const [0, 0.5, 1],
    );
    return KeySurface(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: _radius,
        border: Border.all(color: MillenniumSkin.keyLine),
      ),
      ink: tokens.actionInk,
      edgeColor: const Color(0xffb7b4a4),
      edgeWidth: state.pressed ? 1 : _edge,
      topInset: state.pressed ? 1 : 0,
      radius: _radius,
    );
  }

  @override
  BoxDecoration areaMarker(LifeOSTokens tokens, LifeOSArea area) {
    final fill = tokens.areaKeys[area]!.fill;
    return BoxDecoration(
      borderRadius: _radius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(fill, tokens.paper, 0.35)!, fill, fill],
        stops: const [0, 0.5, 1],
      ),
    );
  }

  @override
  BoxDecoration countBadge(LifeOSTokens tokens) => BoxDecoration(
    color: tokens.runInk,
    borderRadius: const BorderRadius.all(Radius.circular(8)),
  );

  @override
  Color countBadgeInk(LifeOSTokens tokens) => tokens.headInk;

  @override
  Decoration focusRing(LifeOSTokens tokens) =>
      _DottedRectangle(color: tokens.focus);

  @override
  Decoration toolbar(LifeOSTokens tokens) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xfff7f6f0), tokens.chrome],
    ),
    border: Border(bottom: BorderSide(color: tokens.chromeLine)),
  );

  @override
  Color treeBackground(LifeOSTokens tokens) => MillenniumSkin.paneBody;

  /// A face-coloured status bar, as the era had, rather than a dark strip.
  @override
  StatusLineStyle statusLine(LifeOSTokens tokens) => StatusLineStyle(
    // No border: one would push the text down a pixel.
    fill: BoxDecoration(color: tokens.chrome),
    ink: tokens.ink,
    alertInk: tokens.negative,
    indicator: tokens.signal,
    divider: tokens.chromeLine,
  );

  @override
  Color cellCursor(LifeOSTokens tokens) => MillenniumSkin.tabAccent;

  /// Property-sheet tabs: the active tab is white with a warm top edge,
  /// painted inside the same 1-pixel border every tab has, so none
  /// changes size.
  @override
  BoxDecoration segment(
    LifeOSTokens tokens, {
    required bool selected,
    required bool first,
    required bool last,
  }) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: selected
          ? [
              MillenniumSkin.tabAccent,
              MillenniumSkin.tabAccent,
              tokens.paper,
              tokens.paper,
            ]
          : [tokens.paper, tokens.chrome],
      stops: selected ? const [0, 0.12, 0.12, 1] : null,
    ),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    border: Border.all(color: tokens.chromeLine),
  );

  @override
  Color segmentInk(LifeOSTokens tokens, {required bool selected}) => tokens.ink;
}

/// The era's dotted focus rectangle.
final class _DottedRectangle extends Decoration {
  const _DottedRectangle({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedPainter(color);

  @override
  bool operator ==(Object other) =>
      other is _DottedRectangle && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

final class _DottedPainter extends BoxPainter {
  _DottedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    // Inset to sit where Office Machine's 2-pixel ring sits.
    final rect = (offset & size).deflate(2.5);
    final paint = Paint()..color = color;
    void dots(Offset from, Offset to) {
      final length = (to - from).distance;
      final step = (to - from) / length;
      for (var at = 0.0; at < length; at += 2) {
        canvas.drawRect(
          Rect.fromLTWH(from.dx + step.dx * at, from.dy + step.dy * at, 1, 1),
          paint,
        );
      }
    }

    dots(rect.topLeft, rect.topRight);
    dots(rect.topRight, rect.bottomRight);
    dots(rect.bottomRight, rect.bottomLeft);
    dots(rect.bottomLeft, rect.topLeft);
  }
}
