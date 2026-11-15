import 'package:drift/drift.dart'
    show QueryInterceptor, QueryExecutor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_edit/shift_edit.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart'
    show AgreementTerms, ChangeAgreementTermsCommand;
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show
        click,
        gridCell,
        liveToolbarKey,
        press,
        propertyEditor,
        propertyValue,
        pushKey,
        toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';

const _monday = LocalDate(2026, 10, 5);

const _tuesday = LocalDate(2026, 10, 6);

void main() {
  late ShiftsSheetFixture fixture;

  Future<void> pumpSheet(WidgetTester tester) async =>
      fixture = await pumpShiftsSheet(tester);

  testWidgets(
    'an unavailable new-shift write keeps its draft and reports failure',
    (tester) async {
      final gate = _WriteGate();
      fixture = await pumpShiftsSheet(
        tester,
        executor: NativeDatabase.memory().interceptWith(gate),
      );
      await click(tester, toolbarKey('New shift'));
      await settleSheet(tester);
      await stepGridTime(tester, newRowId, 'end', 'up');
      gate.failing = true;
      await click(tester, toolbarKey('Save'));
      await click(tester, pushKey('Save and finalize'));
      await settleSheet(tester);
      expect(sheetOf(tester).edit!.phase, EditPhase.failed);
      expect(sheetOf(tester).edit!.dirty, isTrue);
      expect(statusNotice(tester), EditProblems.unavailable);
      gate.failing = false;
      await closeShiftsSheet(tester, fixture);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  testWidgets('the sheet lists planned days with their properties', (
    tester,
  ) async {
    await pumpSheet(tester);
    final row = plannedRowId(_monday);
    expect(
      find.descendant(
        of: await gridCell(tester, row, 'status'),
        matching: find.text('To confirm'),
      ),
      findsOneWidget,
    );
    await selectShiftsRow(tester, row);
    expect(find.byKey(const ValueKey('property-value:start')), findsOneWidget);
    expect(statusNotice(tester), 'Ready.');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("a planned day's end edited in the grid saves without a window "
      'when another day is selected', (tester) async {
    await pumpSheet(tester);
    final row = plannedRowId(_monday);
    await selectShiftsRow(tester, row);
    await stepGridTime(tester, row, 'end', 'down');
    expect(
      statusNotice(tester),
      'Unsaved plan change: Mon 2026-10-05, End 19:00 → 18:00. Save, or '
      'leave the day, to keep it. Confirmation is separate.',
    );
    await selectShiftsRow(tester, plannedRowId(_tuesday));
    expect(find.byType(ConfirmWindow<ConfirmAnswer>), findsNothing);
    late List<DayException> exceptions;
    await tester.runAsync(() async {
      exceptions = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).exceptions;
    });
    expect((exceptions.single as ChangedDay).end, const LocalTime(18, 0));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('an end edited in the property column marks the grid', (
    tester,
  ) async {
    await pumpSheet(tester);
    final row = plannedRowId(_monday);
    await selectShiftsRow(tester, row);
    final value = find.byKey(const ValueKey('property-value:end'));
    await click(tester, value);
    await click(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('property-editor:end')),
        matching: find.byKey(const ValueKey('era-time-up')),
      ),
    );
    await press(tester, LogicalKeyboardKey.enter);
    await settleSheet(tester);
    final grid = tester.widget<DataGrid<Object?>>(shiftsGrid);
    expect(grid.pendingIds, {row});
    expect(grid.changed, contains(GridCell(row, 'end')));
    expect(statusNotice(tester), contains('End 19:00 → 20:00'));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a day that is gone offers Discard and return to sheet, '
      'which drops its values and selects nothing', (tester) async {
    await pumpSheet(tester);
    final row = plannedRowId(_monday);
    await selectShiftsRow(tester, row);
    await stepGridTime(tester, row, 'end', 'down');
    await tester.runAsync(
      () => fixture.work.plans.markLeave(
        fixtureEmployment,
        _monday,
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      ),
    );
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await click(tester, liveToolbarKey('Reload record'));
    await settleSheet(tester);
    expect(liveToolbarKey('Reload record'), findsNothing);
    await click(tester, liveToolbarKey('Discard and return to sheet'));
    await settleSheet(tester);
    expect(tester.widget<DataGrid<Object?>>(shiftsGrid).selectedId, isNull);
    expect(statusNotice(tester), 'Ready.');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a day changed elsewhere is stale; Reload record shows it', (
    tester,
  ) async {
    await pumpSheet(tester);
    final row = plannedRowId(_monday);
    await selectShiftsRow(tester, row);
    await stepGridTime(tester, row, 'end', 'down');
    await tester.runAsync(
      () => fixture.work.plans.changeDay(
        fixtureEmployment,
        _monday,
        start: const LocalTime(7, 0),
        end: const LocalTime(17, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
      ),
    );
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    expect(statusNotice(tester), EditProblems.stale);
    await click(tester, liveToolbarKey('Reload record'));
    await settleSheet(tester);
    expect(statusNotice(tester), 'Ready.');
    expect(
      find.descendant(
        of: await gridCell(tester, row, 'end'),
        matching: find.text('17:00'),
      ),
      findsOneWidget,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a selected day with unsaved values that leaves the plan stays '
      'on screen with its values', (tester) async {
    await pumpSheet(tester);
    final row = plannedRowId(_monday);
    await selectShiftsRow(tester, row);
    await stepGridTime(tester, row, 'end', 'down');
    await tester.runAsync(
      () => fixture.work.plans.cancelDay(
        fixtureEmployment,
        _monday,
        reason: CancelReason.dayOff,
        note: null,
      ),
    );
    await settleSheet(tester);
    expect(tester.takeException(), isNull);
    expect(
      statusNotice(tester),
      startsWith('Unsaved plan change: Mon 2026-10-05'),
    );
    expect(
      find.descendant(
        of: await gridCell(tester, row, 'end'),
        matching: find.text('18:00'),
      ),
      findsOneWidget,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the footer totals recorded shifts only: no void shift and no '
      'planned estimate', (tester) async {
    await pumpSheet(tester);
    await tester.runAsync(() async {
      await fixture.finishShift(20);
      final voided = await fixture.finishShift(21);
      await fixture.schedule.shifts.commitVoid(
        voided.id,
        expected: voided.revision,
        voidReason: 'Entered twice',
        nowUtc: fixture.schedule.clock.value,
      );
    });
    await settleSheet(tester);
    final grid = tester.widget<DataGrid<Object?>>(shiftsGrid);
    expect(grid.footerLabel, 'Total (1 shift)');
    expect(grid.footer!['paid'], '8:00');
    expect(grid.footer!['pay'], 'EUR 147.20');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('gross and net shifts are totalled apart, never as one sum', (
    tester,
  ) async {
    // Audit 9pk.4.35: 8 h gross at EUR 18.40, then net EUR 10.00 from
    // October 10.
    await pumpSheet(tester);
    await tester.runAsync(() async {
      await fixture.finishShift(8);
      final v1 = (await fixture.reads.agreement(
        fixtureEmployment,
        fixtureAgreement,
      ))!.value;
      final changed = await fixture.work.agreement.changeAgreementTerms(
        ChangeAgreementTermsCommand(
          agreementId: v1.id,
          employmentId: fixtureEmployment,
          expectedRevision: v1.revision,
          from: const LocalDate(2026, 10, 10),
          terms: AgreementTerms.of(v1)
              .change(basis: const NetBasis(), hourlyRateMicroEur: 10000000),
        ),
      );
      expect(changed, isA<Committed<PayAgreement>>());
      await fixture.finishShift(14);
    });
    await settleSheet(tester);
    final grid = tester.widget<DataGrid<Object?>>(shiftsGrid);
    expect(
      grid.footerLabel,
      'Total (2 shifts) · Gross EUR 147.20 · Net EUR 80.00',
    );
    expect(grid.footer!['paid'], '16:00');
    expect(grid.footer!['pay'], 'Mixed basis');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a new shift saves behind the finalization window', (
    tester,
  ) async {
    await pumpSheet(tester);
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    expect(statusNotice(tester), 'Ready.');
    await stepGridTime(tester, newRowId, 'end', 'up');
    expect(
      statusNotice(tester),
      'New shift: Tue 2026-10-20. Save to finalize it.',
    );
    await click(tester, toolbarKey('Save'));
    expect(find.text('Finalize shift'), findsOneWidget);
    expect(pushKey('Save and finalize'), findsOneWidget);
    expect(pushKey('Discard'), findsOneWidget);
    await click(tester, pushKey('Save and finalize'));
    await settleSheet(tester);
    late List<WorkShift> shifts;
    await tester.runAsync(() async {
      shifts = await fixture.reads.shiftsOf(fixtureEmployment);
    });
    expect(shifts.single.state, ShiftState.finalized);
    expect(shifts.single.endUtc, DateTime.utc(2026, 10, 20, 14));
    expect(statusNotice(tester), ShiftProblems.finalized);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Cancel in the finalization window keeps the new values', (
    tester,
  ) async {
    await pumpSheet(tester);
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    await stepGridTime(tester, newRowId, 'end', 'up');
    await click(tester, toolbarKey('Save'));
    await click(tester, pushKey('Cancel'));
    await settleSheet(tester);
    expect(
      statusNotice(tester),
      'New shift: Tue 2026-10-20. Save to finalize it.',
    );
    late List<WorkShift> shifts;
    await tester.runAsync(() async {
      shifts = await fixture.reads.shiftsOf(fixtureEmployment);
    });
    expect(shifts, isEmpty);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the grid shows a Type column after Date', (tester) async {
    await pumpSheet(tester);
    final grid = tester.widget<DataGrid<Object?>>(shiftsGrid);
    expect(
      [for (final column in grid.columns.take(2)) column.key],
      [ShiftsField.date, 'type'],
    );
    expect(
      find.descendant(
        of: await gridCell(tester, plannedRowId(_monday), 'type'),
        matching: find.text('Day'),
      ),
      findsOneWidget,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a finalized shift is read-only and says why', (tester) async {
    await pumpSheet(tester);
    late WorkShift finished;
    await tester.runAsync(() async {
      finished = await fixture.finishShift(20);
    });
    await settleSheet(tester);
    final row = storedRowId(finished);
    await selectShiftsRow(tester, row);
    expect(statusNotice(tester), ShiftProblems.finalized);
    // Neither the grid nor the property column opens an editor.
    final end = await gridCell(tester, row, 'end');
    await click(tester, end);
    await settleSheet(tester);
    expect(
      find.descendant(of: end, matching: find.byType(CellEditor)),
      findsNothing,
    );
    await click(tester, propertyValue(ShiftsField.end));
    await settleSheet(tester);
    expect(propertyEditor(ShiftsField.end), findsNothing);
    expect(statusNotice(tester), ShiftProblems.finalized);
    await closeShiftsSheet(tester, fixture);
  });
}

final class _WriteGate extends QueryInterceptor {
  bool failing = false;
  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (failing) throw const DatabaseOpenFailure();
    return executor.runInsert(statement, args);
  }
}
