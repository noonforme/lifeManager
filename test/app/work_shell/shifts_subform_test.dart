import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_subform.dart';
import 'package:lifeos/app/work_shell/shifts_subform_lines.dart';
import 'package:lifeos/core/history/record_events.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/domain/work_formats.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, gridCell, pushKey, toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';

const _monday = LocalDate(2026, 10, 5);

void main() {
  late ShiftsSheetFixture fixture;

  /// The Breaks grid's cell of [column] in break [index] of [record].
  Future<Finder> breakCell(
    WidgetTester tester,
    String record,
    int index,
    String column,
  ) => gridCell(tester, breakRowId(record, index), column);

  SubformTab dayPlanTab(WidgetTester tester) => tester
      .widget<Subform>(find.byType(Subform))
      .tabs
      .firstWhere((tab) => tab.id == ShiftsSubformTab.dayPlan);

  Finder textIn(Finder of, String text) =>
      find.descendant(of: of, matching: find.text(text));

  Future<List<DayException>> exceptions(WidgetTester tester) async {
    late List<DayException> value;
    await tester.runAsync(() async {
      value = (await fixture.work.plans.repository.planInputs(
        fixtureEmployment,
      )).exceptions;
    });
    return value;
  }

  testWidgets("a break's end edited in the Breaks tab saves with its day", (
    tester,
  ) async {
    fixture = await pumpShiftsSheet(tester);
    final day = plannedRowId(_monday);
    await selectShiftsRow(tester, day);
    expect(
      textIn(await breakCell(tester, day, 0, 'start'), '12:00'),
      findsOneWidget,
    );
    // A first click selects the break; the next opens its end.
    await click(tester, await breakCell(tester, day, 0, 'length'));
    await stepTimeIn(tester, await breakCell(tester, day, 0, 'end'), 'up');
    expect(
      textIn(await breakCell(tester, day, 0, 'length'), '1:30'),
      findsOneWidget,
    );
    // The parent's derived break and paid time follow the child at once.
    expect(
      textIn(await gridCell(tester, day, 'break'), '1:30'),
      findsOneWidget,
    );
    expect(
      textIn(await gridCell(tester, day, 'paid'), '10:30'),
      findsOneWidget,
    );
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    expect(((await exceptions(tester)).single as ChangedDay).breaks, const [
      FixedBreak(start: _noon, dayOffset: 0, minutes: 90),
    ]);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a break is added with the new row and removed with Remove '
      'break; Undo brings the day back whole', (tester) async {
    fixture = await pumpShiftsSheet(tester);
    final day = plannedRowId(_monday);
    await selectShiftsRow(tester, day);
    await click(
      tester,
      find.descendant(
        of: subformGrid('Breaks'),
        matching: find.byKey(const ValueKey('grid-new-row')),
      ),
    );
    await settleSheet(tester);
    // The new break follows the last one.
    expect(
      textIn(await breakCell(tester, day, 1, 'start'), '12:30'),
      findsOneWidget,
    );
    expect(
      textIn(await gridCell(tester, day, 'break'), '1:00'),
      findsOneWidget,
    );
    await click(tester, await breakCell(tester, day, 0, 'length'));
    await click(tester, pushKey(ShiftsSubformWords.removeBreak));
    await settleSheet(tester);
    expect(
      tester.widget<DataGrid<Object?>>(subformGrid('Breaks')).lines,
      hasLength(1),
    );
    expect(statusNotice(tester), startsWith('Unsaved plan change'));
    await click(tester, toolbarKey('Undo'));
    await settleSheet(tester);
    expect(
      textIn(await breakCell(tester, day, 0, 'start'), '12:00'),
      findsOneWidget,
    );
    expect(statusNotice(tester), 'Ready.');
    expect(
      tester.widget<DataGrid<Object?>>(subformGrid('Breaks')).lines,
      hasLength(1),
    );
    expect(
      textIn(await breakCell(tester, day, 0, 'end'), '12:30'),
      findsOneWidget,
    );
    expect(
      textIn(await gridCell(tester, day, 'break'), '0:30'),
      findsOneWidget,
    );
    expect(await exceptions(tester), isEmpty);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Add break and Remove break refused during a save say why in '
      'the status line', (tester) async {
    fixture = await pumpShiftsSheet(tester);
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    await click(
      tester,
      find.descendant(
        of: subformGrid('Breaks'),
        matching: find.byKey(const ValueKey('grid-new-row')),
      ),
    );
    await settleSheet(tester);
    await click(tester, await breakCell(tester, newRowId, 0, 'length'));
    // Keys pressed in the same moment as Save, before the sheet redraws.
    final add = tester.widget<DataGrid<Object?>>(subformGrid('Breaks')).onNew!;
    final remove = tester
        .widget<KeyButton>(pushKey(ShiftsSubformWords.removeBreak))
        .onPressed!;
    await click(tester, toolbarKey('Save'));
    expect(find.text('Finalize shift'), findsOneWidget);
    add();
    await tester.pump();
    expect(statusNotice(tester), EditProblems.busy);
    remove();
    await tester.pump();
    expect(statusNotice(tester), EditProblems.busy);
    await click(tester, pushKey('Cancel'));
    await settleSheet(tester);
    expect(statusNotice(tester), startsWith('New shift'));
    expect(
      tester.widget<DataGrid<Object?>>(subformGrid('Breaks')).lines,
      hasLength(1),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a selected break does not carry over to another day', (
    tester,
  ) async {
    fixture = await pumpShiftsSheet(tester);
    final monday = plannedRowId(_monday);
    await selectShiftsRow(tester, monday);
    await click(tester, await breakCell(tester, monday, 0, 'length'));
    KeyButton remove() =>
        tester.widget<KeyButton>(pushKey(ShiftsSubformWords.removeBreak));
    expect(remove().onPressed, isNotNull);
    await selectShiftsRow(tester, plannedRowId(const LocalDate(2026, 10, 6)));
    expect(remove().onPressed, isNull);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("a finalized shift's history lists its events; a planned day "
      'has none', (tester) async {
    fixture = await pumpShiftsSheet(tester);
    late WorkShift finished;
    await tester.runAsync(() async {
      finished = await fixture.finishShift(20);
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, plannedRowId(_monday));
    await openSubformTab(tester, 'History');
    expect(subformGrid('History'), findsOneWidget);
    expect(textIn(subformGrid('History'), 'Created'), findsNothing);
    await selectShiftsRow(tester, storedRowId(finished));
    await settleSheet(tester);
    expect(textIn(subformGrid('History'), 'Created'), findsOneWidget);
    // A new shift has no stored record either.
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    expect(subformGrid('History'), findsOneWidget);
    expect(textIn(subformGrid('History'), 'Created'), findsNothing);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Working shows the pay groups and the estimate of the pending '
      'values', (tester) async {
    fixture = await pumpShiftsSheet(tester);
    final day = plannedRowId(_monday);
    await selectShiftsRow(tester, day);
    await openSubformTab(tester, 'Working');
    var grid = tester.widget<DataGrid<Object?>>(subformGrid('Working'));
    expect(grid.footerLabel, 'Est. pay EUR 211.60');
    await stepGridTime(tester, day, 'end', 'down');
    grid = tester.widget<DataGrid<Object?>>(subformGrid('Working'));
    expect(grid.footerLabel, 'Est. pay EUR 193.20');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Working explains a planned leave day\'s Est. pay', (
    tester,
  ) async {
    fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(
      () => fixture.work.plans.markLeave(
        fixtureEmployment,
        _monday,
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      ),
    );
    await settleSheet(tester);
    final day = plannedRowId(_monday);
    await selectShiftsRow(tester, day);
    final pay = shiftsLines(
      sheetOf(tester),
      fixture.work.timezones,
    ).singleWhere((line) => line.id == day).pay;
    expect(pay, isNotNull);
    await openSubformTab(tester, 'Working');
    final grid = tester.widget<DataGrid<Object?>>(subformGrid('Leave working'));
    expect(grid.footerLabel, 'Pay ${formatMoney(pay!)}');
    expect(find.text('Agreement rate'), findsOneWidget);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("Day plan sets a planned day beside its plan; a manual shift's "
      'tab is greyed', (tester) async {
    fixture = await pumpShiftsSheet(tester);
    final day = plannedRowId(_monday);
    await selectShiftsRow(tester, day);
    await stepGridTime(tester, day, 'end', 'down');
    await openSubformTab(tester, 'Day plan');
    expect(
      textIn(await gridCell(tester, 'plan:Plan', 'end'), '19:00'),
      findsOneWidget,
    );
    expect(
      textIn(await gridCell(tester, 'plan:This day', 'end'), '18:00'),
      findsOneWidget,
    );
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    final tab = dayPlanTab(tester);
    expect(tab.enabled, isFalse);
    expect(tab.disabledReason, ShiftsSubformWords.noPlan);
    // The greyed tab stays shown as an empty grid; its tooltip says why.
    expect(subformGrid('Day plan'), findsOneWidget);
    expect(find.byType(OperationalState), findsNothing);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("Day plan's greyed tab says why: nothing selected, or the cycle "
      'plans no work on an extra day', (tester) async {
    fixture = await pumpShiftsSheet(tester);
    expect(dayPlanTab(tester).enabled, isFalse);
    expect(dayPlanTab(tester).disabledReason, ShiftsSubformWords.noRecord);
    const thursday = LocalDate(2026, 10, 8);
    await tester.runAsync(
      () => fixture.work.plans.addExtra(
        fixtureEmployment,
        thursday,
        start: const LocalTime(9, 0),
        end: const LocalTime(13, 0),
        endDayOffset: 0,
        breaks: const [],
        shiftTypeId: null,
        countsAsOvertime: false,
      ),
    );
    await settleSheet(tester);
    await selectShiftsRow(tester, plannedRowId(thursday));
    expect(dayPlanTab(tester).enabled, isFalse);
    expect(dayPlanTab(tester).disabledReason, ShiftsSubformWords.noCyclePlan);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a History feed that fails says so', (tester) async {
    await tester.pumpWidget(
      GalleryHost(
        home: RecordHistoryTab(
          recordKind: 'shift',
          history: _FailingHistory(),
          recordId: 'shift-1',
          editors: EditorSessionController(),
        ),
      ),
    );
    await tester.pump();
    final state = tester.widget<OperationalState>(
      find.byType(OperationalState),
    );
    expect(state.kind, OperationalStateKind.unavailable);
    expect(state.title, ShiftsSubformWords.historyUnreadable);
  });
}

const _noon = LocalTime(12, 0);

/// A history whose feed cannot be read.
final class _FailingHistory implements RecordHistory {
  @override
  Stream<List<RecordEvent>> watch(String recordKind, String recordId) =>
      Stream.error(StateError('Local storage cannot be read.'));
}
