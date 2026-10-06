import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: EraMovableDialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
          child: Material(
            color: tokens.chrome,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: MillenniumColors.keyLine),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            clipBehavior: Clip.antiAlias,
            // Named by its caption, which is not announced a second time.
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CaptionBar(
                    title: title,
                    large: true,
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
          ),
        ),
      ),
    );
  }
}

/// Centres a dialog [child] in the space it is given and lets the owner
/// move it by dragging its caption, as an era window moved. It stays wholly
/// inside that space, so its caption can always be reached again.
final class EraMovableDialog extends StatefulWidget {
  const EraMovableDialog({required this.child, super.key});

  final Widget child;

  @override
  State<EraMovableDialog> createState() => _EraMovableDialogState();
}

final class _EraMovableDialogState extends State<EraMovableDialog> {
  final _window = GlobalKey();
  Offset _offset = Offset.zero;

  void _move(Offset delta, Size bounds) {
    final size = _window.currentContext?.size;
    if (size == null) return;
    setState(() => _offset = _inside(_offset + delta, bounds, size));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _EraMoveScope(
      onMove: (delta) => _move(delta, constraints.biggest),
      child: CustomSingleChildLayout(
        delegate: _CentredAt(_offset),
        child: KeyedSubtree(key: _window, child: widget.child),
      ),
    ),
  );
}

/// [offset] from the centre, kept so a [size] window stays inside [bounds].
Offset _inside(Offset offset, Size bounds, Size size) {
  final x = math.max(0.0, (bounds.width - size.width) / 2);
  final y = math.max(0.0, (bounds.height - size.height) / 2);
  return Offset(offset.dx.clamp(-x, x), offset.dy.clamp(-y, y));
}

/// Lays the dialog out loosely and places it [offset] from the centre,
/// clamped again at layout for a window made smaller.
final class _CentredAt extends SingleChildLayoutDelegate {
  const _CentredAt(this.offset);

  final Offset offset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final centre = Offset(
      (size.width - childSize.width) / 2,
      (size.height - childSize.height) / 2,
    );
    return centre + _inside(offset, size, childSize);
  }

  @override
  bool shouldRelayout(_CentredAt oldDelegate) => oldDelegate.offset != offset;
}

/// Tells a dialog's caption how to move its window.
final class _EraMoveScope extends InheritedWidget {
  const _EraMoveScope({required this.onMove, required super.child});

  final ValueChanged<Offset> onMove;

  static ValueChanged<Offset>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EraMoveScope>()?.onMove;

  @override
  bool updateShouldNotify(_EraMoveScope oldWidget) =>
      onMove != oldWidget.onMove;
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
    this.large = false,
    super.key,
  });

  final String title;
  final VoidCallback? onClose;

  /// A dialog's caption, in Caption type; desk tiles keep the small one.
  final bool large;
  final Widget? leading;
  final List<Widget> trailing;

  /// Announced for the close key; defaults to "Close [title]".
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final bar = Container(
      constraints: BoxConstraints(minHeight: large ? 26 : 24),
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
            // A dialog is already named by its caption as a route, so the
            // caption text is not announced again; a desk tile's is.
            child: Semantics(
              header: true,
              excludeSemantics: large,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (large ? skin.typography.caption : skin.typography.strong)
                        .copyWith(color: tokens.headInk),
              ),
            ),
          ),
          ...trailing,
          if (onClose case final close?)
            // A dialog's caption key is not a Tab stop, as in the era:
            // Escape closes a dialog, and Tab starts at its content.
            large
                ? ExcludeFocusTraversal(
                    child: _CloseKey(
                      label: closeLabel ?? 'Close $title',
                      onPressed: close,
                    ),
                  )
                : _CloseKey(
                    label: closeLabel ?? 'Close $title',
                    onPressed: close,
                  ),
        ],
      ),
    );
    // A dialog's caption moves its window; a desk tile's stays put.
    final move = large ? _EraMoveScope.of(context) : null;
    if (move == null) return bar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // From the press, so the window keeps under the pointer.
      dragStartBehavior: DragStartBehavior.down,
      onPanUpdate: (details) => move(details.delta),
      child: bar,
    );
  }
}

final class _CloseKey extends StatelessWidget {
  const _CloseKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => EraPressable(
    label: label,
    onPressed: onPressed,
    child: Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          border: Border.all(color: LifeOSSkinScope.of(context).tokens.paper),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MillenniumColors.closeTop, MillenniumColors.closeBottom],
          ),
        ),
        child: CustomPaint(
          painter: _Cross(LifeOSSkinScope.of(context).tokens.headInk),
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
