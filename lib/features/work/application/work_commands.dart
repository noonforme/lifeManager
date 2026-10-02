import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../../core/time/timezone_service.dart';
import '../data/work_write_store.dart';
import '../domain/agreement.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';

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

final class UpdateEmploymentCommand {
  const UpdateEmploymentCommand({
    required this.employmentId,
    required this.expectedRevision,
    required this.name,
    required this.legalLabel,
  });

  final EmploymentId employmentId;
  final Revision expectedRevision;
  final String name;
  final String? legalLabel;
}

/// Deletes an employment that has no shifts, pay periods or payslips,
/// together with its agreements.
final class DeleteEmploymentCommand {
  const DeleteEmploymentCommand({
    required this.employmentId,
    required this.expectedRevision,
  });

  final EmploymentId employmentId;
  final Revision expectedRevision;
}

final class ArchiveEmploymentCommand {
  const ArchiveEmploymentCommand({
    required this.employmentId,
    required this.expectedRevision,
  });

  final EmploymentId employmentId;
  final Revision expectedRevision;
}

/// Every editable fact of a pay agreement. The premium fields default to
/// [AgreementDefaults], so a new agreement needs only its range and rate.
final class AgreementTerms {
  const AgreementTerms({
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.hourlyRateMicroEur,
    required this.basis,
    required this.label,
    required this.note,
    this.overtimeThresholdMinutes = AgreementDefaults.overtimeThresholdMinutes,
    this.overtimeMultiplier = AgreementDefaults.overtimeMultiplier,
    this.nightEnabled = AgreementDefaults.nightEnabled,
    this.nightStartMinute = AgreementDefaults.nightStartMinute,
    this.nightEndMinute = AgreementDefaults.nightEndMinute,
    this.nightMultiplier = AgreementDefaults.nightMultiplier,
    this.holidayCalendar = AgreementDefaults.holidayCalendar,
    this.holidayMultiplier = AgreementDefaults.holidayMultiplier,
    this.premiumStacking = AgreementDefaults.premiumStacking,
  });

  final LocalDate effectiveStart;
  final LocalDate? effectiveEnd;
  final int hourlyRateMicroEur;
  final RateBasis basis;
  final String? label;
  final String? note;
  final int overtimeThresholdMinutes;
  final RationalMultiplier overtimeMultiplier;
  final bool nightEnabled;
  final int nightStartMinute;
  final int nightEndMinute;
  final RationalMultiplier nightMultiplier;
  final HolidayCalendar holidayCalendar;
  final RationalMultiplier holidayMultiplier;
  final PremiumStacking premiumStacking;
}

final class CreateAgreementCommand {
  const CreateAgreementCommand({
    required this.employmentId,
    required this.version,
    required this.terms,
  });

  final EmploymentId employmentId;
  final int version;
  final AgreementTerms terms;
}

/// Rewrites an agreement that no finalized shift uses.
final class UpdateAgreementCommand {
  const UpdateAgreementCommand({
    required this.agreementId,
    required this.employmentId,
    required this.expectedRevision,
    required this.terms,
  });

  final AgreementId agreementId;
  final EmploymentId employmentId;
  final Revision expectedRevision;
  final AgreementTerms terms;
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

abstract interface class WorkEvidenceIdFactory {
  PayPeriodId payPeriodId();

  PayslipId payslipId();
}

final class CreatePayPeriodCommand {
  const CreatePayPeriodCommand({
    required this.employmentId,
    required this.start,
    required this.end,
    required this.label,
  });

  final EmploymentId employmentId;
  final LocalDate start;
  final LocalDate end;
  final String? label;
}

final class SetPayPeriodStateCommand {
  const SetPayPeriodStateCommand({
    required this.id,
    required this.state,
    required this.expectedRevision,
  });

  final PayPeriodId id;
  final PayPeriodState state;
  final Revision expectedRevision;
}

final class RecordPayslipCommand {
  const RecordPayslipCommand({
    required this.periodId,
    required this.issuedDate,
    required this.paidDate,
    required this.amountMinorUnits,
    required this.basis,
    required this.grossMinorUnits,
    required this.netMinorUnits,
    required this.deductionMinorUnits,
    required this.reference,
    required this.note,
  });

  final PayPeriodId periodId;
  final LocalDate issuedDate;
  final LocalDate? paidDate;
  final int amountMinorUnits;
  final RateBasis basis;
  final int? grossMinorUnits;
  final int? netMinorUnits;
  final int? deductionMinorUnits;
  final String? reference;
  final String? note;
}

final class CorrectPayslipCommand {
  const CorrectPayslipCommand({
    required this.originalId,
    required this.replacementId,
    required this.expectedRevision,
    required this.voidReason,
  });

  final PayslipId originalId;
  final PayslipId replacementId;
  final Revision expectedRevision;
  final String voidReason;
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
    required this.expectedRevision,
  });

  final ShiftId id;
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

final class ManualShiftBreak {
  const ManualShiftBreak({
    required this.localStartDate,
    required this.localStartTime,
    required this.localEndDate,
    required this.localEndTime,
    required this.startFold,
    required this.endFold,
  });

  final LocalDate localStartDate;
  final LocalTime localStartTime;
  final LocalDate localEndDate;
  final LocalTime localEndTime;
  final FoldChoice? startFold;
  final FoldChoice? endFold;
}

/// Owner-entered facts that replace a draft shift's facts before it
/// finalizes, such as a correction's replacement.
final class ReviseShiftDraftCommand {
  const ReviseShiftDraftCommand({
    required this.id,
    required this.expectedRevision,
    required this.localStartDate,
    required this.localStartTime,
    required this.localEndDate,
    required this.localEndTime,
    required this.timezoneId,
    required this.startFold,
    required this.endFold,
    this.breaks = const [],
    required this.note,
  });

  final ShiftId id;
  final Revision expectedRevision;
  final LocalDate localStartDate;
  final LocalTime localStartTime;
  final LocalDate localEndDate;
  final LocalTime localEndTime;
  final String timezoneId;
  final FoldChoice? startFold;
  final FoldChoice? endFold;
  final List<ManualShiftBreak> breaks;
  final String? note;
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
    this.breaks = const [],
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
  final List<ManualShiftBreak> breaks;
  final String? note;
}
