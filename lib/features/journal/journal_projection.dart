import '../../core/history/record_events.dart';
import '../../core/time/local_date.dart';
import '../../shared/workbench/lifeos_tokens.dart';
import '../work/data/projections/work_register_projection.dart';
import '../work/domain/agreement.dart';
import '../work/domain/employment.dart';
import '../work/domain/ids.dart';
import '../work/domain/pay.dart';
import '../work/domain/pay_period.dart';
import '../work/domain/payslip.dart';
import '../work/domain/shift.dart';
import '../work/presentation/work_route_state.dart';
import '../work/presentation/work_sheets.dart' show periodName, shiftStateLabel;

/// What happened, in the Journal's own words (shell spec 6.5).
enum JournalKind {
  shiftStarted('Shift started'),
  manualShift('Shift recorded'),
  breakStarted('Break started'),
  breakEnded('Break ended'),
  shiftEnded('Shift ended'),
  shiftChanged('Shift changed'),
  shiftFinalized('Shift finalized'),
  shiftVoided('Shift voided'),
  periodCreated('Pay period created'),
  periodReviewed('Pay period reviewed'),
  periodReopened('Pay period reopened'),
  payslipRecorded('Payslip recorded'),
  payslipVoided('Payslip voided'),
  employmentCreated('Employment created'),
  employmentChanged('Employment changed'),
  agreementCreated('Agreement created'),
  agreementChanged('Agreement changed');

  const JournalKind(this.label);

  final String label;
}

/// One Journal row. The Journal is computed from records and their history
/// and is never stored.
final class JournalEntry {
  const JournalEntry({
    required this.atUtc,
    required this.localDate,
    required this.area,
    required this.kind,
    required this.record,
    required this.employmentId,
    required this.zoneId,
    required this.summary,
    required this.state,
    this.amount,
    this.paidSeconds,
    this.sequence = 0,
  });

  final DateTime atUtc;

  /// The history order, which breaks ties between entries at one instant.
  final int sequence;

  /// The day the entry belongs to; a shift's own timezone decides it.
  final LocalDate localDate;
  final LifeOSArea area;
  final JournalKind kind;
  final WorkRecordRef record;

  /// The employment the record belongs to, for opening it in Work.
  final EmploymentId employmentId;

  /// The zone [localDate] and the entry's time are read in.
  final String zoneId;
  final String summary;

  /// The record's state now, so a voided original reads "Void".
  final String state;

  /// Expected pay of a finished shift, or a payslip's amount. Absent once the
  /// record is void, so a correction is counted once.
  final Money? amount;

  /// Paid time of a finished shift that still counts.
  final int? paidSeconds;
}

/// A day of entries with its summary (paid time, expected, paid in).
final class JournalDay {
  const JournalDay({
    required this.date,
    required this.entries,
    required this.paidSeconds,
    required this.expected,
    required this.paidIn,
  });

  final LocalDate date;
  final List<JournalEntry> entries;
  final int paidSeconds;
  final Money expected;
  final Money paidIn;
}

/// The facts the Journal reads, by record id.
final class JournalFacts {
  const JournalFacts({
    required this.events,
    required this.shifts,
    required this.payslips,
    required this.periods,
    required this.employments,
    required this.agreements,
  });

  final List<RecordEvent> events;
  final Map<String, ShiftSheetRow> shifts;
  final Map<String, Payslip> payslips;
  final Map<String, PayPeriod> periods;
  final Map<String, Employment> employments;
  final Map<String, ({PayAgreement agreement, int finishedShifts})> agreements;
}

/// Journal entries between [from] and [to] inclusive, newest first.
/// [localDate] reads an instant on a zone's wall clock; [defaultZone] is used
/// for records without one of their own.
List<JournalEntry> journalEntries(
  JournalFacts facts, {
  required LocalDate from,
  required LocalDate to,
  required LocalDate Function(DateTime utc, String zoneId) localDate,
  required String defaultZone,
}) {
  final entries = <JournalEntry>[];
  for (final event in facts.events) {
    final entry = _entry(event, facts, localDate, defaultZone);
    if (entry == null) continue;
    if (entry.localDate.compareTo(from) < 0 ||
        entry.localDate.compareTo(to) > 0) {
      continue;
    }
    entries.add(entry);
  }
  entries.sort((a, b) {
    final time = b.atUtc.compareTo(a.atUtc);
    return time != 0 ? time : b.sequence.compareTo(a.sequence);
  });
  return entries;
}

/// Groups newest-first [entries] into days; each summary is the sum of its
/// rows.
List<JournalDay> journalDays(List<JournalEntry> entries) {
  final byDate = <LocalDate, List<JournalEntry>>{};
  for (final entry in entries) {
    byDate.putIfAbsent(entry.localDate, () => []).add(entry);
  }
  final days = [
    for (final MapEntry(key: date, value: rows) in byDate.entries)
      JournalDay(
        date: date,
        entries: rows,
        paidSeconds: rows.fold(
          0,
          (total, row) => total + (row.paidSeconds ?? 0),
        ),
        expected: Money(
          minorUnits: rows
              .where((row) => row.record.kind == WorkRecordKind.shift)
              .fold(0, (total, row) => total + (row.amount?.minorUnits ?? 0)),
        ),
        paidIn: Money(
          minorUnits: rows
              .where((row) => row.record.kind == WorkRecordKind.payslip)
              .fold(0, (total, row) => total + (row.amount?.minorUnits ?? 0)),
        ),
      ),
  ]..sort((a, b) => b.date.compareTo(a.date));
  return days;
}

JournalEntry? _entry(
  RecordEvent event,
  JournalFacts facts,
  LocalDate Function(DateTime utc, String zoneId) localDate,
  String defaultZone,
) {
  String? after(String field) => event.changes
      .where((change) => change.field == field)
      .map((change) => change.after)
      .firstOrNull;
  String? before(String field) => event.changes
      .where((change) => change.field == field)
      .map((change) => change.before)
      .firstOrNull;
  JournalEntry make({
    required WorkRecordKind kind,
    required JournalKind what,
    required EmploymentId employment,
    required String summary,
    required String state,
    String? zone,
    Money? amount,
    int? paidSeconds,
  }) => JournalEntry(
    atUtc: event.atUtc,
    localDate: localDate(event.atUtc, zone ?? defaultZone),
    area: LifeOSArea.work,
    kind: what,
    record: _ref(kind, event.recordId),
    employmentId: employment,
    zoneId: zone ?? defaultZone,
    summary: summary,
    state: state,
    amount: amount,
    paidSeconds: paidSeconds,
    sequence: event.id,
  );

  switch (event.recordKind) {
    case 'shift':
      final row = facts.shifts[event.recordId];
      if (row == null) return null;
      final shift = row.shift;
      final counts = shift.state == ShiftState.finalized;
      final what = switch (event.kind) {
        RecordEventKind.created when after('State') == 'finalized' =>
          JournalKind.manualShift,
        RecordEventKind.created => JournalKind.shiftStarted,
        RecordEventKind.changed => switch ((before('State'), after('State'))) {
          ('running', 'onBreak') => JournalKind.breakStarted,
          ('onBreak', 'running') => JournalKind.breakEnded,
          ('running', 'draft') => JournalKind.shiftEnded,
          _ => JournalKind.shiftChanged,
        },
        RecordEventKind.finalized => JournalKind.shiftFinalized,
        RecordEventKind.voided => JournalKind.shiftVoided,
        // The replacement appears once, when it is finalized.
        RecordEventKind.replaced || RecordEventKind.reviewed => null,
      };
      if (what == null) return null;
      final finished =
          what == JournalKind.shiftFinalized || what == JournalKind.manualShift;
      return make(
        kind: WorkRecordKind.shift,
        what: what,
        employment: shift.employmentId,
        summary: 'Shift on ${shift.localStartDate}',
        state: shiftStateLabel(shift.state),
        zone: shift.timezoneId,
        amount: finished && counts ? row.pay?.amount : null,
        paidSeconds: finished && counts ? row.paidSeconds : null,
      );
    case 'payslip':
      final payslip = facts.payslips[event.recordId];
      if (payslip == null) return null;
      final what = switch (event.kind) {
        RecordEventKind.created ||
        RecordEventKind.replaced => JournalKind.payslipRecorded,
        RecordEventKind.voided => JournalKind.payslipVoided,
        _ => null,
      };
      if (what == null) return null;
      return make(
        kind: WorkRecordKind.payslip,
        what: what,
        employment: facts.periods[payslip.periodId.value]!.employmentId,
        summary: 'Payslip issued ${payslip.issuedDate}',
        state: payslip.isEffective ? 'Effective' : 'Void',
        amount: what == JournalKind.payslipRecorded && payslip.isEffective
            ? payslip.amount
            : null,
      );
    case 'payPeriod':
      final period = facts.periods[event.recordId];
      if (period == null) return null;
      return make(
        kind: WorkRecordKind.payPeriod,
        employment: period.employmentId,
        what: switch (event.kind) {
          RecordEventKind.created => JournalKind.periodCreated,
          RecordEventKind.reviewed => JournalKind.periodReviewed,
          _ => JournalKind.periodReopened,
        },
        summary: 'Pay period ${periodName(period)}',
        state: period.state == PayPeriodState.reviewed ? 'Reviewed' : 'Open',
      );
    case 'employment':
      final employment = facts.employments[event.recordId];
      if (employment == null) return null;
      return make(
        kind: WorkRecordKind.employment,
        employment: employment.id,
        what: event.kind == RecordEventKind.created
            ? JournalKind.employmentCreated
            : JournalKind.employmentChanged,
        summary: employment.name,
        state: employment.status == EmploymentStatus.active
            ? 'Active'
            : 'Archived',
      );
    case 'agreement':
      final item = facts.agreements[event.recordId];
      if (item == null) return null;
      return make(
        kind: WorkRecordKind.agreement,
        employment: item.agreement.employmentId,
        what: event.kind == RecordEventKind.created
            ? JournalKind.agreementCreated
            : JournalKind.agreementChanged,
        summary: item.agreement.label ?? 'Agreement v${item.agreement.version}',
        state: item.finishedShifts > 0 ? 'In use' : 'Unused',
      );
  }
  return null;
}

WorkRecordRef _ref(WorkRecordKind kind, String id) =>
    WorkRecordRef.tryParse('${kind.name}:$id')!;
