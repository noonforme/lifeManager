import 'package:flutter/widgets.dart';

import 'lifeos_skin.dart';
import 'millennium_style.dart';

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
  const EraComboFace({required this.value, this.minWidth = 60, super.key});

  final String value;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: 24, minWidth: minWidth),
      decoration: BoxDecoration(
        color: skin.tokens.paper,
        border: Border.all(color: MillenniumColors.fieldLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: skin.typography.body.copyWith(color: skin.tokens.ink),
              ),
            ),
          ),
          Container(
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
          ),
        ],
      ),
    );
  }
}

final class _DownArrow extends CustomPainter {
  const _DownArrow();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 4, c.dy - 2)
        ..lineTo(c.dx + 4, c.dy - 2)
        ..lineTo(c.dx, c.dy + 2)
        ..close(),
      Paint()..color = MillenniumColors.comboArrowInk,
    );
  }

  @override
  bool shouldRepaint(_DownArrow oldDelegate) => false;
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
