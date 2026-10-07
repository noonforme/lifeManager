import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/era_dates.dart';
import '../../../shared/workbench/era_icons.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
import 'work_plan_view.dart';

const _weekdayHeads = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The swatch beside an entry's words; the words carry the meaning.
Color entrySwatch(DayEntryKind kind) => switch (kind) {
  DayEntryKind.planned ||
  DayEntryKind.confirmed ||
  DayEntryKind.changed => MillenniumColors.link,
  DayEntryKind.extra => MillenniumColors.orbOrange,
  DayEntryKind.leave => MillenniumColors.orbGreen,
  DayEntryKind.cancelled => MillenniumColors.tabLine,
  DayEntryKind.needsReview => MillenniumColors.sortAccent,
};

/// The Work calendar (schedules spec 6.1): a Monday-first month in the
/// details-list style, each day with up to two written entries.
final class WorkCalendar extends StatefulWidget {
  const WorkCalendar({
    required this.month,
    required this.today,
    required this.days,
    this.onOpen,
    this.onMonth,
    this.onCursor,
    this.readOnly = false,
    this.autofocus = false,
    super.key,
  });

  /// Any date in the month shown.
  final LocalDate month;
  final LocalDate today;

  /// The month's days; dates outside it show no entries.
  final Map<LocalDate, DayView> days;

  /// Enter, or a double-click on a day.
  final ValueChanged<LocalDate>? onOpen;

  /// The month to show next: Page Up/Down, or the cursor leaving the month.
  final ValueChanged<LocalDate>? onMonth;

  /// The day under the cursor changed.
  final ValueChanged<LocalDate>? onCursor;

  /// A preview: no cursor, no keys, nothing opens.
  final bool readOnly;
  final bool autofocus;

  @override
  State<WorkCalendar> createState() => _WorkCalendarState();
}

final class _WorkCalendarState extends State<WorkCalendar> {
  final _node = FocusNode(debugLabel: 'WorkCalendar');
  late LocalDate _cursor = _start();
  bool _focused = false;

  LocalDate _start() {
    final first = widget.month.firstOfMonth;
    return widget.today.firstOfMonth == first ? widget.today : first;
  }

  @override
  void didUpdateWidget(covariant WorkCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The header's ‹ › or Today moved the month; the cursor follows. A
    // cursor that walked into the new month on its own stays where it is.
    if (oldWidget.month != widget.month &&
        _cursor.firstOfMonth != widget.month.firstOfMonth) {
      _cursor = _start();
    }
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  void _move(LocalDate to) {
    setState(() => _cursor = to);
    widget.onCursor?.call(to);
    if (to.firstOfMonth != widget.month.firstOfMonth) {
      widget.onMonth?.call(to.firstOfMonth);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final LocalDate? target = switch (key) {
      LogicalKeyboardKey.arrowLeft => _cursor.addDays(-1),
      LogicalKeyboardKey.arrowRight => _cursor.addDays(1),
      LogicalKeyboardKey.arrowUp => _cursor.addDays(-7),
      LogicalKeyboardKey.arrowDown => _cursor.addDays(7),
      LogicalKeyboardKey.pageUp => _cursor.addMonthsClamped(-1),
      LogicalKeyboardKey.pageDown => _cursor.addMonthsClamped(1),
      LogicalKeyboardKey.home => _cursor.firstOfMonth,
      LogicalKeyboardKey.end => _cursor.lastOfMonth,
      _ => null,
    };
    if (target != null) {
      _move(target);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      widget.onOpen?.call(_cursor);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final grid = monthGridDays(widget.month);
    final body = Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Calendar, ${eraMonthTitle(widget.month)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border.all(color: MillenniumColors.fieldLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final head in _weekdayHeads)
                  Expanded(
                    child: ExcludeSemantics(
                      child: Container(
                        height: 20,
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
                  ),
              ],
            ),
            for (var week = 0; week < 6; week++)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final day in grid.sublist(week * 7, week * 7 + 7))
                      Expanded(child: _cell(skin, day)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    if (widget.readOnly) return body;
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: body,
    );
  }

  Widget _cell(LifeOSSkinData skin, LocalDate day) {
    final tokens = skin.tokens;
    final inMonth =
        day.year == widget.month.year && day.month == widget.month.month;
    final entries = inMonth
        ? widget.days[day]?.entries ?? const <DayEntry>[]
        : const <DayEntry>[];
    final selected = !widget.readOnly && day == _cursor;
    // Blue while the calendar has focus, face grey while not, as in a list.
    final fill = selected
        ? (_focused ? tokens.selWash : MillenniumColors.groupLine)
        : inMonth
        ? tokens.paper
        : tokens.chrome;
    final ink = selected && _focused ? tokens.selInk : tokens.ink;
    final shown = entries.length > 2 ? entries.take(2) : entries;
    Widget cell = Container(
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          right: BorderSide(color: tokens.chromeLine),
          bottom: BorderSide(color: tokens.chromeLine),
        ),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: skin.typography.figure.copyWith(
                color: inMonth ? ink : tokens.muted,
                fontWeight: day == widget.today ? FontWeight.w700 : null,
              ),
            ),
            for (final entry in shown) _EntryLine(entry: entry, ink: ink),
            if (entries.length > 2)
              Text(
                '+${entries.length - 2} more',
                style: skin.typography.body.copyWith(color: ink),
              ),
          ],
        ),
      ),
    );
    if (day == widget.today) {
      cell = DecoratedBox(
        key: const ValueKey('work-calendar-today'),
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: MillenniumColors.sortAccent, width: 2),
        ),
        child: cell,
      );
    }
    if (selected && _focused) {
      cell = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: DottedFocusRectangle(color: tokens.selInk, inset: 3),
        child: cell,
      );
    }
    final spoken = entries.isEmpty
        ? spokenDate(day)
        : '${spokenDate(day)}: ${entries.map((e) => e.spoken).join(', ')}';
    return Semantics(
      key: ValueKey('work-calendar-day-$day'),
      button: !widget.readOnly,
      selected: selected,
      label: spoken,
      excludeSemantics: true,
      onTap: widget.readOnly ? null : () => _move(day),
      child: widget.readOnly
          ? cell
          // Selects on pointer down: a tap that also listens for a double
          // tap would wait out the double-tap timeout before moving.
          : Listener(
              onPointerDown: (event) {
                if (event.buttons != kPrimaryButton) return;
                _node.requestFocus();
                _move(day);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => widget.onOpen?.call(day),
                child: cell,
              ),
            ),
    );
  }
}

/// A swatch and the entry's words on one line; a cancelled type is struck.
final class _EntryLine extends StatelessWidget {
  const _EntryLine({required this.entry, required this.ink});

  final DayEntry entry;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final colour = entrySwatch(entry.kind);
    final style = skin.typography.body.copyWith(color: ink);
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          if (entry.kind == DayEntryKind.needsReview)
            const EraIcon(EraIconKind.warning)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: entry.confirmed ? colour : null,
                border: Border.all(color: colour),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (entry.struck case final struck?)
                    TextSpan(
                      text: '$struck ',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  TextSpan(text: entry.text),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
