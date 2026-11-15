import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../core/time/timezone_service.dart';
import '../../ui/ui.dart';
import 'schedules_subform.dart' show toneOf;
import 'shifts_lines.dart';
import 'shifts_rows.dart';
import 'shifts_sheet_controller.dart';

/// The Calendar's words for each day of [sheet]'s month (plan 4d-2,
/// owner pick 1A), from its [lines] so a pending change shows as typed.
/// Per day: the morning of the night before ("Night until 07:00", muted;
/// on the 1st from the sheet's [ShiftsSheetController.eve]),
/// then each entry's words and what waits on it. A day is dimmed when
/// [type] is set and none of its entries or mornings has it, or when
/// [find] is set and none of its words hold it.
Map<LocalDate, DayCalendarDay> calendarDays({
  required ShiftsSheetController sheet,
  required List<ShiftsLine> lines,
  required TimezoneService timezones,
  String? type,
  String find = '',
}) {
  final rows = {
    for (final row in [...sheet.eve, ...sheet.rows]) row.id: row,
  };
  final typeNames = sheet.shiftTypeNames;
  DayTone toneFor(String? name) => switch (name) {
    'Extra' => DayTone.third,
    null || 'Manual' => DayTone.none,
    _ => switch (typeNames.indexOf(name)) {
      -1 => DayTone.none,
      final index => toneOf(index),
    },
  };
  String clock(LocalTime time) => formatValue(ValueKind.time, time);

  final mornings = <LocalDate, List<DayCalendarLine>>{};
  final entries = <LocalDate, List<DayCalendarLine>>{};
  final types = <LocalDate, Set<String>>{};
  void add(LocalDate date, List<DayCalendarLine> words, String? name) {
    entries.putIfAbsent(date, () => []).addAll(words);
    if (name != null) types.putIfAbsent(date, () => {}).add(name);
  }

  /// What waits on a planned day or leave, under its words.
  DayCalendarLine? waiting(ShiftsLine line) {
    if (line.toConfirm) {
      return DayCalendarLine(
        line.status == ShiftsStatus.changed
            ? 'To confirm, changed'
            : 'To confirm',
        mark: DayCalendarMark.warning,
        ink: DayCalendarInk.run,
      );
    }
    if (line.withoutAgreement) {
      return const DayCalendarLine(
        'No pay agreement',
        ink: DayCalendarInk.muted,
      );
    }
    return null;
  }

  final eve = [
    for (final row in sheet.eve) shiftsLine(row, timezones, sheet.today),
  ];
  for (final line in [...eve, ...lines]) {
    final row = rows[line.id];
    final name = line.type;
    switch (row) {
      case LeaveRow(:final day):
        add(line.date, [
          DayCalendarLine(
            '${leaveTypeWord(day.leaveType)} (${name ?? 'Shift'})',
            tone: DayTone.fourth,
          ),
          ?waiting(line),
        ], name);
        continue;
      case CancelledRow(:final day):
        final replaced = day.replaced;
        String at(DateTime utc) =>
            clock(_local(timezones.localTimeAt(utc, replaced.timezoneId)));
        add(line.date, [
          DayCalendarLine(
            '',
            struck:
                '${name ?? 'Shift'} ${at(replaced.startUtc)}–'
                '${at(replaced.endUtc)}',
          ),
          DayCalendarLine(
            'Cancelled · ${cancelReasonWord(day.reason)}',
            ink: DayCalendarInk.muted,
          ),
        ], name);
        continue;
      case LeaveTakenRow(:final leave):
        add(line.date, [
          DayCalendarLine(
            leaveTypeWord(leave.record.leaveType),
            tone: DayTone.fourth,
          ),
          _confirmed,
        ], name);
        continue;
      case ReviewRow():
        add(line.date, const [
          DayCalendarLine(
            'Needs review',
            mark: DayCalendarMark.warning,
            ink: DayCalendarInk.run,
          ),
        ], name);
        continue;
      case OffRow():
        continue;
      case PlannedRow() || StoredRow() || null:
        break;
    }
    if (line.status == ShiftsStatus.voided) continue;
    final (start, end) = (line.start, line.end);
    if (start == null || end == null) continue;
    // An extra shift says so, whatever shift type it took its times from
    // (plan 4d-2, call 12).
    final extra = line.extra || line.id == newExtraRowId;
    final shown = extra ? 'Extra' : name ?? 'Shift';
    final tone = toneFor(extra ? 'Extra' : name);
    final status = switch (line.status) {
      ShiftsStatus.finalized => _confirmed,
      ShiftsStatus.draft => const DayCalendarLine(
        'Draft',
        ink: DayCalendarInk.muted,
      ),
      ShiftsStatus.fresh => const DayCalendarLine(
        'New, not saved',
        ink: DayCalendarInk.muted,
      ),
      _ =>
        waiting(line) ??
            (line.status == ShiftsStatus.changed
                ? const DayCalendarLine('Changed', ink: DayCalendarInk.muted)
                : null),
    };
    // Type: Extra matches an extra, and its shift type still matches it
    // (bead 9pk.4.43).
    final matches = {?name, if (extra) 'Extra'};
    add(line.date, [
      DayCalendarLine('$shown ${clock(start)}–${clock(end)}', tone: tone),
      ?status,
    ], null);
    types.putIfAbsent(line.date, () => {}).addAll(matches);
    // An end at or before the start is the next day (schedules spec 6.4).
    // Its morning matches the Type filter there too (bead 9pk.4.36).
    if (_minutes(end) <= _minutes(start)) {
      final morning = line.date.addDays(1);
      types.putIfAbsent(morning, () => {}).addAll(matches);
      mornings
          .putIfAbsent(morning, () => [])
          .add(
            DayCalendarLine(
              '$shown until ${clock(end)}',
              tone: tone,
              ink: DayCalendarInk.muted,
            ),
          );
    }
  }

  final needle = find.trim().toLowerCase();
  final days = <LocalDate, DayCalendarDay>{};
  for (var date = sheet.from; date.compareTo(sheet.to) <= 0;) {
    final words = [...?mornings[date], ...?entries[date]];
    final typed = type == null || (types[date]?.contains(type) ?? false);
    final found =
        needle.isEmpty ||
        words.any((line) => line.spoken.toLowerCase().contains(needle));
    days[date] = DayCalendarDay(lines: words, dimmed: !typed || !found);
    date = date.addDays(1);
  }
  return days;
}

const _confirmed = DayCalendarLine(
  'Confirmed',
  mark: DayCalendarMark.confirmed,
  ink: DayCalendarInk.ok,
);

LocalTime _local(LocalTime time) => LocalTime(time.hour, time.minute);

int _minutes(LocalTime time) => time.hour * 60 + time.minute;
