import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/work_edit/pay_edit.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/pay_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';

import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const periodId = PayPeriodId('0190f5d2-6a00-7000-8000-000000000901');
const slipId = PayslipId('0190f5d2-6a00-7000-8000-000000000902');
const today = LocalDate(2026, 10, 20);
void main() {
  test('pay routes round trip, restore older record routes and reject mismatched ids', () {
    for (final place in [
      const WorkLocation.pay(
        fixtureEmployment,
        sheet: WorkSheetKind.periods,
        payRecord: periodId,
        sub: 'reconciliation',
        payStatus: 'reviewed',
      ),
      const WorkLocation.pay(
        fixtureEmployment,
        sheet: WorkSheetKind.payslips,
        payRecord: slipId,
        periodFilter: periodId,
        payStatus: 'all',
        sub: 'history',
      ),
    ]) {
      expect(WorkLocation.parse(place.toUri(), today: today), place);
    }
    expect(
      WorkLocation.parse(
        Uri.parse(
          '/work?employment=${fixtureEmployment.value}&record=payPeriod:${periodId.value}',
        ),
        today: today,
      ).payRecord,
      periodId,
    );
    final wrong = WorkLocation.parse(
      Uri.parse(
        '/work?employment=${fixtureEmployment.value}&sheet=payslips&record=payPeriod:${periodId.value}&payStatus=reviewed&period=bad',
      ),
      today: today,
    );
    expect(wrong.payRecord, isNull);
    expect(wrong.payStatus, isNull);
    expect(wrong.periodFilter, isNull);
    final invalidTab = const WorkLocation.pay(
      fixtureEmployment,
      sheet: WorkSheetKind.payslips,
      payRecord: slipId,
    ).withSub('reconciliation');
    expect(invalidTab.sub, isNull);
    expect(
      WorkLocation.parse(
        Uri.parse('${invalidTab.toUri()}&sub=evidence'),
        today: today,
      ).sub,
      isNull,
    );
  });
  test(
    'failed register read retains record selection and Retry restores it',
    () async {
      final gate = ReadGate();
      final f = await ShiftsSheetFixture.create(
        executor: NativeDatabase.memory().interceptWith(gate),
      );
      addTearDown(f.dispose);
      final period = (await f.work.periods.createPeriod(
        const CreatePayPeriodCommand(
          id: periodId,
          employmentId: fixtureEmployment,
          start: LocalDate(2026, 10, 1),
          end: LocalDate(2026, 10, 31),
          label: null,
        ),
      ) as Committed<PayPeriod>).value;
      gate.failing = true;
      final sheet = PaySheetController(
        kind: PayKind.periods,
        work: f.work,
        reads: f.reads,
        employmentId: fixtureEmployment,
        today: today,
        coordinator: LeaveCoordinator(
          confirm: (_) async => ConfirmAnswer.cancel,
        ),
        confirm: (_) async => ConfirmAnswer.cancel,
      );
      addTearDown(sheet.dispose);
      sheet.start();
      await sheet.ready;
      sheet.show(period.id);
      expect(sheet.failed, isTrue);
      expect(sheet.recordId, period.id);
      gate.failing = false;
      await sheet.reload();
      expect(sheet.failed, isFalse);
      expect(sheet.selected!.id, period.id);
    },
  );
  test('saving a payslip in another period clears the old period filter', () async {
    final f = await ShiftsSheetFixture.create();
    addTearDown(f.dispose);
    Future<PayPeriod> create(LocalDate start, LocalDate end) async =>
        (await f.work.periods.createPeriod(
          CreatePayPeriodCommand(
            employmentId: fixtureEmployment,
            start: start,
            end: end,
            label: null,
          ),
        ) as Committed<PayPeriod>).value;
    final first = await create(
      const LocalDate(2026, 9, 1),
      const LocalDate(2026, 9, 30),
    );
    final second = await create(
      const LocalDate(2026, 10, 1),
      const LocalDate(2026, 10, 31),
    );
    final shell = WorkShellController(
      work: f.work,
      reads: f.reads,
      today: today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.proceed,
      store: MemoryLocationStore(
        '${WorkLocation.pay(fixtureEmployment, sheet: WorkSheetKind.payslips, periodFilter: first.id).toUri()}',
      ),
    );
    addTearDown(shell.dispose);
    await shell.start();
    await shell.addPay(PayKind.payslips, period: first.id);
    shell.paySheet!
      ..set('period', second.id)
      ..set('amount', '25.00')
      ..set('basis', const GrossBasis());
    await shell.paySheet!.save();
    expect(shell.location.periodFilter, isNull);
    expect(shell.location.payRecord, shell.paySheet!.selected!.id);
    expect(shell.paySheet!.selected!.payslip!.periodId, second.id);
  });

  test('foreign period/filter fallback, filter state, Back/Forward and remembered tab', () async {
    final f = await ShiftsSheetFixture.create();
    addTearDown(f.dispose);
    await f.work.periods.createPeriod(
      const CreatePayPeriodCommand(
        id: periodId,
        employmentId: fixtureEmployment,
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
        label: null,
      ),
    );
    final store = MemoryLocationStore(
      '${const WorkLocation.pay(fixtureEmployment, sheet: WorkSheetKind.periods, payRecord: periodId).toUri()}',
    );
    final shell = WorkShellController(
      work: f.work,
      reads: f.reads,
      today: today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: store,
    );
    addTearDown(shell.dispose);
    await shell.start();
    expect(shell.paySheet!.recordId, periodId);
    final other = (await f.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Other', legalLabel: null),
    ) as Committed<Employment>).value;
    await shell.go(
      WorkLocation.pay(
        other.id,
        sheet: WorkSheetKind.periods,
        payRecord: periodId,
      ),
    );
    expect(shell.location.payRecord, isNull);
    await shell.go(
      WorkLocation.pay(
        other.id,
        sheet: WorkSheetKind.payslips,
        periodFilter: periodId,
      ),
    );
    expect(shell.location.periodFilter, isNull);
    await shell.back();
    await shell.back();
    expect(shell.location.payRecord, periodId);
    await shell.setPayFilter('reviewed', null);
    expect(shell.location.payStatus, 'reviewed');
    expect(shell.location.payRecord, isNull);
    await shell.back();
    shell.selectSub('evidence');
    await shell.remember();
    expect(
      WorkLocation.parse(Uri.parse((await store.read())!), today: today).sub,
      'evidence',
    );
    await shell.forward();
    expect(shell.location.payStatus, 'reviewed');
  });

  test('selecting a row keeps a Status that shows it; a Status that would '
      'hide a linked record widens to All', () async {
    final f = await ShiftsSheetFixture.create();
    addTearDown(f.dispose);
    Future<PayPeriod> create(LocalDate start, LocalDate end) async =>
        (await f.work.periods.createPeriod(
          CreatePayPeriodCommand(
            employmentId: fixtureEmployment,
            start: start,
            end: end,
            label: null,
          ),
        ) as Committed<PayPeriod>).value;
    final september = await create(
      const LocalDate(2026, 9, 1),
      const LocalDate(2026, 9, 30),
    );
    final october = await create(
      const LocalDate(2026, 10, 1),
      const LocalDate(2026, 10, 31),
    );
    final reviewed = (await f.work.periods.setState(
      SetPayPeriodStateCommand(
        id: september.id,
        state: PayPeriodState.reviewed,
        expectedRevision: september.revision,
      ),
    ) as Committed<PayPeriod>).value;
    final original = (await f.work.payslips.recordPayslip(
      RecordPayslipCommand(
        periodId: october.id,
        issuedDate: today,
        paidDate: null,
        amountMinorUnits: 10000,
        basis: const GrossBasis(),
        grossMinorUnits: null,
        netMinorUnits: null,
        deductionMinorUnits: null,
        reference: null,
        note: null,
      ),
    ) as Committed<Payslip>).value;
    final replacement = (await f.work.payslips.correctPayslip(
      CorrectPayslipCommand(
        originalId: original.id,
        replacementId: f.schedule.ids.payslipId(),
        expectedRevision: original.revision,
        voidReason: 'Wrong amount',
      ),
    ) as Committed<Payslip>).value;
    final shell = WorkShellController(
      work: f.work,
      reads: f.reads,
      today: today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(
        '${const WorkLocation.pay(fixtureEmployment, sheet: WorkSheetKind.payslips, payStatus: 'all').toUri()}',
      ),
    );
    addTearDown(shell.dispose);
    await shell.start();

    // Payslips, Status All: an effective and a void row both keep it.
    await shell.paySheet!.select(replacement.id);
    expect(shell.location.payRecord, replacement.id);
    expect(shell.location.payStatus, 'all');
    await shell.paySheet!.select(original.id);
    expect(shell.location.payStatus, 'all');

    // Status Void: a link to the effective replacement widens to All.
    await shell.setPayFilter('void', null);
    await shell.go(
      WorkLocation.pay(
        fixtureEmployment,
        sheet: WorkSheetKind.payslips,
        payRecord: replacement.id,
        payStatus: 'void',
      ),
    );
    expect(shell.location.payRecord, replacement.id);
    expect(shell.location.payStatus, 'all');

    // Pay periods, Status Open: the open period keeps it.
    await shell.go(
      const WorkLocation.pay(
        fixtureEmployment,
        sheet: WorkSheetKind.periods,
        payStatus: 'open',
      ),
    );
    await shell.paySheet!.select(october.id);
    expect(shell.location.payRecord, october.id);
    expect(shell.location.payStatus, 'open');

    // A link to the reviewed period under Status Open shows All.
    await shell.go(
      WorkLocation.pay(
        fixtureEmployment,
        sheet: WorkSheetKind.periods,
        payRecord: reviewed.id,
        payStatus: 'open',
      ),
    );
    expect(shell.location.payRecord, reviewed.id);
    expect(shell.location.payStatus, isNull);
  });
}
