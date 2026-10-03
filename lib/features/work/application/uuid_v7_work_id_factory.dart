import 'package:uuid/uuid.dart';

import '../domain/ids.dart';
import '../domain/schedule.dart';
import 'work_commands.dart';

final class UuidV7WorkIdFactory
    implements
        WorkIdFactory,
        ShiftIdFactory,
        WorkEvidenceIdFactory,
        ScheduleIdFactory {
  UuidV7WorkIdFactory({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  EmploymentId employmentId() => EmploymentId(_uuid.v7());

  @override
  AgreementId agreementId() => AgreementId(_uuid.v7());

  @override
  ShiftId shiftId() => ShiftId(_uuid.v7());

  @override
  ShiftBreakId shiftBreakId() => ShiftBreakId(_uuid.v7());

  @override
  PayPeriodId payPeriodId() => PayPeriodId(_uuid.v7());

  @override
  PayslipId payslipId() => PayslipId(_uuid.v7());

  @override
  ScheduleId scheduleId() => ScheduleId(_uuid.v7());

  @override
  ShiftTypeId shiftTypeId() => ShiftTypeId(_uuid.v7());

  @override
  DayExceptionId dayExceptionId() => DayExceptionId(_uuid.v7());

  @override
  LeaveRecordId leaveRecordId() => LeaveRecordId(_uuid.v7());
}
