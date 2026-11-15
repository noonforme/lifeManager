import '../data/projections/work_register_projection.dart';
import '../domain/agreement.dart';
import '../domain/day_exception.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/leave.dart';
import '../domain/planner.dart';
import '../domain/shift.dart';

/// What [day] would pay once confirmed, from the employment's confirmed
/// work and leave; null when no agreement covers its date. A sick day
/// without an illness start is priced as the illness's first day.
LeavePay? plannedLeavePay(
  PlannedLeave day, {
  required EmploymentId employmentId,
  required List<PayAgreement> agreements,
  required List<ShiftSheetRow> shifts,
  required List<LeaveSheetRow> leave,
}) {
  if (day.paidMinutes <= 0) return null;
  final resolution = resolveAgreement(
    employmentId: employmentId,
    localStartDate: day.date,
    agreements: agreements,
  );
  if (resolution is! ResolvedAgreement) return null;
  final stamp = DateTime.utc(2000);
  final record = LeaveRecord(
    id: const LeaveRecordId('planned'),
    employmentId: employmentId,
    date: day.date,
    leaveType: day.leaveType,
    illnessStartedOn: day.leaveType == LeaveType.sick
        ? day.illnessStartedOn ?? day.date
        : null,
    paidMinutes: day.paidMinutes,
    agreementId: resolution.agreement.id,
    scheduleId: day.scheduleId,
    scheduleVersion: day.scheduleVersion,
    state: LeaveState.confirmed,
    voidReason: null,
    replacementId: null,
    replacedId: null,
    createdAtUtc: stamp,
    updatedAtUtc: stamp,
    revision: const Revision(0),
  );
  final worked = [
    for (final row in shifts)
      if (row.shift.state == ShiftState.finalized &&
          row.paidSeconds != null &&
          row.pay != null)
        WorkedPay(
          date: row.shift.localStartDate,
          paidSeconds: row.paidSeconds!,
          pay: row.pay!.amount,
          basis: row.pay!.basis,
        ),
  ];
  final earlier = [
    for (final row in leave)
      if (row.record.isEffective && row.record.date.compareTo(day.date) < 0)
        row.record,
  ];
  return priceLeave(
    leave: [...earlier, record],
    worked: worked,
    agreements: agreements,
  )[record.id];
}
