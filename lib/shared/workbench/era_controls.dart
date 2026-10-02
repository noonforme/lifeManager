import 'package:flutter/widgets.dart';

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
