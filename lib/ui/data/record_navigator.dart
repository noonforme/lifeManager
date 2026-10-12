import 'package:flutter/widgets.dart';

import '../controls/era_controls.dart';
import '../controls/era_form.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// The record navigator of a form or grid: first, previous, "3 of 12", next,
/// last and new, with an optional wrapped note such as the active filter.
///
/// The widget is controlled. It never changes [position]; it reports a
/// request through [onGo] (a one-based target always within `1..count`) or
/// [onNew], and the owner answers by supplying a new [position]. The owner
/// flushes any open editor before acting on a request.
///
/// The keys are mouse-operated: they take no focus and ignore the keyboard
/// (database shell spec 4.6).
final class RecordNavigator extends StatelessWidget {
  const RecordNavigator({
    required this.position,
    required this.count,
    required this.label,
    this.onGo,
    this.onNew,
    this.note,
    super.key,
  }) : assert(count >= 0, 'count must not be negative'),
       assert(position >= 0, 'position is one-based, or 0 for no selection'),
       assert(position <= count, 'position must not pass count'),
       assert(count > 0 || position == 0, 'no records means no position');

  /// The selected record, one-based; zero while none is selected.
  final int position;

  /// How many records there are.
  final int count;

  /// What the records are ("Shifts"), announced with the position.
  final String label;

  /// Asked to move to a one-based record in `1..count`. Null disables the
  /// four movement keys (a read-only or unselectable grid).
  final ValueChanged<int>? onGo;

  /// Asked to start a new record. Null, or a locked [EraFormScope], disables
  /// the new key.
  final VoidCallback? onNew;

  /// A line under the keys, such as "Filtered: open shifts"; it wraps.
  final String? note;

  /// The most width the note asks for when its parent does not limit it.
  static const noteWidth = 320.0;

  void _go(int target) {
    assert(target >= 1 && target <= count);
    onGo?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final go = onGo != null && count > 0;
    final canNew = onNew != null && EraFormScope.enabledOf(context);
    final text = count == 0 ? '0 of 0' : '$position of $count';
    final note = this.note;
    return Semantics(
      container: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavKey(
                name: 'First record',
                glyph: _NavGlyph.first,
                onPressed: go && position != 1 ? () => _go(1) : null,
              ),
              _NavKey(
                name: 'Previous record',
                glyph: _NavGlyph.previous,
                onPressed: go && position > 1 ? () => _go(position - 1) : null,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Semantics(
                  label: count == 0
                      ? 'No records'
                      : position == 0
                      ? 'No record selected, $count records'
                      : 'Record $position of $count',
                  excludeSemantics: true,
                  child: Container(
                    key: const ValueKey('record-position'),
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      minHeight: 24,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: skin.tokens.paper,
                      border: Border(
                        top: BorderSide(color: MillenniumColors.sunkenEdge),
                        left: BorderSide(color: MillenniumColors.sunkenEdge),
                        bottom: BorderSide(color: skin.tokens.paper),
                        right: BorderSide(color: skin.tokens.paper),
                      ),
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: skin.typography.figure.copyWith(
                          color: count == 0
                              ? skin.tokens.muted
                              : skin.tokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _NavKey(
                name: 'Next record',
                glyph: _NavGlyph.next,
                onPressed: go && position < count
                    ? () => _go(position + 1)
                    : null,
              ),
              _NavKey(
                name: 'Last record',
                glyph: _NavGlyph.last,
                onPressed: go && position != count ? () => _go(count) : null,
              ),
              const SizedBox(width: 4),
              _NavKey(
                name: 'New record',
                glyph: _NavGlyph.add,
                onPressed: canNew ? onNew : null,
              ),
            ],
          ),
          if (note != null && note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: noteWidth),
                child: Text(
                  note,
                  key: const ValueKey('record-note'),
                  style: skin.typography.small.copyWith(
                    color: skin.tokens.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _NavGlyph { first, previous, next, last, add }

/// One 24 px navigator key. Mouse only: no focus, no key handling.
final class _NavKey extends StatefulWidget {
  const _NavKey({
    required this.name,
    required this.glyph,
    required this.onPressed,
  });

  final String name;
  final _NavGlyph glyph;
  final VoidCallback? onPressed;

  @override
  State<_NavKey> createState() => _NavKeyState();
}

final class _NavKeyState extends State<_NavKey> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(_NavKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _pressed = false;
      _hovered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final surface = skin.painters.key(
      skin.tokens,
      KeyKind.small,
      KeyState(enabled: _enabled, pressed: _pressed, hovered: _hovered),
    );
    final rings = surface.rings;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.name,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) {
          if (_enabled) setState(() => _hovered = true);
        },
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: Container(
            key: ValueKey('record-${widget.glyph.name}'),
            width: 24,
            height: 24,
            decoration: surface.decoration,
            foregroundDecoration: rings == null
                ? null
                : InsetRings(rings.$1, rings.$2),
            child: Center(child: _glyph(surface.ink)),
          ),
        ),
      ),
    );
  }

  Widget _glyph(Color ink) => switch (widget.glyph) {
    _NavGlyph.previous => EraGlyph(EraGlyphKind.stepBack, color: ink),
    _NavGlyph.next => EraGlyph(EraGlyphKind.stepForward, color: ink),
    _ => ExcludeSemantics(
      child: CustomPaint(
        size: const Size.square(11),
        painter: _EndGlyphPainter(widget.glyph, ink),
      ),
    ),
  };
}

/// First, last and new: a triangle with a stop bar, or with a star.
final class _EndGlyphPainter extends CustomPainter {
  const _EndGlyphPainter(this.glyph, this.color);

  final _NavGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    Path triangle(double x0, double x1) => Path()
      ..moveTo(x0, h * 0.5)
      ..lineTo(x1, h * 0.1)
      ..lineTo(x1, h * 0.9)
      ..close();
    switch (glyph) {
      case _NavGlyph.first:
        canvas
          ..drawLine(Offset(w * 0.12, h * 0.1), Offset(w * 0.12, h * 0.9), line)
          ..drawPath(triangle(w * 0.3, w * 0.9), fill);
      case _NavGlyph.last:
        canvas
          ..drawLine(Offset(w * 0.88, h * 0.1), Offset(w * 0.88, h * 0.9), line)
          ..drawPath(triangle(w * 0.7, w * 0.1), fill);
      case _NavGlyph.add:
        // A right triangle and a small star: "go to a new record".
        canvas.drawPath(triangle(w * 0.55, 0), fill);
        final c = Offset(w * 0.8, h * 0.5);
        final r = w * 0.17;
        line.strokeWidth = 1.2;
        for (final d in const [
          Offset(1, 0),
          Offset(0, 1),
          Offset(0.7, 0.7),
          Offset(0.7, -0.7),
        ]) {
          canvas.drawLine(c - d * r, c + d * r, line);
        }
      case _NavGlyph.previous || _NavGlyph.next:
        break;
    }
  }

  @override
  bool shouldRepaint(_EndGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
