import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// The digit a key types into a date or time box, from the main row or the
/// numpad; null for any other key.
int? eraTypedDigit(LogicalKeyboardKey key) {
  const rows = [
    [LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0],
    [LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1],
    [LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2],
    [LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3],
    [LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4],
    [LogicalKeyboardKey.digit5, LogicalKeyboardKey.numpad5],
    [LogicalKeyboardKey.digit6, LogicalKeyboardKey.numpad6],
    [LogicalKeyboardKey.digit7, LogicalKeyboardKey.numpad7],
    [LogicalKeyboardKey.digit8, LogicalKeyboardKey.numpad8],
    [LogicalKeyboardKey.digit9, LogicalKeyboardKey.numpad9],
  ];
  for (final (digit, keys) in rows.indexed) {
    if (keys.contains(key)) return digit;
  }
  return null;
}

enum OrbGlyph { back, forward, add }

enum OrbTone { green, orange, grey }

/// A painted glossy orb with a white glyph, as on the era's toolbar keys.
/// Decorative: the key beside it carries the words.
final class Orb extends StatelessWidget {
  const Orb({
    required this.glyph,
    required this.tone,
    this.size = 20,
    super.key,
  });

  final OrbGlyph glyph;
  final OrbTone tone;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _OrbPainter(glyph, tone),
    ),
  );
}

final class _OrbPainter extends CustomPainter {
  const _OrbPainter(this.glyph, this.tone);

  final OrbGlyph glyph;
  final OrbTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final (light, fill, edge) = switch (tone) {
      OrbTone.green => (
        MillenniumColors.orbGreenLight,
        MillenniumColors.orbGreen,
        MillenniumColors.orbGreenEdge,
      ),
      OrbTone.orange => (
        MillenniumColors.orbOrangeLight,
        MillenniumColors.orbOrange,
        MillenniumColors.orbOrangeEdge,
      ),
      OrbTone.grey => (
        MillenniumColors.orbGreyLight,
        MillenniumColors.orbGrey,
        MillenniumColors.orbGreyEdge,
      ),
    };
    final rect = Offset.zero & size;
    final circle = rect.deflate(0.5);
    canvas
      ..drawOval(
        circle,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [light, fill],
            stops: const [0, 0.7],
          ).createShader(rect),
      )
      ..drawOval(
        circle,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = edge,
      );
    final white = Paint()..color = MillenniumColors.orbGlyph;
    final s = size.width;
    switch (glyph) {
      case OrbGlyph.back || OrbGlyph.forward:
        final left = glyph == OrbGlyph.back;
        final path = Path()
          ..moveTo(left ? s * 0.25 : s * 0.75, s * 0.5)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.25)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.4)
          ..lineTo(left ? s * 0.75 : s * 0.25, s * 0.4)
          ..lineTo(left ? s * 0.75 : s * 0.25, s * 0.6)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.6)
          ..lineTo(left ? s * 0.52 : s * 0.48, s * 0.75)
          ..close();
        canvas.drawPath(path, white);
      case OrbGlyph.add:
        canvas
          ..drawRect(
            Rect.fromLTRB(s * 0.42, s * 0.24, s * 0.58, s * 0.76),
            white,
          )
          ..drawRect(
            Rect.fromLTRB(s * 0.24, s * 0.42, s * 0.76, s * 0.58),
            white,
          );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.tone != tone;
}

/// What a dropdown looks like closed: a white field with a blue arrow
/// button (spec 5.3). The surrounding menu button supplies the behaviour.
final class EraComboFace extends StatelessWidget {
  const EraComboFace({
    required this.value,
    this.minWidth = 60,
    this.focused = false,
    this.enabled = true,
    this.fill = false,
    super.key,
  });

  final String value;
  final double minWidth;

  /// Gives the text all the width the box is given, so the arrow sits at
  /// the right edge of a box wider than its text, such as a grid cell.
  /// Needs a bounded width. False keeps the box as wide as its text.
  final bool fill;

  /// Lights the value in selection blue, as a focused era list box did.
  final bool focused;

  /// False greys the box onto the face colour, as a read-only form shows
  /// its fields.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    Widget text = Container(
      color: focused ? skin.tokens.selWash : null,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: skin.typography.body.copyWith(
          color: !enabled
              ? skin.tokens.muted
              : focused
              ? skin.tokens.selInk
              : skin.tokens.ink,
        ),
      ),
    );
    // A filled box lights only its text, as a box as wide as its text does.
    if (fill) {
      text = Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: text,
      );
    }
    return Container(
      constraints: BoxConstraints(minHeight: 24, minWidth: minWidth),
      decoration: BoxDecoration(
        color: enabled ? skin.tokens.paper : skin.tokens.chrome,
        border: Border.all(color: MillenniumColors.fieldLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: fill ? FlexFit.tight : FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: text,
            ),
          ),
          ComboArrow(enabled: enabled),
        ],
      ),
    );
  }
}

/// The blue drop-arrow button at the right of a combo box; grey when
/// [enabled] is false.
final class ComboArrow extends StatelessWidget {
  const ComboArrow({this.enabled = true, super.key});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      final t = LifeOSSkinScope.of(context).tokens;
      return Container(
        width: 17,
        constraints: const BoxConstraints(minHeight: 22),
        color: t.chrome,
        child: CustomPaint(painter: _DownArrow(t.muted)),
      );
    }
    return Container(
      width: 17,
      constraints: const BoxConstraints(minHeight: 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MillenniumColors.comboArrowTop,
            MillenniumColors.comboArrowBottom,
          ],
        ),
      ),
      child: const CustomPaint(painter: _DownArrow()),
    );
  }
}

final class _DownArrow extends CustomPainter {
  const _DownArrow([this.color = MillenniumColors.comboArrowInk]);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 4, c.dy - 2)
        ..lineTo(c.dx + 4, c.dy - 2)
        ..lineTo(c.dx, c.dy + 2)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DownArrow oldDelegate) => color != oldDelegate.color;
}

/// A titled frame around related content, its legend in Head blue
/// (spec 5.5).
final class GroupBox extends StatelessWidget {
  const GroupBox({
    required this.legend,
    required this.child,
    this.background,
    super.key,
  });

  final String legend;
  final Widget child;

  /// The colour behind the legend: the surface the box sits on.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: legend,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 7),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              decoration: BoxDecoration(
                border: Border.all(color: MillenniumColors.groupLine),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
            Positioned(
              left: 8,
              top: 0,
              child: ExcludeSemantics(
                child: Container(
                  color: background ?? MillenniumColors.page,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    legend,
                    style: skin.typography.label.copyWith(
                      color: skin.tokens.head,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A form's actions, right-aligned and wrapping when narrow.
final class FormFooter extends StatelessWidget {
  const FormFooter({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 6,
        runSpacing: 6,
        children: children,
      ),
    ),
  );
}

enum EraGlyphKind {
  dropDown,
  sortUp,
  sortDown,
  collapse,
  expand,
  tick,
  stepBack,
  stepForward,
}

/// A small painted mark: drop arrow, sort arrow, step arrow, collapse
/// chevrons or a tick. Painted because the bundled Noto Sans has none of these
/// characters. Decorative; the control beside it carries the words.
final class EraGlyph extends StatelessWidget {
  const EraGlyph(this.kind, {required this.color, this.size = 9, super.key});

  final EraGlyphKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(kind, color),
    ),
  );
}

final class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.kind, this.color);

  final EraGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    Path triangle({required bool up, double top = 0.3, double bottom = 0.7}) =>
        Path()
          ..moveTo(w * 0.1, h * (up ? bottom : top))
          ..lineTo(w * 0.9, h * (up ? bottom : top))
          ..lineTo(w * 0.5, h * (up ? top : bottom))
          ..close();
    Path sideways({required bool back}) => Path()
      ..moveTo(w * (back ? 0.7 : 0.3), h * 0.1)
      ..lineTo(w * (back ? 0.7 : 0.3), h * 0.9)
      ..lineTo(w * (back ? 0.3 : 0.7), h * 0.5)
      ..close();
    Path chevron(double y, {required bool up}) => Path()
      ..moveTo(w * 0.15, h * (up ? y + 0.2 : y))
      ..lineTo(w * 0.5, h * (up ? y : y + 0.2))
      ..lineTo(w * 0.85, h * (up ? y + 0.2 : y));
    switch (kind) {
      case EraGlyphKind.dropDown || EraGlyphKind.sortDown:
        canvas.drawPath(triangle(up: false), fill);
      case EraGlyphKind.sortUp:
        canvas.drawPath(triangle(up: true), fill);
      case EraGlyphKind.stepBack || EraGlyphKind.stepForward:
        canvas.drawPath(sideways(back: kind == EraGlyphKind.stepBack), fill);
      case EraGlyphKind.collapse || EraGlyphKind.expand:
        final up = kind == EraGlyphKind.collapse;
        canvas
          ..drawPath(chevron(0.2, up: up), stroke)
          ..drawPath(chevron(0.55, up: up), stroke);
      case EraGlyphKind.tick:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.15, h * 0.5)
            ..lineTo(w * 0.4, h * 0.78)
            ..lineTo(w * 0.85, h * 0.2),
          stroke..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

/// A small pressable control: reachable by Tab, pressed by Enter, Space or
/// a click, announced as a button (or [link]) with [label], and showing the
/// era's dotted focus rectangle.
final class EraPressable extends StatefulWidget {
  const EraPressable({
    required this.label,
    required this.onPressed,
    required this.child,
    this.link = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;
  final bool link;

  @override
  State<EraPressable> createState() => _EraPressableState();
}

final class _EraPressableState extends State<EraPressable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return MergeSemantics(
      child: Semantics(
        button: !widget.link,
        link: widget.link,
        label: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: ExcludeSemantics(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: _focused
                    ? DottedFocusRectangle(color: skin.tokens.focus, inset: 0.5)
                    : const BoxDecoration(),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
