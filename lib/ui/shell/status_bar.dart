import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/era_scrollbar.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// One sunken panel of a [StatusBar]: a count, a total, "Local database".
/// The caller supplies the display text.
@immutable
final class StatusPanel {
  const StatusPanel(this.text, {this.semanticLabel});

  final String text;

  /// What a screen reader says when it differs from [text].
  final String? semanticLabel;
}

/// The status bar (database shell spec 3, item 5): the last notice or the
/// pending summary, sunken [panels], [warning] text in run ink and a painted
/// size grip, in a bar at least 22 px high.
///
/// It reflows by measured text, not by a fixed breakpoint. When the notice
/// and every panel fit on one line they share the row; otherwise the notice
/// takes the full width (its height capped at three lines, scrolling inside)
/// and the panels wrap onto further rows, each limited to the width of the
/// bar so a long panel wraps its own text. The whole bar is also capped (by
/// [maxHeight], or 30 % of a bounded parent, but room for three lines) and scrolls past the cap, so it
/// can never consume the page around it.
///
/// The size grip is decorative: a fixed 16 px mark that takes no space from
/// the text and does not resize the window (native resize belongs to the
/// shell phase). It is hidden from screen readers. Nothing in the bar takes
/// keyboard focus.
final class StatusBar extends StatefulWidget {
  const StatusBar({
    this.notice,
    this.panels = const [],
    this.warning,
    this.sizeGrip = true,
    this.maxHeight,
    super.key,
  });

  /// The last notice or the pending edit summary; announced when it changes.
  final String? notice;
  final List<StatusPanel> panels;

  /// Run-ink warning text such as "3 days to confirm", with a warning mark.
  final String? warning;

  /// Paints the decorative size grip at the right end.
  final bool sizeGrip;

  /// The most height the bar may take, or null for 30 % of a bounded parent
  /// (and four lines when the parent is unbounded).
  final double? maxHeight;

  @override
  State<StatusBar> createState() => _StatusBarState();
}

const _barMin = 22.0;
const _pad = 2.0;
const _gap = 2.0;
const _gripSize = 16.0;

/// The least height in which an era scrollbar (two arrow keys and a thumb) fits.
const _scrollRoom = 2 * EraScrollbar.thickness + 8;
const _panelPad = 15.0; // 6 + 6 padding, 1 + 1 border, 1 spare

final class _StatusBarState extends State<StatusBar> {
  final _bar = ScrollController();
  final _noticeScroll = ScrollController();

  @override
  void dispose() {
    _bar.dispose();
    _noticeScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final style = skin.typography.body.copyWith(color: tokens.ink);
    final warningStyle = style.copyWith(color: tokens.runInk);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);

    double measure(String text, TextStyle s) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final lineHeight = () {
      final painter = TextPainter(
        text: TextSpan(text: 'Xg', style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final result = painter.height;
      painter.dispose();
      return result;
    }();
    final panelMin = math.max(_barMin - 2 * _pad - 1, lineHeight + 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final grip = widget.sizeGrip ? _gripSize : 0.0;
        final inner = math.max(0.0, constraints.maxWidth - 2 * _pad - grip);
        final notice = widget.notice;
        final warning = widget.warning;
        const warningMark = 16.0 + 4.0;

        // Natural single-line widths decide the layout.
        final panelWidths = [
          for (final panel in widget.panels)
            measure(panel.text, style) + _panelPad,
        ];
        final warningWidth = warning == null
            ? 0.0
            : measure(warning, warningStyle) + _panelPad + warningMark;
        final noticeWidth = notice == null
            ? 0.0
            : measure(notice, style) + _panelPad;
        final items = [
          if (notice != null) noticeWidth,
          ...panelWidths,
          if (warning != null) warningWidth,
        ];
        final oneRow =
            items.fold<double>(0, (a, b) => a + b) +
                _gap * math.max(0, items.length - 1) <=
            inner;

        Widget panel(Widget child, {String? label, bool live = false}) {
          return Semantics(
            container: true,
            label: label,
            liveRegion: live,
            excludeSemantics: label != null,
            child: Container(
              constraints: BoxConstraints(minHeight: panelMin),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.centerLeft,
              decoration: _sunken(tokens.paper),
              child: child,
            ),
          );
        }

        final panelWidgets = [
          for (final p in widget.panels)
            panel(Text(p.text, style: style), label: p.semanticLabel ?? p.text),
          if (warning != null)
            panel(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EraIcon(EraIconKind.warning),
                  const SizedBox(width: 4),
                  Flexible(child: Text(warning, style: warningStyle)),
                ],
              ),
              label: 'Warning: $warning',
              live: true,
            ),
        ];

        final Widget content;
        if (oneRow) {
          content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: notice == null
                    ? const SizedBox.shrink()
                    : panel(
                        Text(notice, style: style),
                        label: notice,
                        live: true,
                      ),
              ),
              for (final w in panelWidgets) ...[const SizedBox(width: _gap), w],
            ],
          );
        } else {
          final noticeCap = math.max(3 * lineHeight + 4, _scrollRoom);
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null)
                Semantics(
                  container: true,
                  liveRegion: true,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: noticeCap),
                    padding: const EdgeInsets.only(left: 6, top: 1, bottom: 1),
                    decoration: _sunken(tokens.paper),
                    child: EraScrollbar(
                      controller: _noticeScroll,
                      axis: Axis.vertical,
                      child: _Shrunk(
                        controller: _noticeScroll,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(notice, style: style),
                        ),
                      ),
                    ),
                  ),
                ),
              if (panelWidgets.isNotEmpty) ...[
                if (notice != null) const SizedBox(height: _gap),
                Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    for (final w in panelWidgets)
                      // Finite constraints: one panel never exceeds the bar,
                      // and a longer text wraps inside it.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: inner),
                        child: w,
                      ),
                  ],
                ),
              ],
            ],
          );
        }

        final cap =
            widget.maxHeight ??
            (constraints.hasBoundedHeight
                ? math.max(
                    constraints.maxHeight * 0.3,
                    // Three lines of text, and room for a scrollbar.
                    math.max(3 * (lineHeight + 4) + 2 * _pad + 1, _scrollRoom),
                  )
                : 4 * (lineHeight + 4) + 2 * _pad);
        final limit = math.min(
          math.max(cap, _barMin),
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : double.infinity,
        );

        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Status',
          child: Container(
            constraints: BoxConstraints(
              minHeight: math.min(_barMin, limit),
              maxHeight: limit,
            ),
            padding: const EdgeInsets.all(_pad),
            decoration: BoxDecoration(
              color: tokens.chrome,
              border: Border(top: BorderSide(color: tokens.paper)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: EraScrollbar(
                    controller: _bar,
                    axis: Axis.vertical,
                    child: _Shrunk(controller: _bar, child: content),
                  ),
                ),
                if (widget.sizeGrip)
                  const ExcludeSemantics(
                    child: SizedBox(
                      width: _gripSize,
                      height: _gripSize,
                      child: CustomPaint(painter: _GripPainter()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A vertical scroll area that is as tall as its content up to the room it
/// is given, then scrolls. The era scrollbar around it is the only bar.
final class _Shrunk extends StatelessWidget {
  const _Shrunk({required this.controller, required this.child});

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: CustomScrollView(
      controller: controller,
      shrinkWrap: true,
      slivers: [SliverToBoxAdapter(child: child)],
    ),
  );
}

/// A sunken panel: dark top-left edge, white bottom-right edge.
BoxDecoration _sunken(Color light) => BoxDecoration(
  border: Border(
    top: const BorderSide(color: MillenniumColors.sunkenEdge),
    left: const BorderSide(color: MillenniumColors.sunkenEdge),
    bottom: BorderSide(color: light),
    right: BorderSide(color: light),
  ),
);

/// The era's size grip: diagonal rows of dots in the bottom-right corner.
final class _GripPainter extends CustomPainter {
  const _GripPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xffffffff);
    final dark = Paint()..color = MillenniumColors.sunkenEdge;
    for (var row = 0; row < 3; row++) {
      for (var i = 0; i <= row; i++) {
        final x = size.width - 3 - 4 * i;
        final y = size.height - 3 - 4 * (row - i);
        canvas
          ..drawRect(Rect.fromLTWH(x + 1, y + 1, 2, 2), light)
          ..drawRect(Rect.fromLTWH(x, y, 2, 2), dark);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter oldDelegate) => false;
}
