import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/planned_day_edit.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart' show FoldChoice;
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

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

  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<ShiftsSheetController> open() async {
    final sheet = ShiftsSheetController(
      work: fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: ShiftsSheetFixture.month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      confirm: (request) => confirm.call(request),
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  Future<ShiftsEdit> monday(ShiftsSheetController sheet) async {
    await sheet.select(plannedRowId(_monday));
    return sheet.edit!;
  }

  test(
    "a planned day's breaks are its children in the same pending edit",
    () async {
      final edit = await monday(await open());
      const noon = BreakLine(
        index: 0,
        start: LocalTime(12, 0),
        end: LocalTime(12, 30),
      );
      expect(edit.breaks, [noon]);
      expect(edit.savedBreaks, [noon]);
      expect(edit.breaks.single.minutes, 30);
    },
  );

  test("a break's new end saves with its day when the day is left", () async {
    final sheet = await open();
    final edit = await monday(sheet);
    expect(edit.setBreak(0, ShiftsField.end, const LocalTime(13, 0)), isNull);
    expect(edit.dirty, isTrue);
    expect(edit.breaks.single.minutes, 60);
    expect(sheet.preview!.breakSeconds, 3600);
    expect(await sheet.select(plannedRowId(_tuesday)), isTrue);
    final saved =
        (await fixture.work.plans.repository.planInputs(fixtureEmployment))
                .exceptions
                .single
            as ChangedDay;
    expect(saved.breaks, const [
      FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 60),
    ]);
  });

  test(
    'a break outside the shift stays in its editor with the reason',
    () async {
      final edit = await monday(await open());
      expect(
        edit.setBreak(0, ShiftsField.start, const LocalTime(19, 30)),
        PlannedDayProblems.breaks,
      );
      expect(edit.dirty, isFalse);
    },
  );

  test('a new break goes in the middle of the shift; Undo reverts the '
      'parent and its children together', () async {
    final sheet = await open();
    final edit = await monday(sheet);
    edit.set(ShiftsField.end, const LocalTime(18, 0));
    expect(edit.addBreak(), isNull);
    expect(edit.breaks.last.start, const LocalTime(12, 30));
    expect(edit.breaks.last.minutes, 30);
    expect(edit.removeBreak(0), isNull);
    expect(edit.breaks, hasLength(1));
    expect(await sheet.undo(), SaveResult.reverted);
    expect(edit.breaks, edit.savedBreaks);
    expect(edit.value(ShiftsField.end), const LocalTime(19, 0));
  });

  test(
    "a night shift's break after midnight is stored on the next day",
    () async {
      final sheet = await open();
      await sheet.addShift();
      final edit = sheet.edit!;
      edit.set(ShiftsField.start, const LocalTime(22, 0));
      edit.set(ShiftsField.end, const LocalTime(6, 0));
      expect(edit.addBreak(), isNull);
      expect(edit.breaks.single.start, const LocalTime(2, 0));
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await sheet.save(), SaveResult.committed);
      final stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
      final breaks = (await fixture.reads.shift(stored.id))!.breaks;
      // 02:00 on 2026-10-21 in Vilnius (UTC+3).
      expect(breaks.single.startUtc, DateTime.utc(2026, 10, 20, 23));
      expect(breaks.single.endUtc, DateTime.utc(2026, 10, 20, 23, 30));
    },
  );

  test("editing a break's start moves it and keeps its length", () async {
    final edit = await monday(await open());
    expect(edit.setBreak(0, ShiftsField.start, const LocalTime(14, 0)), isNull);
    expect(edit.breaks, const [
      BreakLine(index: 0, start: LocalTime(14, 0), end: LocalTime(14, 30)),
    ]);
  });

  test('two breaks added to a planned day do not overlap; the second can '
      'move before the first', () async {
    final edit = await monday(await open());
    expect(edit.addBreak(), isNull);
    expect(edit.addBreak(), isNull);
    expect(edit.breaks, const [
      BreakLine(index: 0, start: LocalTime(12, 0), end: LocalTime(12, 30)),
      BreakLine(index: 1, start: LocalTime(12, 30), end: LocalTime(13, 0)),
      BreakLine(index: 2, start: LocalTime(13, 0), end: LocalTime(13, 30)),
    ]);
    expect(edit.issues, isEmpty);
    expect(edit.setBreak(2, ShiftsField.start, const LocalTime(9, 0)), isNull);
    expect(edit.breaks[2].start, const LocalTime(9, 0));
    expect(edit.issues, isEmpty);
  });

  test('a new break fills the first free half hour when none follows the '
      'last one', () async {
    final sheet = await open();
    await sheet.addShift();
    final edit = sheet.edit!;
    expect(edit.addBreak(), isNull);
    expect(
      edit.setBreak(0, ShiftsField.start, const LocalTime(15, 30)),
      isNull,
    );
    expect(edit.addBreak(), isNull);
    expect(
      edit.breaks.last,
      const BreakLine(index: 1, start: LocalTime(8, 0), end: LocalTime(8, 30)),
    );
    expect(edit.issues, isEmpty);
  });

  test(
    "a shift's break moved before an earlier one is taken and saved",
    () async {
      final sheet = await open();
      await sheet.addShift();
      final edit = sheet.edit!;
      expect(edit.addBreak(), isNull);
      expect(edit.addBreak(), isNull);
      expect(edit.breaks[1].start, const LocalTime(12, 30));
      expect(
        edit.setBreak(1, ShiftsField.start, const LocalTime(10, 0)),
        isNull,
      );
      expect(edit.breaks[1].end, const LocalTime(10, 30));
      expect(edit.issues, isEmpty);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await sheet.save(), SaveResult.committed);
      final stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
      final breaks = (await fixture.reads.shift(stored.id))!.breaks;
      expect(
        {for (final item in breaks) item.startUtc},
        {DateTime.utc(2026, 10, 20, 7), DateTime.utc(2026, 10, 20, 9)},
      );
    },
  );

  test("a new shift's breaks are set and removed in its pending edit and "
      'saved with it', () async {
    final sheet = await open();
    await sheet.addShift();
    final edit = sheet.edit!;
    expect(edit.addBreak(), isNull);
    expect(edit.setBreak(0, ShiftsField.end, const LocalTime(13, 0)), isNull);
    expect(edit.addBreak(), isNull);
    expect(edit.breaks.last.start, const LocalTime(13, 0));
    expect(edit.removeBreak(0), isNull);
    expect(edit.setBreak(0, ShiftsField.start, const LocalTime(14, 0)), isNull);
    expect(edit.breaks, const [
      BreakLine(index: 0, start: LocalTime(14, 0), end: LocalTime(14, 30)),
    ]);
    confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(await sheet.save(), SaveResult.committed);
    final stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
    final breaks = (await fixture.reads.shift(stored.id))!.breaks;
    // 14:00–14:30 on 2026-10-20 in Vilnius (UTC+3).
    expect(breaks.single.startUtc, DateTime.utc(2026, 10, 20, 11));
    expect(breaks.single.endUtc, DateTime.utc(2026, 10, 20, 11, 30));
  });

  test("moving a shift's date carries its breaks", () async {
    final sheet = await open();
    await sheet.addShift();
    final edit = sheet.edit!;
    expect(edit.addBreak(), isNull);
    expect(edit.set(ShiftsField.date, const LocalDate(2026, 10, 22)), isNull);
    expect(edit.issues, isEmpty);
    confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(await sheet.save(), SaveResult.committed);
    final stored = (await fixture.reads.shiftsOf(fixtureEmployment)).single;
    final breaks = (await fixture.reads.shift(stored.id))!.breaks;
    expect(breaks.single.startUtc, DateTime.utc(2026, 10, 22, 9));
    expect(breaks.single.endUtc, DateTime.utc(2026, 10, 22, 9, 30));
  });

  test('a break field other than its start or end cannot be set', () async {
    final sheet = await open();
    final planned = await monday(sheet);
    expect(
      planned.setBreak(0, 'length', const LocalTime(1, 0)),
      ShiftsEditProblems.notEditable,
    );
    expect(planned.dirty, isFalse);
    await sheet.addShift();
    final shift = sheet.edit!;
    expect(shift.addBreak(), isNull);
    expect(
      shift.setBreak(0, ShiftsField.note, const LocalTime(1, 0)),
      ShiftsEditProblems.notEditable,
    );
  });

  test("editing a break's end keeps its start in the repeated hour", () async {
    final sheet = await open();
    await sheet.addShift();
    final edit = sheet.edit! as StoredEdit;
    // The night the clocks go back: 03:00 to 04:00 happens twice.
    edit.set(ShiftsField.date, const LocalDate(2026, 10, 25));
    edit.set(ShiftsField.start, const LocalTime(1, 0));
    edit.set(ShiftsField.end, const LocalTime(7, 0));
    expect(edit.addBreak(), isNull);
    final draft = edit.session.draft;
    final first = draft.breaks.single;
    edit.session.edit(
      draft.copyWith(
        breaks: [
          BreakValues(
            startDate: first.startDate,
            start: const LocalTime(3, 10),
            endDate: first.endDate,
            end: const LocalTime(3, 40),
            startFold: FoldChoice.later,
            endFold: FoldChoice.later,
          ),
        ],
      ),
    );
    expect(edit.setBreak(0, ShiftsField.end, const LocalTime(3, 50)), isNull);
    final kept = edit.session.draft.breaks.single;
    expect(kept.startFold, FoldChoice.later);
    expect(kept.end, const LocalTime(3, 50));
  });
}
