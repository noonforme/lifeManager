import 'dart:async';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_edit/leave_day_edit.dart';
import 'package:lifeos/app/work_edit/planned_day_edit.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_part.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/planned_leave_pay.dart';
import 'package:lifeos/features/work/application/work_commands.dart'
    show AgreementTerms, ChangeAgreementTermsCommand, CloseAgreementCommand;
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/ui/ui.dart' show EditorSessionController, PropertyGrid;

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

const _monday = LocalDate(2026, 10, 5);
const _tuesday = LocalDate(2026, 10, 6);

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedConfirm confirm;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    confirm = ScriptedConfirm();
  });

  tearDown(() => fixture.dispose());

  /// Waits until [condition] holds, letting the database's streams run.
  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<ShiftsSheetController> open({
    LocalDate month = ShiftsSheetFixture.month,
  }) async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      // Each test may script its own answers after the sheet opens.
      confirm: (request) => confirm.call(request),
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  Future<List<DayException>> exceptions() async =>
      (await fixture.work.plans.repository.planInputs(fixtureEmployment))
          .exceptions;

  test('a planned leave day shows its Est. pay from the months before its '
      'scope', () async {
    await fixture.finishShift(20);
    const leaveDay = LocalDate(2026, 11, 10);
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      leaveDay,
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final sheet = await open(month: const LocalDate(2026, 11, 1));
    final row = sheet.rows.whereType<LeaveRow>().single;
    final register = await fixture.work.workRepository
        .watchRegister(
          WorkScope(
            employmentId: fixtureEmployment,
            temporal: const DateRangeScope(
              start: LocalDate(2026, 1, 1),
              end: LocalDate(2026, 12, 31),
            ),
          ),
        )
        .first;
    final inputs = await fixture.work.plans.repository.planInputs(
      fixtureEmployment,
    );
    final expected = plannedLeavePay(
      row.day,
      employmentId: fixtureEmployment,
      agreements: inputs.agreements,
      shifts: register.shiftSheet,
      leave: register.leaveSheet,
    );
    expect(expected, isNotNull);
    expect(expected!.usedFallback, isFalse, reason: 'October was worked');
    await until(
      () =>
          shiftsLines(
            sheet,
            fixture.work.timezones,
          ).singleWhere((line) => line.date == leaveDay).pay !=
          null,
    );
    final line = shiftsLines(
      sheet,
      fixture.work.timezones,
    ).singleWhere((line) => line.date == leaveDay);
    expect(line.pay, expected.amount);
    // The months read for pricing are not rows of the sheet.
    expect(
      sheet.rows.every(
        (row) => row.date.compareTo(LocalDate(2026, 11, 1)) >= 0,
      ),
      isTrue,
    );
  });

  test('a planned net leave day never estimates from gross months', () async {
    await fixture.finishShift(20);
    final v1 = (await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!.value;
    final changed = await fixture.work.agreement.changeAgreementTerms(
      ChangeAgreementTermsCommand(
        agreementId: v1.id,
        employmentId: fixtureEmployment,
        expectedRevision: v1.revision,
        from: const LocalDate(2026, 11, 1),
        terms: AgreementTerms.of(v1)
            .change(basis: const NetBasis(), hourlyRateMicroEur: 10000000),
      ),
    );
    expect(changed, isA<Committed<PayAgreement>>());
    const leaveDay = LocalDate(2026, 11, 10);
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      leaveDay,
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    final sheet = await open(month: const LocalDate(2026, 11, 1));
    final row = sheet.rows.whereType<LeaveRow>().single;
    final register = await fixture.work.workRepository
        .watchRegister(
          WorkScope(
            employmentId: fixtureEmployment,
            temporal: const DateRangeScope(
              start: LocalDate(2026, 1, 1),
              end: LocalDate(2026, 12, 31),
            ),
          ),
        )
        .first;
    final inputs = await fixture.work.plans.repository.planInputs(
      fixtureEmployment,
    );
    final expected = plannedLeavePay(
      row.day,
      employmentId: fixtureEmployment,
      agreements: inputs.agreements,
      shifts: register.shiftSheet,
      leave: register.leaveSheet,
    )!;
    // October's gross work is left out: the net agreement rate, EUR 10.00.
    expect(expected.usedFallback, isTrue);
    expect(expected.otherBasisLeftOut, isTrue);
    expect(expected.basis, const NetBasis());
    expect(expected.amount.minorUnits, row.day.paidMinutes * 1000 ~/ 60);
  });

  test('the sheet lists planned days and stored shifts by start', () async {
    final stored = await fixture.finishShift(20);
    final sheet = await open();
    final ids = sheet.rows.map((row) => row.id).toList();
    // 3 Day, 3 Off, 3 Night, 3 Off from the 5th: 15 working days in
    // October, none confirmed.
    expect(sheet.rows.whereType<PlannedRow>(), hasLength(15));
    expect(ids.first, plannedRowId(_monday));
    expect(
      ids.indexOf(storedRowId(stored)),
      ids.indexOf(plannedRowId(const LocalDate(2026, 10, 19))) + 1,
    );
  });

  test(
    'a planned day edits its times; leaving it saves without asking',
    () async {
      final sheet = await open();
      expect(await sheet.select(plannedRowId(_monday)), isTrue);
      expect(sheet.edit, isA<PlannedEdit>());
      expect(
        sheet.editField(
          plannedRowId(_monday),
          ShiftsField.end,
          const LocalTime(18, 0),
        ),
        isNull,
      );
      expect(sheet.edit!.dirty, isTrue);
      expect(sheet.edit!.changed(ShiftsField.end), isTrue);
      expect(await sheet.select(plannedRowId(_tuesday)), isTrue);
      expect(confirm.asked, isEmpty);
      expect(sheet.selectedId, plannedRowId(_tuesday));
      final saved = (await exceptions()).single as ChangedDay;
      expect(saved.end, const LocalTime(18, 0));
    },
  );

  test('the preview follows the pending times', () async {
    final sheet = await open();
    await sheet.select(plannedRowId(_monday));
    sheet.editField(
      plannedRowId(_monday),
      ShiftsField.end,
      const LocalTime(18, 0),
    );
    final preview = sheet.preview!;
    expect(preview.paidSeconds, 37800);
    expect(preview.planDifferenceSeconds, -3600);
  });

  test(
    'values that cannot be saved keep the selection and write nothing',
    () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_monday));
      // A start after the noon break leaves the break outside the shift.
      expect(
        sheet.editField(
          plannedRowId(_monday),
          ShiftsField.start,
          const LocalTime(13, 0),
        ),
        isNull,
      );
      expect(await sheet.select(plannedRowId(_tuesday)), isFalse);
      expect(sheet.selectedId, plannedRowId(_monday));
      expect(sheet.edit!.phase, EditPhase.failed);
      expect(await exceptions(), isEmpty);
    },
  );

  test(
    'a new shift asks to finalize when saved and becomes its stored row',
    () async {
      final sheet = await open();
      expect(await sheet.addShift(), isTrue);
      expect(sheet.selectedId, newRowId);
      expect(sheet.edit!.isNew, isTrue);
      sheet.editField(newRowId, ShiftsField.end, const LocalTime(17, 0));
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await sheet.save(), SaveResult.committed);
      expect(confirm.asked.single.title, 'Finalize shift');
      final stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
      expect(sheet.selectedId, storedRowId(stored));
      expect(sheet.edit, isNull, reason: 'a finalized shift is read-only');
      expect(sheet.readOnlyReason, ShiftProblems.finalized);
      await until(() => sheet.rows.any((row) => row.id == sheet.selectedId));
    },
  );

  test(
    'Cancel in the finalization window keeps the new shift selected',
    () async {
      final sheet = await open();
      await sheet.addShift();
      sheet.editField(newRowId, ShiftsField.end, const LocalTime(17, 0));
      confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(await sheet.select(plannedRowId(_monday)), isFalse);
      expect(sheet.selectedId, newRowId);
      expect(sheet.edit!.dirty, isTrue);
      expect(await fixture.reads.shiftsOf(fixtureEmployment), isEmpty);
    },
  );

  test(
    'a new shift holding only its defaults leaves nothing on leave',
    () async {
      final sheet = await open();
      await sheet.addShift();
      expect(await sheet.select(plannedRowId(_monday)), isTrue);
      expect(confirm.asked, isEmpty);
      expect(await fixture.reads.shiftsOf(fixtureEmployment), isEmpty);
    },
  );

  test('Undo of an untouched new shift drops its row', () async {
    final sheet = await open();
    await sheet.addShift();
    expect(await sheet.undo(), SaveResult.clean);
    expect(sheet.selectedId, isNull);
    expect(sheet.edit, isNull);
  });

  test('a finalized shift is read-only with its reason', () async {
    final stored = await fixture.finishShift(20);
    final sheet = await open();
    expect(await sheet.select(storedRowId(stored)), isTrue);
    expect(sheet.edit, isNull);
    expect(sheet.readOnlyReason, ShiftProblems.finalized);
  });

  test('of two quick selections the later one wins', () async {
    final sheet = await open();
    final first = sheet.select(plannedRowId(_monday));
    final second = sheet.select(plannedRowId(_tuesday));
    await Future.wait([first, second]);
    expect(sheet.selectedId, plannedRowId(_tuesday));
    expect((sheet.edit! as PlannedEdit).record.date, _tuesday);
  });

  test('only the selected row takes edits', () async {
    final sheet = await open();
    await sheet.select(plannedRowId(_monday));
    expect(
      sheet.editField(
        plannedRowId(_tuesday),
        ShiftsField.end,
        const LocalTime(18, 0),
      ),
      ShiftsEditProblems.notEditable,
    );
  });

  ShiftsSheetController unstarted({
    ProductionWorkProviders? work,
    WorkReads? reads,
    LeaveCoordinator? coordinator,
  }) => ShiftsSheetController(
    work: work ?? fixture.work,
    reads: reads ?? fixture.reads,
    employmentId: fixtureEmployment,
    month: ShiftsSheetFixture.month,
    today: ShiftsSheetFixture.today,
    timezoneId: ShiftsSheetFixture.zone,
    confirm: (request) => confirm.call(request),
    coordinator: coordinator,
  );

  /// A started sheet over storage whose reads [hold] can slow.
  Future<ShiftsSheetController> openHeld(ReadHold hold) async {
    final held = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(hold),
    );
    addTearDown(held.dispose);
    final stored = await held.finishShift(20);
    final sheet = unstarted(work: held.work, reads: held.reads)..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    expect(sheet.rows.map((row) => row.id), contains(storedRowId(stored)));
    return sheet;
  }

  test('while the next row opens, the last one is let go', () async {
    final hold = ReadHold();
    final sheet = await openHeld(hold);
    final shift = sheet.rows.whereType<StoredRow>().single;
    await sheet.select(plannedRowId(_monday));
    expect(sheet.edit, isNotNull);

    hold.hold();
    final opening = sheet.select(shift.id);
    await until(() => sheet.selectedId == shift.id);
    expect(sheet.edit, isNull, reason: 'Monday is no longer editable');
    expect(sheet.readOnlyReason, ShiftsNotices.opening);
    hold.release();
    expect(await opening, isTrue);
    expect(sheet.readOnlyReason, isNot(ShiftsNotices.opening));
  });

  test(
    'choosing the last row again while the next one opens keeps it',
    () async {
      final hold = ReadHold();
      final sheet = await openHeld(hold);
      final shift = sheet.rows.whereType<StoredRow>().single;
      await sheet.select(plannedRowId(_monday));

      hold.hold();
      final away = sheet.select(shift.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final back = sheet.select(plannedRowId(_monday));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      hold.release();
      await Future.wait([away, back]);
      expect(sheet.selectedId, plannedRowId(_monday));
      expect(sheet.edit, isA<PlannedEdit>());
    },
  );

  test('ready completes when the sheet is disposed before it loads', () async {
    final sheet = unstarted()..start();
    sheet.dispose();
    await sheet.ready.timeout(const Duration(seconds: 5));
    expect(sheet.loaded, isFalse);
    // The cancelled feeds' reads finish before the database closes.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  test('a feed error completes ready and the sheet says so', () async {
    final reports = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reports.add;
    addTearDown(() => FlutterError.onError = previous);
    // Storage that cannot be read: every feed fails.
    final closed = await EmptyWorkFixture.create(
      executor: NativeDatabase.memory().interceptWith(ReadGate(failing: true)),
    );
    addTearDown(closed.dispose);
    final sheet = unstarted(work: closed.work, reads: closed.reads)..start();
    addTearDown(sheet.dispose);
    await sheet.ready.timeout(const Duration(seconds: 5));
    expect(sheet.loaded, isFalse);
    final editors = EditorSessionController();
    final part = ShiftsSheetPart(
      sheet: sheet,
      followShift: (id) => unawaited(sheet.select(shiftRowId(id))),
      editors: editors,
      work: closed.work,
      today: ShiftsSheetFixture.today,
    );
    addTearDown(() {
      part.dispose();
      editors.dispose();
    });
    expect(part.notice(part.lines), ShiftsNotices.unreadable);
    expect(reports, isNotEmpty);
    expect(reports.first.library, 'shifts sheet');
  });

  test('a sheet disposed while a row opens registers nothing with the '
      'coordinator', () async {
    final coordinator = LeaveCoordinator(confirm: confirm.call);
    final sheet = unstarted(coordinator: coordinator)..start();
    await until(() => sheet.loaded);
    final pending = sheet.show(plannedRowId(_monday));
    sheet.dispose();
    await pending;
    await sheet.show(plannedRowId(_tuesday));
    expect(sheet.edit, isNull);
    expect(await coordinator.quit(), isTrue);
    expect(confirm.asked, isEmpty);
  });

  test('a day changed elsewhere is stale; Reload record shows it', () async {
    final sheet = await open();
    await sheet.select(plannedRowId(_monday));
    sheet.editField(
      plannedRowId(_monday),
      ShiftsField.end,
      const LocalTime(18, 0),
    );
    await fixture.work.plans.changeDay(
      fixtureEmployment,
      _monday,
      start: const LocalTime(7, 0),
      end: const LocalTime(17, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: null,
    );
    expect(await sheet.save(), SaveResult.stale);
    await sheet.reload();
    expect(sheet.edit!.phase, EditPhase.idle);
    expect(sheet.edit!.value(ShiftsField.end), const LocalTime(17, 0));
  });

  test('a day that is gone keeps its values until Discard and return to '
      'sheet drops them and selects nothing', () async {
    final sheet = await open();
    await sheet.select(plannedRowId(_monday));
    sheet.editField(
      plannedRowId(_monday),
      ShiftsField.end,
      const LocalTime(18, 0),
    );
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      _monday,
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    expect(await sheet.save(), SaveResult.stale);
    await sheet.reload();
    expect(sheet.edit!.session.gone, isTrue);
    expect(sheet.edit!.value(ShiftsField.end), const LocalTime(18, 0));

    await sheet.discardAndReturn();
    expect(sheet.selectedId, isNull);
    expect(sheet.edit, isNull);
    expect(await sheet.coordinator.quit(), isTrue);
    expect(confirm.asked, isEmpty);
  });

  test(
    "a planned day's note and date each say why they are not edited",
    () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_monday));
      final lines = shiftsLines(sheet, fixture.work.timezones);
      String? reason(LocalDate day, String field) => shiftsReadOnlyReason(
        sheet,
        lines.singleWhere((line) => line.id == plannedRowId(day)),
        field,
      );
      for (final day in [_monday, _tuesday]) {
        expect(reason(day, ShiftsField.note), ShiftsReadOnly.plannedNote);
        expect(reason(day, ShiftsField.date), ShiftsReadOnly.plannedField);
      }
      expect(reason(_monday, ShiftsField.end), isNull);
    },
  );

  test('a problem found on Save marks the property it is entered as', () async {
    final sheet = await open();
    confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    await sheet.addShift();
    // 03:30 does not exist in Vilnius on the night the clocks go forward.
    sheet.editField(newRowId, ShiftsField.date, const LocalDate(2026, 3, 29));
    sheet.editField(newRowId, ShiftsField.start, const LocalTime(3, 30));
    expect(await sheet.save(), SaveResult.invalid);
    expect(sheet.edit!.issues.keys, contains('localTime'));

    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    final part = ShiftsSheetPart(
      sheet: sheet,
      followShift: (id) => unawaited(sheet.select(shiftRowId(id))),
      editors: editors,
      work: fixture.work,
      today: ShiftsSheetFixture.today,
    );
    addTearDown(part.dispose);
    final grid = part.properties(
      shiftsLines(sheet, fixture.work.timezones),
    ) as PropertyGrid;
    String? error(String key) =>
        grid.items.singleWhere((item) => item.key == key).error;
    expect(error(ShiftsField.start), ShiftProblems.localTime);
    expect(error(ShiftsField.end), isNull);
  });

  test('off days are rows of their own', () async {
    final sheet = await open();
    final off = sheet.rows.whereType<OffRow>().toList();
    expect(off, hasLength(12), reason: '8-10, 14-16, 20-22, 26-28 October');
    expect(off.first.id, 'off:2026-10-08');
    expect(await sheet.select(off.first.id), isTrue);
    expect(sheet.edit, isNull);
    expect(sheet.readOnlyReason, ShiftsNotices.offDay);
  });

  test('each line names its type', () async {
    final stored = await fixture.finishShift(20);
    final sheet = await open();
    await until(() => sheet.rows.any((row) => row is StoredRow));
    final lines = shiftsLines(sheet, fixture.work.timezones);
    String? type(String id) => lines.singleWhere((line) => line.id == id).type;
    expect(type(plannedRowId(_monday)), 'Day');
    expect(type(plannedRowId(const LocalDate(2026, 10, 11))), 'Night');
    expect(type(storedRowId(stored)), 'Manual');
    expect(type('off:2026-10-08'), isNull);
  });
  group('every kind of day is a row', () {
    String words(ShiftsSheetController sheet, String id) => shiftsLines(
      sheet,
      fixture.work.timezones,
    ).singleWhere((line) => line.id == id).statusText;

    test('past planned days wait to be confirmed', () async {
      await fixture.work.plans.changeDay(
        fixtureEmployment,
        const LocalDate(2026, 10, 7),
        start: const LocalTime(7, 0),
        end: const LocalTime(19, 45),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
      );
      final sheet = await open();
      await until(
        () => sheet.rows.any(
          (row) => row is PlannedRow && row.planned.day.changed,
        ),
      );
      final lines = shiftsLines(sheet, fixture.work.timezones);
      ShiftsLine line(int day) => lines.singleWhere(
        (value) => value.id == plannedRowId(LocalDate(2026, 10, day)),
      );
      expect(line(6).statusText, 'To confirm');
      expect(line(6).toConfirm, isTrue);
      expect(line(7).statusText, 'Changed, to confirm');
      expect(line(23).statusText, 'Planned');
      expect(line(23).toConfirm, isFalse);
    });

    test('leave, cancelled and confirmed leave days are rows', () async {
      final plans = fixture.work.plans;
      await plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      await plans.cancelDay(
        fixtureEmployment,
        const LocalDate(2026, 10, 13),
        reason: CancelReason.swapped,
        note: null,
      );
      await plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 11),
        leaveType: LeaveType.sick,
        illnessStartedOn: null,
      );
      await plans.confirm(fixtureEmployment, const LocalDate(2026, 10, 11));
      final sheet = await open();
      await until(() => sheet.rows.any((row) => row is LeaveTakenRow));
      final leave = sheet.rows.whereType<LeaveRow>().single;
      expect(leave.id, plannedRowId(const LocalDate(2026, 10, 12)));
      final cancelled = sheet.rows.whereType<CancelledRow>().single;
      expect(cancelled.id, plannedRowId(const LocalDate(2026, 10, 13)));
      final taken = sheet.rows.whereType<LeaveTakenRow>().single;
      expect(taken.date, const LocalDate(2026, 10, 11));
      expect(
        sheet.rows.whereType<PlannedRow>().map((row) => row.date.day),
        isNot(anyOf(contains(11), contains(12), contains(13))),
      );
      expect(words(sheet, leave.id), 'Vacation, to confirm');
      expect(words(sheet, cancelled.id), 'Cancelled · Swapped');
      expect(words(sheet, taken.id), 'Sick, confirmed');
      final lines = shiftsLines(sheet, fixture.work.timezones);
      final leaveLine = lines.singleWhere((line) => line.id == leave.id);
      expect(leaveLine.type, 'Night');
      expect(leaveLine.paidSeconds, 41400);
      // No worked month before it: priced at the agreement's rate (bead
      // 9pk.4.19).
      expect(leaveLine.pay, isNotNull);
      final cancelledLine = lines.singleWhere(
        (line) => line.id == cancelled.id,
      );
      expect(cancelledLine.start, isNull);
      expect(cancelledLine.paidSeconds, isNull);
      expect(lines.singleWhere((line) => line.id == taken.id).type, 'Sick');
    });

    test('a day no agreement covers says so and is not to confirm', () async {
      final current = (await fixture.reads.agreementsOf(fixtureEmployment))
          .single;
      await fixture.work.agreement.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: fixtureEmployment,
          end: const LocalDate(2026, 10, 15),
          expectedRevision: current.revision,
        ),
      );
      final sheet = await open();
      final line = shiftsLines(sheet, fixture.work.timezones).singleWhere(
        (value) => value.id == plannedRowId(const LocalDate(2026, 10, 17)),
      );
      expect(line.statusText, 'No pay agreement');
      expect(line.withoutAgreement, isTrue);
      expect(line.toConfirm, isFalse);
      expect(sheet.agreementCovers(const LocalDate(2026, 10, 17)), isFalse);
      expect(sheet.agreementCovers(const LocalDate(2026, 10, 6)), isTrue);
    });
  });
  group("a planned day's shift type", () {
    test('choosing Night on a Day fills in its times and breaks', () async {
      final sheet = await open();
      final id = plannedRowId(_tuesday);
      await sheet.select(id);
      final edit = sheet.edit! as PlannedEdit;
      expect(edit.typeChoices.map((type) => type.name), ['Day', 'Night']);
      expect(edit.value(ShiftsField.type), 'Day');
      expect(sheet.editField(id, ShiftsField.type, 'Night'), isNull);
      expect(edit.value(ShiftsField.start), const LocalTime(19, 0));
      expect(edit.value(ShiftsField.end), const LocalTime(7, 0));
      expect(edit.session.draft.endDayOffset, 1);
      expect(edit.breaks.single.start, const LocalTime(0, 0));
      expect(edit.changed(ShiftsField.type), isTrue);
      expect(sheet.editField(id, ShiftsField.type, 'Day'), isNull);
      expect(edit.dirty, isFalse);
    });

    test('a type the schedule does not have is refused', () async {
      final sheet = await open();
      final id = plannedRowId(_tuesday);
      await sheet.select(id);
      expect(
        sheet.editField(id, ShiftsField.type, 'Late'),
        PlannedDayProblems.shiftType,
      );
    });

    test('the changed type shows on the line and is saved', () async {
      final sheet = await open();
      final id = plannedRowId(_tuesday);
      await sheet.select(id);
      sheet.editField(id, ShiftsField.type, 'Night');
      final line = shiftsLines(
        sheet,
        fixture.work.timezones,
      ).singleWhere((value) => value.id == id);
      expect(line.type, 'Night');
      await sheet.select(plannedRowId(_monday));
      final saved = (await exceptions()).single as ChangedDay;
      expect(saved.shiftTypeId?.value, 'night');
    });
  });
  group('Change leave', () {
    const night = LocalDate(2026, 10, 12);

    test('a planned leave day edits its leave; leaving it saves without '
        'asking', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        night,
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      final sheet = await open();
      final id = plannedRowId(night);
      await sheet.select(id);
      expect(sheet.edit, isA<LeaveEdit>());
      expect(
        sheet.editField(id, ShiftsField.leaveType, LeaveType.sick),
        isNull,
      );
      expect(
        sheet.editField(id, ShiftsField.illness, const LocalDate(2026, 10, 11)),
        isNull,
      );
      expect(sheet.edit!.dirty, isTrue);
      final line = shiftsLines(
        sheet,
        fixture.work.timezones,
      ).singleWhere((value) => value.id == id);
      expect(line.statusText, 'Sick, to confirm');
      await sheet.select(plannedRowId(_monday));
      expect(confirm.asked, isEmpty);
      final saved = (await exceptions()).single as LeaveDay;
      expect(saved.leaveType, LeaveType.sick);
      expect(saved.illnessStartedOn, const LocalDate(2026, 10, 11));
    });

    test(
      'vacation clears the illness start; one after the day is refused',
      () async {
        await fixture.work.plans.markLeave(
          fixtureEmployment,
          night,
          leaveType: LeaveType.sick,
          illnessStartedOn: const LocalDate(2026, 10, 10),
        );
        final sheet = await open();
        final id = plannedRowId(night);
        await sheet.select(id);
        expect(
          sheet.editField(
            id,
            ShiftsField.illness,
            const LocalDate(2026, 10, 13),
          ),
          LeaveDayProblems.illness,
        );
        sheet.editField(id, ShiftsField.leaveType, LeaveType.vacation);
        expect(sheet.edit!.value(ShiftsField.illness), isNull);
      },
    );
  });
  test('an older planned snapshot and a newer leave or cancelled day '
      'publish each day only once', () async {
    final sheet = await open();
    final earlierPlan = sheet.rows
        .whereType<PlannedRow>()
        .map((row) => row.planned)
        .toList();
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 12),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await fixture.work.plans.cancelDay(
      fixtureEmployment,
      const LocalDate(2026, 10, 13),
      reason: CancelReason.other,
      note: null,
    );
    await until(
      () =>
          sheet.rows.any((row) => row is LeaveRow) &&
          sheet.rows.any((row) => row is CancelledRow),
    );
    final merged = mergeShiftsRows(
      stored: const [],
      planned: earlierPlan,
      leave: sheet.rows.whereType<LeaveRow>().toList(),
      cancelled: [
        for (final row in sheet.rows.whereType<CancelledRow>()) row.day,
      ],
    );
    expect(merged.map((row) => row.id).toSet(), hasLength(merged.length));
    expect(
      merged.where((row) => row.date == const LocalDate(2026, 10, 12)).single,
      isA<LeaveRow>(),
    );
    expect(
      merged.where((row) => row.date == const LocalDate(2026, 10, 13)).single,
      isA<CancelledRow>(),
    );
  });
}
