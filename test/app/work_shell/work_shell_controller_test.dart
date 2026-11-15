import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart'
    show EditPhase;
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/failing_work.dart' show PlanReadGate;
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

const _october = LocalDate(2026, 10, 1);
const _september = LocalDate(2026, 9, 1);
const _november = LocalDate(2026, 11, 1);
const _goneShift = ShiftId('0190f5d2-6a00-7000-8000-00000000beef');
const _gone = EmploymentId('0190f5d2-6a00-7000-8000-00000000dead');

/// A place store whose read answers only when the test lets it.
final class _GatedStore implements LocationStore {
  _GatedStore(this._route);

  final Future<String?> _route;

  @override
  Future<String?> read() => _route;

  @override
  Future<void> write(String route) async {}
}

void main() {
  test('with no employment the first start is the Work overview', () async {
    final empty = await EmptyWorkFixture.create();
    addTearDown(empty.dispose);
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
    expect(shell.location, const WorkLocation.overview());
    expect(shell.sheet, isNull);
  });

  test('unreadable storage leaves the overview, says so and remembers '
      'nothing', () async {
    final closed = await EmptyWorkFixture.create(
      executor: NativeDatabase.memory().interceptWith(ReadGate(failing: true)),
    );
    addTearDown(closed.dispose);
    final writes = <String>[];
    final shell = WorkShellController(
      work: closed.work,
      reads: closed.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: _WriteLog(writes),
    );
    addTearDown(shell.dispose);
    await shell.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(shell.location, const WorkLocation.overview());
    expect(shell.notice, WorkShellNotices.unreadable);
    expect(shell.employmentsFailed, isTrue);
    await shell.remember();
    expect(writes, isEmpty);
    // Nor after a look at the Licences page.
    expect(await shell.openLicences(), isTrue);
    await shell.remember();
    expect(writes, isEmpty);
  });

  group('FileLocationStore', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('location_store'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a missing file reads null', () async {
      expect(await FileLocationStore(File('${dir.path}/none')).read(), isNull);
    });

    test('a file of invalid UTF-8 reads null', () async {
      final file = File('${dir.path}/bad')
        ..writeAsBytesSync([0xff, 0xfe, 0xc3]);
      expect(await FileLocationStore(file).read(), isNull);
    });

    test('the place file sits beside the database', () {
      final database = File('${dir.path}/lifeos.sqlite');
      expect(
        FileLocationStore.beside(database).file.path,
        '${dir.path}/${FileLocationStore.placeFilename}',
      );
      expect(FileLocationStore.placeFilename, 'last-location.txt');
    });

    test('a written route reads back', () async {
      final store = FileLocationStore(File('${dir.path}/ok'));
      await store.write('/work?x=1');
      expect(await store.read(), '/work?x=1');
    });
  });

  group('with the depot', _depot);
}

void _depot() {
  late ShiftsSheetFixture fixture;

  setUp(() async => fixture = await ShiftsSheetFixture.create());
  tearDown(() => fixture.dispose());

  /// Waits until [condition] holds, letting the database's streams run.
  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  /// The shell over the depot, on [remembered], else on October's Shifts;
  /// with [firstStart], on nothing remembered at all.
  Future<WorkShellController> open({
    String? remembered,
    ScriptedConfirm? confirm,
    LocationStore? store,
    bool firstStart = false,
    Uri? link,
  }) async {
    final answers = confirm ?? ScriptedConfirm();
    final shell = WorkShellController(
      work: fixture.work,
      reads: fixture.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (request) => answers.call(request),
      store:
          store ??
          MemoryLocationStore(
            remembered ??
                (firstStart
                    ? null
                    : '${const WorkLocation.shifts(fixtureEmployment, month: _october).toUri()}'),
          ),
      link: link,
    );
    addTearDown(shell.dispose);
    await shell.start();
    return shell;
  }

  WorkLocation shifts({LocalDate month = _october, ShiftId? shift}) =>
      WorkLocation.shifts(fixtureEmployment, month: month, shift: shift);

  test('Details or days that cannot be read say so', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final shell = WorkShellController(
      work: over.work,
      reads: over.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(),
    );
    addTearDown(shell.dispose);
    await shell.start();
    await until(() => shell.details != null);
    expect(shell.notice, isNull);
    gate.failing = true;
    // Only the plans read cycle blocks; the employments feed does not.
    final database = over.schedule.database;
    await database.customUpdate(
      'UPDATE work_schedule_blocks SET position = position',
      updates: {database.workScheduleBlocks},
    );
    await until(() => shell.notice == WorkShellNotices.unreadable);
    expect(shell.employmentsFailed, isFalse);
  });

  test('the unreadable notice goes when the employments read again', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final shell = WorkShellController(
      work: over.work,
      reads: over.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(),
    );
    addTearDown(shell.dispose);
    await shell.start();
    await until(() => shell.details != null);
    final database = over.schedule.database;
    gate.failing = true;
    await database.customUpdate(
      'UPDATE employments SET name = name',
      updates: {database.employments},
    );
    await until(() => shell.employmentsFailed);
    expect(shell.notice, WorkShellNotices.unreadable);
    gate.failing = false;
    await database.customUpdate(
      'UPDATE employments SET name = name',
      updates: {database.employments},
    );
    await until(() => !shell.employmentsFailed);
    expect(shell.notice, isNull);
  });

  test('remembering on Licences writes the place before it', () async {
    final writes = <String>[];
    final shell = await open(store: _WriteLog(writes));
    final before = shell.location;
    expect(await shell.go(const WorkLocation.licences()), isTrue);
    await shell.remember();
    expect(writes, ['${before.toUri()}']);
  });

  test(
    'past planned days to confirm are counted per active employment',
    () async {
      final shell = await open();
      await until(() => shell.pastDays.containsKey(fixtureEmployment));
      expect(shell.pastDays[fixtureEmployment], (
        toConfirm: 9,
        withoutAgreement: 0,
      ));
      expect(shell.daysToConfirm, 9);
      await fixture.work.plans.confirm(
        fixtureEmployment,
        const LocalDate(2026, 10, 5),
      );
      await until(() => shell.daysToConfirm == 8);
    },
  );

  test('days before any agreement are not to confirm', () async {
    final database = fixture.schedule.database;
    await database.customUpdate(
      "UPDATE pay_agreements SET effective_start = '2026-10-12'",
      updates: {database.payAgreements},
    );
    final shell = await open();
    await until(() => shell.pastDays.containsKey(fixtureEmployment));
    // The 5th, 6th, 7th and the 11th's night have no agreement.
    expect(shell.pastDays[fixtureEmployment], (
      toConfirm: 5,
      withoutAgreement: 4,
    ));
    expect(shell.daysToConfirm, 5);
  });

  test("an archived employment's days are not in the total", () async {
    final shell = await open();
    await until(() => shell.daysToConfirm == 9);
    final employment = (await fixture.reads.employment(fixtureEmployment))!
        .value;
    await fixture.work.employment.archiveEmployment(
      ArchiveEmploymentCommand(
        employmentId: fixtureEmployment,
        expectedRevision: employment.revision,
      ),
    );
    await until(() => !shell.pastDays.containsKey(fixtureEmployment));
    expect(shell.daysToConfirm, 0);
  });

  test(
    'a link opens instead of the remembered place, and is remembered',
    () async {
      final store = MemoryLocationStore('${shifts().toUri()}');
      final shell = await open(
        store: store,
        link: const WorkLocation.agreements(fixtureEmployment).toUri(),
      );
      expect(shell.location, const WorkLocation.agreements(fixtureEmployment));
      await shell.remember();
      expect(
        store.route,
        '${const WorkLocation.agreements(fixtureEmployment).toUri()}',
      );
      await until(() => shell.details != null);
    },
  );

  test('a link with obsolete mode= and add= keeps its target', () async {
    final stored = await fixture.finishShift(20);
    final shell = await open(
      link: Uri.parse(
        '/work?employment=${fixtureEmployment.value}'
        '&record=shift:${stored.id.value}&mode=edit&add=agreement',
      ),
    );
    expect(shell.location, shifts(shift: stored.id));
    expect(shell.sheet?.selectedId, storedRowId(stored));
  });

  test('a link to an employment that is gone falls back and says so', () async {
    final shell = await open(
      link: WorkLocation.shifts(_gone, month: _october).toUri(),
    );
    expect(shell.location, const WorkLocation.overview());
    expect(shell.notice, WorkShellNotices.employmentGone);
  });

  test('the first start opens the first active employment this month, on '
      'Calendar while its schedule is in use (addendum decision 2)', () async {
    final shell = await open(firstStart: true);
    expect(
      shell.location,
      const WorkLocation.calendar(fixtureEmployment, month: _october),
    );
    expect(shell.sheet?.month, _october);
    expect(shell.canBack, isFalse);
  });

  test('a first start whose schedules cannot be read opens Shifts this '
      'month', () async {
    final plans = fixture.work.plans;
    final shell = WorkShellController(
      work: fixture.work.replacing(
        plans: DayPlanService(
          repository: PlanReadGate(plans.repository),
          shifts: plans.shifts,
          ids: plans.ids,
          clock: plans.clock,
          zoneClocks: plans.zoneClocks,
        ),
      ),
      reads: fixture.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(),
    );
    addTearDown(shell.dispose);
    await shell.start();
    expect(shell.location, shifts());
    expect(shell.notice, isNull);
  });

  test('a remembered shift in another month opens in its own month', () async {
    final stored = await fixture.finishShift(20);
    final shell = await open(
      remembered: '${shifts(month: _september, shift: stored.id).toUri()}',
    );
    expect(shell.location, shifts(shift: stored.id));
    expect(shell.sheet?.selectedId, storedRowId(stored));
    expect(shell.notice, isNull);
  });

  test(
    'a remembered employment that is gone falls back to the overview',
    () async {
      final shell = await open(
        remembered: '${WorkLocation.shifts(_gone, month: _october).toUri()}',
      );
      expect(shell.location, const WorkLocation.overview());
      expect(shell.notice, WorkShellNotices.employmentGone);
    },
  );

  test('employment and agreement updates refresh shell summaries', () async {
    final shell = await open();
    final current = (await fixture.reads.employment(fixtureEmployment))!.value;
    await fixture.work.employment.updateEmployment(
      UpdateEmploymentCommand(
        employmentId: current.id,
        expectedRevision: current.revision,
        name: 'Synthetic renamed depot',
        legalLabel: current.legalLabel,
      ),
    );
    await until(
      () =>
          shell.employments.single.employment.name == 'Synthetic renamed depot',
    );
    final agreement = (await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!.value;
    await fixture.work.agreement.changeAgreementTerms(
      ChangeAgreementTermsCommand(
        agreementId: agreement.id,
        expectedRevision: agreement.revision,
        from: const LocalDate(2026, 11, 1),
        terms: AgreementTerms.of(agreement),
        employmentId: fixtureEmployment,
      ),
    );
    await until(() => shell.employments.single.agreements == 2);
  });

  test('a remembered agreement that is gone shows the Agreements sheet', () async {
    final shell = await open(
      remembered:
          '${const WorkLocation.agreements(fixtureEmployment, agreement: AgreementId('0190f5d2-6a00-7000-8000-00000000beef')).toUri()}',
    );
    expect(shell.location, const WorkLocation.agreements(fixtureEmployment));
    expect(shell.notice, WorkShellNotices.agreementGone);
    // The Details read settles before the database closes.
    await until(() => shell.details != null);
  });

  test('the Schedules sheet follows its employment being archived', () async {
    final shell = await open(
      remembered: '${const WorkLocation.schedules(fixtureEmployment).toUri()}',
    );
    final sheet = shell.schedulesSheet!;
    expect(sheet.archived, isFalse);
    final employment = (await fixture.reads.employment(fixtureEmployment))!
        .value;
    await fixture.work.employment.archiveEmployment(
      ArchiveEmploymentCommand(
        employmentId: fixtureEmployment,
        expectedRevision: employment.revision,
      ),
    );
    await until(() => sheet.archived);
    expect(sheet.deleteBlocked, isNotNull);
    await until(() => shell.details != null);
  });

  test('a remembered schedule that is gone shows the Schedules sheet', () async {
    final shell = await open(
      remembered:
          '${const WorkLocation.schedules(fixtureEmployment, schedule: ScheduleId('0190f5d2-6a00-7000-8000-00000000beef')).toUri()}',
    );
    expect(shell.location, const WorkLocation.schedules(fixtureEmployment));
    expect(shell.notice, WorkShellNotices.scheduleGone);
    await until(() => shell.details != null);
  });

  test('a remembered shift that is gone opens its month with none selected', () async {
    final shell = await open(
      remembered:
          '${shifts(shift: const ShiftId('0190f5d2-6a00-7000-8000-00000000beef')).toUri()}',
    );
    expect(shell.location, shifts());
    expect(shell.sheet?.selectedId, isNull);
    expect(shell.notice, WorkShellNotices.recordGone);
  });

  test('a remembered day the schedule does not plan selects none', () async {
    // The 8th is an Off day of the depot's rotation.
    final shell = await open(
      remembered:
          '${shifts().withRow(plannedRowId(const LocalDate(2026, 10, 8))).toUri()}',
    );
    expect(shell.location, shifts());
    expect(shell.sheet!.selectedId, isNull);
    expect(shell.notice, isNull);
  });

  Set<LocalDate> plannedDates(WorkShellController shell) => {
    for (final row in shell.sheet!.rows)
      if (row is PlannedRow) row.date,
  };

  test('a range lists the rows of every day in it', () async {
    final stored = await fixture.finishShift(21);
    final shell = await open();
    expect(
      await shell.goScope(
        const LocalDate(2026, 10, 20),
        const LocalDate(2026, 11, 10),
      ),
      isTrue,
    );
    await until(() => shell.sheet!.loaded);
    expect(plannedDates(shell), {
      for (final day in [23, 24, 25, 29, 30, 31]) LocalDate(2026, 10, day),
      for (final day in [4, 5, 6, 10]) LocalDate(2026, 11, day),
    });
    expect(
      shell.sheet!.rows.whereType<StoredRow>().map((row) => row.shift.id),
      [stored.id],
    );
  });

  test('the period steps by a month, a pay period or its own length', () async {
    final shell = await open();
    expect(await shell.stepScope(1), isTrue);
    expect(
      (shell.location.from, shell.location.to),
      (const LocalDate(2026, 11, 1), const LocalDate(2026, 11, 30)),
    );
    for (final (start, end) in [
      (const LocalDate(2026, 10, 16), const LocalDate(2026, 11, 15)),
      (const LocalDate(2026, 11, 16), const LocalDate(2026, 12, 15)),
    ]) {
      await fixture.work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: fixtureEmployment,
          start: start,
          end: end,
          label: null,
        ),
      );
    }
    await shell.goScope(
      const LocalDate(2026, 10, 16),
      const LocalDate(2026, 11, 15),
    );
    await until(() => (shell.details?.periods.length ?? 0) == 2);
    expect(await shell.stepScope(-1), isFalse, reason: 'the first period');
    expect(await shell.stepScope(1), isTrue);
    expect(
      (shell.location.from, shell.location.to),
      (const LocalDate(2026, 11, 16), const LocalDate(2026, 12, 15)),
    );
    await shell.goScope(
      const LocalDate(2026, 10, 20),
      const LocalDate(2026, 11, 10),
    );
    expect(await shell.stepScope(1), isTrue);
    expect(
      (shell.location.from, shell.location.to),
      (const LocalDate(2026, 11, 11), const LocalDate(2026, 12, 2)),
    );
  });

  test('the pay periods stay while the next Details load', () async {
    final hold = ReadHold();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(hold),
    );
    addTearDown(over.dispose);
    for (final (start, end) in [
      (const LocalDate(2026, 10, 16), const LocalDate(2026, 11, 15)),
      (const LocalDate(2026, 11, 16), const LocalDate(2026, 12, 15)),
    ]) {
      await over.work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: fixtureEmployment,
          start: start,
          end: end,
          label: null,
        ),
      );
    }
    final shell = WorkShellController(
      work: over.work,
      reads: over.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (_) async => ConfirmAnswer.cancel,
      store: MemoryLocationStore(
        '${const WorkLocation.shifts(fixtureEmployment, month: _november).toUri()}',
      ),
    );
    addTearDown(shell.dispose);
    await shell.start();
    await until(() => (shell.details?.periods.length ?? 0) == 2);
    // From November to a period: the Details of another month load, and
    // are held up as the move lands.
    void holdOnArrival() {
      if (shell.location.from == const LocalDate(2026, 10, 16)) hold.hold();
    }

    shell.addListener(holdOnArrival);
    final moving = shell.goScope(
      const LocalDate(2026, 10, 16),
      const LocalDate(2026, 11, 15),
    );
    await until(() => hold.held);
    shell.removeListener(holdOnArrival);
    expect(shell.details, isNull);
    expect(shell.periods, hasLength(2));
    hold.release();
    await moving;
  });

  test('a filter replaces the place; Back does not step through it', () async {
    final shell = await open();
    const filter = ShiftsFilter(offDays: true);
    shell.setFilter(filter);
    expect(shell.location.filter, filter);
    expect(shell.canBack, isFalse);
  });

  test('a scope across a year end loads both years', () async {
    final shell = await open();
    await shell.goScope(
      const LocalDate(2026, 12, 20),
      const LocalDate(2027, 1, 10),
    );
    await until(() => shell.sheet!.loaded);
    expect(
      plannedDates(shell),
      containsAll([const LocalDate(2026, 12, 22), const LocalDate(2027, 1, 3)]),
    );
  });

  test('moves push; Back and Forward walk them', () async {
    final shell = await open();
    expect(await shell.stepScope(-1), isTrue);
    expect(shell.location, shifts(month: _september));
    expect(shell.sheet?.month, _september);
    expect(
      await shell.go(const WorkLocation.employment(fixtureEmployment)),
      isTrue,
    );
    expect(shell.sheet, isNull);
    expect(await shell.back(), isTrue);
    expect(shell.location, shifts(month: _september));
    expect(await shell.back(), isTrue);
    expect(shell.location, shifts());
    expect(shell.canBack, isFalse);
    expect(await shell.forward(), isTrue);
    expect(shell.location, shifts(month: _september));
  });

  test('a selected row replaces the place: Back skips it', () async {
    final shell = await open();
    await shell.stepScope(1);
    await shell.back();
    final day = plannedRowId(const LocalDate(2026, 10, 5));
    expect(await shell.sheet!.select(day), isTrue);
    expect(shell.location.rowId, day);
    expect(shell.canForward, isTrue, reason: 'a selection pushes nothing');
    shell.selectSub('history');
    expect(shell.location.sub, 'history');
    expect(await shell.forward(), isTrue);
    expect(await shell.back(), isTrue);
    expect(shell.location.rowId, day, reason: 'Back returns to the row');
    expect(shell.sheet?.selectedId, day);
    expect(shell.location.sub, 'history');
  });

  test(
    'past midnight the counts move on and the place shows the new day',
    () async {
      final shell = await open();
      await until(() => shell.pastDays[fixtureEmployment]?.toConfirm == 9);
      fixture.schedule.clock.value = DateTime.utc(2026, 10, 24, 6);
      await shell.checkDay();
      const next = LocalDate(2026, 10, 24);
      expect(shell.today, next);
      // The night of the 23rd is past now.
      await until(() => shell.pastDays[fixtureEmployment]?.toConfirm == 10);
      expect(shell.daysToConfirm, 10);
      expect(shell.sheet?.today, next);
      expect(shell.location, shifts());
      expect(shell.canBack, isFalse, reason: 'the new day replaces the place');
      await until(() => shell.details != null);
    },
  );

  test('a pending edit holds the new day back until it settles', () async {
    final shell = await open(confirm: ScriptedConfirm([ConfirmAnswer.revert]));
    await shell.sheet!.addShift();
    shell.sheet!.editField(newRowId, ShiftsField.note, 'Cover');
    final before = shell.sheet;
    fixture.schedule.clock.value = DateTime.utc(2026, 10, 24, 6);
    await shell.checkDay();
    const next = LocalDate(2026, 10, 24);
    expect(shell.today, next, reason: 'the counts move on at once');
    expect(shell.sheet, same(before));
    expect(shell.sheet?.today, ShiftsSheetFixture.today);
    expect(shell.sheet?.selectedId, newRowId);

    await shell.sheet!.undo();
    await shell.checkDay();
    expect(shell.sheet, isNot(same(before)));
    expect(shell.sheet?.today, next);
    await until(() => shell.details != null);
  });

  test('a new row is not in the route; once saved, its shift is', () async {
    final shell = await open(confirm: ScriptedConfirm([ConfirmAnswer.proceed]));
    await shell.sheet!.addShift();
    expect(shell.sheet?.selectedId, newRowId);
    expect(shell.location.rowId, isNull);
    shell.sheet!.editField(newRowId, ShiftsField.note, 'Cover');
    await shell.sheet!.save();
    await until(() => shell.location.shift != null);
    expect(shell.sheet?.selectedId, shell.location.rowId);
  });

  test('a filter set while a move waits is kept when it lands', () async {
    final confirm = ScriptedConfirm();
    final shell = await open(confirm: confirm);
    await shell.sheet!.addShift();
    shell.sheet!.editField(newRowId, ShiftsField.note, 'Cover');
    final answer = confirm.hold = Completer<ConfirmAnswer>();
    final moving = shell.goScope(_november, _november.lastOfMonth);
    await until(() => confirm.asked.isNotEmpty);
    shell.setFilter(const ShiftsFilter(offDays: true));
    answer.complete(ConfirmAnswer.revert);
    expect(await moving, isTrue);
    expect(shell.location.from, _november);
    expect(shell.location.filter.offDays, isTrue);
  });

  test('when the record keeps the owner, nothing moves', () async {
    final confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
    final shell = await open(confirm: confirm);
    await shell.sheet!.addShift();
    shell.sheet!.editField(newRowId, ShiftsField.note, 'Cover');
    expect(await shell.stepScope(1), isFalse);
    expect(confirm.asked.single.title, 'Finalize shift');
    expect(shell.location, shifts());
    expect(shell.canBack, isFalse);
    expect(shell.sheet?.selectedId, newRowId);
  });

  test('the owner\'s last click wins', () async {
    final shell = await open();
    final first = shell.stepScope(1);
    final second = shell.stepScope(-1);
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(shell.location, shifts(month: _september));
    expect(shell.canBack, isTrue);
    await shell.back();
    expect(shell.location, shifts());
  });

  test('a move overtaken while it shows its place did not go; the later '
      'move keeps its notice', () async {
    final stored = await fixture.finishShift(20);
    final shell = await open(
      remembered: '${shifts(month: _september, shift: stored.id).toUri()}',
    );
    expect(shell.location, shifts(shift: stored.id));
    Future<bool>? second;
    void overtake() {
      // The November sheet is made: Next month shows its place now.
      if (second == null && shell.sheet?.month == _november) {
        second = shell.go(shifts(shift: _goneShift));
      }
    }

    shell.addListener(overtake);
    final first = shell.stepScope(1);
    expect(
      await first.timeout(const Duration(seconds: 5)),
      isFalse,
      reason: 'the first move was overtaken',
    );
    await until(() => second != null);
    expect(await second!.timeout(const Duration(seconds: 5)), isTrue);
    shell.removeListener(overtake);
    expect(shell.notice, WorkShellNotices.recordGone);
    expect(shell.location, shifts());
    expect(shell.sheet?.month, _october);
    expect(await shell.back(), isTrue);
    expect(shell.location, shifts(month: _november));
    expect(await shell.back(), isTrue);
    expect(shell.location, shifts(shift: stored.id));
  });

  test('a start overtaken by a move leaves the move\'s notice', () async {
    final remembered = Completer<String?>();
    final shell = WorkShellController(
      work: fixture.work,
      reads: fixture.reads,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: ScriptedConfirm().call,
      store: _GatedStore(remembered.future),
    );
    addTearDown(shell.dispose);
    final starting = shell.start();
    expect(await shell.go(shifts(shift: _goneShift)), isTrue);
    expect(shell.notice, WorkShellNotices.recordGone);
    // The remembered place resolves after the move: it is dropped.
    remembered.complete(
      '${WorkLocation.shifts(_gone, month: _october).toUri()}',
    );
    await starting;
    expect(shell.notice, WorkShellNotices.recordGone);
    expect(shell.location, shifts());
  });

  test('remember writes the resolved place', () async {
    final store = MemoryLocationStore('${shifts().toUri()}');
    final shell = await open(store: store);
    await shell.stepScope(-1);
    await shell.remember();
    expect(store.route, '${shifts(month: _september).toUri()}');
  });

  test('quitting waits for a Void that runs, then lets go', () async {
    final stored = await fixture.finishShift(20);
    final shell = await open(remembered: '${shifts(shift: stored.id).toUri()}');
    final sheet = shell.sheet!;
    expect(await sheet.openAction(ShiftsActionKind.voidShift), isTrue);
    sheet.action!.setReason('Entered twice');
    final voiding = sheet.submitAction();
    // While the command runs the panel would keep the owner (spec 4.8:
    // the close waits for the result instead).
    expect(await shell.mayQuit(), isTrue);
    await voiding;
    expect(
      (await fixture.reads.shift(stored.id))!.shift.state,
      ShiftState.voided,
    );
  });

  test(
    'a remembered route that does not parse starts at the first place',
    () async {
      final shell = await open(remembered: 'http://[::1');
      expect(shell.started, isTrue);
      expect(
        shell.location,
        const WorkLocation.calendar(fixtureEmployment, month: _october),
      );
      expect(shell.notice, WorkShellNotices.placeUnreadable);
    },
  );

  test('Extend pay agreement… lets a pending edit go first', () async {
    final shell = await open(
      remembered:
          '${const WorkLocation.agreements(fixtureEmployment, agreement: fixtureAgreement).toUri()}',
      // Only the extension asks: the valid edit is saved on leaving.
      confirm: ScriptedConfirm([ConfirmAnswer.proceed]),
    );
    final sheet = shell.agreementsSheet!;
    await until(() => sheet.session != null);
    expect(
      sheet.editField(
        fixtureAgreement.value,
        AgreementField.hourlyRate,
        '19.00',
      ),
      isNull,
    );
    await shell.extendAgreement([const LocalDate(2026, 8, 25)]);
    final after = (await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!.value;
    expect(after.hourlyRateMicroEur, 19000000);
    expect(after.effectiveStart, const LocalDate(2026, 8, 25));
    expect(sheet.session?.phase, isNot(EditPhase.stale));
  });

  test('the employments are listed with their agreements', () async {
    final shell = await open();
    await until(() => shell.employments.isNotEmpty);
    expect(shell.employments.single.employment.name, 'Synthetic depot');
    expect(shell.employments.single.agreements, 1);
  });
}

/// A place store that only records what is written.
final class _WriteLog implements LocationStore {
  _WriteLog(this.writes);

  final List<String> writes;

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String route) async => writes.add(route);
}
