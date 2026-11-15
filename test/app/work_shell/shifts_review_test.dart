import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/shifts_subform_lines.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const _monday = LocalDate(2026, 10, 5);
const _tuesday = LocalDate(2026, 10, 6);

/// The rotation starting with Night: the 5th, changed as a Day shift, is a
/// Night now.
const _nightFirst = [
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
  CycleBlock(count: 3, shiftTypeId: null),
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('day')),
  CycleBlock(count: 3, shiftTypeId: null),
];

/// One Day, then off: the 6th, changed as a Day shift, is off now.
const _oneDay = [
  CycleBlock(count: 1, shiftTypeId: ShiftTypeId('day')),
  CycleBlock(count: 3, shiftTypeId: null),
  CycleBlock(count: 3, shiftTypeId: ShiftTypeId('night')),
  CycleBlock(count: 3, shiftTypeId: null),
];

void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
  });

  tearDown(() => fixture.dispose());

  /// Waits until [condition] holds, letting the database's streams run.
  Future<void> until(bool Function() condition) async {
    for (var turn = 0; turn < 200 && !condition(); turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition never held');
  }

  Future<ShiftsSheetController> open({ProductionWorkProviders? work}) async {
    final sheet = ShiftsSheetController(
      work: work ?? fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      month: ShiftsSheetFixture.month,
      today: ShiftsSheetFixture.today,
      timezoneId: ShiftsSheetFixture.zone,
      // Nothing here asks: Remove change writes no pay.
      confirm: ScriptedConfirm().call,
    )..start();
    addTearDown(sheet.dispose);
    await until(() => sheet.loaded);
    return sheet;
  }

  ShiftsLine lineOf(ShiftsSheetController sheet, String id) => shiftsLines(
    sheet,
    fixture.work.timezones,
  ).firstWhere((line) => line.id == id);

  DayPlanService scriptedPlans(PlanReadGate gate) => DayPlanService(
    repository: gate,
    shifts: fixture.schedule.shifts,
    ids: fixture.schedule.ids,
    clock: fixture.schedule.clock,
    zoneClocks: fixture.work.plans.zoneClocks,
  );

  for (final scenario in [
    (
      'lost but written',
      const Uncertain<DayException>(SafeFailureCode.commitOutcomeUnknown),
      true,
      0,
      ShiftsNotices.restored,
    ),
    (
      'lost not written',
      const Uncertain<DayException>(SafeFailureCode.commitOutcomeUnknown),
      false,
      0,
      ShiftsNotices.removeNotDone,
    ),
    (
      'readback unknown',
      const Uncertain<DayException>(SafeFailureCode.commitOutcomeUnknown),
      false,
      1,
      ShiftsNotices.removeUnknown,
    ),
    (
      'unavailable',
      const Unavailable<DayException>(SafeFailureCode.storageUnavailable),
      false,
      0,
      'Not done: local storage is unavailable. Try again.',
    ),
    (
      'confirmed',
      const Invalid<DayException>({}),
      false,
      0,
      'This day is already confirmed.',
    ),
  ]) {
    test('Remove change outcome: ${scenario.$1}', () async {
      await fixture.changeThenReshape(5, _nightFirst);
      final gate = PlanReadGate(fixture.work.plans.repository, failing: false)
        ..nextRemoval = scenario.$2
        ..removeBeforeReport = scenario.$3
        ..failReadsAfterRemoval = scenario.$4;
      final sheet = await open(
        work: fixture.work.replacing(plans: scriptedPlans(gate)),
      );
      await sheet.select(plannedRowId(_monday));
      await sheet.removeChange();
      expect(sheet.notice, scenario.$5);
      expect(sheet.selectedId, plannedRowId(_monday));
    });
  }

  test(
    'selection stays during Remove change and quit waits for its command',
    () async {
      await fixture.changeThenReshape(5, _nightFirst);
      final answer = Completer<MutationOutcome<DayException>>();
      final gate = PlanReadGate(fixture.work.plans.repository, failing: false)
        ..nextRemoval = answer.future;
      final sheet = await open(
        work: fixture.work.replacing(plans: scriptedPlans(gate)),
      );
      await sheet.select(plannedRowId(_monday));
      final removing = sheet.removeChange();
      expect(await sheet.select(plannedRowId(_tuesday)), isFalse);
      var quitFinished = false;
      final quitting = sheet.coordinator.quit().then((value) {
        quitFinished = true;
        return value;
      });
      await pumpEventQueue();
      expect(quitFinished, isFalse);
      answer.complete(const Unavailable(SafeFailureCode.storageUnavailable));
      await removing;
      expect(await quitting, isTrue);
      expect(sheet.selectedId, plannedRowId(_monday));
    },
  );

  test('a change that no longer fits its schedule is listed as Needs '
      'review, read-only, beside the plan it no longer fits', () async {
    await fixture.changeThenReshape(5, _nightFirst);
    final sheet = await open();
    final id = plannedRowId(_monday);
    expect(sheet.rows.firstWhere((row) => row.id == id), isA<ReviewRow>());
    final line = lineOf(sheet, id);
    expect(line.status, ShiftsStatus.review);
    expect(
      (line.start, line.end),
      (const LocalTime(7, 0), const LocalTime(20, 0)),
    );
    expect(countsInTotals(line), isFalse);

    expect(await sheet.select(id), isTrue);
    expect(sheet.edit, isNull);
    expect(sheet.readOnlyReason, ShiftsNotices.needsReview);
    expect(sheet.removeChangeBlocked, isNull);
    expect(sheet.correctBlocked, ShiftsCommandWords.correctOnlyFinalized);
    expect(
      sheet.editField(id, ShiftsField.end, const LocalTime(19, 0)),
      ShiftsEditProblems.notEditable,
    );
    final plan = dayPlanLines(sheet, line, fixture.work.timezones)!;
    expect(
      [for (final value in plan) (value.label, value.start)],
      [
        ('Plan', const LocalTime(19, 0)),
        ('This change', const LocalTime(7, 0)),
      ],
    );
    expect(breaksOf(sheet, fixture.work.timezones), isEmpty);
  });

  test('Remove change opens the day as its cycle plans it now, ready to '
      'edit', () async {
    await fixture.changeThenReshape(5, _nightFirst);
    final sheet = await open();
    final id = plannedRowId(_monday);
    await sheet.select(id);
    await sheet.removeChange();
    expect(sheet.notice, ShiftsNotices.restored);
    expect(sheet.selectedId, id);
    expect(sheet.edit, isA<PlannedEdit>());
    expect(sheet.edit!.value(ShiftsField.start), const LocalTime(19, 0));
    expect(
      (await fixture.work.plans.repository.planInputs(fixtureEmployment))
          .exceptions,
      isEmpty,
    );
    // The planned feed lists the day once it reads the plan again.
    await until(() => sheet.selectedRow is PlannedRow);
    expect(sheet.rows.whereType<ReviewRow>(), isEmpty);
  });

  test(
    'overlapping planned and review snapshots publish each day only once',
    () async {
      final sheet = await open();
      final earlierPlan = sheet.rows
          .whereType<PlannedRow>()
          .map((row) => row.planned)
          .toList();
      await fixture.changeThenReshape(5, _nightFirst);
      await until(() => sheet.rows.whereType<ReviewRow>().isNotEmpty);
      final review = sheet.rows
          .whereType<ReviewRow>()
          .map((row) => row.day)
          .toList();
      final merged = mergeShiftsRows(
        stored: const [],
        planned: earlierPlan,
        review: review,
      );
      expect(merged.map((row) => row.id).toSet(), hasLength(merged.length));
      expect(
        merged.where((row) => row.date == _monday).single,
        isA<ReviewRow>(),
      );
      await sheet.select(plannedRowId(_monday));
      await sheet.removeChange();
      await until(() => sheet.rows.whereType<ReviewRow>().isEmpty);
      final restoredPlan = sheet.rows
          .whereType<PlannedRow>()
          .map((row) => row.planned)
          .toList();
      final removing = mergeShiftsRows(
        stored: const [],
        planned: restoredPlan,
        review: review,
      );
      expect(removing.map((row) => row.id).toSet(), hasLength(removing.length));
    },
  );

  test('Remove change on a day the schedule now leaves off clears the '
      'selection', () async {
    await fixture.changeThenReshape(6, _oneDay);
    final sheet = await open();
    await sheet.select(plannedRowId(_tuesday));
    await sheet.removeChange();
    expect(sheet.notice, ShiftsNotices.restoredOff);
    expect(sheet.selectedId, isNull);
    await until(() => sheet.rows.whereType<ReviewRow>().isEmpty);
    // The day is Off now: only its Off row is left.
    expect(sheet.rows.where((row) => row.date == _tuesday), [isA<OffRow>()]);
  });

  test(
    'a change removed elsewhere meanwhile shows the day as it is now',
    () async {
      final change = await fixture.changeThenReshape(5, _nightFirst);
      final sheet = await open();
      await sheet.select(plannedRowId(_monday));
      await fixture.work.plans.removeException(
        change.id,
        expected: change.revision,
      );
      await sheet.removeChange();
      expect(sheet.notice, ShiftsNotices.reviewChanged);
      expect(sheet.edit, isA<PlannedEdit>());
    },
  );
}
