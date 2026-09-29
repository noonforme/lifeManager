import '../../../core/time/local_date.dart';
import 'facts.dart';
import 'ids.dart';

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
    if (overtimeMultiplier.numerator <= 0 ||
        overtimeMultiplier.denominator <= 0) {
      throw ArgumentError.value(overtimeMultiplier, 'overtimeMultiplier');
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
