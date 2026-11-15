import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/app_clock.dart';
import '../../features/work/application/agreement_correction.dart';
import '../../features/work/application/agreement_service.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/work_formats.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import '../edit_session/record_edit_session.dart';
import 'work_outcomes.dart';
import 'work_records.dart';

/// A pay agreement's edit session.
typedef AgreementSession = RecordEditSession<AgreementRecord, AgreementValues>;

/// The pending terms of a pay agreement, compared field by field.
@immutable
final class AgreementValues {
  const AgreementValues(this.terms);

  final AgreementTerms terms;

  @override
  bool operator ==(Object other) {
    if (other is! AgreementValues) return false;
    final a = terms;
    final b = other.terms;
    return a.effectiveStart == b.effectiveStart &&
        a.effectiveEnd == b.effectiveEnd &&
        a.hourlyRateMicroEur == b.hourlyRateMicroEur &&
        a.basis == b.basis &&
        a.label == b.label &&
        a.note == b.note &&
        a.overtimeThresholdMinutes == b.overtimeThresholdMinutes &&
        a.overtimeMultiplier == b.overtimeMultiplier &&
        a.nightEnabled == b.nightEnabled &&
        a.nightStartMinute == b.nightStartMinute &&
        a.nightEndMinute == b.nightEndMinute &&
        a.nightMultiplier == b.nightMultiplier &&
        a.holidayCalendar == b.holidayCalendar &&
        a.holidayMultiplier == b.holidayMultiplier &&
        a.premiumStacking == b.premiumStacking &&
        a.vacationPay == b.vacationPay &&
        a.sickPay == b.sickPay &&
        a.sickEmployerDays == b.sickEmployerDays;
  }

  @override
  int get hashCode => Object.hash(
    terms.effectiveStart,
    terms.effectiveEnd,
    terms.hourlyRateMicroEur,
    terms.basis,
    terms.label,
    terms.note,
    terms.overtimeThresholdMinutes,
    terms.overtimeMultiplier,
    terms.nightEnabled,
    terms.nightStartMinute,
    terms.nightEndMinute,
    terms.nightMultiplier,
    terms.holidayCalendar,
    terms.holidayMultiplier,
    terms.premiumStacking,
    terms.vacationPay,
    terms.sickPay,
    terms.sickEmployerDays,
  );
}

/// Words for an agreement's problems, by field key.
abstract final class AgreementProblems {
  static const rate = 'Enter an hourly rate above zero.';
  static const endBeforeStart = 'End the agreement on or after its start.';
  static const terms = "Check the agreement's terms.";
  static const startAfterUse =
      'It pays days before this date. Start it no later than the first.';
  static const endBeforeUse =
      'It pays days after this date. End it no earlier than the last.';
  static const overlap =
      'Another agreement of this employment covers some of these dates.';
  static const startRequired = 'Enter the first day it pays.';
  static const hours = 'Enter hours above zero, such as 8 or 7.5.';
  static const multiplier = 'Enter a multiplier of 1 or more, such as 1.5.';
  static const percent = 'Enter a percent above zero, such as 62.06.';
  static const sickDays = 'Enter whole days from 0 to 30.';
  static const nightWindow = 'Night pay must start and end at different times.';
  static const notEditable = 'This value is not edited here.';
}

/// The repricing window (spec 4.2 repricing guard): what saving the
/// correction reprices, with [impact] as the consent the save passes on.
ConfirmRequest repricingRequest(AgreementCorrectionImpact impact) {
  String count(int value, String one, String many) =>
      '$value ${value == 1 ? one : many}';
  final records = [
    if (impact.shifts > 0)
      count(impact.shifts, 'finished shift', 'finished shifts'),
    if (impact.leaveDays > 0)
      count(impact.leaveDays, 'leave day', 'leave days'),
    if (impact.otherLeaveDays > 0)
      count(impact.otherLeaveDays, 'other leave day', 'other leave days'),
  ];
  final listed = records.length < 2
      ? records.join()
      : '${records.sublist(0, records.length - 1).join(', ')} and '
            '${records.last}';
  final reviewed = impact.inReviewedPeriods;
  return ConfirmRequest(
    title: 'Reprice',
    message: [
      'Saving reprices $listed: ${formatMoney(impact.before)} → '
          '${formatMoney(impact.after)}.',
      if (reviewed == 1) '1 of them is in a reviewed pay period.',
      if (reviewed > 1) '$reviewed of them are in reviewed pay periods.',
    ].join(' '),
    proceed: 'Save and reprice',
    revert: 'Revert',
    consent: impact,
  );
}

/// Asked again when the repricing the owner confirmed disappeared before
/// the commit: the correction now reprices nothing.
const repricingGoneRequest = ConfirmRequest(
  title: 'Reprice',
  message: 'What this correction reprices changed: it now reprices nothing.',
  proceed: 'Save',
  revert: 'Revert',
  warning: false,
);

/// Creates a pay agreement with `AgreementService.createAgreement` and
/// updates one with `updateAgreement` (spec 4.2 save matrix, agreement
/// rows). A correction that reprices asks *Save and reprice / Revert /
/// Cancel* first with the previewed impact as consent; when that impact
/// changes before the commit, the command's Stale becomes [Reconfirm] with
/// the fresh impact, and consent is never reused. "Change terms from…"
/// and "End agreement…" stay explicit actions. One adapter serves one
/// session.
final class AgreementAdapter
    implements RecordEditAdapter<AgreementRecord, AgreementValues> {
  AgreementAdapter({
    required this.employmentId,
    required this.defaults,
    required this.service,
    required this.preview,
    required this.reads,
    required this.clock,
  });

  final EmploymentId employmentId;

  /// What a new agreement starts with.
  final AgreementTerms defaults;
  final AgreementService service;
  final AgreementCorrectionPreview preview;
  final WorkReads reads;
  final AppClock clock;

  /// When the last create was sent.
  DateTime? _sentAt;

  @override
  AgreementValues draftOf(AgreementRecord? saved) => AgreementValues(
    saved == null ? defaults : AgreementTerms.of(saved.value),
  );

  @override
  Map<String, String> validate(AgreementValues draft) {
    final terms = draft.terms;
    final end = terms.effectiveEnd;
    // The rules `PayAgreement` enforces, under the field that breaks them.
    return {
      if (terms.hourlyRateMicroEur <= 0) 'hourlyRate': AgreementProblems.rate,
      if (end != null && end.compareTo(terms.effectiveStart) < 0)
        'effectiveEnd': AgreementProblems.endBeforeStart,
      if (terms.overtimeThresholdMinutes <= 0)
        'overtimeHours': AgreementProblems.hours,
      if (terms.nightEnabled && terms.nightStartMinute == terms.nightEndMinute)
        'nightEnd': AgreementProblems.nightWindow,
      if (terms.sickEmployerDays < 0 || terms.sickEmployerDays > 30)
        'sickDays': AgreementProblems.sickDays,
    };
  }

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final MapEntry(:key, :value) in fields.entries)
      key: switch ((key, value.firstOrNull?.code)) {
        ('effectiveStart', FieldIssueCode.conflict) =>
          AgreementProblems.startAfterUse,
        ('effectiveEnd', FieldIssueCode.conflict) =>
          AgreementProblems.endBeforeUse,
        ('effectiveEnd', _) => AgreementProblems.endBeforeStart,
        ('effectiveRange', _) => AgreementProblems.overlap,
        ('agreement', _) => AgreementProblems.terms,
        _ => WorkProblems.unknownField,
      },
  };

  @override
  Future<ConfirmRequest?> guard(
    AgreementRecord? baseline,
    AgreementValues draft,
  ) async {
    if (baseline == null) return null;
    final impact = await preview.previewAgreementCorrection(
      baseline.value.id,
      draft.terms,
    );
    return impact == null ? null : repricingRequest(impact);
  }

  @override
  Future<SubmitResult<AgreementRecord>> submit(
    AgreementRecord? baseline,
    AgreementValues draft, {
    Object? consent,
  }) async {
    if (baseline == null) {
      final versions = [
        for (final value in await reads.agreementsOf(employmentId))
          value.version,
      ];
      _sentAt = clock.nowUtc();
      final outcome = await service.createAgreement(
        CreateAgreementCommand(
          employmentId: employmentId,
          version: versions.fold(0, (a, b) => a > b ? a : b) + 1,
          terms: draft.terms,
        ),
      );
      return Submitted(
        await settle(outcome, (value) async => AgreementRecord(value)),
      );
    }
    final confirmed = consent as AgreementCorrectionImpact?;
    final current = baseline.value;
    final outcome = await service.updateAgreement(
      UpdateAgreementCommand(
        agreementId: current.id,
        employmentId: current.employmentId,
        expectedRevision: current.revision,
        terms: draft.terms,
        confirmedImpact: confirmed,
      ),
    );
    if (outcome is Stale<PayAgreement>) {
      // Stale is either a moved revision or a repricing that changed since
      // it was confirmed; only the second is asked again. Nothing was
      // written, so a read that fails here leaves it plainly Stale.
      try {
        final stored = await reads.agreement(current.employmentId, current.id);
        if (stored == null) return const Submitted(Missing());
        if (stored.value.revision == current.revision) {
          final fresh = await preview.previewAgreementCorrection(
            current.id,
            draft.terms,
          );
          if (fresh != confirmed) {
            return Reconfirm(
              fresh == null ? repricingGoneRequest : repricingRequest(fresh),
            );
          }
        }
      } on Object {
        return const Submitted(Stale());
      }
    }
    return Submitted(
      await settle(
        outcome,
        (value) => reads.agreement(value.employmentId, value.id),
      ),
    );
  }

  @override
  Future<ReadBack<AgreementRecord>> readBack(
    AgreementRecord? baseline,
    AgreementValues? submitted,
  ) async {
    if (baseline != null) {
      final current = await reads.agreement(
        baseline.value.employmentId,
        baseline.value.id,
      );
      if (current == null) return const ReadGone();
      return ReadFound(
        current,
        saved:
            submitted != null &&
            current.value.revision != baseline.value.revision &&
            draftOf(current) == _stored(submitted),
      );
    }
    final sentAt = _sentAt;
    if (submitted == null || sentAt == null) return const ReadUnknown();
    // Any matching agreement created since the send counts, even one made
    // identically elsewhere meanwhile: the result is the same, and telling
    // them apart would need an idempotency key, new service behaviour.
    for (final value in await reads.agreementsOf(employmentId)) {
      final found = AgreementRecord(value);
      if (!value.createdAtUtc.isBefore(sentAt) &&
          draftOf(found) == _stored(submitted)) {
        return ReadFound(found, saved: true);
      }
    }
    return const ReadNotSaved();
  }
}

/// [values] as the service stores them: label and note trimmed, empty
/// ones none.
AgreementValues _stored(AgreementValues values) {
  String? trimmed(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }

  final terms = values.terms;
  return AgreementValues(
    AgreementTerms(
      effectiveStart: terms.effectiveStart,
      effectiveEnd: terms.effectiveEnd,
      hourlyRateMicroEur: terms.hourlyRateMicroEur,
      basis: terms.basis,
      label: trimmed(terms.label),
      note: trimmed(terms.note),
      overtimeThresholdMinutes: terms.overtimeThresholdMinutes,
      overtimeMultiplier: terms.overtimeMultiplier,
      nightEnabled: terms.nightEnabled,
      nightStartMinute: terms.nightStartMinute,
      nightEndMinute: terms.nightEndMinute,
      nightMultiplier: terms.nightMultiplier,
      holidayCalendar: terms.holidayCalendar,
      holidayMultiplier: terms.holidayMultiplier,
      premiumStacking: terms.premiumStacking,
      vacationPay: terms.vacationPay,
      sickPay: terms.sickPay,
      sickEmployerDays: terms.sickEmployerDays,
    ),
  );
}
