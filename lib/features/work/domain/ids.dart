sealed class WorkRecordId {
  const WorkRecordId();

  String get value;
}

final class EmploymentId extends WorkRecordId {
  const EmploymentId(this.value);

  @override
  final String value;

  static EmploymentId? tryParse(String? value) =>
      _parse(value, EmploymentId.new);

  @override
  bool operator ==(Object other) =>
      other is EmploymentId && value == other.value;

  @override
  int get hashCode => Object.hash(EmploymentId, value);
}

final class AgreementId extends WorkRecordId {
  const AgreementId(this.value);

  @override
  final String value;

  static AgreementId? tryParse(String? value) => _parse(value, AgreementId.new);

  @override
  bool operator ==(Object other) =>
      other is AgreementId && value == other.value;

  @override
  int get hashCode => Object.hash(AgreementId, value);
}

final class ShiftId extends WorkRecordId {
  const ShiftId(this.value);

  @override
  final String value;

  static ShiftId? tryParse(String? value) => _parse(value, ShiftId.new);

  @override
  bool operator ==(Object other) => other is ShiftId && value == other.value;

  @override
  int get hashCode => Object.hash(ShiftId, value);
}

final class ShiftBreakId extends WorkRecordId {
  const ShiftBreakId(this.value);

  @override
  final String value;

  static ShiftBreakId? tryParse(String? value) =>
      _parse(value, ShiftBreakId.new);

  @override
  bool operator ==(Object other) =>
      other is ShiftBreakId && value == other.value;

  @override
  int get hashCode => Object.hash(ShiftBreakId, value);
}

final class PayPeriodId extends WorkRecordId {
  const PayPeriodId(this.value);

  @override
  final String value;

  static PayPeriodId? tryParse(String? value) => _parse(value, PayPeriodId.new);

  @override
  bool operator ==(Object other) =>
      other is PayPeriodId && value == other.value;

  @override
  int get hashCode => Object.hash(PayPeriodId, value);
}

final class PayslipId extends WorkRecordId {
  const PayslipId(this.value);

  @override
  final String value;

  static PayslipId? tryParse(String? value) => _parse(value, PayslipId.new);

  @override
  bool operator ==(Object other) => other is PayslipId && value == other.value;

  @override
  int get hashCode => Object.hash(PayslipId, value);
}

T? _parse<T>(String? value, T Function(String value) create) {
  if (value == null || !_uuidV7.hasMatch(value)) return null;
  return create(value);
}

final RegExp _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
