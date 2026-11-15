import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../core/time/timezone_service.dart';
import '../../features/work/domain/day_exception.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/shift.dart';
import '../../ui/ui.dart' show ValueKind, eraBoxDate, formatValue;
import '../work_edit/shift_edit.dart';
import 'shifts_edit.dart';
import 'shifts_filter.dart';
import 'shifts_rows.dart';
import 'shifts_sheet_controller.dart';

/// What a Shifts row is, as its Status column and row label say.
enum ShiftsStatus {
  planned('Planned'),
  changed('Changed'),
  extra('Extra'),
  draft('Draft'),
  finalized('Finalized'),
  voided('Void'),
  review('Needs review'),
  fresh('New'),
  off('Off'),
  leave('Leave'),
  cancelled('Cancelled'),
  leaveTaken('Leave taken');

  const ShiftsStatus(this.label);

  final String label;
}

/// One line of the Shifts grid as shown: the stored or planned values, or
/// the selected record's pending values with their live preview.
final class ShiftsLine {
  const ShiftsLine({
    required this.id,
    required this.status,
    required this.date,
    required this.start,
    required this.end,
    required this.breakSeconds,
    required this.paidSeconds,
    required this.pay,
    required this.note,
    this.basis,
    this.planDifferenceSeconds,
    this.type,
    this.extra = false,
    this.toConfirm = false,
    this.withoutAgreement = false,
    this.words,
  });

  final String id;
  final ShiftsStatus status;
  final LocalDate date;
  final LocalTime? start;
  final LocalTime? end;
  final int? breakSeconds;
  final int? paidSeconds;
  final Money? pay;

  /// The basis [pay] is on; gross and net are never added together.
  final RateBasis? basis;
  final String note;
  final int? planDifferenceSeconds;

  /// The plan's shift type, `Extra` or `Manual`; null for an Off day or a
  /// change under review.
  final String? type;

  /// An extra shift, planned or recorded, whatever shift type it took its
  /// times from: Type: Extra keeps it (bead 9pk.4.43).
  final bool extra;

  /// A past planned day or leave an agreement covers: it waits to be
  /// confirmed.
  final bool toConfirm;

  /// No pay agreement covers the planned day, so it is not priced or
  /// confirmed until one does.
  final bool withoutAgreement;

  /// Whether Type: [name] keeps this line: its own type, or Extra for an
  /// extra shift.
  bool isOfType(String name) => type == name || (extra && name == 'Extra');

  /// The Status column's words when they say more than [status]'s label.
  final String? words;

  /// What the Status column says (plan 4d-1, call 1).
  String get statusText => words ?? status.label;

  /// [field]'s shown value.
  Object? value(String field) => switch (field) {
    ShiftsField.date => date,
    ShiftsField.start => start,
    ShiftsField.end => end,
    ShiftsField.note => note,
    ShiftsField.type => type,
    _ => null,
  };
}

/// The grid's lines: every row of [sheet], the selected one with its
/// pending values, and the new shift being entered last. A selected record
/// whose row left the sheet while it is edited (cancelled or confirmed
/// elsewhere) keeps its line, by date, so its values stay in view until
/// its save reports what happened.
List<ShiftsLine> shiftsLines(
  ShiftsSheetController sheet,
  TimezoneService timezones,
) {
  final edit = sheet.edit;
  final selected = sheet.selectedId;
  final lines = <ShiftsLine>[
    for (final row in sheet.rows)
      row.id == selected && edit is LeaveEdit
          ? _leavePending(_shown(row, timezones, sheet.today), edit)
          : row.id == selected && edit != null
          ? _pending(
              row.id,
              _statusOf(row),
              edit,
              sheet,
              type: _typeOf(row),
              like: _shown(row, timezones, sheet.today),
            )
          : _shown(row, timezones, sheet.today),
  ];
  if (selected == null || edit == null) return lines;
  if (selected == newRowId) {
    lines.add(
      _pending(newRowId, ShiftsStatus.fresh, edit, sheet, type: _manual),
    );
  } else if (sheet.selectedRow == null) {
    final line = _pending(
      selected,
      switch (edit) {
        PlannedEdit(isNew: true) => ShiftsStatus.fresh,
        PlannedEdit() => ShiftsStatus.planned,
        _ => ShiftsStatus.draft,
      },
      edit,
      sheet,
      type: edit is PlannedEdit ? null : _manual,
    );
    final at = lines.indexWhere((value) => value.date.compareTo(line.date) > 0);
    lines.insert(at < 0 ? lines.length : at, line);
  }
  return lines;
}

/// [row]'s line as the grid shows it, with no pending values: for a row
/// beside the sheet's own (the Calendar's [ShiftsSheetController.eve]).
ShiftsLine shiftsLine(
  ShiftsRow row,
  TimezoneService timezones,
  LocalDate today,
) => _shown(row, timezones, today);

/// The lines [filter] and [find] keep (spec 3): a status the filter
/// admits, its type (an Off day only while Off days is ticked, and only
/// under All or Effective), and Find's text (trimmed, ignoring case) in
/// the line's shown date, type, times, status or note. The selected line
/// [keep] and the new row are always kept: a filter never hides the record
/// being edited.
List<ShiftsLine> filterShiftsLines(
  List<ShiftsLine> lines, {
  required ShiftsFilter filter,
  String find = '',
  String? keep,
}) {
  final needle = find.trim().toLowerCase();
  bool passes(ShiftsLine line) {
    if (line.status == ShiftsStatus.off) {
      if (!filter.offDays ||
          (filter.status != ShiftsStatusFilter.all &&
              filter.status != ShiftsStatusFilter.effective)) {
        return false;
      }
    } else if (!filter.status.admits(line.status, toConfirm: line.toConfirm)) {
      return false;
    }
    if (filter.type case final type? when !line.isOfType(type)) return false;
    if (needle.isEmpty) return true;
    final shown = [
      eraBoxDate(line.date),
      ?line.type,
      if (line.start case final start?) formatValue(ValueKind.time, start),
      if (line.end case final end?) formatValue(ValueKind.time, end),
      line.status.label,
      line.note,
    ].join(' ').toLowerCase();
    return shown.contains(needle);
  }

  return [
    for (final line in lines)
      if (line.id == keep || line.id == newRowId || passes(line)) line,
  ];
}

/// Whether [line] is a recorded shift the footer totals: not void, not a
/// planned estimate.
bool countsInTotals(ShiftsLine line) => switch (line.status) {
  ShiftsStatus.draft || ShiftsStatus.finalized || ShiftsStatus.fresh => true,
  _ => false,
};

ShiftsStatus _statusOf(ShiftsRow row) => switch (row) {
  PlannedRow(:final planned) when planned.day.isExtra => ShiftsStatus.extra,
  PlannedRow(:final planned) when planned.day.changed => ShiftsStatus.changed,
  PlannedRow() => ShiftsStatus.planned,
  ReviewRow() => ShiftsStatus.review,
  OffRow() => ShiftsStatus.off,
  LeaveRow() => ShiftsStatus.leave,
  CancelledRow() => ShiftsStatus.cancelled,
  LeaveTakenRow() => ShiftsStatus.leaveTaken,
  StoredRow(:final shift) => switch (shift.state) {
    ShiftState.draft => ShiftsStatus.draft,
    ShiftState.finalized => ShiftsStatus.finalized,
    ShiftState.voided => ShiftsStatus.voided,
  },
};

ShiftsLine _shown(
  ShiftsRow row,
  TimezoneService timezones,
  LocalDate today,
) => switch (row) {
  PlannedRow(:final planned) => () {
    final day = planned.day;
    final elapsed = day.endUtc.difference(day.startUtc).inSeconds;
    final status = _statusOf(row);
    final waiting = !planned.withoutAgreement && day.date.compareTo(today) < 0;
    return ShiftsLine(
      id: row.id,
      status: _statusOf(row),
      date: day.date,
      start: timezones.localTimeAt(day.startUtc, day.timezoneId),
      end: timezones.localTimeAt(day.endUtc, day.timezoneId),
      breakSeconds: elapsed - day.paidSeconds,
      paidSeconds: day.paidSeconds,
      pay: planned.pay?.amount,
      basis: planned.pay?.basis,
      note: '',
      type: _typeOf(row),
      extra: day.isExtra,
      toConfirm: waiting,
      withoutAgreement: planned.withoutAgreement,
      words: planned.withoutAgreement
          ? ShiftsStatusWords.noAgreement
          : switch ((status, waiting)) {
              (ShiftsStatus.planned, true) => ShiftsStatusWords.toConfirm,
              (_, true) => '${status.label}, to confirm',
              _ => null,
            },
    );
  }(),
  LeaveRow(:final day, :final withoutAgreement, :final pay) => () {
    final waiting = !withoutAgreement && day.date.compareTo(today) < 0;
    return ShiftsLine(
      id: row.id,
      status: ShiftsStatus.leave,
      date: day.date,
      start: null,
      end: null,
      breakSeconds: null,
      paidSeconds: day.paidMinutes * 60,
      pay: pay?.amount,
      basis: pay?.basis,
      note: '',
      type: _typeOf(row),
      toConfirm: waiting,
      withoutAgreement: withoutAgreement,
      words: withoutAgreement
          ? ShiftsStatusWords.noAgreement
          : '${leaveTypeWord(day.leaveType)}${waiting ? ', to confirm' : ''}',
    );
  }(),
  CancelledRow(:final day) => ShiftsLine(
    id: row.id,
    status: ShiftsStatus.cancelled,
    date: day.date,
    start: null,
    end: null,
    breakSeconds: null,
    paidSeconds: null,
    pay: null,
    note: '',
    type: _typeOf(row),
    words: 'Cancelled · ${cancelReasonWord(day.reason)}',
  ),
  LeaveTakenRow(:final leave) => ShiftsLine(
    id: row.id,
    status: ShiftsStatus.leaveTaken,
    date: leave.record.date,
    start: null,
    end: null,
    breakSeconds: null,
    paidSeconds: leave.record.paidMinutes * 60,
    pay: leave.pay?.amount,
    basis: leave.pay?.basis,
    note: '',
    type: _typeOf(row),
    words: '${leaveTypeWord(leave.record.leaveType)}, confirmed',
  ),
  OffRow() => ShiftsLine(
    id: row.id,
    status: ShiftsStatus.off,
    date: row.date,
    start: null,
    end: null,
    breakSeconds: null,
    paidSeconds: null,
    pay: null,
    note: '',
  ),
  ReviewRow(:final exception) => ShiftsLine(
    id: row.id,
    status: ShiftsStatus.review,
    date: row.date,
    start: switch (exception) {
      ChangedDay(:final start) || ExtraDay(:final start) => start,
      _ => null,
    },
    end: switch (exception) {
      ChangedDay(:final end) || ExtraDay(:final end) => end,
      _ => null,
    },
    breakSeconds: null,
    paidSeconds: null,
    pay: null,
    note: '',
  ),
  StoredRow(:final stored, :final shift) => ShiftsLine(
    id: row.id,
    status: _statusOf(row),
    date: shift.localStartDate,
    start: timezones.localTimeAt(shift.startUtc, shift.timezoneId),
    end: switch (shift.endUtc) {
      final end? => timezones.localTimeAt(end, shift.timezoneId),
      null => null,
    },
    breakSeconds: stored.breakSeconds,
    paidSeconds: stored.paidSeconds,
    pay: stored.pay?.amount,
    basis: stored.pay?.basis,
    note: shift.note ?? '',
    type: _typeOf(row),
    extra: shift.schedule?.isExtra ?? false,
  ),
};

const _manual = 'Manual';

/// [row]'s type: the plan's shift type, `Extra`, or `Manual` for a shift
/// no schedule planned; null for an Off day or a change under review.
String? _typeOf(ShiftsRow row) => switch (row) {
  PlannedRow(:final planned) =>
    planned.day.type?.name ?? (planned.day.isExtra ? 'Extra' : null),
  StoredRow(:final stored) => stored.typeName ?? _manual,
  LeaveRow(:final day) => _replacedType(day.replaced),
  CancelledRow(:final day) => _replacedType(day.replaced),
  LeaveTakenRow(:final leave) => leaveTypeWord(leave.record.leaveType),
  ReviewRow() || OffRow() => null,
};

String _replacedType(PlannedShift shift) =>
    shift.type?.name ?? (shift.isExtra ? 'Extra' : 'Shift');

/// What the Status column says beyond a status's own label.
abstract final class ShiftsStatusWords {
  static const toConfirm = 'To confirm';
  static const noAgreement = 'No pay agreement';
}

/// A leave type in words.
String leaveTypeWord(LeaveType type) => switch (type) {
  LeaveType.vacation => 'Vacation',
  LeaveType.sick => 'Sick',
};

/// Why a shift was cancelled, in words.
String cancelReasonWord(CancelReason reason) => switch (reason) {
  CancelReason.swapped => 'Swapped',
  CancelReason.dayOff => 'Day off',
  CancelReason.other => 'Other',
};

ShiftsLine _pending(
  String id,
  ShiftsStatus status,
  ShiftsEdit edit,
  ShiftsSheetController sheet, {
  String? type,
  ShiftsLine? like,
}) {
  final preview = sheet.preview;
  return ShiftsLine(
    id: id,
    status: status,
    date: edit.value(ShiftsField.date)! as LocalDate,
    start: edit.value(ShiftsField.start) as LocalTime?,
    end: edit.value(ShiftsField.end) as LocalTime?,
    breakSeconds: preview?.breakSeconds,
    paidSeconds: preview?.paidSeconds,
    pay: preview?.pay?.amount,
    basis: preview?.pay?.basis,
    note: (edit.value(ShiftsField.note) as String?) ?? '',
    planDifferenceSeconds: preview?.planDifferenceSeconds,
    type: edit is PlannedEdit
        ? (edit.value(ShiftsField.type) as String?) ?? type
        : type,
    toConfirm: like?.toConfirm ?? false,
    withoutAgreement: like?.withoutAgreement ?? false,
    words: like?.words,
  );
}

/// A leave day's line with its pending leave's words.
ShiftsLine _leavePending(ShiftsLine line, LeaveEdit edit) {
  final type = edit.value(ShiftsField.leaveType)! as LeaveType;
  return ShiftsLine(
    id: line.id,
    status: line.status,
    date: line.date,
    start: null,
    end: null,
    breakSeconds: null,
    paidSeconds: line.paidSeconds,
    pay: line.pay,
    basis: line.basis,
    note: '',
    type: line.type,
    toConfirm: line.toConfirm,
    withoutAgreement: line.withoutAgreement,
    words: line.withoutAgreement
        ? ShiftsStatusWords.noAgreement
        : '${leaveTypeWord(type)}${line.toConfirm ? ', to confirm' : ''}',
  );
}

/// Why [field] of [line] cannot be edited; null when it can.
String? shiftsReadOnlyReason(
  ShiftsSheetController sheet,
  ShiftsLine line,
  String field,
) {
  final edit = sheet.edit;
  if (line.id == sheet.selectedId) {
    if (edit == null) return sheet.readOnlyReason;
    if (edit.editable.contains(field)) return null;
    if (edit is LeaveEdit) return ShiftsReadOnly.leaveField;
    if (field == ShiftsField.type) return ShiftsReadOnly.typeOnlyPlanned;
    return field == ShiftsField.note
        ? ShiftsReadOnly.plannedNote
        : ShiftsReadOnly.plannedField;
  }
  return switch (line.status) {
    ShiftsStatus.finalized => ShiftProblems.finalized,
    ShiftsStatus.voided => ShiftProblems.voided,
    ShiftsStatus.review => ShiftsNotices.needsReview,
    ShiftsStatus.off => ShiftsNotices.offDay,
    ShiftsStatus.leave => ShiftsNotices.leaveDay,
    ShiftsStatus.cancelled => ShiftsNotices.cancelledDay,
    ShiftsStatus.leaveTaken => ShiftsNotices.leaveTaken,
    ShiftsStatus.planned || ShiftsStatus.changed || ShiftsStatus.extra
        when field == ShiftsField.note =>
      ShiftsReadOnly.plannedNote,
    ShiftsStatus.planned || ShiftsStatus.changed || ShiftsStatus.extra
        when field == ShiftsField.date =>
      ShiftsReadOnly.plannedField,
    ShiftsStatus.draft || ShiftsStatus.fresh when field == ShiftsField.type =>
      ShiftsReadOnly.typeOnlyPlanned,
    _ => null,
  };
}

/// Why a value cannot be edited here.
abstract final class ShiftsReadOnly {
  static const plannedField =
      'A planned day changes only its times here; its date is the plan\'s.';
  static const typeOnlyPlanned =
      'Only a planned day changes its shift type; a recorded shift has none.';
  static const plannedNote =
      'A planned day has no note; a shift you record has one.';
  static const leaveField =
      'A leave day has no times, type or note of its own; its leave is '
      'changed in its properties.';
}
