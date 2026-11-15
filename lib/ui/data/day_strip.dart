import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/era_scrollbar.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// The tint of a day cell: none, or one of four, by shift type order.
enum DayTone { none, first, second, third, fourth }

/// One day of a [DayStrip] or [MonthStrip]: its letter, tone and marks.
/// The words in [semantics] carry its meaning; colour only supports them.
@immutable
final class DayMark {
  const DayMark({
    required this.semantics,
    this.text = '',
    this.tone = DayTone.none,
    this.ring = false,
    this.strong = false,
    this.hatched = false,
    this.weekend = false,
  });

  /// The full words, such as "Mon 2026-10-19, Day, today".
  final String semantics;

  /// The letter shown, such as "D"; empty for an off day.
  final String text;
  final DayTone tone;

  /// Today: a 2 px outline.
  final bool ring;

  /// Bold text: a confirmed day.
  final bool strong;

  /// Belongs to something else (another schedule): hatched, no text.
  final bool hatched;

  /// A weekend: an untoned cell takes the weekend tint.
  final bool weekend;
}

/// [tone]'s tint and edge; null for [DayTone.none].
(Color, Color)? dayToneColours(DayTone tone) => switch (tone) {
  DayTone.none => null,
  DayTone.first => (MillenniumColors.toneFirst, MillenniumColors.toneFirstEdge),
  DayTone.second => (
    MillenniumColors.toneSecond,
    MillenniumColors.toneSecondEdge,
  ),
  DayTone.third => (MillenniumColors.toneThird, MillenniumColors.toneThirdEdge),
  DayTone.fourth => (
    MillenniumColors.toneFourth,
    MillenniumColors.toneFourthEdge,
  ),
};

/// One day cell: tint, edge, hatching, ring and its letter.
final class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.mark,
    required this.width,
    required this.height,
    this.number,
    super.key,
  });

  final DayMark mark;
  final double width;
  final double height;

  /// The small number above the letter (a cycle day), or none.
  final int? number;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final tone = dayToneColours(mark.tone);
    final fill =
        tone?.$1 ??
        (mark.weekend ? MillenniumColors.weekendTint : tokens.paper);
    final edge = tone?.$2 ?? MillenniumColors.groupLine;
    final letter = mark.hatched || mark.text.isEmpty
        ? null
        : Text(
            mark.text,
            maxLines: 1,
            style: skin.typography.small.copyWith(
              color: tokens.ink,
              fontWeight: mark.strong || number != null
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          );
    return Semantics(
      label: mark.semantics,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _DayFrame(
          edge: edge,
          ring: mark.ring ? MillenniumColors.closeBottom : null,
          hatch: mark.hatched ? MillenniumColors.groupLine : null,
        ),
        child: Container(
          width: width,
          constraints: BoxConstraints(minHeight: height),
          color: mark.hatched ? tokens.chrome : fill,
          alignment: Alignment.center,
          child: number == null
              ? letter
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$number',
                      style: skin.typography.small.copyWith(
                        color: tokens.muted,
                        height: 1,
                      ),
                    ),
                    letter ?? const SizedBox.shrink(),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A day cell's 1 px edge, its hatching and today's 2 px ring.
final class _DayFrame extends CustomPainter {
  const _DayFrame({required this.edge, this.ring, this.hatch});

  final Color edge;
  final Color? ring;
  final Color? hatch;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (hatch case final colour?) {
      canvas.save();
      canvas.clipRect(rect);
      final paint = Paint()
        ..color = colour
        ..strokeWidth = 1;
      for (var x = -size.height; x < size.width; x += 4) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
      }
      canvas.restore();
    }
    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke,
    );
    if (ring case final colour?) {
      canvas.drawRect(
        rect.deflate(1),
        Paint()
          ..color = colour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_DayFrame oldDelegate) =>
      oldDelegate.edge != edge ||
      oldDelegate.ring != ring ||
      oldDelegate.hatch != hatch;
}

/// A rotation at a glance (schedules, the Cycle subform): [label], then one
/// numbered cell per day, then [trailing] in muted ink. With no days it
/// says "No days yet". Takes its own height; nothing takes focus.
final class DayStrip extends StatelessWidget {
  const DayStrip({
    required this.label,
    required this.marks,
    this.trailing,
    super.key,
  });

  /// Such as "Cycle, 12 days:".
  final String label;
  final List<DayMark> marks;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final scaler = MediaQuery.textScalerOf(context);
    final muted = skin.typography.body.copyWith(color: tokens.muted);
    return Container(
      decoration: BoxDecoration(
        color: tokens.paper,
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Wrap(
        spacing: 1,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Text(label, style: muted),
          ),
          if (marks.isEmpty)
            Text('No days yet', style: muted)
          else
            for (final (index, mark) in marks.indexed)
              _DayCell(
                key: ValueKey('strip-day:$index'),
                mark: mark,
                number: index + 1,
                width: scaler.scale(24),
                height: scaler.scale(22),
              ),
          if (trailing case final text?)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(text, style: muted),
            ),
        ],
      ),
    );
  }
}

/// One month of a [MonthStrip]: its days from the 1st, and its totals, or
/// a [note] spanning the totals' columns instead.
@immutable
final class MonthStripRow {
  const MonthStripRow({
    required this.label,
    required this.days,
    required this.totals,
    this.note,
  });

  /// Such as "Oct 2026".
  final String label;
  final List<DayMark> days;
  final List<String> totals;
  final String? note;
}

/// Months in rows, days 1–31 across, then each month's totals (the
/// schedule Preview). Days past a month's end stay empty. Scrolls sideways
/// under the era scrollbar when narrower than its content. Mouse only.
final class MonthStrip extends StatefulWidget {
  const MonthStrip({
    required this.label,
    required this.rows,
    required this.totalHeads,
    super.key,
  });

  /// What it shows, for assistive technology ("Preview").
  final String label;
  final List<MonthStripRow> rows;
  final List<String> totalHeads;

  @override
  State<MonthStrip> createState() => _MonthStripState();
}

final class _MonthStripState extends State<MonthStrip> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final scaler = MediaQuery.textScalerOf(context);
    final body = skin.typography.body.copyWith(color: tokens.ink);
    final figure = skin.typography.figure.copyWith(color: tokens.ink);
    final month = scaler.scale(64);
    final day = scaler.scale(19);
    final total = scaler.scale(58);
    final pay = scaler.scale(92);
    final rowHeight = math.max(24.0, scaler.scale(14) + 10);
    double totalWidth(int index) =>
        index == widget.totalHeads.length - 1 ? pay : total;
    var totalsWidth = 0.0;
    for (var i = 0; i < widget.totalHeads.length; i++) {
      totalsWidth += totalWidth(i);
    }
    final width = month + 31 * day + totalsWidth + 8;

    Widget head(
      String text,
      double width, {
      TextAlign align = TextAlign.center,
      double pad = 4,
    }) => Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: 3),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: tokens.chromeLine)),
      ),
      child: Text(text, textAlign: align, maxLines: 1, style: body),
    );

    final header = Container(
      decoration: BoxDecoration(
        gradient: skin.painters.columnHead(tokens),
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          head('Month', month, align: TextAlign.left),
          for (var d = 1; d <= 31; d++) head('$d', day, pad: 0),
          for (final (index, text) in widget.totalHeads.indexed)
            head(text, totalWidth(index), align: TextAlign.right),
        ],
      ),
    );

    Widget line(int index, MonthStripRow row) {
      final totals = row.note == null
          ? [
              for (final (i, text) in row.totals.indexed)
                Container(
                  width: totalWidth(i),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.centerRight,
                  child: Text(text, maxLines: 1, style: figure),
                ),
            ]
          : [
              Container(
                width: totalsWidth,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.centerRight,
                child: Text(
                  row.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body.copyWith(color: tokens.muted),
                ),
              ),
            ];
      return Container(
        height: rowHeight,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.rule)),
        ),
        child: Row(
          children: [
            Container(
              width: month,
              padding: const EdgeInsets.only(left: 5),
              alignment: Alignment.centerLeft,
              child: Text(row.label, maxLines: 1, style: body),
            ),
            for (var d = 1; d <= 31; d++)
              SizedBox(
                width: day,
                child: d > row.days.length
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: _DayCell(
                          key: ValueKey('month-day:$index:$d'),
                          mark: row.days[d - 1],
                          width: day - 2,
                          height: rowHeight - 6,
                        ),
                      ),
              ),
            ...totals,
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      label: widget.label,
      child: DecoratedBox(
        decoration: BoxDecoration(color: tokens.paper),
        child: EraScrollbar(
          controller: _horizontal,
          axis: Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              // Short of room, the months scroll down as well (by wheel;
              // a bar there would take the rows' width).
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      header,
                      for (final (index, row) in widget.rows.indexed)
                        line(index, row),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
