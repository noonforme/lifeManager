import '../../core/history/record_events.dart';
import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../core/time/timezone_service.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/shift.dart';
import '../../features/work/domain/work_formats.dart';
import 'shifts_edit.dart';
import 'shifts_lines.dart';
import 'shifts_rows.dart';
import 'shifts_sheet_controller.dart';

/// The selected record's breaks: the pending ones while it is edited, else
/// the stored or planned ones in the shift's own zone.
List<BreakLine> breaksOf(
  ShiftsSheetController sheet,
  TimezoneService timezones,
) {
  if (sheet.edit case final edit?) return edit.breaks;
  return switch (sheet.selectedRow) {
    StoredRow(:final stored, :final shift) => storedBreakLines(
      stored.breaks,
      zone: shift.timezoneId,
      timezones: timezones,
    ),
    // A change that needs review is ignored, breaks and all; an Off day,
    // a leave day and a cancelled shift have none.
    ReviewRow() ||
    OffRow() ||
    LeaveRow() ||
    CancelledRow() ||
    LeaveTakenRow() => const [],
    PlannedRow(:final planned) => [
      for (final (index, item) in planned.day.breaks.indexed)
        BreakLine(
          index: index,
          start: timezones.localTimeAt(item.start, planned.day.timezoneId),
          end: timezones.localTimeAt(item.end, planned.day.timezoneId),
        ),
    ],
    null => const [],
  };
}

/// The Breaks grid's row id of break [index] of record [recordId]: a
/// temporary identity until the parent saves (spec 4.2).
String breakRowId(String recordId, int index) => '$recordId/break:$index';

/// One group of paid time with the same premiums, as the Working tab
/// lists it: the paid time, the agreement's rate and the multiplier the
/// premiums stack to. The amount is the pay result's own total, never a
/// second calculation per group.
final class WorkingLine {
  const WorkingLine({
    required this.kind,
    required this.seconds,
    required this.rate,
    required this.multiplier,
  });

  final String kind;
  final int seconds;
  final String rate;
  final String multiplier;
}

/// "Regular", or the premiums a group carries: "Night + Holiday".
String payGroupName(PayGroup group) => group.isRegular
    ? 'Regular'
    : [
        if (group.night) 'Night',
        if (group.holiday) 'Holiday',
        if (group.overtime) 'Overtime',
      ].join(' + ');

/// [pay]'s groups under [agreement], regular first.
List<WorkingLine> workingLines(ExpectedPay pay, PayAgreement agreement) => [
  for (final group in pay.groups)
    WorkingLine(
      kind: payGroupName(group),
      seconds: group.seconds,
      rate: formatHourlyRate(agreement.hourlyRateMicroEur),
      multiplier: formatMultiplier(group.multiplier),
    ),
];

/// The pay worked out for the selected record and the agreement it is
/// priced under; null when there is none (no single agreement covers the
/// date, or the values make no shift).
({ExpectedPay pay, PayAgreement agreement})? workingOf(
  ShiftsSheetController sheet,
) {
  if (sheet.edit case final edit?) {
    final pay = sheet.preview?.pay;
    final agreement = sheet.agreementFor(
      edit.value(ShiftsField.date)! as LocalDate,
    );
    if (pay == null || agreement == null) return null;
    return (pay: pay, agreement: agreement);
  }
  return switch (sheet.selectedRow) {
    StoredRow(:final stored) => switch ((stored.pay, stored.facts)) {
      (final pay?, final facts?) => (pay: pay, agreement: facts.agreement),
      _ => null,
    },
    _ => null,
  };
}

/// A stored shift's breaks in [zone]'s wall time; a break still open has
/// no end yet.
List<BreakLine> storedBreakLines(
  List<ShiftBreak> breaks, {
  required String zone,
  required TimezoneService timezones,
}) => [
  for (final (index, item) in breaks.indexed)
    BreakLine(
      index: index,
      start: timezones.localTimeAt(item.startUtc, zone),
      end: switch (item.endUtc) {
        final end? => timezones.localTimeAt(end, zone),
        null => null,
      },
    ),
];

/// The breaks of [now] that match none of [saved] by their times, so a
/// removed break does not mark the unchanged ones after it.
/// The cells of [now]'s breaks that differ from the saved ones: a break
/// none saved matches whole is compared with the saved break that shares
/// its start, else its end, so only the value that moved is marked; one
/// sharing neither is changed in both.
Set<(int, String)> changedBreakCells(
  List<BreakLine> now,
  List<BreakLine> saved,
) => {
  for (final index in changedBreaks(now, saved))
    for (final field in const [ShiftsField.start, ShiftsField.end])
      if (switch (saved
              .where((was) => was.start == now[index].start)
              .firstOrNull ??
          saved.where((was) => was.end == now[index].end).firstOrNull) {
        final was? => was.value(field) != now[index].value(field),
        null => true,
      })
        (index, field),
};

Set<int> changedBreaks(List<BreakLine> now, List<BreakLine> saved) => {
  for (final (index, line) in now.indexed)
    if (!saved.any((was) => was.start == line.start && was.end == line.end))
      index,
};

/// One line of the Day plan tab: the plan, or the day as it is now.
final class DayPlanLine {
  const DayPlanLine({
    required this.label,
    required this.start,
    required this.end,
    required this.paidSeconds,
  });

  final String label;
  final LocalTime? start;
  final LocalTime? end;
  final int? paidSeconds;
}

/// The plan of [line]'s day beside the day itself: a planned day against
/// its cycle's own plan, a confirmed shift against the window it was
/// planned in. Null when the record has no plan (a manual shift).
List<DayPlanLine>? dayPlanLines(
  ShiftsSheetController sheet,
  ShiftsLine line,
  TimezoneService timezones,
) {
  DayPlanLine planned(PlannedShift day) => DayPlanLine(
    label: 'Plan',
    start: timezones.localTimeAt(day.startUtc, day.timezoneId),
    end: timezones.localTimeAt(day.endUtc, day.timezoneId),
    paidSeconds: day.paidSeconds,
  );
  final plan = switch ((sheet.edit, sheet.selectedRow)) {
    (PlannedEdit(), _) || (_, PlannedRow()) || (_, ReviewRow()) => switch (sheet
        .cyclePlanOf(line.date)) {
      final day? => planned(day),
      null => null,
    },
    (_, StoredRow(:final shift)) => switch (shift.schedule) {
      final link? => DayPlanLine(
        label: 'Plan',
        start: timezones.localTimeAt(link.plannedStartUtc, shift.timezoneId),
        end: timezones.localTimeAt(link.plannedEndUtc, shift.timezoneId),
        paidSeconds: null,
      ),
      null => null,
    },
    _ => null,
  };
  if (plan == null) return null;
  return [
    plan,
    DayPlanLine(
      label: switch (sheet.selectedRow) {
        StoredRow() => 'Recorded',
        ReviewRow() => 'This change',
        _ => 'This day',
      },
      start: line.start,
      end: line.end,
      paidSeconds: line.paidSeconds,
    ),
  ];
}

/// One history event as the History tab lists it.
final class HistoryLine {
  const HistoryLine({
    required this.id,
    required this.at,
    required this.what,
    required this.changes,
    required this.reason,
  });

  final int id;
  final String at;
  final String what;
  final String changes;
  final String reason;
}

/// What happened, in the History tab's words.
String recordEventWord(RecordEventKind kind) => switch (kind) {
  RecordEventKind.created => 'Created',
  RecordEventKind.changed => 'Changed',
  RecordEventKind.finalized => 'Finalized',
  RecordEventKind.voided => 'Voided',
  RecordEventKind.replaced => 'Created as a replacement',
  RecordEventKind.reviewed => 'Reviewed',
};

HistoryLine historyLine(RecordEvent event) => HistoryLine(
  id: event.id,
  at:
      '${event.atUtc.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}'
      ' UTC',
  what: recordEventWord(event.kind),
  changes: [
    for (final change in event.changes)
      switch ((change.before, change.after)) {
        (null, null) => change.field,
        (null, final after?) => '${change.field}: $after',
        (final before?, final after) =>
          '${change.field}: $before → ${after ?? '—'}',
      },
  ].join('; '),
  reason: event.reason ?? '',
);
