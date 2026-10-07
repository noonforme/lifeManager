import '../../../core/time/local_date.dart';
import '../../../core/time/timezone_service.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/day_exception.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/pay.dart';
import '../domain/planner.dart';
import '../domain/schedule.dart';
import '../domain/shift.dart';

/// What a calendar entry stands for (schedules spec 6.1).
enum DayEntryKind {
  planned,
  confirmed,
  changed,
  cancelled,
  leave,
  extra,
  needsReview,

  /// The tail of an earlier day's shift that ends on this date.
  continued,

  /// "No pay agreement" under a planned day no agreement covers.
  noAgreement,
}

/// One written entry in a calendar cell, such as "Day 07:00–19:00".
final class DayEntry {
  const DayEntry(
    this.kind,
    this.text, {
    this.struck,
    this.confirmed = false,
    this.spokenText,
  });

  final DayEntryKind kind;
  final String text;

  /// A cancelled shift's type name, drawn struck through before [text].
  final String? struck;

  /// Confirmed entries have a filled swatch; planned ones an outline.
  final bool confirmed;

  /// What screen readers say when it differs from [text].
  final String? spokenText;

  /// The entry as one phrase, for screen readers and tests.
  String get spoken => spokenText ?? (struck == null ? text : '$struck $text');
}

/// One date of the calendar: what the plan and the records hold on it.
final class DayView {
  const DayView({
    required this.date,
    required this.entries,
    this.planned,
    this.shifts = const [],
    this.leave,
    this.withoutAgreement = false,
  });

  final LocalDate date;
  final List<DayEntry> entries;

  /// What the plan holds; null once the date is confirmed or when no
  /// schedule is in use on it.
  final PlannedDay? planned;

  /// Shifts recorded on this date, voided ones left out.
  final List<ShiftSheetRow> shifts;

  /// Effective leave on this date.
  final LeaveSheetRow? leave;

  /// [planned] is work no pay agreement covers: it is neither priced nor
  /// confirmable until one does.
  final bool withoutAgreement;

  bool get confirmed => shifts.isNotEmpty || leave != null;
}

/// "07:00–19:00" on the shift's own wall clock.
String shiftTimes(
  DateTime startUtc,
  DateTime endUtc,
  String zone,
  TimezoneService timezones,
) => '${_clock(startUtc, zone, timezones)}–${_clock(endUtc, zone, timezones)}';

String _clock(DateTime utc, String zone, TimezoneService timezones) =>
    timezones.localTimeAt(utc, zone).toString().substring(0, 5);

String cancelReasonLabel(CancelReason reason) => switch (reason) {
  CancelReason.swapped => 'Swapped',
  CancelReason.dayOff => 'Day off',
  CancelReason.other => 'Other',
};

String leaveTypeLabel(LeaveType type) => switch (type) {
  LeaveType.vacation => 'Vacation',
  LeaveType.sick => 'Sick',
};

/// "Extra", the shift type's name, or "Shift" for custom times.
String plannedShiftName(PlannedShift shift) =>
    shift.isExtra ? 'Extra' : shift.type?.name ?? 'Shift';

/// Calendar when a schedule is in use on [today], otherwise Shifts.
WorkSheet defaultSheetFor(List<WorkSchedule> schedules, LocalDate today) =>
    schedules.any((value) => value.isInUseOn(today))
    ? WorkSheet.calendar
    : WorkSheet.shifts;

/// Every date [from]..[to] with its entries: the plan's days, then the
/// shifts and leave recorded on dates the plan no longer holds. A planned
/// day [withoutAgreement] picks also reads "No pay agreement".
Map<LocalDate, DayView> dayViews({
  required LocalDate from,
  required LocalDate to,
  required List<PlannedDay> plan,
  required List<ShiftSheetRow> shifts,
  required List<LeaveSheetRow> leave,
  required List<WorkSchedule> schedules,
  required TimezoneService timezones,
  bool Function(PlannedDay day)? withoutAgreement,
}) {
  bool inRange(LocalDate date) =>
      date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
  final planned = {
    for (final day in plan)
      if (inRange(day.date)) day.date: day,
  };
  final shiftsOn = <LocalDate, List<ShiftSheetRow>>{};
  for (final row in shifts) {
    if (row.shift.state == ShiftState.voided) continue;
    final date = row.shift.schedule?.plannedDate ?? row.shift.localStartDate;
    if (inRange(date)) shiftsOn.putIfAbsent(date, () => []).add(row);
  }
  final leaveOn = {
    for (final row in leave)
      if (row.record.isEffective && inRange(row.record.date))
        row.record.date: row,
  };

  String shiftName(WorkShift shift) {
    final link = shift.schedule;
    if (link == null) return 'Shift';
    if (link.isExtra) return 'Extra';
    return schedules
            .where(
              (value) =>
                  value.id == link.scheduleId &&
                  value.version == link.scheduleVersion,
            )
            .firstOrNull
            ?.shiftTypeOn(link.plannedDate)
            ?.name ??
        'Shift';
  }

  DayEntry plannedEntry(PlannedShift shift) {
    final times = shiftTimes(
      shift.startUtc,
      shift.endUtc,
      shift.timezoneId,
      timezones,
    );
    if (shift.isExtra) return DayEntry(DayEntryKind.extra, 'Extra $times');
    final name = plannedShiftName(shift);
    return shift.changed
        ? DayEntry(DayEntryKind.changed, '$name $times changed')
        : DayEntry(DayEntryKind.planned, '$name $times');
  }

  // A shift that ends after midnight also shows on the date it ends on,
  // read from every shift given so the day before the range counts too.
  // Display only: the shift stays on its own date for counts and opening.
  final continuedOn = <LocalDate, List<DayEntry>>{};
  void continueOn(
    LocalDate startDate,
    DateTime endUtc,
    String zone,
    String name,
  ) {
    final endDate = timezones.localDateAt(endUtc, zone);
    if (endDate.compareTo(startDate) <= 0 || !inRange(endDate)) return;
    final until = _clock(endUtc, zone, timezones);
    continuedOn
        .putIfAbsent(endDate, () => [])
        .add(
          DayEntry(
            DayEntryKind.continued,
            '$name until $until',
            spokenText: '$name continues until $until',
          ),
        );
  }

  for (final day in plan) {
    if (day is PlannedShift) {
      continueOn(day.date, day.endUtc, day.timezoneId, plannedShiftName(day));
    }
  }
  for (final row in shifts) {
    final end = row.shift.endUtc;
    if (row.shift.state == ShiftState.voided || end == null) continue;
    continueOn(
      row.shift.localStartDate,
      end,
      row.shift.timezoneId,
      shiftName(row.shift),
    );
  }

  final views = <LocalDate, DayView>{};
  for (var date = from; date.compareTo(to) <= 0; date = date.addDays(1)) {
    final day = planned[date];
    final recorded = shiftsOn[date] ?? const <ShiftSheetRow>[];
    final leaveRow = leaveOn[date];
    final unpaid =
        day != null && withoutAgreement != null && withoutAgreement(day);
    final entries = <DayEntry>[
      ...switch (day) {
        PlannedShift() => [plannedEntry(day)],
        CancelledPlan(:final reason, :final replaced) => [
          DayEntry(
            DayEntryKind.cancelled,
            'Cancelled · ${cancelReasonLabel(reason)}',
            struck: plannedShiftName(replaced),
          ),
        ],
        PlannedLeave(:final leaveType) => [
          DayEntry(DayEntryKind.leave, leaveTypeLabel(leaveType)),
        ],
        NeedsReview() => [
          const DayEntry(DayEntryKind.needsReview, 'Needs review'),
        ],
        OffDay() || null => const <DayEntry>[],
      },
      // Straight under the day's own words, before any continuation.
      if (unpaid) const DayEntry(DayEntryKind.noAgreement, 'No pay agreement'),
      for (final row in recorded)
        DayEntry(
          row.shift.schedule?.isExtra ?? false
              ? DayEntryKind.extra
              : DayEntryKind.confirmed,
          [
            shiftName(row.shift),
            if (row.shift.endUtc case final end?)
              shiftTimes(
                row.shift.startUtc,
                end,
                row.shift.timezoneId,
                timezones,
              ),
            if (row.shift.state == ShiftState.draft) '· Draft',
          ].join(' '),
          confirmed: true,
        ),
      if (leaveRow != null)
        DayEntry(
          DayEntryKind.leave,
          leaveTypeLabel(leaveRow.record.leaveType),
          confirmed: true,
        ),
      ...?continuedOn[date],
    ];
    views[date] = DayView(
      date: date,
      entries: entries,
      planned: day,
      shifts: recorded,
      leave: leaveRow,
      withoutAgreement: unpaid,
    );
  }
  return views;
}

/// A month's figures for the line under the calendar (spec 6.1).
final class MonthTotals {
  const MonthTotals({
    required this.shifts,
    required this.paidSeconds,
    required this.planned,
    required this.confirmed,
    this.withoutAgreement = 0,
  });

  /// Planned and confirmed shifts together.
  final int shifts;
  final int paidSeconds;

  /// Expected pay of the shifts still planned.
  final Money planned;

  /// Expected pay of finalized shifts and confirmed leave.
  final Money confirmed;

  /// Planned days no pay agreement covers, so left out of [planned].
  final int withoutAgreement;
}

/// " · 16 days without a pay agreement", or nothing when every day is
/// paid.
String withoutAgreementSuffix(int days) => switch (days) {
  0 => '',
  1 => ' · 1 day without a pay agreement',
  _ => ' · $days days without a pay agreement',
};

MonthTotals monthTotals(
  Iterable<DayView> days, {
  required ExpectedPay? Function(PlannedShift shift) price,
}) {
  var shifts = 0;
  var paid = 0;
  var planned = 0;
  var confirmed = 0;
  var unpaid = 0;
  for (final day in days) {
    if (day.withoutAgreement) unpaid++;
    if (day.planned case final PlannedShift shift) {
      shifts++;
      paid += shift.paidSeconds;
      planned += price(shift)?.amount.minorUnits ?? 0;
    }
    for (final row in day.shifts) {
      if (row.shift.state != ShiftState.finalized) continue;
      shifts++;
      paid += row.paidSeconds ?? 0;
      confirmed += row.pay?.amount.minorUnits ?? 0;
    }
    confirmed += day.leave?.pay?.amount.minorUnits ?? 0;
  }
  return MonthTotals(
    shifts: shifts,
    paidSeconds: paid,
    planned: Money(minorUnits: planned),
    confirmed: Money(minorUnits: confirmed),
    withoutAgreement: unpaid,
  );
}

/// What [day] would pay once confirmed, from the employment's confirmed
/// work and leave; null when no agreement covers its date. A sick day
/// without an illness start is priced as the illness's first day.
LeavePay? plannedLeavePay(
  PlannedLeave day, {
  required EmploymentId employmentId,
  required List<PayAgreement> agreements,
  required List<ShiftSheetRow> shifts,
  required List<LeaveSheetRow> leave,
}) {
  if (day.paidMinutes <= 0) return null;
  final resolution = resolveAgreement(
    employmentId: employmentId,
    localStartDate: day.date,
    agreements: agreements,
  );
  if (resolution is! ResolvedAgreement) return null;
  final stamp = DateTime.utc(2000);
  final record = LeaveRecord(
    id: const LeaveRecordId('planned'),
    employmentId: employmentId,
    date: day.date,
    leaveType: day.leaveType,
    illnessStartedOn: day.leaveType == LeaveType.sick
        ? day.illnessStartedOn ?? day.date
        : null,
    paidMinutes: day.paidMinutes,
    agreementId: resolution.agreement.id,
    scheduleId: day.scheduleId,
    scheduleVersion: day.scheduleVersion,
    state: LeaveState.confirmed,
    voidReason: null,
    replacementId: null,
    replacedId: null,
    createdAtUtc: stamp,
    updatedAtUtc: stamp,
    revision: const Revision(0),
  );
  final worked = [
    for (final row in shifts)
      if (row.shift.state == ShiftState.finalized &&
          row.paidSeconds != null &&
          row.pay != null)
        WorkedPay(
          date: row.shift.localStartDate,
          paidSeconds: row.paidSeconds!,
          pay: row.pay!.amount,
        ),
  ];
  final earlier = [
    for (final row in leave)
      if (row.record.isEffective && row.record.date.compareTo(day.date) < 0)
        row.record,
  ];
  return priceLeave(
    leave: [...earlier, record],
    worked: worked,
    agreements: agreements,
  )[record.id];
}
