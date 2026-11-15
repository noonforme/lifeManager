import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_shell/day_action.dart';
import 'package:lifeos/app/work_shell/day_commands.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart'
    show EmploymentsWords;
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_part.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart'
    show CloseAgreementCommand, CorrectShiftCommand;
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/failing_work.dart' show PlanReadGate;
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const _tuesday = LocalDate(2026, 10, 6);

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedConfirm confirm;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    confirm = ScriptedConfirm();
  });

  tearDown(() => fixture.dispose());

  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<ShiftsSheetController> open({
    Future<MutationOutcome<ConfirmedDay>> Function(EmploymentId, LocalDate)?
    confirmDay,
    LocalDate month = ShiftsSheetFixture.month,
  }) async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (request) => confirm.call(request),
      confirmDay: confirmDay,
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  group('Confirm', () {
    test(
      'Confirm finalizes a past planned day and selects its shift',
      () async {
        final sheet = await open();
        await sheet.select(plannedRowId(_tuesday));
        expect(sheet.confirmBlocked, isNull);
        await sheet.confirmDay();
        final row = sheet.selectedRow;
        expect(sheet.selectedId, startsWith('shift:'));
        await until(() => sheet.selectedRow is StoredRow);
        final shift = (sheet.selectedRow! as StoredRow).shift;
        expect(row, anyOf(isNull, isA<StoredRow>()));
        expect(shift.state, ShiftState.finalized);
        expect(shift.localStartDate, _tuesday);
        expect(sheet.notice, DayCommandWords.confirmed(_tuesday));
        expect(confirm.asked, isEmpty);
      },
    );

    test('a pending time change is saved before Confirm', () async {
      final sheet = await open();
      final id = plannedRowId(_tuesday);
      await sheet.select(id);
      sheet.editField(id, ShiftsField.end, const LocalTime(18, 0));
      await sheet.confirmDay();
      final record = await fixture.reads.shift(
        ShiftId.tryParse(sheet.selectedId!.substring(6))!,
      );
      expect(
        fixture.work.timezones.localTimeAt(
          record!.shift.endUtc!,
          ShiftsSheetFixture.zone,
        ),
        const LocalTime(18, 0),
      );
    });

    test('Confirm on a leave day selects its confirmed leave', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 12)));
      await sheet.confirmDay();
      expect(sheet.selectedId, startsWith('leave:'));
      expect(
        sheet.notice,
        DayCommandWords.confirmedLeave(const LocalDate(2026, 10, 12)),
      );
      await until(() => sheet.selectedRow is LeaveTakenRow);
    });

    test('Confirm is greyed with its reason', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 23)));
      expect(sheet.confirmBlocked, DayCommandWords.confirmOnly);
      await sheet.select('off:2026-10-08');
      expect(sheet.confirmBlocked, DayCommandWords.confirmOnly);
    });

    test('Confirm is greyed on a day no agreement covers', () async {
      final current = (await fixture.reads.agreementsOf(fixtureEmployment))
          .single;
      await fixture.work.agreement.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: fixtureEmployment,
          end: const LocalDate(2026, 10, 1),
          expectedRevision: current.revision,
        ),
      );
      final sheet = await open();
      await sheet.select(plannedRowId(_tuesday));
      expect(sheet.confirmBlocked, DayCommandWords.noAgreement);
    });

    test('a day confirmed elsewhere is Stale and shown as it is now', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_tuesday));
      await fixture.work.plans.confirm(fixtureEmployment, _tuesday);
      await sheet.confirmDay();
      expect(sheet.notice, DayCommandWords.alreadyConfirmed);
      expect(sheet.selectedId, startsWith('shift:'));
    });

    test(
      'an uncertain confirm that went through reads back as confirmed',
      () async {
        var calls = 0;
        final sheet = await open(
          confirmDay: (id, date) async {
            calls++;
            await fixture.work.plans.confirm(id, date);
            return const Uncertain<ConfirmedDay>(
              SafeFailureCode.storageUnavailable,
            );
          },
        );
        await sheet.select(plannedRowId(_tuesday));
        await sheet.confirmDay();
        expect(calls, 1);
        expect(sheet.notice, DayCommandWords.confirmed(_tuesday));
        expect(sheet.selectedId, startsWith('shift:'));
      },
    );

    test('an uncertain confirm that did not go through says so', () async {
      final sheet = await open(
        confirmDay: (id, date) async =>
            const Uncertain<ConfirmedDay>(SafeFailureCode.storageUnavailable),
      );
      await sheet.select(plannedRowId(_tuesday));
      await sheet.confirmDay();
      expect(sheet.notice, DayCommandWords.notDone);
      expect(sheet.selectedId, plannedRowId(_tuesday));
    });

    test('Confirm is a key and a Record menu row', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_tuesday));
      final editors = EditorSessionController();
      final part = ShiftsSheetPart(
        sheet: sheet,
        followShift: (id) => unawaited(sheet.select(shiftRowId(id))),
        editors: editors,
        work: fixture.work,
        today: ShiftsSheetFixture.today,
      );
      addTearDown(() {
        part.dispose();
        editors.dispose();
      });
      final menu = part.recordMenu().singleWhere(
        (item) => item.label == 'Confirm',
      );
      expect(menu.onSelected, isNotNull);
      final key = part
          .bands()
          .expand((band) => band.items)
          .singleWhere((item) => item.label == 'Confirm');
      key.onPressed!();
      await sheet.settled();
      expect(part.notice(part.lines), DayCommandWords.confirmed(_tuesday));
    });
  });
  group('Restore shift', () {
    Future<List<DayException>> exceptions() async =>
        (await fixture.work.plans.repository.planInputs(fixtureEmployment))
            .exceptions;

    test('Restore shift on a cancelled day brings the plan back', () async {
      await fixture.work.plans.cancelDay(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        reason: CancelReason.dayOff,
        note: null,
      );
      final sheet = await open();
      final id = plannedRowId(const LocalDate(2026, 10, 12));
      await sheet.select(id);
      expect(sheet.restoreBlocked, isNull);
      expect(sheet.restoreLabel, 'Restore shift');
      await sheet.restoreShift();
      expect(sheet.notice, DayCommandWords.restored);
      expect(sheet.selectedId, id);
      expect(sheet.edit, isA<PlannedEdit>());
      expect(await exceptions(), isEmpty);
    });

    test('Restore shift on a leave day and on a changed day', () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        const LocalDate(2026, 10, 11),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      await fixture.work.plans.changeDay(
        fixtureEmployment,
        _tuesday,
        start: const LocalTime(7, 0),
        end: const LocalTime(18, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
      );
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 11)));
      await sheet.restoreShift();
      expect(sheet.notice, DayCommandWords.restored);
      await sheet.select(plannedRowId(_tuesday));
      expect(sheet.restoreBlocked, isNull);
      await sheet.restoreShift();
      expect(await exceptions(), isEmpty);
    });

    test('Remove extra shift on an extra day leaves an Off day', () async {
      await fixture.work.plans.addExtra(
        fixtureEmployment,
        const LocalDate(2026, 10, 9),
        start: const LocalTime(8, 0),
        end: const LocalTime(14, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
        countsAsOvertime: false,
      );
      final sheet = await open();
      await until(
        () => sheet.rows.any(
          (row) => row is PlannedRow && row.planned.day.isExtra,
        ),
      );
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 9)));
      expect(sheet.restoreLabel, 'Remove extra shift');
      await sheet.restoreShift();
      expect(sheet.notice, DayCommandWords.extraRemoved);
      expect(sheet.selectedId, isNull);
    });

    test('Restore is greyed on a day the cycle plans as it is', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_tuesday));
      expect(sheet.restoreBlocked, DayCommandWords.restoreOnly);
    });

    test('a change made since selecting is not removed', () async {
      await fixture.work.plans.cancelDay(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        reason: CancelReason.dayOff,
        note: null,
      );
      final sheet = await open();
      await sheet.select(plannedRowId(const LocalDate(2026, 10, 12)));
      final first = (await exceptions()).single;
      await fixture.work.plans.cancelDay(
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
        reason: CancelReason.other,
        note: 'Changed elsewhere',
        expected: first.revision,
      );
      await sheet.restoreShift();
      expect(sheet.notice, ShiftsNotices.reviewChanged);
      expect(await exceptions(), hasLength(1));
    });
  });
  group('Add extra shift', () {
    const off = LocalDate(2026, 10, 9);

    Future<List<DayException>> exceptions() async =>
        (await fixture.work.plans.repository.planInputs(fixtureEmployment))
            .exceptions;

    test('an Off day takes a new extra shift from the first type; untouched, '
        'leaving writes nothing', () async {
      final sheet = await open();
      await sheet.select('off:$off');
      expect(sheet.extraBlocked, isNull);
      expect(await sheet.addExtra(), isTrue);
      expect(sheet.selectedId, newExtraRowId);
      final edit = sheet.edit! as PlannedEdit;
      expect(edit.isNew, isTrue);
      expect(edit.value(ShiftsField.start), const LocalTime(7, 0));
      expect(edit.value(ShiftsField.type), 'Day');
      expect(edit.breaks.single.start, const LocalTime(12, 0));
      expect(edit.value(ShiftsField.overtime), isFalse);
      await sheet.select(plannedRowId(_tuesday));
      expect(await exceptions(), isEmpty);
    });

    test(
      'a changed extra shift is saved and selected as the extra day',
      () async {
        final sheet = await open();
        await sheet.select('off:$off');
        await sheet.addExtra();
        expect(
          sheet.editField(
            newExtraRowId,
            ShiftsField.end,
            const LocalTime(15, 0),
          ),
          isNull,
        );
        expect(
          sheet.editField(newExtraRowId, ShiftsField.overtime, true),
          isNull,
        );
        await sheet.save();
        expect(sheet.selectedId, plannedRowId(off));
        final saved = (await exceptions()).single as ExtraDay;
        expect(saved.end, const LocalTime(15, 0));
        expect(saved.countsAsOvertime, isTrue);
        await until(
          () => sheet.rows.any(
            (row) => row is PlannedRow && row.planned.day.isExtra,
          ),
        );
      },
    );

    test('an existing extra shift edits Counts as overtime', () async {
      await fixture.work.plans.addExtra(
        fixtureEmployment,
        off,
        start: const LocalTime(8, 0),
        end: const LocalTime(14, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
        countsAsOvertime: false,
      );
      final sheet = await open();
      await until(
        () => sheet.rows.any(
          (row) => row is PlannedRow && row.planned.day.isExtra,
        ),
      );
      final id = plannedRowId(off);
      await sheet.select(id);
      expect(sheet.editField(id, ShiftsField.overtime, true), isNull);
      await sheet.select(plannedRowId(_tuesday));
      expect(
        ((await exceptions()).single as ExtraDay).countsAsOvertime,
        isTrue,
      );
    });

    test('Add extra shift is greyed off an Off day', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_tuesday));
      expect(sheet.extraBlocked, DayCommandWords.extraOnlyOff);
      expect(await sheet.addExtra(), isFalse);
    });

    test('Add ▾ offers the extra shift on the selected Off day', () async {
      final sheet = await open();
      await sheet.select('off:$off');
      final editors = EditorSessionController();
      final part = ShiftsSheetPart(
        sheet: sheet,
        followShift: (id) => unawaited(sheet.select(shiftRowId(id))),
        editors: editors,
        work: fixture.work,
        today: ShiftsSheetFixture.today,
      );
      addTearDown(() {
        part.dispose();
        editors.dispose();
      });
      final item = part.addItems().singleWhere(
        (value) => value.label == 'Extra shift on Fri 2026-10-09',
      );
      expect(item.onSelected, isNotNull);
      await sheet.select(plannedRowId(_tuesday));
      final greyed = part.addItems().singleWhere(
        (value) => value.label == 'Extra shift on an Off day',
      );
      expect(greyed.onSelected, isNull);
      expect(greyed.disabledReason, DayCommandWords.extraOnlyOff);
      final last = part.addItems().singleWhere(
        (value) => value.label == 'Manual shift from last time',
      );
      expect(last.disabledReason, DayCommandWords.noLastShift);
    });
  });
  test('a day changed but not opened keeps its panel: Reload and check '
      'opens it without changing it again', () async {
    final plans = fixture.work.plans;
    final gate = PlanReadGate(plans.repository, failing: false);
    final sheet = ShiftsSheetController(
      work: fixture.work.replacing(
        plans: DayPlanService(
          repository: gate,
          shifts: plans.shifts,
          ids: plans.ids,
          clock: plans.clock,
          zoneClocks: plans.zoneClocks,
        ),
      ),
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: ShiftsSheetFixture.month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (request) => confirm.call(request),
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    await sheet.select(plannedRowId(_tuesday));
    expect(await sheet.openDayAction(DayActionKind.cancel), isTrue);
    gate.failAfterWrite = true;
    await sheet.submitDayAction();
    final action = sheet.dayAction!;
    expect(action.phase, DayActionPhase.committed);
    expect(action.error, DayActionWords.openFailed);
    Future<DayException> stored() async =>
        (await plans.repository.planInputs(fixtureEmployment))
            .exceptions
            .single;
    final written = await stored();
    expect(written, isA<CancelledDay>());
    gate
      ..failAfterWrite = false
      ..failing = false;
    await sheet.submitDayAction();
    expect(sheet.dayAction, isNull);
    expect(sheet.notice, DayActionWords.cancelled(_tuesday));
    expect((await stored()).revision, written.revision);
  });

  group('Finalize', () {
    Future<WorkShift> draft() async {
      final original = await fixture.finishShift(20);
      final outcome = await fixture.work.shifts.correctShift(
        CorrectShiftCommand(
          originalId: original.id,
          replacementId: fixture.schedule.ids.shiftId(),
          expectedRevision: original.revision,
          voidReason: 'Wrong end',
        ),
      );
      return (outcome as Committed<WorkShift>).value;
    }

    test('Finalize asks, then finalizes an unchanged draft', () async {
      final made = await draft();
      final sheet = await open();
      await sheet.select(shiftRowId(made.id));
      expect(sheet.finalizeBlocked, isNull);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.finalize();
      expect(confirm.asked, hasLength(1));
      expect(sheet.edit, isNull);
      final stored = await fixture.reads.shift(made.id);
      expect(stored!.shift.state, ShiftState.finalized);
    });

    test('a changed draft is finalized by Save; Finalize says so', () async {
      final made = await draft();
      final sheet = await open();
      final id = shiftRowId(made.id);
      await sheet.select(id);
      sheet.editField(id, ShiftsField.end, const LocalTime(17, 0));
      expect(sheet.finalizeBlocked, DayCommandWords.finalizeChanged);
      confirm = ScriptedConfirm([ConfirmAnswer.revert]);
      await sheet.select(plannedRowId(_tuesday));
    });

    test('Finalize just after a typed value is taken saves and finalizes '
        'the changed draft', () async {
      final made = await draft();
      final sheet = await open();
      final id = shiftRowId(made.id);
      await sheet.select(id);
      // The key's flush takes the value typed into the open editor.
      sheet.editField(id, ShiftsField.end, const LocalTime(17, 0));
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.finalize();
      expect(confirm.asked, hasLength(1));
      expect(sheet.edit, isNull);
      final stored = await fixture.reads.shift(made.id);
      expect(stored!.shift.state, ShiftState.finalized);
      // 08:00 to the 17:00 typed.
      expect(stored.shift.elapsedSeconds, 9 * 3600);
    });

    test('Finalize is greyed off a draft', () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_tuesday));
      expect(sheet.finalizeBlocked, DayCommandWords.finalizeOnlyDraft);
    });
  });
  group('new shifts', () {
    ShiftValues draftOf(ShiftsSheetController sheet) =>
        (sheet.edit! as StoredEdit).session.draft;

    test(
      "a new shift takes the selected planned day's times and breaks",
      () async {
        final sheet = await open();
        await sheet.select(plannedRowId(_tuesday));
        expect(await sheet.addShift(), isTrue);
        final draft = draftOf(sheet);
        expect(draft.startDate, _tuesday);
        expect(draft.start, const LocalTime(7, 0));
        expect(draft.end, const LocalTime(19, 0));
        expect(draft.endDate, _tuesday);
        expect(draft.breaks.single.start, const LocalTime(12, 0));
        expect(draft.breaks.single.end, const LocalTime(12, 30));
      },
    );

    test('a month that does not hold today starts on its first day', () async {
      final sheet = await open(month: const LocalDate(2026, 11, 1));
      await sheet.addShift();
      final draft = draftOf(sheet);
      expect(draft.startDate, const LocalDate(2026, 11, 1));
      // The 1st of November is not a planned day: the usual 08:00-16:00.
      expect(draft.start, const LocalTime(8, 0));
    });

    test(
      'Manual shift from last time copies the last finalized shift',
      () async {
        final sheet = await open();
        expect(sheet.fromLastBlocked, DayCommandWords.noLastShift);
        await fixture.finishShift(
          15,
          start: const LocalTime(9, 0),
          end: const LocalTime(17, 30),
          breaks: const [(LocalTime(13, 0), LocalTime(13, 45))],
        );
        await until(() => sheet.fromLastBlocked == null);
        expect(await sheet.addShift(fromLast: true), isTrue);
        final draft = draftOf(sheet);
        expect(draft.startDate, ShiftsSheetFixture.today);
        expect(draft.start, const LocalTime(9, 0));
        expect(draft.end, const LocalTime(17, 30));
        expect(draft.breaks.single.start, const LocalTime(13, 0));
        expect(draft.breaks.single.end, const LocalTime(13, 45));
      },
    );
  });
  test(
    "an archived employment's Shifts lists its days and changes none",
    () async {
      final sheet = await open();
      sheet.archived = true;
      expect(await sheet.addShift(), isFalse);
      await sheet.select(plannedRowId(_tuesday));
      expect(sheet.edit, isNull);
      expect(sheet.readOnlyReason, EmploymentsWords.archivedReadOnly);
      for (final blocked in [
        sheet.confirmBlocked,
        sheet.restoreBlocked,
        sheet.cancelBlocked,
        sheet.leaveBlocked,
        sheet.extraBlocked,
        sheet.correctBlocked,
        sheet.voidBlocked,
        sheet.finalizeBlocked,
        sheet.fromLastBlocked,
        sheet.addBlocked,
      ]) {
        expect(blocked, EmploymentsWords.archivedReadOnly);
      }
      sheet.archived = false;
      expect(sheet.addBlocked, isNull);
    },
  );
  test('Save on an untouched new extra shift adds it as it is', () async {
    final sheet = await open();
    await sheet.select('off:2026-10-09');
    await sheet.addExtra();
    await sheet.save();
    expect(sheet.selectedId, plannedRowId(const LocalDate(2026, 10, 9)));
    final stored =
        (await fixture.work.plans.repository.planInputs(fixtureEmployment))
                .exceptions
                .single
            as ExtraDay;
    expect(stored.start, const LocalTime(7, 0));
  });
  test('Restore after a pending change on the same day removes it', () async {
    await fixture.work.plans.changeDay(
      fixtureEmployment,
      _tuesday,
      start: const LocalTime(7, 0),
      end: const LocalTime(18, 0),
      endDayOffset: 0,
      breaks: const [],
      shiftTypeId: null,
    );
    final sheet = await open();
    final id = plannedRowId(_tuesday);
    await sheet.select(id);
    sheet.editField(id, ShiftsField.end, const LocalTime(17, 0));
    await sheet.restoreShift();
    expect(sheet.notice, DayCommandWords.restored);
    expect(
      (await fixture.work.plans.repository.planInputs(fixtureEmployment))
          .exceptions,
      isEmpty,
    );
  });
}
