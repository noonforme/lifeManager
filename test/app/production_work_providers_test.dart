import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/ids.dart';

void main() {
  test('production ID factory emits domain-valid UUIDv7 values', () {
    final ids = UuidV7WorkIdFactory();

    expect(EmploymentId.tryParse(ids.employmentId().value), isNotNull);
    expect(AgreementId.tryParse(ids.agreementId().value), isNotNull);
    expect(ShiftId.tryParse(ids.shiftId().value), isNotNull);
    expect(ShiftBreakId.tryParse(ids.shiftBreakId().value), isNotNull);
    expect(PayPeriodId.tryParse(ids.payPeriodId().value), isNotNull);
    expect(PayslipId.tryParse(ids.payslipId().value), isNotNull);
  });

  test('production Work composition resolves every controller dependency', () {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ids = _Ids();
    final composition = buildWorkProviders(
      database: database,
      clock: _Clock(),
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Amsterdam',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    expect(composition.workRepository, isNotNull);
    expect(composition.employment, isNotNull);
    expect(composition.agreement, isNotNull);
    expect(composition.shifts, isNotNull);
    expect(composition.manualShifts, isNotNull);
    expect(composition.periods, isNotNull);
    expect(composition.payslips, isNotNull);
    expect(composition.schedules, isNotNull);
    expect(composition.plans, isNotNull);
    expect(composition.history, isNotNull);
    expect(composition.currentTimezoneId(), 'Europe/Amsterdam');
  });
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 1, 8);
}

final class _Ids
    implements WorkIdFactory, ShiftIdFactory, WorkEvidenceIdFactory {
  @override
  EmploymentId employmentId() =>
      const EmploymentId('00000000-0000-7000-8000-000000000001');

  @override
  AgreementId agreementId() =>
      const AgreementId('00000000-0000-7000-8000-000000000002');

  @override
  ShiftId shiftId() => const ShiftId('00000000-0000-7000-8000-000000000003');

  @override
  ShiftBreakId shiftBreakId() =>
      const ShiftBreakId('00000000-0000-7000-8000-000000000004');

  @override
  PayPeriodId payPeriodId() =>
      const PayPeriodId('00000000-0000-7000-8000-000000000005');

  @override
  PayslipId payslipId() =>
      const PayslipId('00000000-0000-7000-8000-000000000006');
}
