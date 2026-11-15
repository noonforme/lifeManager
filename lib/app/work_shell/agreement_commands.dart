import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/agreement_correction.dart'
    show AgreementCorrectionImpact;
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/planner.dart';
import '../edit_session/confirm.dart';
import '../production_work_providers.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/work_records.dart';

/// What Remove agreement… and Extend pay agreement… say.
abstract final class AgreementCommandWords {
  static const removed = 'Agreement removed.';
  static const inUse =
      "Finished shifts or confirmed leave now use this agreement, so it can't "
      'be removed.';
  static const notRemoved = 'It was not removed. Try again when ready.';
  static const removeUnknown =
      'It is not known whether it was removed; the sheet shows it as it is '
      'now.';
  static const extended = 'Agreement extended.';
  static const noAgreement = 'No pay agreement yet: set one up first.';
  static const covered = 'An agreement already pays that day.';
  static const extendUnknown =
      'It is not known whether it was extended; check the agreement.';
  static const stale =
      'This agreement changed meanwhile; nothing was done. Try again.';
  static const missing = 'This agreement no longer exists.';
  static const unavailable =
      'Not done: local storage is unavailable. Try again.';
  static const overlap = AgreementProblems.overlap;
}

/// Remove agreement… (spec 4.7: deleting a record asks first).
ConfirmRequest removeAgreementRequest(PayAgreement value) => ConfirmRequest(
  title: 'Remove agreement',
  message:
      'Remove pay agreement v${value.version}? No finished shift or '
      "confirmed leave uses it. This can't be undone.",
  proceed: 'Remove',
);

/// Extend pay agreement… for [date] (schedules spec 6.6): its terms stay.
ConfirmRequest extendAgreementRequest(PayAgreement value, LocalDate date) {
  final earlier = date.compareTo(value.effectiveStart) < 0;
  return ConfirmRequest(
    title: 'Extend agreement',
    message:
        'Extend pay agreement v${value.version} to '
        '${earlier ? 'start' : 'end'} on $date? Its terms stay as they are. '
        'The planned days it then covers are priced by it and can be '
        'confirmed.',
    proceed: 'Extend',
  );
}

/// Extend pay agreement… (schedules spec 6.6): widens the agreement of
/// [employmentId] nearest to the first of [days] just enough to pay as
/// many of them as one widening can — an earlier start, or a later end up
/// to the eve of the next version — its terms unchanged, after asking.
/// Returns what the status line says; empty when the owner cancelled.
Future<String> extendAgreement({
  required ProductionWorkProviders work,
  required WorkReads reads,
  required Confirm confirm,
  required EmploymentId employmentId,
  required List<LocalDate> days,
}) async {
  if (days.isEmpty) return AgreementCommandWords.covered;
  final sorted = [...days]..sort();
  final List<PayAgreement> agreements;
  try {
    agreements = await reads.agreementsOf(employmentId);
  } on Object {
    return AgreementCommandWords.unavailable;
  }
  final first = sorted.first;
  final nearest = nearestAgreement(agreements, first);
  if (nearest == null) return AgreementCommandWords.noAgreement;
  final end = nearest.effectiveEnd;
  final earlier = first.compareTo(nearest.effectiveStart) < 0;
  final later = end != null && first.compareTo(end) > 0;
  if (!earlier && !later) return AgreementCommandWords.covered;
  // After its end: on to the last day before the next version starts.
  final next = [
    for (final value in agreements)
      if (later && value.effectiveStart.compareTo(end) > 0)
        value.effectiveStart,
  ]..sort();
  final date = earlier
      ? first
      : sorted.lastWhere(
          (day) => next.isEmpty || day.compareTo(next.first) < 0,
        );
  if (await confirm(extendAgreementRequest(nearest, date)) !=
      ConfirmAnswer.proceed) {
    return '';
  }
  final terms = AgreementTerms.of(
    nearest,
    effectiveStart: earlier ? date : null,
    effectiveEnd: later ? () => date : null,
  );
  // Widening keeps its terms, so it reprices nothing; should the preview
  // say otherwise, the owner is asked as for any correction. Nothing is
  // sent yet, so a preview that cannot be read is plainly not done.
  final AgreementCorrectionImpact? impact;
  try {
    impact = await work.workRepository.previewAgreementCorrection(
      nearest.id,
      terms,
    );
  } on Object {
    return AgreementCommandWords.unavailable;
  }
  if (impact != null &&
      await confirm(repricingRequest(impact)) != ConfirmAnswer.proceed) {
    return '';
  }
  final MutationOutcome<PayAgreement> outcome;
  try {
    outcome = await work.agreement.updateAgreement(
      UpdateAgreementCommand(
        agreementId: nearest.id,
        employmentId: employmentId,
        expectedRevision: nearest.revision,
        terms: terms,
        confirmedImpact: impact,
      ),
    );
  } on Object {
    return AgreementCommandWords.extendUnknown;
  }
  return switch (outcome) {
    Committed() => AgreementCommandWords.extended,
    Invalid(:final fields) when fields.containsKey('effectiveRange') =>
      AgreementCommandWords.overlap,
    Invalid() => AgreementProblems.terms,
    Stale() => AgreementCommandWords.stale,
    Missing() => AgreementCommandWords.missing,
    Unavailable() => AgreementCommandWords.unavailable,
    Uncertain() => AgreementCommandWords.extendUnknown,
  };
}
