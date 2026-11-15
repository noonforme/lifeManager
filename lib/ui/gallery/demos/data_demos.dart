import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../ui.dart';
import '../gallery_demo.dart';
import 'tree_view_demo.dart';

final dataDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'data/data_register',
    widget: 'DataRegister',
    summary:
        'The details list: bevelled sortable headers, group rows, 20 px rows, '
        'planned rows greyed, a subtotal.',
    size: const Size(640, 260),
    build: (context, knobs) => GalleryValue<String?>(
      initial: '2026-10-06',
      builder: (context, selected, select) => SizedBox(
        width: 600 * knobs.textScale,
        height: 220 * knobs.textScale,
        child: DataRegister<_Day>(
          label: 'Shifts',
          lines: [
            GroupLine<_Day>(
              label: 'October 2026',
              summary: knobs.text(
                '3 shifts',
                '3 shifts, 34:30 paid, EUR 634.80 expected',
              ),
            ),
            for (final day in _days)
              RowLine<_Day>(
                day,
                state: day.planned ? RowState.planned : RowState.normal,
              ),
            const SubtotalLine<_Day>(
              label: 'Total',
              cells: {'paid': '34:30', 'pay': 'EUR 634.80'},
            ),
          ],
          columns: [
            RegisterColumn<_Day>(
              key: 'date',
              label: 'Date',
              kind: ColumnKind.date,
              width: 96,
              value: (day) => day.date,
            ),
            RegisterColumn<_Day>(
              key: 'type',
              label: 'Type',
              kind: ColumnKind.text,
              width: 64,
              value: (day) => day.type,
            ),
            RegisterColumn<_Day>(
              key: 'paid',
              label: 'Paid',
              kind: ColumnKind.duration,
              width: 64,
              value: (day) => day.paid,
            ),
            RegisterColumn<_Day>(
              key: 'pay',
              label: 'Est. pay',
              kind: ColumnKind.money,
              width: 96,
              value: (day) => day.pay,
            ),
            RegisterColumn<_Day>(
              key: 'state',
              label: 'State',
              kind: ColumnKind.state,
              width: 96,
              value: (day) => day.state,
            ),
          ],
          rowId: (day) => day.date,
          rowLabel: (day) => 'Shift ${day.date}',
          selectedId: selected,
          onOpen: (day) => select(day.date),
          sortedColumn: 'date',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/cell_selection_scope',
    widget: 'CellSelectionScope',
    summary:
        'Shares the selected list cell with the window, for a derived '
        "figure's explanation.",
    build: (context, knobs) => _CellSelectionDemo(knobs: knobs),
  ),
  GalleryDemo(
    id: 'data/operational_state',
    widget: 'OperationalState',
    summary:
        "A sheet's loading, empty, unavailable, conflict and uncertain "
        'states.',
    build: (context, knobs) => SizedBox(
      width: 420 * knobs.textScale,
      height: 180 * knobs.textScale,
      child: OperationalState(
        kind: knobs.error
            ? OperationalStateKind.unavailable
            : OperationalStateKind.empty,
        title: knobs.error ? 'Shifts are unavailable' : 'No shifts yet',
        message: knobs.text(
          'Add a shift or set up a schedule.',
          'Add a shift by hand, or set up a pay agreement and a schedule so '
              'planned days appear here.',
        ),
        action: KeyButton(label: 'Add a shift', onPressed: knobs.press(() {})),
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/day_strip',
    widget: 'DayStrip',
    summary:
        "A rotation at a glance: one numbered cell per cycle day, today's "
        'ringed.',
    size: const Size(560, 60),
    build: (context, knobs) => DayStrip(
      label: knobs.longText
          ? 'Cycle of the depot rotation, 12 days:'
          : 'Cycle, 12 days:',
      marks: [
        for (var day = 1; day <= 12; day++)
          DayMark(
            text: day <= 3 ? 'D' : (day <= 6 ? 'N' : ''),
            tone: day <= 3
                ? DayTone.first
                : (day <= 6 ? DayTone.second : DayTone.none),
            ring: day == 1,
            semantics: 'Cycle day $day',
          ),
      ],
      trailing: knobs.text(
        '6 shifts, 69:00 paid',
        'Today is cycle day 1 · 6 shifts, 69:00 paid per cycle',
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/month_strip',
    widget: 'MonthStrip',
    summary:
        "Months in rows, days across, each month's totals; another "
        "schedule's days hatched.",
    size: const Size(940, 170),
    build: (context, knobs) => SizedBox(
      width: 900 * knobs.textScale,
      height: 130 * knobs.textScale,
      child: MonthStrip(
        label: 'Preview',
        totalHeads: const ['Shifts', 'Paid', 'Planned pay'],
        rows: [
          for (final (year, month, days) in [
            (2026, 10, 31),
            (2026, 11, 30),
            (2026, 12, 31),
            (2027, 1, 31),
          ])
            _monthRow(year, month, days),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/day_calendar',
    widget: 'DayCalendar',
    summary:
        'One month, each day in words: planned and confirmed shifts, a '
        "night's morning, leave, a cancelled shift; today ringed. Click a "
        'day to select it.',
    size: const Size(810, 520),
    build: (context, knobs) => GalleryValue<LocalDate?>(
      initial: const LocalDate(2026, 10, 19),
      // The Calendar sheet's middle column at 1280 x 800.
      builder: (context, selected, select) => SizedBox(
        width: 770 * knobs.textScale,
        height: 480 * knobs.textScale,
        child: DayCalendar(
          label: 'Calendar',
          month: const LocalDate(2026, 10, 1),
          today: const LocalDate(2026, 10, 20),
          selected: selected,
          onSelect: knobs.enabled ? select : null,
          enabled: knobs.enabled,
          days: _calendarDays(knobs.longText),
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/day_calendar_key',
    widget: 'DayCalendarKey',
    summary: "The calendar's key: each tone's swatch and its word.",
    size: const Size(360, 40),
    build: (context, knobs) => DayCalendarKey([
      (DayTone.first, knobs.text('Day', 'Day shift')),
      (DayTone.second, knobs.text('Night', 'Night shift')),
      (DayTone.third, 'Extra'),
      (DayTone.fourth, 'Leave'),
    ]),
  ),
  treeViewDemo,
];

/// A synthetic 3 days / 3 nights / 6 off rotation from 2026-09-01, handed
/// over to another schedule from 2027.
MonthStripRow _monthRow(int year, int month, int days) {
  const names = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final start = DateTime.utc(2026, 9, 1);
  var dayShifts = 0;
  var nights = 0;
  final marks = <DayMark>[];
  for (var day = 1; day <= days; day++) {
    final date = DateTime.utc(year, month, day);
    final weekend = date.weekday >= DateTime.saturday;
    if (year > 2026) {
      marks.add(
        DayMark(
          hatched: true,
          weekend: weekend,
          semantics: '$day, Winter rotation',
        ),
      );
      continue;
    }
    final cycle = date.difference(start).inDays % 12;
    final kind = cycle < 3 ? 'D' : (cycle < 6 ? 'N' : '');
    if (kind == 'D') dayShifts++;
    if (kind == 'N') nights++;
    marks.add(
      DayMark(
        text: kind,
        tone: kind == 'D'
            ? DayTone.first
            : (kind == 'N' ? DayTone.second : DayTone.none),
        weekend: weekend,
        ring: year == 2026 && month == 10 && day == 19,
        strong: year == 2026 && month == 10 && day < 10 && kind.isNotEmpty,
        semantics: '$day ${kind.isEmpty ? 'Off' : kind}',
      ),
    );
  }
  final paid = (dayShifts + nights) * 690;
  return MonthStripRow(
    label: '${names[month]} $year',
    days: marks,
    totals: [
      '${dayShifts + nights}',
      '${paid ~/ 60}:${(paid % 60).toString().padLeft(2, '0')}',
      'EUR ${(dayShifts * 211.60 + nights * 280.60).toStringAsFixed(2).replaceFirstMapped(RegExp(r'^(\d)(\d{3})'), (m) => '${m[1]} ${m[2]}')}',
    ],
    note: year > 2026 ? 'Winter rotation' : null,
  );
}

final class _Day {
  const _Day(
    this.date,
    this.type,
    this.paid,
    this.pay,
    this.state, {
    this.planned = false,
  });

  final String date;
  final String type;
  final String paid;
  final String pay;
  final String state;
  final bool planned;
}

const _days = [
  _Day('2026-10-05', 'Day', '11:30', 'EUR 211.60', 'Finalized'),
  _Day('2026-10-06', 'Day', '11:30', 'EUR 211.60', 'To confirm'),
  _Day('2026-10-07', 'Day', '11:30', 'EUR 211.60', 'To confirm'),
  _Day('2026-10-11', 'Night', '11:30', 'EUR 280.60', 'Planned', planned: true),
];

final class _CellSelectionDemo extends StatefulWidget {
  const _CellSelectionDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_CellSelectionDemo> createState() => _CellSelectionDemoState();
}

final class _CellSelectionDemoState extends State<_CellSelectionDemo> {
  final _cells = CellSelectionController();

  @override
  void dispose() {
    _cells.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CellSelectionScope(
    controller: _cells,
    child: ValueListenableBuilder<CellSelection?>(
      valueListenable: _cells,
      builder: (context, cell, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cell == null
                ? 'No cell selected.'
                : '${cell.columnLabel}: ${cell.display}',
          ),
          KeyButton(
            label: 'Select paid time',
            onPressed: widget.knobs.press(
              () => _cells.value = CellSelection(
                owner: this,
                reference: 'D1',
                columnLabel: 'Paid',
                display: '11:30',
              ),
            ),
          ),
          KeyButton(
            label: 'Clear selection',
            onPressed: widget.knobs.press(() => _cells.clearFrom(this)),
          ),
        ],
      ),
    ),
  );
}

/// October 2026 of a synthetic 3 days / 3 nights / 6 off rotation from
/// 2026-09-01, in the Calendar's words.
Map<LocalDate, DayCalendarDay> _calendarDays(bool long) {
  const day = DayCalendarLine('Day 07:00–19:00', tone: DayTone.first);
  const night = DayCalendarLine('Night 19:00–07:00', tone: DayTone.second);
  const morning = DayCalendarLine(
    'Night until 07:00',
    tone: DayTone.second,
    ink: DayCalendarInk.muted,
  );
  const confirmed = DayCalendarLine(
    'Confirmed',
    mark: DayCalendarMark.confirmed,
    ink: DayCalendarInk.ok,
  );
  const toConfirm = DayCalendarLine(
    'To confirm',
    mark: DayCalendarMark.warning,
    ink: DayCalendarInk.run,
  );
  final days = <LocalDate, DayCalendarDay>{};
  for (var date = 1; date <= 31; date++) {
    // The cycle day: 0–2 Day, 3–5 Night, 6–11 Off.
    final cycle = (29 + date) % 12;
    final cancelled = date == 22;
    final leave = date == 12;
    final lines = <DayCalendarLine>[
      // The morning after a night that was worked.
      if (cycle >= 4 && cycle <= 6 && date != 13 && date != 23) morning,
      if (cycle < 3) day,
      if (cycle >= 3 && cycle < 6)
        cancelled
            ? const DayCalendarLine('', struck: 'Night 19:00–07:00')
            : leave
            ? const DayCalendarLine('Vacation (Night)', tone: DayTone.fourth)
            : night,
      if (cancelled)
        const DayCalendarLine('Cancelled · Swapped', ink: DayCalendarInk.muted)
      else if (cycle < 6 && date <= 8)
        confirmed
      else if (cycle < 6 && date < 20)
        long
            ? const DayCalendarLine(
                'To confirm, changed from its plan',
                mark: DayCalendarMark.warning,
                ink: DayCalendarInk.run,
              )
            : toConfirm,
    ];
    days[LocalDate(2026, 10, date)] = DayCalendarDay(lines: lines);
  }
  return days;
}
