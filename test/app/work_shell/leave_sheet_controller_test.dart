import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/work_shell/leave_sheet_controller.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/employment.dart';

import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

void main() {
  test(
    'failed reads retain the route selection and Retry recovers it',
    () async {
      final gate = ReadGate();
      final fixture = await ShiftsSheetFixture.create(
        executor: NativeDatabase.memory().interceptWith(gate),
      );
      addTearDown(fixture.dispose);
      final plans = fixture.work.plans;
      await plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 6),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      final original =
          ((await plans.confirm(
                    fixtureEmployment,
                    const LocalDate(2026, 10, 6),
                  ) as Committed<ConfirmedDay>).value
                  as ConfirmedLeave)
              .leave;
      gate.failing = true;
      final sheet = LeaveSheetController(
        work: fixture.work,
        employmentId: fixtureEmployment,
        from: const LocalDate(2026, 10, 1),
        to: const LocalDate(2026, 10, 31),
        coordinator: LeaveCoordinator(
          confirm: (_) async => ConfirmAnswer.cancel,
        ),
        confirm: (_) async => ConfirmAnswer.cancel,
      );
      addTearDown(sheet.dispose);
      sheet.start();
      await sheet.ready;
      sheet.show(original.id);
      expect(sheet.failed, isTrue);
      expect(sheet.notice, LeaveSheetWords.unreadable);
      expect(sheet.selectedId, original.id);
      gate.failing = false;
      await sheet.reload();
      expect(sheet.failed, isFalse);
      expect(sheet.selectedRow!.record.id, original.id);
    },
  );

  test('foreign leave routes select nothing; Back/Forward, scope and remember stay on Leave', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final plans = fixture.work.plans;
    await plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final original =
        ((await plans.confirm(
                  fixtureEmployment,
                  const LocalDate(2026, 10, 6),
                ) as Committed<ConfirmedDay>).value
                as ConfirmedLeave)
            .leave;
    final store = MemoryLocationStore(
      '${WorkLocation.leave(fixtureEmployment, month: const LocalDate(2026, 10, 1), leave: original.id).toUri()}',
    );
    final shell = WorkShellController(
      work: fixture.work,
      reads: fixture.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: store,
    );
    addTearDown(shell.dispose);
    await shell.start();
    expect(shell.leaveSheet!.selectedId, original.id);
    final foreign = ((await fixture.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Other depot', legalLabel: null),
    )) as Committed<Employment>).value;
    await shell.go(
      WorkLocation.leave(
        foreign.id,
        month: const LocalDate(2026, 10, 1),
        leave: original.id,
      ),
    );
    expect(shell.location.leave, isNull);
    expect(shell.leaveSheet!.loaded, isTrue);
    expect(shell.leaveSheet!.rows, isEmpty);
    await shell.back();
    expect(shell.location.leave, original.id);
    await shell.forward();
    expect(shell.location.employmentId, foreign.id);
    await shell.back();
    // Moving to another month drops a selection outside it.
    await shell.goScope(
      const LocalDate(2026, 11, 1),
      const LocalDate(2026, 11, 30),
    );
    expect(shell.location.month, const LocalDate(2026, 11, 1));
    expect(shell.location.leave, isNull);
    await shell.back();
    shell.selectSub('working');
    await shell.remember();
    expect(
      WorkLocation.parse(
        Uri.parse((await store.read())!),
        today: ShiftsSheetFixture.today,
      ).sub,
      'working',
    );
  });

  test('successful correction selects its replacement and resets a hiding filter once', () async {
    final fixture = await ShiftsSheetFixture.create();
    addTearDown(fixture.dispose);
    final plans = fixture.work.plans;
    await plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final original =
        ((await plans.confirm(
                  fixtureEmployment,
                  const LocalDate(2026, 10, 6),
                ) as Committed<ConfirmedDay>).value
                as ConfirmedLeave)
            .leave;
    final shell = WorkShellController(
      work: fixture.work,
      reads: fixture.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(
        '${WorkLocation.leave(fixtureEmployment, month: const LocalDate(2026, 10, 1), leave: original.id).toUri()}',
      ),
    );
    addTearDown(shell.dispose);
    await shell.start();
    shell.setFilter(
      const ShiftsFilter(
        status: ShiftsStatusFilter.effective,
        type: 'Vacation',
      ),
    );
    final sheet = shell.leaveSheet!;
    await sheet.openCorrect();
    sheet.action!
      ..set('type', LeaveType.sick)
      ..set('reason', 'Was ill');
    await sheet.submitAction();
    expect(sheet.selectedRow!.record.leaveType, LeaveType.sick);
    expect(shell.location.leave, sheet.selectedId);
    expect(
      shell.location.filter,
      const ShiftsFilter(status: ShiftsStatusFilter.effective),
    );
    shell.setFilter(const ShiftsFilter(status: ShiftsStatusFilter.voided));
    await sheet.reload();
    expect(shell.location.filter.status, ShiftsStatusFilter.voided);
    await shell.go(shell.location.withLeave(original.id));
    expect(shell.leaveSheet!.selectedRow!.record.isEffective, isFalse);
  });
}
