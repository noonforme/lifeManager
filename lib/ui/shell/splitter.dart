import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../foundation/lifeos_skin.dart';

/// The 5 px draggable divider between two panes (database shell spec 3).
///
/// [axis] is the direction the panes are laid out in, which is the
/// direction the splitter drags: [Axis.horizontal] separates side-by-side
/// panes (a vertical bar, resize-column cursor, reports horizontal
/// movement); [Axis.vertical] separates stacked panes (a horizontal bar,
/// resize-row cursor, reports vertical movement).
///
/// **Controlled layout.** The splitter owns no size. [onDragStart] tells the
/// parent to remember the pane's current size; [onDrag] then reports the
/// pointer's **total displacement since the press** along [axis], so the
/// parent sets `size = startSize + offset` and clamps. Because the report is
/// cumulative, dragging far past a clamp and back is reversible: the pane
/// follows the pointer again only when it returns to the clamp edge.
/// [onDragEnd] fires on release or cancel, when the parent reports/persists
/// the final size.
///
/// **Mouse only.** It reacts to pointer press, move and release from the
/// first pixel (no touch slop) and never takes focus; the keyboard does
/// nothing here (spec section 4.6). Place it where its cross axis is
/// bounded (in a `Row` or `Column`, or a sized box); it fills that axis.
final class Splitter extends StatefulWidget {
  const Splitter({
    required this.axis,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    this.semanticLabel = 'Resize panes',
    super.key,
  });

  /// The direction the panes lie in and the splitter drags.
  final Axis axis;

  final VoidCallback? onDragStart;

  /// Total displacement in pixels since the press, along [axis].
  final ValueChanged<double> onDrag;
  final VoidCallback? onDragEnd;
  final String semanticLabel;

  /// The splitter's thickness along [axis].
  static const thickness = 5.0;

  @override
  State<Splitter> createState() => _SplitterState();
}

final class _SplitterState extends State<Splitter> {
  int? _pointer;
  double _offset = 0;

  double _along(Offset delta) =>
      widget.axis == Axis.horizontal ? delta.dx : delta.dy;

  void _down(PointerDownEvent event) {
    if (_pointer != null || (event.buttons & kPrimaryButton) == 0) return;
    _pointer = event.pointer;
    _offset = 0;
    widget.onDragStart?.call();
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final delta = _along(event.delta);
    if (delta == 0) return;
    _offset += delta;
    widget.onDrag(_offset);
  }

  void _finish(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final horizontal = widget.axis == Axis.horizontal;
    return Semantics(
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: horizontal
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _finish,
          onPointerCancel: _finish,
          child: SizedBox(
            width: horizontal ? Splitter.thickness : double.infinity,
            height: horizontal ? double.infinity : Splitter.thickness,
            child: ColoredBox(color: tokens.chrome),
          ),
        ),
      ),
    );
  }
}
