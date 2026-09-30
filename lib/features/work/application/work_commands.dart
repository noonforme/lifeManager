import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
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

abstract interface class ShiftIdFactory {
  ShiftId shiftId();

  ShiftBreakId shiftBreakId();
}

final class StartShiftCommand {
  const StartShiftCommand({
    required this.employmentId,
    required this.timezoneId,
    this.note,
  });

  final EmploymentId employmentId;
  final String timezoneId;
  final String? note;
}

final class StartBreakCommand {
  const StartBreakCommand({
    required this.shiftId,
    required this.expectedShiftRevision,
  });

  final ShiftId shiftId;
  final Revision expectedShiftRevision;
}

final class EndBreakCommand {
  const EndBreakCommand({
    required this.shiftId,
    required this.breakId,
    required this.expectedShiftRevision,
    required this.expectedBreakRevision,
  });

  final ShiftId shiftId;
  final ShiftBreakId breakId;
  final Revision expectedShiftRevision;
  final Revision expectedBreakRevision;
}

final class EndShiftCommand {
  const EndShiftCommand({required this.id, required this.expectedRevision});

  final ShiftId id;
  final Revision expectedRevision;
}

final class FinalizeShiftCommand {
  const FinalizeShiftCommand({
    required this.id,
    required this.overtimeMinutes,
    required this.expectedRevision,
  });

  final ShiftId id;
  final int overtimeMinutes;
  final Revision expectedRevision;
}

final class CorrectShiftCommand {
  const CorrectShiftCommand({
    required this.originalId,
    required this.replacementId,
    required this.expectedRevision,
    required this.voidReason,
  });

  final ShiftId originalId;
  final ShiftId replacementId;
  final Revision expectedRevision;
  final String voidReason;
}

final class CreateManualShiftCommand {
  const CreateManualShiftCommand({
    required this.employmentId,
    required this.localStartDate,
    required this.localStartTime,
    required this.localEndDate,
    required this.localEndTime,
    required this.timezoneId,
    required this.startFold,
    required this.endFold,
    required this.overtimeMinutes,
    required this.note,
  });

  final EmploymentId employmentId;
  final LocalDate localStartDate;
  final LocalTime localStartTime;
  final LocalDate localEndDate;
  final LocalTime localEndTime;
  final String timezoneId;
  final FoldChoice? startFold;
  final FoldChoice? endFold;
  final int overtimeMinutes;
  final String? note;
}
