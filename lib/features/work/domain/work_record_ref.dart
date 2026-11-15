import 'ids.dart';

/// The kinds of Work record a route can name (`record=kind:id`).
enum WorkRecordKind {
  employment,
  agreement,
  shift,
  shiftBreak,
  payPeriod,
  payslip,
  schedule,
  leave,
}

/// A Work record named in a route, as `kind:id`.
final class WorkRecordRef {
  const WorkRecordRef({required this.kind, required this.id});

  final WorkRecordKind kind;
  final WorkRecordId id;

  static WorkRecordRef? tryParse(String? value) {
    if (value == null) return null;
    final separator = value.indexOf(':');
    if (separator <= 0 || separator != value.lastIndexOf(':')) return null;
    final kindText = value.substring(0, separator);
    final idText = value.substring(separator + 1);
    return switch (kindText) {
      'employment' => _record(
        WorkRecordKind.employment,
        EmploymentId.tryParse(idText),
      ),
      'agreement' => _record(
        WorkRecordKind.agreement,
        AgreementId.tryParse(idText),
      ),
      'shift' => _record(WorkRecordKind.shift, ShiftId.tryParse(idText)),
      'shiftBreak' => _record(
        WorkRecordKind.shiftBreak,
        ShiftBreakId.tryParse(idText),
      ),
      'payPeriod' => _record(
        WorkRecordKind.payPeriod,
        PayPeriodId.tryParse(idText),
      ),
      'payslip' => _record(WorkRecordKind.payslip, PayslipId.tryParse(idText)),
      'schedule' => _record(
        WorkRecordKind.schedule,
        ScheduleId.tryParse(idText),
      ),
      'leave' => _record(WorkRecordKind.leave, LeaveRecordId.tryParse(idText)),
      _ => null,
    };
  }

  static WorkRecordRef? _record(WorkRecordKind kind, WorkRecordId? id) =>
      id == null ? null : WorkRecordRef(kind: kind, id: id);
}
