import 'package:flutter/widgets.dart';

import 'lifeos_skin.dart';
import 'lifeos_tokens.dart';

/// Named colours of the 2001 office-PC style that sit outside the token
/// set (Millennium shell spec 3.3). Widgets use these names, never
/// literals.
abstract final class MillenniumColors {
  /// Task-pane links, 5.5:1 on [paneBody].
  static const link = Color(0xff1c50b0);
  static const paneTop = Color(0xff7ba2e7);
  static const paneBottom = Color(0xff6375d6);
  static const paneBody = Color(0xffd6dff7);

  /// The light end of an ordinary task-group header.
  static const groupHeaderEnd = Color(0xffc6d3f7);

  /// The light end of the special task-group header.
  static const specialHeaderEnd = Color(0xff2a6ee8);

  /// The active property-sheet tab's top edge.
  static const tabAccent = Color(0xffffc83c);

  /// The sorted column's bottom edge. Decorative: the painted arrow beside
  /// the column name, announced as "sorted ascending", says the order.
  static const sortAccent = Color(0xfff9b119);

  /// The faint grey down the sorted column's cells.
  static const sortTint = Color(0xfff7f7f7);
  static const keyLine = Color(0xff003c74);
  static const fieldLine = Color(0xff7f9db9);

  /// The property-sheet page.
  static const page = Color(0xfffcfcfe);
  static const groupLine = Color(0xffd0d0bf);
  static const tabLine = Color(0xff919b9c);
  static const progress = Color(0xff2fbf2f);

  /// The pale rule under a details-list group row.
  static const groupRowRule = Color(0xffa0b8e8);

  /// Caption bars of dialogs and tiles: top, then [LifeOSTokens.head],
  /// then [captionBottom].
  static const captionTop = Color(0xff0a5fe8);
  static const captionBottom = Color(0xff003cb8);
  static const closeTop = Color(0xffe87c5a);
  static const closeBottom = Color(0xffc1300f);

  /// The default push button's inner double ring.
  static const defaultRingOuter = Color(0xff6c9cec);
  static const defaultRingInner = Color(0xffb9d1fa);

  /// The hovered push button's warm inner edge.
  static const hotRingOuter = Color(0xfff9b119);
  static const hotRingInner = Color(0xffffe7a2);

  /// The push button face's lower stop.
  static const keyFaceLow = Color(0xffd6d0c5);
  static const comboArrowTop = Color(0xffe6eeff);
  static const comboArrowBottom = Color(0xffb9cdf5);
  static const comboArrowInk = Color(0xff4d6185);

  /// A tooltip's pale yellow face.
  static const tooltip = Color(0xffffffe1);

  /// The edge of a drop-down or right-click menu panel.
  static const menuEdge = Color(0xffaca899);

  /// The dark edge of a sunken panel.
  static const sunkenEdge = Color(0xffa0a0a0);
  static const orbGreenLight = Color(0xffa6e88a);
  static const orbGreen = Color(0xff2f9a1f);
  static const orbGreenEdge = Color(0xff23741a);
  static const orbOrangeLight = Color(0xffffd08a);
  static const orbOrange = Color(0xffe0700f);
  static const orbOrangeEdge = Color(0xffb3530a);
  static const orbGreyLight = Color(0xffdddddd);
  static const orbGrey = Color(0xff9a9a9a);
  static const orbGreyEdge = Color(0xff888888);
  static const orbGlyph = Color(0xffffffff);

  /// A transparent edge that keeps a flat key the same size as a raised one.
  static const clear = Color(0x00000000);
  static const infoGlyph = Color(0xff215dc6);

  // Check boxes and radios (XP-authentic shell spec 8.1).
  static const choiceLine = Color(0xff1c5180);
  static const choiceMark = Color(0xff21a121);
  static const choiceMarkLight = Color(0xff55d651);

  // Scrollbars (XP-authentic shell spec 6.2).
  static const scrollTrack = Color(0xfff4f3ee);
  static const scrollTrackEdge = Color(0xffeeede5);
  static const scrollFaceTop = Color(0xffcadaff);
  static const scrollFaceBottom = Color(0xffb5c9f7);
  static const scrollFaceEdge = Color(0xff98b0e8);
  static const scrollGripLight = Color(0xffeef4fe);
  static const scrollGripDark = Color(0xff8cb0f8);
  static const warningGlyph = Color(0xfff2b01e);
}

/// LifeOS type (Millennium shell spec 3.4): Noto Sans throughout, tabular
/// figures for numbers. Sizes scale with the platform text scale.
const _family = 'EraSans';
const _fallback = ['NotoSans'];

/// EraSans's bold face draws "fi" with its regular ligature; Tahoma joined
/// no letters, so neither does LifeOS.
const _noLigatures = FontFeature.disable('liga');

/// The era's 8 pt system type: EraSans, Wine's Tahoma-metric font, at 11 px
/// (XP-authentic shell spec 6.1). Noto Sans covers any glyph it lacks.
const lifeOSTypography = LifeOSTypography(
  caption: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w700,
    fontFeatures: [_noLigatures],
  ),
  strong: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    fontFeatures: [_noLigatures],
  ),
  label: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    fontFeatures: [_noLigatures],
  ),
  body: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    fontFeatures: [_noLigatures],
  ),
  small: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    fontFeatures: [_noLigatures],
  ),
  // EraSans digits share one advance width (checked 2026-10-04: 1118 units
  // regular, 1304 bold), so figures line up; the feature is kept for the
  // fallback face.
  figure: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures(), _noLigatures],
  ),
  counter: TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    height: 20 / 18,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures(), _noLigatures],
  ),
);

/// How LifeOS-owned controls are painted.
final class LifeOSPainters {
  const LifeOSPainters();

  static const _radius = BorderRadius.all(Radius.circular(3));

  /// A push button (spec 5.1), or a flat toolbar key that shows a raised
  /// face only when hovered, focused or pressed. No state changes a key's
  /// size.
  KeySurface key(LifeOSTokens tokens, KeyKind kind, KeyState state) {
    if (!state.enabled) {
      return KeySurface(
        decoration: BoxDecoration(
          color: kind == KeyKind.toolbar ? null : tokens.chrome,
          borderRadius: _radius,
          border: Border.all(
            color: kind == KeyKind.toolbar
                ? MillenniumColors.clear
                : tokens.chromeLine,
          ),
        ),
        ink: tokens.muted,
      );
    }
    if (kind == KeyKind.toolbar) {
      final raised = state.hovered || state.focused || state.pressed;
      return KeySurface(
        decoration: BoxDecoration(
          gradient: raised
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: state.pressed
                      ? [tokens.chrome, tokens.paper]
                      : [tokens.paper, tokens.chrome],
                )
              : null,
          borderRadius: _radius,
          border: Border.all(
            color: raised ? tokens.chromeLine : MillenniumColors.clear,
          ),
        ),
        ink: tokens.ink,
      );
    }
    return KeySurface(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: state.pressed
              ? [MillenniumColors.keyFaceLow, tokens.chrome, tokens.paper]
              : [tokens.paper, tokens.chrome, MillenniumColors.keyFaceLow],
          stops: const [0, 0.85, 1],
        ),
        borderRadius: _radius,
        border: Border.all(color: MillenniumColors.keyLine),
      ),
      ink: tokens.ink,
      rings: state.hovered && !state.pressed
          ? (MillenniumColors.hotRingOuter, MillenniumColors.hotRingInner)
          : kind == KeyKind.primary
          ? (
              MillenniumColors.defaultRingOuter,
              MillenniumColors.defaultRingInner,
            )
          : null,
    );
  }

  BoxDecoration countBadge(LifeOSTokens tokens) => BoxDecoration(
    color: tokens.runInk,
    borderRadius: const BorderRadius.all(Radius.circular(8)),
  );

  Color countBadgeInk(LifeOSTokens tokens) => tokens.headInk;

  Decoration focusRing(LifeOSTokens tokens) =>
      DottedFocusRectangle(color: tokens.focus);

  /// The face of a column head in a details list: paper fading to the band.
  Gradient columnHead(LifeOSTokens tokens) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [tokens.paper, tokens.band],
  );

  Decoration toolbar(LifeOSTokens tokens) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [tokens.paper, tokens.chrome],
    ),
    border: Border(
      top: BorderSide(color: tokens.paper),
      bottom: BorderSide(color: tokens.chromeLine),
    ),
  );

  /// The dotted cell cursor: white on a selected (blue) row, ink elsewhere.
  Decoration cellCursor(LifeOSTokens tokens, {required bool onSelection}) =>
      DottedFocusRectangle(
        color: onSelection ? tokens.selInk : tokens.focus,
        inset: 1.5,
      );
}

/// Two 1-pixel rings painted just inside a key's outline: the default
/// key's blue double ring or the hovered key's warm edge.
final class InsetRings extends Decoration {
  const InsetRings(this.outer, this.inner);

  final Color outer;
  final Color inner;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _InsetRingsPainter(outer, inner);

  @override
  bool operator ==(Object other) =>
      other is InsetRings && other.outer == outer && other.inner == inner;

  @override
  int get hashCode => Object.hash(outer, inner);
}

final class _InsetRingsPainter extends BoxPainter {
  _InsetRingsPainter(this.outer, this.inner);

  final Color outer;
  final Color inner;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(2)),
        stroke..color = outer,
      )
      ..drawRect(rect.deflate(2.5), stroke..color = inner);
  }
}

/// The era's dotted focus rectangle, drawn [inset] pixels inside the box.
final class DottedFocusRectangle extends Decoration {
  const DottedFocusRectangle({required this.color, this.inset = 2.5});

  final Color color;
  final double inset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedPainter(color, inset);

  @override
  bool operator ==(Object other) =>
      other is DottedFocusRectangle &&
      other.color == color &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(color, inset);
}

final class _DottedPainter extends BoxPainter {
  _DottedPainter(this.color, this.inset);

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = (offset & size).deflate(inset);
    final paint = Paint()..color = color;
    void dots(Offset from, Offset to) {
      final length = (to - from).distance;
      if (length == 0) return;
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
