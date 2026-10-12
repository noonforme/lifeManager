import 'dart:math' as math;

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';

/// An icon-only mouse action in a [PaneCaption]. It always carries a
/// [semanticLabel], which is also its tooltip.
@immutable
final class PaneCaptionAction {
  const PaneCaptionAction({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final EraIconKind icon;
  final String semanticLabel;

  /// Null greys the action in place.
  final VoidCallback? onPressed;
}

/// The caption over a pane (database shell spec 3, 5): the pane's icon and
/// title, optional passive [trailing] content, icon-only [actions] and a
/// Close key.
///
/// **Reflow.** The title and trailing content are bounded by the caption's
/// width and wrap onto further lines (the caption grows; font size is never
/// clamped). The actions and Close sit in a column at the right edge, so
/// Close stays visible and reachable at any width or text scale.
///
/// **Mouse only; the slot contract.** Nothing here takes focus: the actions
/// and Close are mouse hit targets of at least 24 x 24 px (spec section
/// 4.6). [trailing] is for passive display (a count, a muted note, a mark).
/// It is wrapped so that nothing inside it can take keyboard focus or be
/// activated by Enter or Space: a `KeyButton` placed there still works by
/// mouse but never by keyboard. Commands belong in [actions]; an editor
/// does not belong in a caption.
final class PaneCaption extends StatelessWidget {
  const PaneCaption({
    required this.title,
    this.icon,
    this.trailing,
    this.actions = const [],
    this.onClose,
    this.closeLabel,
    super.key,
  });

  final String title;
  final EraIconKind? icon;

  /// Passive content after the title. Keyboard focus is removed from it.
  final Widget? trailing;

  /// Icon-only mouse actions, left of Close.
  final List<PaneCaptionAction> actions;

  /// The Close key; null shows none. Announced as [closeLabel], by default
  /// "Close <title>".
  final VoidCallback? onClose;
  final String? closeLabel;

  static const _padding = 4.0;
  static const _keySize = 24.0;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final keyCount = actions.length + (onClose == null ? 0 : 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        // What the title and trailing may take beside the keys.
        final room = math.max(
          0.0,
          constraints.maxWidth - 2 * _padding - keyCount * _keySize - 4,
        );
        final slot = trailing;
        return DecoratedBox(
          decoration: skin.painters.toolbar(tokens),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: room),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon case final icon?)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: EraIcon(icon),
                                  ),
                                Flexible(
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      title,
                                      style: skin.typography.strong.copyWith(
                                        color: tokens.ink,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (slot != null)
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: room),
                              // Passive content only: no focus, no
                              // keyboard activation.
                              child: ExcludeFocus(child: slot),
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final action in actions)
                    _CaptionKey(
                      label: action.semanticLabel,
                      onPressed: action.onPressed,
                      mark: EraIcon(
                        action.icon,
                        disabled: action.onPressed == null,
                      ),
                    ),
                  if (onClose case final close?)
                    _CaptionKey(
                      label: closeLabel ?? 'Close $title',
                      onPressed: close,
                      mark: const _CrossMark(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A 24 px mouse-only key: raised when hovered or pressed, no focus.
final class _CaptionKey extends StatefulWidget {
  const _CaptionKey({
    required this.label,
    required this.onPressed,
    required this.mark,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget mark;

  @override
  State<_CaptionKey> createState() => _CaptionKeyState();
}

final class _CaptionKeyState extends State<_CaptionKey> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final surface = skin.painters.key(
      skin.tokens,
      KeyKind.toolbar,
      KeyState(
        enabled: _enabled,
        pressed: _pressed,
        hovered: _hovered,
        focused: false,
      ),
    );
    return Tooltip(
      message: widget.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.label,
        excludeSemantics: true,
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel: _enabled
                ? () => setState(() => _pressed = false)
                : null,
            onTap: widget.onPressed,
            child: Container(
              width: PaneCaption._keySize,
              height: PaneCaption._keySize,
              alignment: Alignment.center,
              decoration: surface.decoration,
              child: widget.mark,
            ),
          ),
        ),
      ),
    );
  }
}

/// The painted close cross.
final class _CrossMark extends StatelessWidget {
  const _CrossMark();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 10,
    child: CustomPaint(
      painter: _CrossPainter(LifeOSSkinScope.of(context).tokens.ink),
    ),
  );
}

final class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.ink != ink;
}
