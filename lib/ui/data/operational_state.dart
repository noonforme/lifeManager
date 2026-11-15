import 'package:flutter/widgets.dart';

import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

enum OperationalStateKind {
  loading,
  empty,
  unavailable,
  invalidScope,
  conflict,
  uncertain,
}

final class OperationalState extends StatelessWidget {
  const OperationalState({
    required this.kind,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final OperationalStateKind kind;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final warning = switch (kind) {
      OperationalStateKind.unavailable ||
      OperationalStateKind.invalidScope ||
      OperationalStateKind.conflict ||
      OperationalStateKind.uncertain => true,
      OperationalStateKind.loading || OperationalStateKind.empty => false,
    };
    return Semantics(
      container: true,
      liveRegion: kind == OperationalStateKind.loading,
      label: title,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Glyph(warning: warning),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: skin.typography.body.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: skin.typography.body.copyWith(color: tokens.ink),
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 12),
                        action!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A painted ⓘ in a blue disc, or ! in an amber triangle.
final class _Glyph extends StatelessWidget {
  const _Glyph({required this.warning});

  final bool warning;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CustomPaint(
          painter: _GlyphPainter(warning: warning, ink: skin.tokens.paper),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: warning ? 8 : 0),
              child: Text(
                warning ? '!' : 'i',
                style: skin.typography.strong.copyWith(
                  color: warning ? skin.tokens.ink : skin.tokens.paper,
                  fontSize: 14,
                  height: 18 / 14,
                  fontFamily: 'NotoSans',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.warning, required this.ink});

  final bool warning;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (warning) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 1)
          ..lineTo(size.width - 1, size.height - 2)
          ..lineTo(1, size.height - 2)
          ..close(),
        Paint()..color = MillenniumColors.warningGlyph,
      );
    } else {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width / 2 - 1,
        Paint()..color = MillenniumColors.infoGlyph,
      );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.warning != warning || oldDelegate.ink != ink;
}
