import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';

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
    final container = composition.createContainer();
    addTearDown(container.dispose);

    expect(container.read(workQueryRepositoryProvider), isNotNull);
    expect(container.read(createEmploymentProvider), isNotNull);
    expect(container.read(createAgreementProvider), isNotNull);
    expect(container.read(startShiftProvider), isNotNull);
    expect(container.read(startBreakProvider), isNotNull);
    expect(container.read(endBreakProvider), isNotNull);
    expect(container.read(endShiftProvider), isNotNull);
    expect(container.read(finalizeShiftProvider), isNotNull);
    expect(container.read(saveManualShiftProvider), isNotNull);
    expect(container.read(createPayPeriodProvider), isNotNull);
    expect(container.read(setPayPeriodStateProvider), isNotNull);
    expect(container.read(recordPayslipProvider), isNotNull);
    expect(container.read(correctPayslipProvider), isNotNull);
    expect(container.read(correctShiftProvider), isNotNull);
    expect(container.read(currentTimezoneIdProvider)(), 'Europe/Amsterdam');
  });

  testWidgets('production Work composition scopes its child', (tester) async {
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

    await tester.pumpWidget(composition.scope(const _ProviderProbe()));

    expect(find.text('ready'), findsOneWidget);
  });
}

final class _ProviderProbe extends ConsumerWidget {
  const _ProviderProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(workQueryRepositoryProvider);
    ref.watch(createEmploymentProvider);
    ref.watch(startShiftProvider);
    ref.watch(recordPayslipProvider);
    return const Text('ready', textDirection: TextDirection.ltr);
  }
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
