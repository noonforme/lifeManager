import 'package:flutter/widgets.dart';

import 'lifeos_tokens.dart';

/// The painted icon set (XP-authentic shell spec 7). No vendor artwork and
/// no font glyphs: each is drawn on a 16-unit grid with a dark outline, a
/// two-stop gradient and a highlight, then scaled.
enum EraIconKind {
  app,
  work,
  finance,
  tracking,
  knowledge,
  shift,
  payPeriod,
  payslip,
  employment,
  agreement,
  add,
  properties,
  correct,
  reviewed,
  recordPayslip,
  saveView,
  newDesk,
  delete,
}

EraIconKind areaIcon(LifeOSArea area) => switch (area) {
  LifeOSArea.work => EraIconKind.work,
  LifeOSArea.finance => EraIconKind.finance,
  LifeOSArea.tracking => EraIconKind.tracking,
  LifeOSArea.knowledge => EraIconKind.knowledge,
};

final class EraIcon extends StatelessWidget {
  const EraIcon(
    this.kind, {
    this.size = 16,
    this.disabled = false,
    this.semanticLabel,
    super.key,
  });

  final EraIconKind kind;
  final double size;

  /// Painted in greys, for an unbuilt area or an unavailable action.
  final bool disabled;

  /// Announced when the icon stands for something; silent otherwise.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(kind, disabled: disabled)),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: icon)
        : Semantics(label: label, excludeSemantics: true, child: icon);
  }
}

// Icon colours are artwork, not interface tokens, so they live beside the
// shapes that use them (the one documented exception to "colours only from
// tokens").
const _paperTop = Color(0xffffffff);
const _paperBottom = Color(0xffe6e6e0);
const _paperLine = Color(0xff8a8a8a);
const _rule = Color(0xff9aa6c0);
const _brownTop = Color(0xffe2a85c);
const _brownBottom = Color(0xff9a5a1a);
const _brownEdge = Color(0xff5a3410);
const _goldTop = Color(0xffffe27a);
const _goldBottom = Color(0xffd09a10);
const _goldEdge = Color(0xff8a6400);
const _greenTop = Color(0xff8fd46a);
const _greenBottom = Color(0xff2f8a1f);
const _greenEdge = Color(0xff1f5a14);
const _purpleTop = Color(0xffb7a0e0);
const _purpleBottom = Color(0xff6a4ea0);
const _purpleEdge = Color(0xff3e2a66);
const _blueTop = Color(0xff8fb4f5);
const _blueBottom = Color(0xff2a5fd0);
const _blueEdge = Color(0xff163a8a);
const _redTop = Color(0xffff8a6a);
const _redBottom = Color(0xffc1300f);
const _redEdge = Color(0xff7a1c06);
const _ink = Color(0xff1a1a1a);
const _white = Color(0xffffffff);
const _pencilTip = Color(0xfff2c09a);

final class _IconPainter extends CustomPainter {
  const _IconPainter(this.kind, {required this.disabled});

  final EraIconKind kind;
  final bool disabled;

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.55, 0,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    if (disabled) {
      canvas.saveLayer(Offset.zero & size, Paint()..colorFilter = _grey);
    } else {
      canvas.save();
    }
    canvas.scale(size.width / 16, size.height / 16);
    switch (kind) {
      case EraIconKind.app:
        _orb(canvas, const Offset(8, 8), 6.5, _blueTop, _blueBottom, _blueEdge);
        _tick(canvas, const Offset(4.8, 8.2), 3, _white);
      case EraIconKind.work:
        _shape(
          canvas,
          RRect.fromLTRBR(1.5, 5, 14.5, 14, const Radius.circular(1.5)),
          _brownTop,
          _brownBottom,
          _brownEdge,
        );
        _stroke(
          canvas,
          RRect.fromLTRBR(5.5, 2.5, 10.5, 5, const Radius.circular(1)),
          _brownEdge,
        );
        _line(canvas, const Offset(1.5, 9), const Offset(14.5, 9), _brownEdge);
        _shape(
          canvas,
          RRect.fromLTRBR(7, 8, 9, 10.5, const Radius.circular(0.5)),
          _goldTop,
          _goldBottom,
          _goldEdge,
        );
      case EraIconKind.finance:
        for (final (x, y) in const [(3.0, 9.0), (8.0, 11.0), (6.0, 5.5)]) {
          _ovalShape(
            canvas,
            Rect.fromLTWH(x, y, 7, 4),
            _goldTop,
            _goldBottom,
            _goldEdge,
          );
        }
      case EraIconKind.tracking:
        _paper(canvas, const Rect.fromLTRB(1.5, 1.5, 14.5, 14.5));
        for (final (x, top) in const [(3.5, 9.0), (7.0, 5.0), (10.5, 7.0)]) {
          _shape(
            canvas,
            RRect.fromLTRBR(x, top, x + 2.5, 12.5, Radius.zero),
            _greenTop,
            _greenBottom,
            _greenEdge,
          );
        }
      case EraIconKind.knowledge:
        _shape(
          canvas,
          RRect.fromLTRBR(2.5, 1.5, 12.5, 14.5, const Radius.circular(1)),
          _purpleTop,
          _purpleBottom,
          _purpleEdge,
        );
        _fillRect(canvas, const Rect.fromLTRB(12.5, 2.5, 14, 14), _paperTop);
        _line(canvas, const Offset(14, 2.5), const Offset(14, 14), _paperLine);
        _line(canvas, const Offset(5, 5), const Offset(10, 5), _goldTop);
      case EraIconKind.shift:
        _orb(
          canvas,
          const Offset(8, 8),
          6.5,
          _paperTop,
          _paperBottom,
          _blueEdge,
        );
        _line(canvas, const Offset(8, 8), const Offset(8, 4), _ink);
        _line(canvas, const Offset(8, 8), const Offset(11, 9.5), _ink);
      case EraIconKind.payPeriod:
        _paper(canvas, const Rect.fromLTRB(1.5, 2.5, 14.5, 14.5));
        _fillRect(canvas, const Rect.fromLTRB(2, 3, 14, 6), _redBottom);
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 4; col++) {
            _fillRect(
              canvas,
              Rect.fromLTWH(3.5 + col * 2.6, 7.5 + row * 2.2, 1.4, 1.2),
              _rule,
            );
          }
        }
      case EraIconKind.payslip:
        _slip(canvas);
      case EraIconKind.employment:
        _shape(
          canvas,
          RRect.fromLTRBR(3, 2, 13, 14.5, Radius.zero),
          _blueTop,
          _blueBottom,
          _blueEdge,
        );
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 2; col++) {
            _fillRect(
              canvas,
              Rect.fromLTWH(5 + col * 3.5, 4 + row * 3, 2, 1.8),
              _goldTop,
            );
          }
        }
      case EraIconKind.agreement:
        _paper(canvas, const Rect.fromLTRB(2.5, 1.5, 13.5, 14.5));
        for (final y in const [4.5, 6.5, 8.5]) {
          _line(canvas, Offset(4.5, y), Offset(11.5, y), _paperLine);
        }
        _orb(
          canvas,
          const Offset(10.5, 11.5),
          2.5,
          _redTop,
          _redBottom,
          _redEdge,
        );
      case EraIconKind.add:
        _paper(canvas, const Rect.fromLTRB(2.5, 1.5, 12.5, 13.5));
        _plus(canvas, const Offset(11.5, 11.5));
      case EraIconKind.properties:
        _paper(canvas, const Rect.fromLTRB(2.5, 1.5, 13.5, 14.5));
        for (final y in const [5.0, 8.0, 11.0]) {
          _fillRect(
            canvas,
            Rect.fromLTWH(4.5, y - 0.75, 1.5, 1.5),
            _blueBottom,
          );
          _line(canvas, Offset(7, y), Offset(11.5, y), _paperLine);
        }
      case EraIconKind.correct:
        final pencil = Path()
          ..moveTo(3, 13)
          ..lineTo(4, 10)
          ..lineTo(11.5, 2.5)
          ..lineTo(13.5, 4.5)
          ..lineTo(6, 12)
          ..close();
        _pathShape(canvas, pencil, _goldTop, _goldBottom, _goldEdge);
        _fillPath(
          canvas,
          Path()
            ..moveTo(3, 13)
            ..lineTo(4, 10)
            ..lineTo(6, 12)
            ..close(),
          _pencilTip,
        );
      case EraIconKind.reviewed:
        _tick(canvas, const Offset(2.5, 8.5), 5.5, _greenBottom, width: 2.6);
      case EraIconKind.recordPayslip:
        _slip(canvas);
        _plus(canvas, const Offset(11.5, 11.5));
      case EraIconKind.saveView:
        _shape(
          canvas,
          RRect.fromLTRBR(2, 2, 14, 14, const Radius.circular(1)),
          _blueTop,
          _blueBottom,
          _blueEdge,
        );
        _fillRect(canvas, const Rect.fromLTRB(4, 2.5, 12, 7), _paperTop);
        _fillRect(canvas, const Rect.fromLTRB(5, 9.5, 11, 13.5), _paperBottom);
      case EraIconKind.newDesk:
        _shape(
          canvas,
          RRect.fromLTRBR(1.5, 2.5, 12.5, 12.5, const Radius.circular(1)),
          _paperTop,
          _paperBottom,
          _blueEdge,
        );
        _fillRect(canvas, const Rect.fromLTRB(2, 3, 12, 5.5), _blueBottom);
        _plus(canvas, const Offset(11.5, 11.5));
      case EraIconKind.delete:
        final paint = Paint()
          ..color = _redBottom
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(const Offset(4, 4), const Offset(12, 12), paint)
          ..drawLine(const Offset(12, 4), const Offset(4, 12), paint);
    }
    canvas.restore();
  }

  void _shape(Canvas canvas, RRect shape, Color top, Color bottom, Color edge) {
    canvas.drawRRect(shape, _gradient(shape.outerRect, top, bottom));
    _stroke(canvas, shape, edge);
  }

  void _pathShape(
    Canvas canvas,
    Path path,
    Color top,
    Color bottom,
    Color edge,
  ) {
    canvas
      ..drawPath(path, _gradient(path.getBounds(), top, bottom))
      ..drawPath(
        path,
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  void _ovalShape(
    Canvas canvas,
    Rect oval,
    Color top,
    Color bottom,
    Color edge,
  ) => _pathShape(canvas, Path()..addOval(oval), top, bottom, edge);

  void _orb(
    Canvas canvas,
    Offset centre,
    double radius,
    Color top,
    Color bottom,
    Color edge,
  ) => _ovalShape(
    canvas,
    Rect.fromCircle(center: centre, radius: radius),
    top,
    bottom,
    edge,
  );

  void _stroke(Canvas canvas, RRect shape, Color edge) => canvas.drawRRect(
    shape,
    Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );

  void _paper(Canvas canvas, Rect rect) => _shape(
    canvas,
    RRect.fromRectAndRadius(rect, Radius.zero),
    _paperTop,
    _paperBottom,
    _paperLine,
  );

  void _slip(Canvas canvas) {
    _paper(canvas, const Rect.fromLTRB(3, 1.5, 13, 14.5));
    for (final y in const [4.5, 6.5, 8.5]) {
      _line(canvas, Offset(5, y), Offset(11, y), _paperLine);
    }
    _line(canvas, const Offset(5, 11.5), const Offset(8, 11.5), _greenBottom);
  }

  void _plus(Canvas canvas, Offset centre) {
    _orb(canvas, centre, 3.5, _greenTop, _greenBottom, _greenEdge);
    final paint = Paint()
      ..color = _white
      ..strokeWidth = 1.4;
    canvas
      ..drawLine(centre.translate(-2, 0), centre.translate(2, 0), paint)
      ..drawLine(centre.translate(0, -2), centre.translate(0, 2), paint);
  }

  void _tick(
    Canvas canvas,
    Offset start,
    double size,
    Color color, {
    double width = 1.6,
  }) {
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + size * 0.4, start.dy + size * 0.45)
        ..lineTo(start.dx + size * 1.4, start.dy - size * 0.75),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _line(Canvas canvas, Offset a, Offset b, Color color) => canvas.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = 1,
  );

  void _fillRect(Canvas canvas, Rect rect, Color color) =>
      canvas.drawRect(rect, Paint()..color = color);

  void _fillPath(Canvas canvas, Path path, Color color) =>
      canvas.drawPath(path, Paint()..color = color);

  Paint _gradient(Rect bounds, Color top, Color bottom) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ).createShader(bounds);

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.disabled != disabled;
}
