import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/shifts_subform_lines.dart';
import 'package:lifeos/core/history/record_events.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/data/work_history.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/facts.dart' show Revision;
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const _monday = LocalDate(2026, 10, 5);
const _night = LocalDate(2026, 10, 11);

void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async => fixture = await ShiftsSheetFixture.create());
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
      confirm: ScriptedConfirm().call,
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  ShiftsLine selectedLine(ShiftsSheetController sheet) => shiftsLines(
    sheet,
    fixture.work.timezones,
  ).firstWhere((line) => line.id == sheet.selectedId);

  test('a pay group is named by its premiums, regular when it has none', () {
    const one = RationalMultiplier(numerator: 1, denominator: 1);
    expect(
      payGroupName(
        const PayGroup(
          night: false,
          holiday: false,
          overtime: false,
          seconds: 60,
          multiplier: one,
        ),
      ),
      'Regular',
    );
    expect(
      payGroupName(
        const PayGroup(
          night: true,
          holiday: false,
          overtime: true,
          seconds: 60,
          multiplier: one,
        ),
      ),
      'Night + Overtime',
    );
  });

  test(
    "a planned day's working is its pay groups at the agreement's rate",
    () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_night));
      final working = workingOf(sheet)!;
      expect(working.agreement.id, fixtureAgreement);
      final lines = workingLines(working.pay, working.agreement);
      expect([for (final line in lines) line.kind], ['Regular', 'Night']);
      expect([for (final line in lines) line.seconds], [14400, 27000]);
      expect(lines.first.rate, '18.40/h');
      expect(lines.last.multiplier, '1.5');
      expect(working.pay.amount.minorUnits, 28060);
    },
  );

  test('working follows the pending values', () async {
    final sheet = await open();
    await sheet.select(plannedRowId(_monday));
    sheet.editField(
      plannedRowId(_monday),
      ShiftsField.end,
      const LocalTime(18, 0),
    );
    expect(workingOf(sheet)!.pay.amount.minorUnits, 19320);
  });

  test(
    "a planned day's day plan is its cycle's own plan beside the day",
    () async {
      final sheet = await open();
      await sheet.select(plannedRowId(_monday));
      sheet.editField(
        plannedRowId(_monday),
        ShiftsField.end,
        const LocalTime(18, 0),
      );
      final lines = dayPlanLines(
        sheet,
        selectedLine(sheet),
        fixture.work.timezones,
      )!;
      expect([for (final line in lines) line.label], ['Plan', 'This day']);
      expect(lines.first.end, const LocalTime(19, 0));
      expect(lines.first.paidSeconds, 41400);
      expect(lines.last.end, const LocalTime(18, 0));
      expect(lines.last.paidSeconds, 37800);
    },
  );

  test('a manual shift has no day plan; its stored breaks are shown', () async {
    final stored = await fixture.finishShift(
      20,
      breaks: [(const LocalTime(12, 0), const LocalTime(12, 30))],
    );
    final sheet = await open();
    await sheet.select(storedRowId(stored));
    expect(
      dayPlanLines(sheet, selectedLine(sheet), fixture.work.timezones),
      isNull,
    );
    // Stored at 09:00–09:30 UTC, shown in the shift's zone (UTC+3).
    expect(breaksOf(sheet, fixture.work.timezones), const [
      BreakLine(index: 0, start: LocalTime(12, 0), end: LocalTime(12, 30)),
    ]);
    final working = workingOf(sheet)!;
    expect(working.pay.amount.minorUnits, 13800);
  });

  test('a history event lists what happened, its changes and reason', () async {
    final stored = await fixture.finishShift(20);
    final events = await fixture.work.history
        .watch(WorkRecordKinds.shift, stored.id.value)
        .first;
    final line = historyLine(events.first);
    expect(line.what, 'Created');
    expect(line.at, endsWith(' UTC'));
    expect(
      historyLine(
        RecordEvent(
          id: 9,
          recordKind: WorkRecordKinds.shift,
          recordId: 'x',
          atUtc: DateTime.utc(2026, 10, 21, 8, 5),
          kind: RecordEventKind.voided,
          changes: const [FieldChange('state', 'finalized', 'voided')],
          revisionAfter: 3,
          reason: 'Entered twice',
        ),
      ),
      isA<HistoryLine>()
          .having((line) => line.at, 'at', '2026-10-21 08:05 UTC')
          .having((line) => line.what, 'what', 'Voided')
          .having(
            (line) => line.changes,
            'changes',
            'state: finalized → voided',
          )
          .having((line) => line.reason, 'reason', 'Entered twice'),
    );
  });

  test('an open break is listed with an empty end', () {
    final lines = storedBreakLines(
      [
        ShiftBreak(
          id: const ShiftBreakId('01a1431f-3719-71d5-903b-ed22e08b3e01'),
          shiftId: const ShiftId('01a1431f-3719-71d5-903b-ed22e08b3e02'),
          startUtc: DateTime.utc(2026, 10, 5, 9),
          endUtc: null,
          createdAtUtc: DateTime.utc(2026, 10, 5, 9),
          updatedAtUtc: DateTime.utc(2026, 10, 5, 9),
          revision: const Revision(0),
        ),
      ],
      zone: 'Europe/Vilnius',
      timezones: IanaTimezoneService(),
    );
    expect(lines.single.start, const LocalTime(12, 0));
    expect(lines.single.end, isNull);
    expect(lines.single.minutes, 0);
  });

  test('a change with neither side names its field alone', () {
    final line = historyLine(
      RecordEvent(
        id: 1,
        recordKind: 'shift',
        recordId: 'x',
        atUtc: DateTime.utc(2026, 10, 5, 9),
        kind: RecordEventKind.changed,
        changes: const [FieldChange('note', null, null)],
        revisionAfter: 1,
      ),
    );
    expect(line.changes, 'note');
  });

  test('removing the first break marks no later break changed', () {
    const b1 = BreakLine(
      index: 0,
      start: LocalTime(10, 0),
      end: LocalTime(10, 15),
    );
    const b2 = BreakLine(
      index: 1,
      start: LocalTime(12, 0),
      end: LocalTime(12, 30),
    );
    const b3 = BreakLine(
      index: 2,
      start: LocalTime(15, 0),
      end: LocalTime(15, 15),
    );
    const now = [
      BreakLine(index: 0, start: LocalTime(12, 0), end: LocalTime(12, 30)),
      BreakLine(index: 1, start: LocalTime(15, 0), end: LocalTime(15, 15)),
    ];
    expect(changedBreaks(now, const [b1, b2, b3]), isEmpty);
    expect(
      changedBreaks(
        const [
          BreakLine(index: 0, start: LocalTime(12, 0), end: LocalTime(13, 0)),
        ],
        const [b2],
      ),
      {0},
    );
  });

  test('a changed break marks only the values that differ from its saved '
      'one', () {
    const saved = [
      BreakLine(index: 0, start: LocalTime(12, 0), end: LocalTime(12, 30)),
      BreakLine(index: 1, start: LocalTime(15, 0), end: LocalTime(15, 15)),
    ];
    // The first removed, the second's end changed.
    expect(
      changedBreakCells(const [
        BreakLine(index: 0, start: LocalTime(15, 0), end: LocalTime(15, 30)),
      ], saved),
      {(0, ShiftsField.end)},
    );
    // A break like none saved is changed in both values.
    expect(
      changedBreakCells(const [
        BreakLine(index: 0, start: LocalTime(9, 0), end: LocalTime(9, 15)),
      ], saved),
      {(0, ShiftsField.start), (0, ShiftsField.end)},
    );
    expect(changedBreakCells(saved, saved), isEmpty);
  });
}
