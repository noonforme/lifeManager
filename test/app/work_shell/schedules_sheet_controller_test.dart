import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart'
    show EmploymentsWords;
import 'package:lifeos/app/work_shell/schedule_commands.dart';
import 'package:lifeos/app/work_shell/schedules_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_history.dart'
    show scheduleRecordId;
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

/// Waits until [condition] holds, letting the database's streams run.
Future<void> until(bool Function() condition) async {
  for (var turn = 0; turn < 200 && !condition(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'condition never held');
}

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedConfirm confirm;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    confirm = ScriptedConfirm();
  });

  tearDown(() => fixture.dispose());

  Future<SchedulesSheetController> open({
    ProductionWorkProviders? work,
    WorkReads? reads,
    EmploymentId employment = fixtureEmployment,
    bool archived = false,
  }) async {
    final sheet = SchedulesSheetController(
      work: work ?? fixture.work,
      reads: reads ?? fixture.reads,
      employmentId: employment,
      today: ShiftsSheetFixture.today,
      confirm: confirm.call,
      coordinator: LeaveCoordinator(confirm: confirm.call),
      archived: archived,
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    return sheet;
  }

  Future<WorkSchedule> depot() async =>
      (await fixture.schedule.repository.schedulesFor(fixtureEmployment))
          .single;

  test('the sheet lists versions and selects one', () async {
    final sheet = await open();
    final stored = await depot();
    expect(sheet.rows.single.rowId, scheduleRecordId(stored));
    expect(sheet.selectedId, isNull);
    expect(await sheet.select(scheduleRecordId(stored)), isTrue);
    expect(sheet.selectedId, scheduleRecordId(stored));
    expect(sheet.session!.baseline!.value.id, stored.id);
    expect(
      sheet.place,
      WorkLocation.schedules(
        fixtureEmployment,
        schedule: stored.id,
        version: 1,
      ),
    );
  });

  test('an unused schedule is edited and saved', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    expect(sheet.editBlock(0, ScheduleField.blockDays, '4'), isNull);
    expect(sheet.session!.dirty, isTrue);
    expect(await sheet.save(), SaveResult.committed);
    await until(() => sheet.rows.single.schedule.cycleLength == 13);
    expect(sheet.selectedId, scheduleRecordId(await depot()));
  });

  test('a used version refuses edits with the reason', () async {
    final stored = await depot();
    await fixture.schedule.markUsed(stored);
    final sheet = await open();
    await until(() => sheet.rows.single.used);
    await sheet.select(sheet.rows.single.rowId);
    final before = sheet.session!.draft;
    expect(sheet.editBlocked, SchedulesCommandWords.used);
    expect(
      sheet.editBlock(0, ScheduleField.blockDays, '4'),
      SchedulesCommandWords.used,
    );
    expect(sheet.moveBlock('block:2', 1), SchedulesCommandWords.used);
    expect(sheet.addType(), SchedulesCommandWords.used);
    expect(
      sheet.editBreak(
        const ShiftTypeId('day'),
        0,
        ScheduleField.breakStart,
        const LocalTime(12, 15),
      ),
      SchedulesCommandWords.used,
    );
    expect(
      sheet.editField(ScheduleField.name, 'Other'),
      SchedulesCommandWords.used,
    );
    expect(sheet.session!.draft, before);
  });

  test('a new schedule starts empty with today', () async {
    final empty = await EmptyWorkFixture.create();
    addTearDown(empty.dispose);
    final created = await empty.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic site', legalLabel: null),
    );
    final site = (created as Committed<Employment>).value;
    final sheet = await open(
      work: empty.work,
      reads: empty.reads,
      employment: site.id,
    );
    expect(sheet.rows, isEmpty);
    expect(await sheet.addSchedule(), isTrue);
    expect(sheet.selectedId, newScheduleId);
    final draft = sheet.session!.draft;
    expect(draft.timezoneId, ShiftsSheetFixture.zone);
    expect(draft.inUseFrom, ShiftsSheetFixture.today);
    expect(draft.cycleStart, ShiftsSheetFixture.today);
    expect(draft.types, isEmpty);
    expect(draft.blocks, isEmpty);
    expect(sheet.notice, isNull);
  });

  test('moving a block by row id', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    expect(sheet.moveBlock('block:2', 1), isNull);
    expect(
      [for (final b in sheet.session!.draft.blocks) b.shiftTypeId],
      [const ShiftTypeId('day'), const ShiftTypeId('night'), null, null],
    );
  });

  test('the selected block follows a drag', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    sheet.selectBlock('block:2');
    sheet.moveBlock('block:2', 0);
    expect(sheet.selectedBlock, 'block:0');
    sheet.selectBlock('block:0');
    sheet.moveBlock('block:3', 0);
    expect(sheet.selectedBlock, 'block:1');
    sheet.moveBlock('block:1', 3);
    expect(sheet.selectedBlock, 'block:3');
  });

  test('a plan that cannot be read says so', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    gate.failing = true;
    final sheet = await open(work: over.work, reads: over.reads);
    await until(() => sheet.planFailed);
    expect(sheet.planInputs, isNull);
  });

  test('Delete asks and removes an unused schedule', () async {
    final stored = await depot();
    final sheet = await open();
    await sheet.select(scheduleRecordId(stored));
    expect(sheet.deleteBlocked, isNull);
    confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    final asking = await open();
    await asking.select(scheduleRecordId(stored));
    await asking.delete();
    expect(confirm.asked.single.message, deleteScheduleRequest(stored).message);
    await until(() => asking.rows.isEmpty);
    expect(asking.selectedId, isNull);
    expect(asking.notice, SchedulesNotices.deleted);
  });

  test('Delete is greyed for a used schedule', () async {
    await fixture.schedule.markUsed(await depot());
    final sheet = await open();
    await until(() => sheet.rows.single.used);
    await sheet.select(sheet.rows.single.rowId);
    expect(sheet.deleteBlocked, SchedulesCommandWords.deleteUsed);
  });

  test('an invalid pending edit keeps Delete from running', () async {
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    expect(
      sheet.editBreak(
        const ShiftTypeId('day'),
        0,
        ScheduleField.breakStart,
        const LocalTime(18, 50),
      ),
      isNull,
    );
    await sheet.delete();
    expect(confirm.asked, isEmpty);
    expect(sheet.rows, hasLength(1));
    expect(sheet.session!.dirty, isTrue);
    expect(sheet.session!.problem, EditProblems.invalid);
  });

  test('a valid pending edit is saved before Delete asks', () async {
    confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
    final sheet = await open();
    await sheet.select(scheduleRecordId(await depot()));
    expect(sheet.editBlock(0, ScheduleField.blockDays, '4'), isNull);
    await sheet.delete();
    expect(confirm.asked.single.title, 'Delete schedule');
    await until(() => sheet.rows.single.schedule.cycleLength == 13);
    expect(sheet.rows, hasLength(1));
  });

  test('an archived employment\'s schedule is read-only', () async {
    final sheet = await open(archived: true);
    await sheet.select(scheduleRecordId(await depot()));
    expect(sheet.editBlocked, EmploymentsWords.archivedReadOnly);
    expect(sheet.deleteBlocked, EmploymentsWords.archivedReadOnly);
    expect(
      sheet.editBlock(0, ScheduleField.blockDays, '4'),
      EmploymentsWords.archivedReadOnly,
    );
  });

  test('unreadable storage keeps the last rows and says so', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final sheet = await open(work: over.work, reads: over.reads);
    expect(sheet.rows, hasLength(1));
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    gate.failing = true;
    final database = over.schedule.database;
    await database.customUpdate(
      'UPDATE work_schedules SET revision = revision',
      updates: {database.workSchedules},
    );
    await until(() => sheet.failed);
    expect(sheet.rows, hasLength(1));
    // The rows and the Preview's plan inputs both report it.
    expect(errors, isNotEmpty);
    expect(
      errors.map((error) => error.library),
      everyElement('schedules sheet'),
    );
  });

  group('Change schedule from…', () {
    Future<SchedulesSheetController> used() async {
      await fixture.schedule.markUsed(await depot());
      final sheet = await open();
      await until(() => sheet.rows.single.used);
      await sheet.select(sheet.rows.single.rowId);
      return sheet;
    }

    test('makes version 2', () async {
      final sheet = await used();
      expect(sheet.changeBlocked, isNull);
      expect(await sheet.changeFrom(), isTrue);
      expect(sheet.versioning, isTrue);
      expect(sheet.editBlocked, isNull);
      // The latest of today, the day after the start and the day after the
      // last confirmed day.
      expect(sheet.session!.draft.versionFrom, ShiftsSheetFixture.today);
      expect(sheet.displayRows, hasLength(2));
      expect(
        sheet.displayRows.first.schedule.inUseUntil,
        const LocalDate(2026, 10, 19),
      );
      expect(sheet.editBlock(0, ScheduleField.blockDays, '4'), isNull);
      expect(
        sheet.editField(
          ScheduleField.versionFrom,
          const LocalDate(2026, 10, 19),
        ),
        isNull,
      );
      expect(await sheet.save(), SaveResult.committed);
      await until(() => sheet.rows.length == 2);
      expect(
        sheet.rows.first.schedule.inUseUntil,
        const LocalDate(2026, 10, 18),
      );
      expect(sheet.rows.last.schedule.inUseFrom, const LocalDate(2026, 10, 19));
      expect(sheet.rows.last.schedule.blocks.first.count, 4);
      expect(sheet.versioning, isFalse);
      expect(sheet.selectedId, sheet.rows.last.rowId);
      expect(sheet.notice, 'Schedule changed: version 2 starts on 2026-10-19.');
    });

    test('From on the last confirmed day says so', () async {
      final sheet = await used();
      await sheet.changeFrom();
      expect(
        sheet.editField(
          ScheduleField.versionFrom,
          const LocalDate(2026, 10, 5),
        ),
        ScheduleProblems.confirmedUpTo(const LocalDate(2026, 10, 5)),
      );
      expect(sheet.session!.draft.versionFrom, ShiftsSheetFixture.today);
      expect(sheet.rows, hasLength(1));
      expect(sheet.versioning, isTrue);
    });

    test('Cancel with input asks, then shows the stored version', () async {
      confirm = ScriptedConfirm([ConfirmAnswer.cancel, ConfirmAnswer.revert]);
      final sheet = await used();
      await sheet.changeFrom();
      sheet.editBlock(0, ScheduleField.blockDays, '4');
      await sheet.cancelChange();
      expect(sheet.versioning, isTrue, reason: 'Keep editing');
      await sheet.cancelChange();
      expect(sheet.versioning, isFalse);
      expect(sheet.editBlocked, SchedulesCommandWords.used);
      expect(sheet.session!.draft.blocks.first.count, 3);
    });

    test('leaving with input asks to discard, never saves', () async {
      confirm = ScriptedConfirm([ConfirmAnswer.cancel, ConfirmAnswer.revert]);
      final sheet = await used();
      await sheet.changeFrom();
      sheet.editBlock(0, ScheduleField.blockDays, '4');
      expect(await sheet.coordinator.navigate(() {}), isFalse);
      expect(confirm.asked.single.revert, 'Discard');
      expect(await sheet.coordinator.navigate(() {}), isTrue);
      expect(await fixture.reads.scheduleRows(fixtureEmployment), hasLength(1));
    });

    test(
      'an unknown result found by Reload and check closes the panel',
      () async {
        await fixture.schedule.markUsed(await depot());
        final losing = LosingSchedules(fixture.schedule.repository);
        final sheet = await open(
          work: fixture.work.replacing(
            schedules: ScheduleService(
              repository: losing,
              ids: fixture.schedule.ids,
              clock: fixture.schedule.clock,
            ),
          ),
        );
        await until(() => sheet.rows.single.used);
        await sheet.select(sheet.rows.single.rowId);
        await sheet.changeFrom();
        sheet.editField(
          ScheduleField.versionFrom,
          const LocalDate(2026, 10, 25),
        );
        await sheet.save();
        expect(sheet.session!.phase, EditPhase.uncertain);
        await sheet.reload();
        expect(sheet.versioning, isFalse);
        expect(sheet.session!.baseline!.value.version, 2);
        expect(
          sheet.notice,
          'Schedule changed: version 2 starts on 2026-10-25.',
        );
      },
    );

    test('is greyed for an unused version', () async {
      final sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
      expect(sheet.changeBlocked, SchedulesCommandWords.notUsed);
      expect(await sheet.changeFrom(), isFalse);
    });
  });

  group('the shift types view', () {
    test('edits the same pending schedule', () async {
      final sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
      sheet.showTypes(true);
      expect(sheet.showingTypes, isTrue);
      expect(sheet.selectedType, const ShiftTypeId('day'));
      expect(
        sheet.editType(
          const ShiftTypeId('day'),
          ScheduleField.typeEnd,
          const LocalTime(19, 30),
        ),
        isNull,
      );
      sheet.showTypes(false);
      expect(sheet.selectedType, isNull);
      expect(sheet.session!.dirty, isTrue);
      expect(await sheet.save(), SaveResult.committed);
      await until(
        () =>
            sheet.rows.single.schedule.shiftTypes.first.end ==
            const LocalTime(19, 30),
      );
    });

    test('a new type is selected', () async {
      final sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
      sheet.showTypes(true);
      expect(sheet.addType(), isNull);
      expect(sheet.selectedType, sheet.session!.draft.types.last.id);
    });

    test('removing a type the cycle uses is refused', () async {
      final sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
      sheet.showTypes(true);
      expect(
        sheet.removeType(const ShiftTypeId('day')),
        ScheduleProblems.typeInCycle,
      );
      expect(sheet.session!.draft.types, hasLength(2));
    });

    test(
      'a break moved past its end is refused until the end follows',
      () async {
        final sheet = await open();
        await sheet.select(scheduleRecordId(await depot()));
        sheet.showTypes(true);
        const night = ShiftTypeId('night');
        // The depot's night break is 00:00–00:30.
        expect(
          sheet.editBreak(
            night,
            0,
            ScheduleField.breakStart,
            const LocalTime(1, 0),
          ),
          isNull,
        );
        expect(
          sheet.session!.issues[typeKey(night, 'breaks')],
          ScheduleProblems.breaks,
        );
        expect(
          sheet.editBreak(
            night,
            0,
            ScheduleField.breakEnd,
            const LocalTime(1, 30),
          ),
          isNull,
        );
        expect(
          sheet.session!.issues,
          isNot(contains(typeKey(night, 'breaks'))),
        );
      },
    );

    test('another schedule leaves the types view', () async {
      final sheet = await open();
      await sheet.select(scheduleRecordId(await depot()));
      sheet.showTypes(true);
      await sheet.show(null);
      expect(sheet.showingTypes, isFalse);
    });
  });
}
