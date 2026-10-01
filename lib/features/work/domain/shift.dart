import '../../../core/time/local_date.dart';
import 'agreement.dart';
import 'facts.dart';
import 'ids.dart';
import 'pay.dart';

enum ShiftState { draft, running, onBreak, finalized, voided }

final class WorkShift {
  WorkShift({
    required this.id,
    required this.employmentId,
    required this.agreementId,
    required this.state,
    required this.startUtc,
    required this.endUtc,
    required this.timezoneId,
    required this.localStartDate,
    required this.overtimeMinutes,
    required this.note,
    required this.voidReason,
    required this.replacementShiftId,
    required this.replacedShiftId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  }) {
    _requireUtc(startUtc, 'startUtc');
    _requireUtc(createdAtUtc, 'createdAtUtc');
    _requireUtc(updatedAtUtc, 'updatedAtUtc');
    if (endUtc != null) {
      _requireUtc(endUtc!, 'endUtc');
      if (!endUtc!.isAfter(startUtc)) {
        throw ArgumentError.value(endUtc, 'endUtc');
      }
    }
    if (timezoneId.trim().isEmpty) {
      throw ArgumentError.value(timezoneId, 'timezoneId');
    }
    if (overtimeMinutes < 0) {
      throw ArgumentError.value(overtimeMinutes, 'overtimeMinutes');
    }
    switch (state) {
      case ShiftState.running || ShiftState.onBreak:
        if (endUtc != null) throw ArgumentError.value(endUtc, 'endUtc');
      case ShiftState.finalized:
        if (endUtc == null || agreementId == null) {
          throw ArgumentError('Finalized shifts require end and agreement.');
        }
      case ShiftState.voided:
        if (voidReason?.trim().isEmpty != false || replacementShiftId == null) {
          throw ArgumentError('Voided shifts require reason and replacement.');
        }
      case ShiftState.draft:
        break;
    }
  }

  final ShiftId id;
  final EmploymentId employmentId;
  final AgreementId? agreementId;
  final ShiftState state;
  final DateTime startUtc;
  final DateTime? endUtc;
  final String timezoneId;
  final LocalDate localStartDate;
  final int overtimeMinutes;
  final String? note;
  final String? voidReason;
  final ShiftId? replacementShiftId;
  final ShiftId? replacedShiftId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  int get elapsedSeconds => endUtc!.difference(startUtc).inSeconds;

  WorkShift finalizedWith(PayAgreement agreement) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreement.id,
      state: ShiftState.finalized,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      overtimeMinutes: overtimeMinutes,
      note: note,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision.next(),
    );
  }

  WorkShift voidedForCorrection({
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  }) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreementId,
      state: ShiftState.voided,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      overtimeMinutes: overtimeMinutes,
      note: note,
      voidReason: voidReason,
      replacementShiftId: replacementId,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: nowUtc,
      revision: revision.next(),
    );
  }

  /// The same shift with owner-revised facts; identity, lineage, agreement and
  /// revision are kept so the write stays revision-checked.
  WorkShift revisedFacts({
    required DateTime startUtc,
    required DateTime endUtc,
    required String timezoneId,
    required LocalDate localStartDate,
    required int overtimeMinutes,
    required String? note,
    DateTime? updatedAtUtc,
  }) {
    return WorkShift(
      id: id,
      employmentId: employmentId,
      agreementId: agreementId,
      state: state,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      overtimeMinutes: overtimeMinutes,
      note: note,
      voidReason: voidReason,
      replacementShiftId: replacementShiftId,
      replacedShiftId: replacedShiftId,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      revision: revision,
    );
  }

  WorkShift replacementDraft({
    required ShiftId replacementId,
    required DateTime nowUtc,
  }) {
    return WorkShift(
      id: replacementId,
      employmentId: employmentId,
      agreementId: agreementId,
      state: ShiftState.draft,
      startUtc: startUtc,
      endUtc: endUtc,
      timezoneId: timezoneId,
      localStartDate: localStartDate,
      overtimeMinutes: overtimeMinutes,
      note: note,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: id,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      revision: const Revision(0),
    );
  }
}

final class ShiftBreak {
  ShiftBreak({
    required this.id,
    required this.shiftId,
    required this.startUtc,
    required this.endUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  }) {
    _requireUtc(startUtc, 'startUtc');
    _requireUtc(createdAtUtc, 'createdAtUtc');
    _requireUtc(updatedAtUtc, 'updatedAtUtc');
    if (endUtc != null) {
      _requireUtc(endUtc!, 'endUtc');
      if (!endUtc!.isAfter(startUtc)) {
        throw ArgumentError.value(endUtc, 'endUtc');
      }
    }
  }

  final ShiftBreakId id;
  final ShiftId shiftId;
  final DateTime startUtc;
  final DateTime? endUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;
}

final class FinalizationFacts {
  const FinalizationFacts({
    required this.shift,
    required this.breaks,
    required this.agreement,
    required this.paidSeconds,
  });

  final WorkShift shift;
  final List<ShiftBreak> breaks;
  final PayAgreement agreement;
  final int paidSeconds;

  ExpectedPayInput toExpectedPayInput() => ExpectedPayInput(
    paidSeconds: paidSeconds,
    overtimeMinutes: shift.overtimeMinutes,
    hourlyRateMicroEur: agreement.hourlyRateMicroEur,
    multiplier: agreement.overtimeMultiplier,
    currency: const CurrencyCode.eur(),
  );
}

final class FinalizationValidation {
  const FinalizationValidation({required this.issues, this.facts});

  final List<DomainIssue> issues;
  final FinalizationFacts? facts;

  bool get isValid => facts != null;
}

FinalizationValidation validateFinalization({
  required WorkShift shift,
  required Iterable<ShiftBreak> breaks,
  required Iterable<PayAgreement> agreements,
}) {
  final issues = <DomainIssue>[];
  final end = shift.endUtc;
  if (end == null) {
    issues.add(const DomainIssue('shift.endMissing', field: 'endUtc'));
  } else if (!end.isAfter(shift.startUtc)) {
    issues.add(const DomainIssue('shift.endNotAfterStart', field: 'endUtc'));
  }

  final ordered = [...breaks]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  var breakSeconds = 0;
  DateTime? previousEnd;
  for (final item in ordered) {
    if (item.shiftId != shift.id) {
      issues.add(const DomainIssue('break.outsideShift', field: 'breaks'));
      continue;
    }
    final breakEnd = item.endUtc;
    if (breakEnd == null) {
      issues.add(const DomainIssue('break.open', field: 'breaks'));
      continue;
    }
    if (end == null ||
        item.startUtc.isBefore(shift.startUtc) ||
        breakEnd.isAfter(end)) {
      issues.add(const DomainIssue('break.outsideShift', field: 'breaks'));
    }
    if (previousEnd != null && item.startUtc.isBefore(previousEnd)) {
      issues.add(const DomainIssue('break.overlap', field: 'breaks'));
    }
    breakSeconds += breakEnd.difference(item.startUtc).inSeconds;
    previousEnd = breakEnd;
  }

  final paidSeconds = end == null
      ? 0
      : end.difference(shift.startUtc).inSeconds - breakSeconds;
  if (end != null && paidSeconds <= 0) {
    issues.add(
      const DomainIssue('shift.paidDurationNotPositive', field: 'duration'),
    );
  }
  if (shift.overtimeMinutes < 0) {
    issues.add(
      const DomainIssue('shift.overtimeNegative', field: 'overtimeMinutes'),
    );
  } else if (shift.overtimeMinutes > paidSeconds ~/ 60) {
    issues.add(
      const DomainIssue(
        'shift.overtimeExceedsPaidMinutes',
        field: 'overtimeMinutes',
      ),
    );
  }
  if (issues.isNotEmpty) {
    return FinalizationValidation(issues: List.unmodifiable(issues));
  }

  final resolution = resolveAgreement(
    employmentId: shift.employmentId,
    localStartDate: shift.localStartDate,
    agreements: agreements,
  );
  if (resolution is! ResolvedAgreement) {
    return FinalizationValidation(
      issues: [DomainIssue('shift.agreement.${resolution.runtimeType}')],
    );
  }
  final finalized = shift.finalizedWith(resolution.agreement);
  return FinalizationValidation(
    issues: const [],
    facts: FinalizationFacts(
      shift: finalized,
      breaks: List.unmodifiable(ordered),
      agreement: resolution.agreement,
      paidSeconds: paidSeconds,
    ),
  );
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name);
}
