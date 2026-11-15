import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/app/work_shell/work_tree.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/day_exception.dart' show LeaveType;
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

const _october = LocalDate(2026, 10, 1);
const _tuesday = LocalDate(2026, 10, 6);

/// Calendar and To confirm in the shell (plan 4d-2, Task 3).
void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
  });

  tearDown(() => fixture.dispose());

  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<WorkShellController> open({String? remembered}) async {
    final shell = WorkShellController(
      work: fixture.work,
      reads: fixture.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(remembered),
    );
    addTearDown(shell.dispose);
    await shell.start();
    return shell;
  }

  Future<ShiftsSheetController> sheet() async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: _october,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      kind: WorkSheetKind.calendar,
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  test("rowIdOn picks a date's row", () async {
    final finished = await fixture.finishShift(9);
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 13),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await fixture.work.plans.confirm(
      fixtureEmployment,
      const LocalDate(2026, 10, 13),
    );
    final calendar = await sheet();
    await until(() => calendar.rows.any((row) => row is LeaveTakenRow));
    expect(calendar.rowIdOn(_tuesday), plannedRowId(_tuesday));
    expect(
      calendar.rowIdOn(const LocalDate(2026, 10, 9)),
      storedRowId(finished),
    );
    expect(
      calendar.rowIdOn(const LocalDate(2026, 10, 13)),
      startsWith('leave:'),
    );
    expect(calendar.rowIdOn(const LocalDate(2026, 10, 8)), 'off:2026-10-08');
    expect(calendar.rowIdOn(const LocalDate(2026, 11, 2)), isNull);
    // A void shift gives way to its replacement on the same date.
    final corrected = await fixture.work.shifts.correctShift(
      CorrectShiftCommand(
        originalId: finished.id,
        replacementId: fixture.schedule.ids.shiftId(),
        expectedRevision: finished.revision,
        voidReason: 'Wrong end',
      ),
    );
    final replacement = (corrected as Committed<WorkShift>).value;
    await until(
      () => calendar.rows.any(
        (row) => row is StoredRow && row.shift.id == replacement.id,
      ),
    );
    expect(
      calendar.rowIdOn(const LocalDate(2026, 10, 9)),
      storedRowId(replacement),
    );
    expect(calendar.shiftTypeNames, ['Day', 'Night']);
  });

  test(
    'the first start opens Calendar when a schedule is in use today',
    () async {
      final shell = await open();
      expect(
        shell.location,
        const WorkLocation.calendar(fixtureEmployment, month: _october),
      );
      expect(shell.sheet?.kind, WorkSheetKind.calendar);
    },
  );

  test('…otherwise Shifts', () async {
    final depot = (await fixture.schedule.repository.schedulesFor(
      fixtureEmployment,
    )).single;
    final ended = await fixture.work.schedules.update(
      depot.id,
      expected: depot.revision,
      draft: depotDraft(until: const LocalDate(2026, 10, 10)),
    );
    expect(ended, isA<Committed<WorkSchedule>>());
    final shell = await open();
    expect(
      shell.location,
      const WorkLocation.shifts(fixtureEmployment, month: _october),
    );
  });

  test('a remembered Licences page starts by the rule', () async {
    final shell = await open(
      remembered: '${const WorkLocation.licences().toUri()}',
    );
    expect(shell.location.sheet, WorkSheetKind.calendar);
  });

  test('a Calendar day selects its row and the route follows', () async {
    final shell = await open();
    expect(
      await shell.go(
        const WorkLocation.calendar(
          fixtureEmployment,
          month: _october,
          day: _tuesday,
        ),
      ),
      isTrue,
    );
    expect(shell.sheet!.selectedId, plannedRowId(_tuesday));
    expect(await shell.sheet!.select('off:2026-10-08'), isTrue);
    expect(shell.location.day, const LocalDate(2026, 10, 8));
    expect(shell.location.sheet, WorkSheetKind.calendar);
    // A remembered day that is confirmed now selects its stored shift.
    await fixture.work.plans.confirm(fixtureEmployment, _tuesday);
    final again = await open(
      remembered:
          '${const WorkLocation.calendar(fixtureEmployment, month: _october, day: _tuesday).toUri()}',
    );
    await until(() => again.sheet?.selectedRow is StoredRow);
    expect(again.location.day, _tuesday);
  });

  test('To confirm over all past days', () async {
    final shell = await open();
    expect(
      await shell.go(const WorkLocation.toConfirm(fixtureEmployment)),
      isTrue,
    );
    final sheet = shell.sheet!;
    expect(sheet.kind, WorkSheetKind.toConfirm);
    expect(sheet.from, const LocalDate(2026, 10, 5));
    expect(sheet.to, const LocalDate(2026, 10, 19));
    expect(sheet.addBlocked, ShiftsCommandWords.addElsewhere);
    expect(shell.location.allPastDays, isTrue);
  });

  test('To confirm with no schedule is yesterday alone', () async {
    final empty = await EmptyWorkFixture.create();
    addTearDown(empty.dispose);
    final created = await empty.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic site', legalLabel: null),
    );
    final site = (created as Committed<Employment>).value;
    final shell = WorkShellController(
      work: empty.work,
      reads: empty.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(),
    );
    addTearDown(shell.dispose);
    await shell.start();
    expect(shell.location.sheet, WorkSheetKind.shifts, reason: 'no schedule');
    expect(await shell.go(WorkLocation.toConfirm(site.id)), isTrue);
    expect(shell.sheet!.from, const LocalDate(2026, 10, 19));
    expect(shell.sheet!.to, const LocalDate(2026, 10, 19));
    expect(shell.sheet!.rows.whereType<PlannedRow>(), isEmpty);
  });

  test('Calendar and To confirm step by month', () async {
    final shell = await open();
    expect(await shell.stepScope(1), isTrue);
    expect(
      shell.location,
      const WorkLocation.calendar(
        fixtureEmployment,
        month: LocalDate(2026, 11, 1),
      ),
    );
    expect(
      await shell.go(
        const WorkLocation.toConfirm(
          fixtureEmployment,
          from: LocalDate(2026, 9, 1),
          to: LocalDate(2026, 9, 30),
        ),
      ),
      isTrue,
    );
    expect(await shell.stepScope(1), isTrue);
    expect(shell.location.from, _october);
    expect(shell.location.sheet, WorkSheetKind.toConfirm);
    expect(await shell.stepScope(1), isFalse, reason: 'after this month');
    expect(await shell.goAllPastDays(), isTrue);
    expect(shell.location.allPastDays, isTrue);
    expect(await shell.stepScope(-1), isFalse);
  });

  test('the tree shows Calendar and To confirm live', () async {
    final shell = await open();
    final employment = workTreeNodes(
      employments: shell.employments,
      pastDays: shell.pastDays,
      place: shell.location,
    ).single.children.single;
    final ids = employment.children.map((node) => node.id).toList();
    final id = fixtureEmployment.value;
    expect(ids, contains('calendar:$id'));
    expect(ids, contains('toConfirm:$id'));
    expect(ids, contains('leave:$id'));
    expect(
      employment.children.firstWhere((node) => node.id == 'calendar:$id').muted,
      isFalse,
    );
  });
}
