import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'era_controls.dart';
import 'millennium_style.dart';

/// Gives every scroll area the era scrollbar and no overscroll glow
/// (XP-authentic shell spec 6.2). One-line text fields ask for no
/// scrollbar and get none.
final class EraScrollBehavior extends MaterialScrollBehavior {
  const EraScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final controller = details.controller;
    if (controller == null) return child;
    return EraScrollbar(
      controller: controller,
      axis: axisDirectionToAxis(details.direction),
      child: child,
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// A 17 px era scrollbar beside (or under) its scroll area: arrow keys at
/// both ends, a pale track and a blue thumb with grip lines. Shown only
/// while the content overflows.
final class EraScrollbar extends StatefulWidget {
  const EraScrollbar({
    required this.controller,
    required this.axis,
    required this.child,
    this.depth = 0,
    super.key,
  });

  static const thickness = 17.0;
  static const step = 20.0;

  final ScrollController controller;
  final Axis axis;
  final Widget child;

  /// How many scroll views lie between this bar and the one it follows:
  /// 0 for its own child, 1 for a list inside a sideways-scrolling table.
  final int depth;

  @override
  State<EraScrollbar> createState() => _EraScrollbarState();
}

final class _EraScrollbarState extends State<EraScrollbar> {
  final _content = GlobalKey(debugLabel: 'Era scroll area');
  ScrollMetrics? _metrics;
  Timer? _repeat;

  bool get _vertical => widget.axis == Axis.vertical;

  void _update(ScrollMetrics metrics) {
    if (metrics.axis != widget.axis) return;
    final old = _metrics;
    if (old != null &&
        old.pixels == metrics.pixels &&
        old.minScrollExtent == metrics.minScrollExtent &&
        old.maxScrollExtent == metrics.maxScrollExtent &&
        old.viewportDimension == metrics.viewportDimension) {
      return;
    }
    final copy = metrics.copyWith();
    // A position clamped during layout (its content just shrank) reports
    // mid-frame, when a rebuild can no longer be asked for; the bar then
    // catches up right after the frame.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) setState(() => _metrics = copy);
      });
      return;
    }
    setState(() => _metrics = copy);
  }

  void _scrollBy(double delta) {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    widget.controller.jumpTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  void _startRepeat(double delta) {
    _scrollBy(delta);
    _repeat?.cancel();
    _repeat = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _scrollBy(delta),
      );
    });
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == widget.depth) {
          _update(notification.metrics);
        }
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == widget.depth) {
            _update(notification.metrics);
          }
          return false;
        },
        child: widget.child,
      ),
    );
    final metrics = _metrics;
    final overflow =
        metrics != null && metrics.maxScrollExtent > metrics.minScrollExtent;
    // The scroll area keeps its state (position, focus) when the bar
    // comes and goes: the global key carries it into and out of the row.
    final kept = KeyedSubtree(key: _content, child: content);
    // Only content that overflows its viewport gets a bar, and such a
    // viewport is always bounded, so the row never sees infinite room.
    // Without a bar the scroll area is returned as is, which keeps
    // intrinsic sizing (popup menus) working.
    if (!overflow) return kept;
    final bar = SizedBox(
      key: const ValueKey('era-scrollbar'),
      width: _vertical ? EraScrollbar.thickness : null,
      height: _vertical ? null : EraScrollbar.thickness,
      child: _bar(metrics),
    );
    return _vertical
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: kept),
              bar,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: kept),
              bar,
            ],
          );
  }

  Widget _bar(ScrollMetrics metrics) {
    final children = [
      _ArrowKey(
        key: const ValueKey('era-scrollbar-back'),
        glyph: _vertical ? EraGlyphKind.sortUp : EraGlyphKind.stepBack,
        onDown: () => _startRepeat(-EraScrollbar.step),
        onUp: _stopRepeat,
      ),
      Expanded(
        child: LayoutBuilder(
          key: const ValueKey('era-scrollbar-track'),
          builder: (context, constraints) {
            final track = _vertical
                ? constraints.maxHeight
                : constraints.maxWidth;
            final range = metrics.maxScrollExtent - metrics.minScrollExtent;
            final thumb = math.min(
              track,
              math.max(
                EraScrollbar.thickness,
                track *
                    metrics.viewportDimension /
                    (range + metrics.viewportDimension),
              ),
            );
            final travel = math.max(0.0, track - thumb);
            final offset = range == 0
                ? 0.0
                : travel * (metrics.pixels - metrics.minScrollExtent) / range;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final at = _vertical
                    ? details.localPosition.dy
                    : details.localPosition.dx;
                _scrollBy(
                  at < offset
                      ? -metrics.viewportDimension
                      : metrics.viewportDimension,
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: _vertical
                        ? Alignment.centerLeft
                        : Alignment.topCenter,
                    end: _vertical
                        ? Alignment.centerRight
                        : Alignment.bottomCenter,
                    colors: const [
                      MillenniumColors.scrollTrackEdge,
                      MillenniumColors.scrollTrack,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: _vertical ? 0 : offset,
                      right: _vertical ? 0 : null,
                      top: _vertical ? offset : 0,
                      bottom: _vertical ? null : 0,
                      width: _vertical ? null : thumb,
                      height: _vertical ? thumb : null,
                      child: GestureDetector(
                        key: const ValueKey('era-scrollbar-thumb'),
                        onVerticalDragUpdate: _vertical && travel > 0
                            ? (details) =>
                                  _scrollBy(details.delta.dy * range / travel)
                            : null,
                        onHorizontalDragUpdate: !_vertical && travel > 0
                            ? (details) =>
                                  _scrollBy(details.delta.dx * range / travel)
                            : null,
                        child: _Face(grip: true, vertical: _vertical),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      _ArrowKey(
        key: const ValueKey('era-scrollbar-forward'),
        glyph: _vertical ? EraGlyphKind.sortDown : EraGlyphKind.stepForward,
        onDown: () => _startRepeat(EraScrollbar.step),
        onUp: _stopRepeat,
      ),
    ];
    // Decorative for screen readers: the scroll area itself is announced
    // and scrolled by them.
    return ExcludeSemantics(
      child: _vertical ? Column(children: children) : Row(children: children),
    );
  }
}

final class _ArrowKey extends StatelessWidget {
  const _ArrowKey({
    required this.glyph,
    required this.onDown,
    required this.onUp,
    super.key,
  });

  final EraGlyphKind glyph;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => onDown(),
    onTapUp: (_) => onUp(),
    onTapCancel: onUp,
    child: SizedBox.square(
      dimension: EraScrollbar.thickness,
      child: _Face(
        grip: false,
        vertical: true,
        child: Center(
          child: EraGlyph(
            glyph,
            color: MillenniumColors.comboArrowInk,
            size: 7,
          ),
        ),
      ),
    ),
  );
}

final class _Face extends StatelessWidget {
  const _Face({required this.grip, required this.vertical, this.child});

  final bool grip;
  final bool vertical;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(0.5),
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.all(Radius.circular(3)),
      border: Border.all(color: MillenniumColors.scrollFaceEdge),
      gradient: LinearGradient(
        begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
        end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const [
          MillenniumColors.scrollFaceTop,
          MillenniumColors.scrollFaceBottom,
        ],
      ),
    ),
    child: grip ? CustomPaint(painter: _GripLines(vertical: vertical)) : child,
  );
}

final class _GripLines extends CustomPainter {
  const _GripLines({required this.vertical});

  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = MillenniumColors.scrollGripLight;
    final dark = Paint()..color = MillenniumColors.scrollGripDark;
    final centre = size.center(Offset.zero);
    for (var i = -1; i <= 1; i++) {
      if (vertical) {
        final y = centre.dy + i * 2.0;
        canvas
          ..drawLine(Offset(centre.dx - 3, y), Offset(centre.dx + 3, y), light)
          ..drawLine(
            Offset(centre.dx - 3, y + 1),
            Offset(centre.dx + 3, y + 1),
            dark,
          );
      } else {
        final x = centre.dx + i * 2.0;
        canvas
          ..drawLine(Offset(x, centre.dy - 3), Offset(x, centre.dy + 3), light)
          ..drawLine(
            Offset(x + 1, centre.dy - 3),
            Offset(x + 1, centre.dy + 3),
            dark,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_GripLines oldDelegate) =>
      oldDelegate.vertical != vertical;
}
