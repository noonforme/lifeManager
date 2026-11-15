import '../../core/time/local_date.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/leave.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/shift.dart';

/// One line of the new shell's Shifts sheet (spec 3, 4.2): a planned day no
/// confirmed record covers yet, a day whose change needs review, a stored
/// shift, or the new shift being entered. Its [id] is the grid's row id and never a fabricated record id:
/// a planned day is `day:<date>`, a stored shift `shift:<id>`.
sealed class ShiftsRow {
  const ShiftsRow();

  String get id;
  LocalDate get date;

  /// Where the row sorts: its start.
  DateTime get startUtc;
}

/// An unconfirmed planned, changed or extra work day.
final class PlannedRow extends ShiftsRow {
  const PlannedRow(this.planned);

  final PlannedShiftRow planned;

  @override
  String get id => plannedRowId(planned.day.date);

  @override
  LocalDate get date => planned.day.date;

  @override
  DateTime get startUtc => planned.day.startUtc;
}

/// A day whose change no longer fits what its schedule plans there
/// (schedules spec 3.5): the change is ignored until it is removed, so the
/// day is read-only. It has the planned day's id: it is the same day.
final class ReviewRow extends ShiftsRow {
  const ReviewRow(this.day);

  final NeedsReview day;

  DayException get exception => day.exception;

  @override
  String get id => plannedRowId(day.date);

  @override
  LocalDate get date => day.date;

  /// It has no planned start: it sorts at the start of its date.
  @override
  DateTime get startUtc => DateTime.utc(date.year, date.month, date.day);
}

/// An unconfirmed planned day taken as leave (schedules spec 3.5): the
/// shift it replaces gives its hours. It has the planned day's id.
final class LeaveRow extends ShiftsRow {
  const LeaveRow(this.day, {required this.withoutAgreement, this.pay});

  final PlannedLeave day;

  /// What the day would pay once confirmed; null while it cannot be told
  /// (no agreement, or the months before it not read yet).
  final LeavePay? pay;

  /// No pay agreement covers the day, so it cannot be confirmed yet.
  final bool withoutAgreement;

  @override
  String get id => plannedRowId(day.date);

  @override
  LocalDate get date => day.date;

  @override
  DateTime get startUtc => day.replaced.startUtc;
}

/// A planned day cancelled: not worked and not paid. It has the planned
/// day's id; Restore shift brings the plan back.
final class CancelledRow extends ShiftsRow {
  const CancelledRow(this.day);

  final CancelledPlan day;

  @override
  String get id => plannedRowId(day.date);

  @override
  LocalDate get date => day.date;

  @override
  DateTime get startUtc => day.replaced.startUtc;
}

/// A confirmed leave day: read-only here, corrected on the Leave sheet.
final class LeaveTakenRow extends ShiftsRow {
  const LeaveTakenRow(this.leave);

  final LeaveSheetRow leave;

  @override
  String get id => leaveRowId(leave.record.id);

  @override
  LocalDate get date => leave.record.date;

  /// It has no start: it sorts at the start of its date.
  @override
  DateTime get startUtc => DateTime.utc(date.year, date.month, date.day);
}

/// A stored shift: draft, finalized or void.
final class StoredRow extends ShiftsRow {
  const StoredRow(this.stored);

  final ShiftSheetRow stored;

  WorkShift get shift => stored.shift;

  @override
  String get id => storedRowId(stored.shift);

  @override
  LocalDate get date => stored.shift.localStartDate;

  @override
  DateTime get startUtc => stored.shift.startUtc;
}

/// A day the schedule plans no work on, listed while Off days is ticked
/// (spec 3). Read-only; it has a row id of its own, never routed.
final class OffRow extends ShiftsRow {
  const OffRow(this.day);

  final OffDay day;

  @override
  String get id => 'off:${day.date}';

  @override
  LocalDate get date => day.date;

  /// It has no start: it sorts at the start of its date.
  @override
  DateTime get startUtc => DateTime.utc(date.year, date.month, date.day);
}

/// The grid row id of the planned day on [date].
String plannedRowId(LocalDate date) => 'day:$date';

/// The grid row id of [shift].
String storedRowId(WorkShift shift) => shiftRowId(shift.id);

/// The grid row id of the stored shift [id].
String shiftRowId(ShiftId id) => 'shift:${id.value}';

/// The grid row id of the confirmed leave [id].
String leaveRowId(LeaveRecordId id) => 'leave:${id.value}';

/// The grid row id of the new shift being entered; it gets its stored id
/// only when its first save commits (spec 4.3).
const newRowId = 'new';

/// The grid row id of the new extra shift being entered on an Off day; it
/// becomes the planned day's id when its first save commits.
const newExtraRowId = 'new-extra';

/// The sheet's lines by start, a planned day before a stored shift that
/// starts at the same moment.
List<ShiftsRow> mergeShiftsRows({
  required List<ShiftSheetRow> stored,
  required List<PlannedShiftRow> planned,
  List<NeedsReview> review = const [],
  List<OffDay> off = const [],
  List<LeaveRow> leave = const [],
  List<CancelledPlan> cancelled = const [],
  List<LeaveSheetRow> taken = const [],
}) {
  // The feeds arrive independently. Until both catch up, review takes
  // precedence over an older planned snapshot of the same day.
  final reviewDates = {for (final value in review) value.date};
  // So does a day the plan now holds as leave or cancelled: a planned
  // snapshot of that day is older.
  final notWork = {
    ...reviewDates,
    for (final value in leave) value.date,
    for (final value in cancelled) value.date,
  };
  // An off day someone worked shows the shift, not the Off row.
  final storedDates = {for (final value in stored) value.shift.localStartDate};
  final rows = <ShiftsRow>[
    for (final value in planned)
      if (!notWork.contains(value.day.date)) PlannedRow(value),
    for (final value in review) ReviewRow(value),
    for (final value in leave)
      if (!reviewDates.contains(value.date)) value,
    for (final value in cancelled)
      if (!reviewDates.contains(value.date)) CancelledRow(value),
    for (final value in taken) LeaveTakenRow(value),
    for (final value in stored) StoredRow(value),
    for (final value in off)
      if (!storedDates.contains(value.date)) OffRow(value),
  ];
  // List.sort is not stable; the index keeps equal starts in this order.
  final order = {for (final (index, row) in rows.indexed) row: index};
  rows.sort((a, b) {
    final byStart = a.startUtc.compareTo(b.startUtc);
    return byStart != 0 ? byStart : order[a]!.compareTo(order[b]!);
  });
  return List.unmodifiable(rows);
}
