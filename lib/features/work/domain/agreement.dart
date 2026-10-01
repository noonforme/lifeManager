import '../../../core/time/local_date.dart';
import 'facts.dart';
import 'ids.dart';
import 'lithuanian_holidays.dart';

export 'lithuanian_holidays.dart' show HolidayCalendar;

/// How premiums combine when several apply to the same paid time.
enum PremiumStacking {
  /// The largest active multiplier.
  highest,

  /// 1 plus the sum of each active multiplier's extra.
  additive,

  /// The product of every active multiplier.
  multiplicative,
}

final class RationalMultiplier {
  const RationalMultiplier({required this.numerator, required this.denominator})
    : assert(numerator > 0),
      assert(denominator > 0);

  final int numerator;
  final int denominator;

  @override
  bool operator ==(Object other) =>
      other is RationalMultiplier &&
      numerator == other.numerator &&
      denominator == other.denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  /// Whether this multiplier is at least ×1.
  bool get isAtLeastOne => numerator >= denominator;

  @override
  String toString() => '$numerator/$denominator';
}

/// Defaults for a new agreement: the minimums of the Lithuanian Labour Code
/// (Article 144). LifeOS labels them as defaults, not legal advice.
abstract final class AgreementDefaults {
  static const overtimeThresholdMinutes = 480;
  static const overtimeMultiplier = RationalMultiplier(
    numerator: 3,
    denominator: 2,
  );
  static const nightEnabled = true;
  static const nightStartMinute = 22 * 60;
  static const nightEndMinute = 6 * 60;
  static const nightMultiplier = RationalMultiplier(
    numerator: 3,
    denominator: 2,
  );
  static const holidayCalendar = HolidayCalendar.lithuania;
  static const holidayMultiplier = RationalMultiplier(
    numerator: 2,
    denominator: 1,
  );
  static const premiumStacking = PremiumStacking.highest;
}

final class PayAgreement {
  PayAgreement({
    required this.id,
    required this.employmentId,
    required this.version,
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.hourlyRateMicroEur,
    required this.basis,
    required this.overtimeThresholdMinutes,
    required this.overtimeMultiplier,
    required this.label,
    required this.note,
    required this.createdAtUtc,
    required this.revision,
    required this.usedByFinalizedShift,
    this.nightEnabled = AgreementDefaults.nightEnabled,
    this.nightStartMinute = AgreementDefaults.nightStartMinute,
    this.nightEndMinute = AgreementDefaults.nightEndMinute,
    this.nightMultiplier = AgreementDefaults.nightMultiplier,
    this.holidayCalendar = AgreementDefaults.holidayCalendar,
    this.holidayMultiplier = AgreementDefaults.holidayMultiplier,
    this.premiumStacking = AgreementDefaults.premiumStacking,
  }) {
    if (version <= 0) throw ArgumentError.value(version, 'version');
    if (hourlyRateMicroEur <= 0) {
      throw ArgumentError.value(hourlyRateMicroEur, 'hourlyRateMicroEur');
    }
    if (overtimeThresholdMinutes <= 0) {
      throw ArgumentError.value(
        overtimeThresholdMinutes,
        'overtimeThresholdMinutes',
      );
    }
    for (final (name, multiplier) in [
      ('overtimeMultiplier', overtimeMultiplier),
      ('nightMultiplier', nightMultiplier),
      ('holidayMultiplier', holidayMultiplier),
    ]) {
      if (multiplier.numerator <= 0 ||
          multiplier.denominator <= 0 ||
          !multiplier.isAtLeastOne) {
        throw ArgumentError.value(multiplier, name);
      }
    }
    for (final (name, minute) in [
      ('nightStartMinute', nightStartMinute),
      ('nightEndMinute', nightEndMinute),
    ]) {
      if (minute < 0 || minute > 1439) throw ArgumentError.value(minute, name);
    }
    // The window is kept even when night pay is off, so it must stay valid.
    if (nightStartMinute == nightEndMinute) {
      throw ArgumentError.value(nightEndMinute, 'nightEndMinute');
    }
    if (effectiveEnd != null && effectiveEnd!.compareTo(effectiveStart) < 0) {
      throw ArgumentError.value(effectiveEnd, 'effectiveEnd');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
  }

  final AgreementId id;
  final EmploymentId employmentId;
  final int version;
  final LocalDate effectiveStart;
  final LocalDate? effectiveEnd;
  final int hourlyRateMicroEur;
  final RateBasis basis;
  final int overtimeThresholdMinutes;
  final RationalMultiplier overtimeMultiplier;
  final String? label;
  final String? note;
  final DateTime createdAtUtc;
  final Revision revision;
  final bool usedByFinalizedShift;

  /// Night pay applies to paid time inside the local window
  /// [nightStartMinute] (inclusive) to [nightEndMinute] (exclusive). A
  /// start after the end crosses midnight. The window is kept when night pay
  /// is off, so switching it back on restores it.
  final bool nightEnabled;
  final int nightStartMinute;
  final int nightEndMinute;
  final RationalMultiplier nightMultiplier;
  final HolidayCalendar holidayCalendar;
  final RationalMultiplier holidayMultiplier;
  final PremiumStacking premiumStacking;

  bool isEffectiveOn(LocalDate date) =>
      effectiveStart.compareTo(date) <= 0 &&
      (effectiveEnd == null || effectiveEnd!.compareTo(date) >= 0);

  PayAgreement withRangeEnd(LocalDate end) {
    if (usedByFinalizedShift) {
      throw StateError('Used agreements are immutable.');
    }
    return PayAgreement(
      id: id,
      employmentId: employmentId,
      version: version,
      effectiveStart: effectiveStart,
      effectiveEnd: end,
      hourlyRateMicroEur: hourlyRateMicroEur,
      basis: basis,
      overtimeThresholdMinutes: overtimeThresholdMinutes,
      overtimeMultiplier: overtimeMultiplier,
      label: label,
      note: note,
      createdAtUtc: createdAtUtc,
      revision: revision.next(),
      usedByFinalizedShift: false,
      nightEnabled: nightEnabled,
      nightStartMinute: nightStartMinute,
      nightEndMinute: nightEndMinute,
      nightMultiplier: nightMultiplier,
      holidayCalendar: holidayCalendar,
      holidayMultiplier: holidayMultiplier,
      premiumStacking: premiumStacking,
    );
  }
}

sealed class AgreementResolution {
  const AgreementResolution();
}

final class ResolvedAgreement extends AgreementResolution {
  const ResolvedAgreement(this.agreement);

  final PayAgreement agreement;
}

final class MissingAgreement extends AgreementResolution {
  const MissingAgreement();
}

final class AmbiguousAgreement extends AgreementResolution {
  const AmbiguousAgreement();
}

final class ForeignAgreement extends AgreementResolution {
  const ForeignAgreement();
}

AgreementResolution resolveAgreement({
  required EmploymentId employmentId,
  required LocalDate localStartDate,
  required Iterable<PayAgreement> agreements,
}) {
  final all = agreements.toList(growable: false);
  final sameEmployment = all
      .where((item) => item.employmentId == employmentId)
      .toList(growable: false);
  if (sameEmployment.isEmpty && all.isNotEmpty) {
    return const ForeignAgreement();
  }
  final matches = sameEmployment
      .where((item) => item.isEffectiveOn(localStartDate))
      .toList(growable: false);
  return switch (matches) {
    [] => const MissingAgreement(),
    [final one] => ResolvedAgreement(one),
    _ => const AmbiguousAgreement(),
  };
}

DomainValidation validateAgreementSet(Iterable<PayAgreement> agreements) {
  final grouped = <EmploymentId, List<PayAgreement>>{};
  for (final agreement in agreements) {
    grouped.putIfAbsent(agreement.employmentId, () => []).add(agreement);
  }
  final issues = <DomainIssue>[];
  for (final items in grouped.values) {
    items.sort((a, b) => a.effectiveStart.compareTo(b.effectiveStart));
    for (var index = 1; index < items.length; index++) {
      final previous = items[index - 1];
      final current = items[index];
      if (previous.effectiveEnd == null ||
          previous.effectiveEnd!.compareTo(current.effectiveStart) >= 0) {
        issues.add(
          const DomainIssue('agreement.rangeOverlap', field: 'effectiveRange'),
        );
      }
    }
  }
  return DomainValidation(List.unmodifiable(issues));
}
