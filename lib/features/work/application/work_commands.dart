import '../../../core/time/local_date.dart';
import '../data/work_write_store.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';

abstract interface class WorkCommandRepository {
  Future<T> transaction<T>(Future<T> Function(WorkWriteStore store) body);
}

abstract interface class WorkIdFactory {
  EmploymentId employmentId();

  AgreementId agreementId();
}

final class CreateEmploymentCommand {
  const CreateEmploymentCommand({required this.name, required this.legalLabel});

  final String name;
  final String? legalLabel;
}

final class ArchiveEmploymentCommand {
  const ArchiveEmploymentCommand({
    required this.employmentId,
    required this.expectedRevision,
  });

  final EmploymentId employmentId;
  final Revision expectedRevision;
}

final class CreateAgreementCommand {
  const CreateAgreementCommand({
    required this.employmentId,
    required this.version,
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.hourlyRateMicroEur,
    required this.basis,
    required this.overtimeThresholdMinutes,
    required this.overtimeMultiplierNumerator,
    required this.overtimeMultiplierDenominator,
    required this.label,
    required this.note,
  });

  final EmploymentId employmentId;
  final int version;
  final LocalDate effectiveStart;
  final LocalDate? effectiveEnd;
  final int hourlyRateMicroEur;
  final RateBasis basis;
  final int overtimeThresholdMinutes;
  final int overtimeMultiplierNumerator;
  final int overtimeMultiplierDenominator;
  final String? label;
  final String? note;
}

final class CloseAgreementCommand {
  const CloseAgreementCommand({
    required this.agreementId,
    required this.employmentId,
    required this.end,
    required this.expectedRevision,
  });

  final AgreementId agreementId;
  final EmploymentId employmentId;
  final LocalDate end;
  final Revision expectedRevision;
}
