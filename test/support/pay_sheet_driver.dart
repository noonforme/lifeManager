import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';

import 'schedule_fixture.dart';
import 'shifts_sheet_driver.dart';
import 'shifts_sheet_fixture.dart';

Future<(PayPeriod, Payslip)> openPay(
  WidgetTester tester,
  ShiftsSheetFixture fixture, {
  bool payslips = false,
}) async {
  late PayPeriod period;
  late Payslip slip;
  await tester.runAsync(() async {
    await fixture.finishShift(6);
    period = (await fixture.work.periods.createPeriod(
      const CreatePayPeriodCommand(
        employmentId: fixtureEmployment,
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
        label: 'October 2026',
      ),
    ) as Committed<PayPeriod>).value;
    slip = (await fixture.work.payslips.recordPayslip(
      RecordPayslipCommand(
        periodId: period.id,
        issuedDate: const LocalDate(2026, 10, 20),
        paidDate: const LocalDate(2026, 10, 20),
        amountMinorUnits: 14720,
        basis: const GrossBasis(),
        grossMinorUnits: 14720,
        netMinorUnits: null,
        deductionMinorUnits: null,
        reference: 'Synthetic transfer',
        note: 'October evidence',
      ),
    ) as Committed<Payslip>).value;
  });
  unawaited(
    shellOf(tester).go(
      WorkLocation.pay(
        fixtureEmployment,
        sheet: payslips ? WorkSheetKind.payslips : WorkSheetKind.periods,
        payRecord: payslips ? slip.id : period.id,
      ),
    ),
  );
  await settleSheet(tester);
  return (period, slip);
}
