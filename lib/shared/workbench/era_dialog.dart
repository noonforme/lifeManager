import 'package:flutter/material.dart';

import 'era_controls.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

/// An in-app dialog in the era's shape (spec 5.9): a blue caption with the
/// title and a red close key, a face-coloured body and keys bottom-right.
final class EraDialog extends StatelessWidget {
  const EraDialog({
    required this.title,
    required this.body,
    required this.actions,
    this.onClose,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// The close key; defaults to popping the dialog.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Dialog(
      backgroundColor: tokens.chrome,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: MillenniumColors.keyLine),
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CaptionBar(
              title: title,
              onClose: onClose ?? () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DefaultTextStyle.merge(
                style: skin.typography.body.copyWith(color: tokens.ink),
                child: body,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: FormFooter(children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

/// A blue gradient caption with a title and a red close key, shared by
/// dialogs and desk tiles.
final class CaptionBar extends StatelessWidget {
  const CaptionBar({
    required this.title,
    required this.onClose,
    this.leading,
    this.trailing = const [],
    this.closeLabel,
    super.key,
  });

  final String title;
  final VoidCallback? onClose;
  final Widget? leading;
  final List<Widget> trailing;

  /// Announced for the close key; defaults to "Close [title]".
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MillenniumColors.captionTop,
            tokens.head,
            MillenniumColors.captionBottom,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Row(
        children: [
          if (leading case final leading?) ...[
            leading,
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: skin.typography.body.copyWith(
                  color: tokens.headInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ...trailing,
          if (onClose case final close?)
            _CloseKey(label: closeLabel ?? 'Close $title', onPressed: close),
        ],
      ),
    );
  }
}

final class _CloseKey extends StatelessWidget {
  const _CloseKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              border: Border.all(
                color: LifeOSSkinScope.of(context).tokens.paper,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MillenniumColors.closeTop,
                  MillenniumColors.closeBottom,
                ],
              ),
            ),
            child: CustomPaint(
              painter: _Cross(LifeOSSkinScope.of(context).tokens.headInk),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _Cross extends CustomPainter {
  const _Cross(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    final inset = size.width * 0.3;
    canvas
      ..drawLine(
        Offset(inset, inset),
        Offset(size.width - inset, size.height - inset),
        paint,
      )
      ..drawLine(
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        paint,
      );
  }

  @override
  bool shouldRepaint(_Cross oldDelegate) => oldDelegate.ink != ink;
}
