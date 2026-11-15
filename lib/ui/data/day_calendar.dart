import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/time/local_date.dart';
import '../controls/era_controls.dart';
import '../foundation/active_region.dart';
import '../foundation/era_dates.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';
import 'day_strip.dart';

const _weekdayHeads = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The ink of a [DayCalendarLine].
enum DayCalendarInk { normal, muted, ok, run }

/// A painted mark before a [DayCalendarLine]'s words.
enum DayCalendarMark { none, confirmed, warning }

/// One written line of a calendar day, such as "Day 07:00–19:00". The
/// words carry its meaning; the swatch and mark only support them.
@immutable
final class DayCalendarLine {
  const DayCalendarLine(
    this.text, {
    this.tone = DayTone.none,
    this.struck,
    this.ink = DayCalendarInk.normal,
    this.mark = DayCalendarMark.none,
  });

  final String text;

  /// The swatch before the words; none draws no swatch.
  final DayTone tone;

  /// Words drawn struck through before [text] (a cancelled shift).
  final String? struck;
  final DayCalendarInk ink;
  final DayCalendarMark mark;

  /// The line as one phrase, for screen readers.
  String get spoken => [?struck, if (text.isNotEmpty) text].join(' ');
}

/// What one day of a [DayCalendar] shows.
@immutable
final class DayCalendarDay {
  const DayCalendarDay({this.lines = const [], this.dimmed = false});

  final List<DayCalendarLine> lines;

  /// Left out by a filter: every line is drawn in muted ink.
  final bool dimmed;
}

/// One month's days with their entries (the Calendar sheet, spec 3): the
/// Monday-first weekday heads, then six weeks filling the height. Each
/// day shows its number and its lines; today is ringed; days outside
/// [month] show nothing and take no click. Mouse only: a click on a day
/// asks [onSelect]; nothing takes focus or keys.
final class DayCalendar extends StatelessWidget {
  const DayCalendar({
    required this.label,
    required this.month,
    required this.today,
    required this.days,
    this.selected,
    this.onSelect,
    this.active = true,
    this.enabled = true,
    super.key,
  });

  /// What screen readers call the calendar, before its month.
  final String label;

  /// Any date in the month shown.
  final LocalDate month;
  final LocalDate today;

  /// The month's days; other dates are ignored.
  final Map<LocalDate, DayCalendarDay> days;
  final LocalDate? selected;
  final ValueChanged<LocalDate>? onSelect;

  /// The selection is blue while active, face grey while not.
  final bool active;

  /// False: no day can be clicked.
  final bool enabled;

  bool _inMonth(LocalDate day) =>
      day.year == month.year && day.month == month.month;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final grid = monthGridDays(month);
    final lit = active && ActiveRegion.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$label, ${eraMonthTitle(month)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border.all(color: MillenniumColors.fieldLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final head in _weekdayHeads)
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: skin.painters.columnHead(tokens),
                          border: Border(
                            right: BorderSide(color: tokens.chromeLine),
                            bottom: BorderSide(color: tokens.chromeLine),
                          ),
                        ),
                        child: Text(
                          head,
                          style: skin.typography.label.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            for (var week = 0; week < 6; week++)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in grid.sublist(week * 7, week * 7 + 7))
                      Expanded(child: _cell(skin, day, lit)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(LifeOSSkinData skin, LocalDate day, bool active) {
    final tokens = skin.tokens;
    final inMonth = _inMonth(day);
    final entry = inMonth ? days[day] : null;
    final lines = entry?.lines ?? const <DayCalendarLine>[];
    final isSelected = inMonth && day == selected;
    final lit = isSelected && active;
    final fill = isSelected
        ? (active ? tokens.selWash : MillenniumColors.groupLine)
        : inMonth
        ? tokens.paper
        : tokens.chrome;
    Widget cell = Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 2, 2),
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          right: BorderSide(color: tokens.chromeLine),
          bottom: BorderSide(color: tokens.chromeLine),
        ),
      ),
      child: ClipRect(
        child: CustomMultiChildLayout(
          delegate: _DayLines(lines.length),
          children: [
            LayoutId(
              id: 'number',
              child: Text(
                '${day.day}',
                style: skin.typography.figure.copyWith(
                  color: !inMonth
                      ? tokens.muted
                      : lit
                      ? tokens.selInk
                      : tokens.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final (index, line) in lines.indexed)
              LayoutId(
                id: 'line$index',
                child: _Line(line: line, dimmed: entry!.dimmed, lit: lit),
              ),
            // One for each count the layout may fold away; it shows one.
            for (var more = 1; more <= lines.length; more++)
              LayoutId(
                id: 'more$more',
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    '+$more more',
                    maxLines: 1,
                    style: skin.typography.body.copyWith(
                      color: lit ? tokens.selInk : tokens.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (day == today) {
      cell = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: MillenniumColors.sortAccent, width: 2),
        ),
        child: cell,
      );
    }
    final spoken = lines.isEmpty
        ? spokenDate(day)
        : '${spokenDate(day)}: ${lines.map((line) => line.spoken).join(', ')}';
    final pick = inMonth && enabled && onSelect != null;
    return Semantics(
      key: ValueKey('day-calendar-$day'),
      button: inMonth,
      selected: isSelected,
      enabled: pick,
      label: spoken,
      excludeSemantics: true,
      onTap: pick ? () => onSelect!(day) : null,
      // Selects on pointer down, as a row of a grid does.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: pick
            ? (event) {
                if (event.buttons == kPrimaryButton) onSelect!(day);
              }
            : null,
        child: cell,
      ),
    );
  }
}

/// A day's number, then as many of its [count] lines as fit whole, in
/// order; when some do not, "+N more" follows the last one shown. A line
/// is never cut at the day's edge. What is not shown lies beyond the clip.
final class _DayLines extends MultiChildLayoutDelegate {
  _DayLines(this.count);

  final int count;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints(maxWidth: size.width);
    final top = layoutChild('number', loose).height;
    positionChild('number', Offset.zero);
    final heights = [
      for (var index = 0; index < count; index++)
        layoutChild('line$index', loose).height,
    ];
    final more = [
      for (var folded = 1; folded <= count; folded++)
        layoutChild('more$folded', loose).height,
    ];
    double through(int shown) =>
        top + heights.take(shown).fold(0.0, (sum, height) => sum + height);
    var shown = count;
    if (through(count) > size.height) {
      shown = count - 1;
      while (shown > 0 &&
          through(shown) + more[count - shown - 1] > size.height) {
        shown--;
      }
    }
    // Far below the clip, so nothing of it can show or be found there.
    final away = Offset(0, size.height * 2 + 100);
    var y = top;
    for (var index = 0; index < count; index++) {
      positionChild('line$index', index < shown ? Offset(0, y) : away);
      if (index < shown) y += heights[index];
    }
    for (var folded = 1; folded <= count; folded++) {
      positionChild(
        'more$folded',
        folded == count - shown ? Offset(0, y) : away,
      );
    }
  }

  @override
  bool shouldRelayout(_DayLines oldDelegate) => oldDelegate.count != count;
}

/// A swatch or mark, then the words; a cancelled shift's words struck.
final class _Line extends StatelessWidget {
  const _Line({required this.line, required this.dimmed, required this.lit});

  final DayCalendarLine line;
  final bool dimmed;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final ink = lit
        ? tokens.selInk
        : dimmed
        ? tokens.muted
        : switch (line.ink) {
            DayCalendarInk.normal => tokens.ink,
            DayCalendarInk.muted => tokens.muted,
            DayCalendarInk.ok => tokens.positive,
            DayCalendarInk.run => tokens.runInk,
          };
    final tone = dayToneColours(line.tone);
    final size = MediaQuery.textScalerOf(context).scale(8);
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tone != null) ...[
            Container(
              width: size,
              height: size,
              margin: EdgeInsets.only(top: size / 2),
              decoration: BoxDecoration(
                color: tone.$1,
                border: Border.all(color: tone.$2),
              ),
            ),
            const SizedBox(width: 3),
          ],
          switch (line.mark) {
            DayCalendarMark.none => const SizedBox.shrink(),
            DayCalendarMark.confirmed => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: EraGlyph(EraGlyphKind.tick, color: ink, size: size + 1),
            ),
            DayCalendarMark.warning => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: EraIcon(EraIconKind.warning, size: size + 3),
            ),
          },
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (line.struck case final struck?)
                    TextSpan(
                      text: line.text.isEmpty ? struck : '$struck ',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  if (line.text.isNotEmpty) TextSpan(text: line.text),
                ],
              ),
              // A line too long for the day wraps once rather than lose
              // its end time.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.body.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The calendar's key: each tone's swatch and its word, on one line.
final class DayCalendarKey extends StatelessWidget {
  const DayCalendarKey(this.entries, {super.key});

  final List<(DayTone, String)> entries;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final size = MediaQuery.textScalerOf(context).scale(8);
    return Wrap(
      spacing: 10,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (tone, word) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dayToneColours(tone) case (final tint, final edge))
                Container(
                  width: size,
                  height: size,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: tint,
                    border: Border.all(color: edge),
                  ),
                ),
              Text(
                word,
                style: skin.typography.body.copyWith(color: tokens.ink),
              ),
            ],
          ),
      ],
    );
  }
}
