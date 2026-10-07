import '../domain/ids.dart';
import '../domain/pay.dart';
import 'work_commands.dart';

/// What correcting an agreement in place does to pay already worked out
/// under it, shown before the owner confirms (premiums spec 7, added
/// 2026-10-08). Pay is priced from the stored agreement, so a correction
/// reprices every finished shift and leave day it pays.
final class AgreementCorrectionImpact {
  const AgreementCorrectionImpact({
    required this.shifts,
    required this.leaveDays,
    required this.otherLeaveDays,
    required this.before,
    required this.after,
    required this.inReviewedPeriods,
  });

  /// Finished shifts paid under the agreement.
  final int shifts;

  /// Confirmed leave paid under it.
  final int leaveDays;

  /// Confirmed leave under another agreement whose 3-month average moves
  /// with the shifts repriced.
  final int otherLeaveDays;

  /// What all of them are paid in total now, and corrected.
  final Money before;
  final Money after;

  /// How many of them fall in a reviewed pay period or one with a payslip,
  /// whose reconciliation changes.
  final int inReviewedPeriods;

  Money get difference =>
      Money(minorUnits: after.minorUnits - before.minorUnits);

  /// The same records and totals: what the owner confirmed still holds.
  @override
  bool operator ==(Object other) =>
      other is AgreementCorrectionImpact &&
      shifts == other.shifts &&
      leaveDays == other.leaveDays &&
      otherLeaveDays == other.otherLeaveDays &&
      before == other.before &&
      after == other.after &&
      inReviewedPeriods == other.inReviewedPeriods;

  @override
  int get hashCode => Object.hash(
    shifts,
    leaveDays,
    otherLeaveDays,
    before,
    after,
    inReviewedPeriods,
  );
}

abstract interface class AgreementCorrectionPreview {
  /// The impact of rewriting agreement [id] with [terms]; null when it is
  /// missing or unused, the terms are invalid or change no pay, no record
  /// would be repriced, or its new dates leave out a shift it pays. Saving
  /// then needs no confirmation: it says why, or reprices nothing.
  Future<AgreementCorrectionImpact?> previewAgreementCorrection(
    AgreementId id,
    AgreementTerms terms,
  );
}
