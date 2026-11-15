import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/confirm_days_action.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/manual_shift_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart'
    show CloseAgreementCommand, VoidShiftCommand;
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart' show click, toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';

/// Finalizing the first day fails as storage would; the rest go through.
final class _RefusesFirst implements ManualShiftRepository {
  _RefusesFirst(this.inner);

  final ManualShiftRepository inner;
  bool refused = false;

  @override
  Future<MutationOutcome<WorkShift>> createAndFinalizeManual(
    WorkShift draft,
    List<ShiftBreak> breaks,
  ) {
    if (!refused) {
      refused = true;
      return Future.value(
        const Unavailable(SafeFailureCode.storageUnavailable),
      );
    }
    return inner.createAndFinalizeManual(draft, breaks);
  }
}

Finder _treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

DataGrid<ShiftsLine> _grid(WidgetTester tester) =>
    tester.widget<DataGrid<ShiftsLine>>(
      find.byWidgetPredicate(
        (widget) => widget is DataGrid && widget.label == 'To confirm',
      ),
    );

List<String> _groups(WidgetTester tester) => [
  for (final line in _grid(tester).lines)
    if (line is GridGroup<ShiftsLine>) line.label,
];

List<LocalDate> _days(WidgetTester tester) => [
  for (final line in _grid(tester).lines)
    if (line is GridRow<ShiftsLine>) line.row.date,
];

final _window = find.byWidgetPredicate((widget) => widget is ConfirmWindow);

ActionPanel _panel(WidgetTester tester) =>
    tester.widget<ActionPanel>(find.byType(ActionPanel));

/// The To confirm sheet and Confirm worked days (plan 4d-2, Task 6).
void main() {
  testWidgets("the tree's To confirm lists the past days to confirm, oldest "
      'first', (tester) async {
    await pumpShiftsSheet(tester);
    await click(tester, _treeNode('To confirm'));
    await settleSheet(tester);
    expect(shellOf(tester).location.sheet, WorkSheetKind.toConfirm);
    expect(_groups(tester), ['Days to confirm (9)']);
    expect(_days(tester).first, const LocalDate(2026, 10, 5));
    expect(_days(tester).last, const LocalDate(2026, 10, 19));
    expect(_days(tester), hasLength(9));
    expect(find.text('All past days'), findsOneWidget);
    expect(find.text('Off days'), findsNothing);
    expect(
      tester.widget<StatusBar>(find.byType(StatusBar)).panels.first.text,
      '9 days',
    );
    expect(sheetOf(tester).addBlocked, isNotNull);
  });

  testWidgets('a day without an agreement is listed after them with Extend '
      'pay agreement…', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.toConfirm(fixtureEmployment).toUri()}',
      ),
    );
    await tester.runAsync(() async {
      final current = (await fixture.reads.agreementsOf(fixtureEmployment))
          .single;
      await fixture.work.agreement.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: fixtureEmployment,
          end: const LocalDate(2026, 10, 6),
          expectedRevision: current.revision,
        ),
      );
    });
    await settleSheet(tester);
    expect(_groups(tester), [
      'Days to confirm (2)',
      'Without a pay agreement (7)',
    ]);
    expect(find.text('Extend pay agreement…'), findsOneWidget);
    await click(tester, find.text('Extend pay agreement…'));
    await settleSheet(tester);
    expect(_window, findsOneWidget);
    await click(
      tester,
      find.descendant(of: _window, matching: find.text('Cancel')),
    );
    await settleSheet(tester);
  });

  testWidgets('from Shifts, Confirm worked days… moves to To confirm in pick '
      'mode', (tester) async {
    await pumpShiftsSheet(tester);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    expect(shellOf(tester).location.sheet, WorkSheetKind.toConfirm);
    expect(_grid(tester).pickMode, isTrue);
    expect(_grid(tester).pickedIds, hasLength(9));
    expect(_grid(tester).footerLabel, 'Ticked (9 days)');
    expect(_panel(tester).primaryLabel, 'Confirm 9 days');
    expect(tester.widget<TreeView>(find.byType(TreeView)).enabled, isFalse);
    expect(
      tester.widget<FilterStrip>(find.byType(FilterStrip)).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<Subform>(find.byType(Subform))
          .tabs
          .where((tab) => tab.id != AppFrame.propertiesTabId)
          .every((tab) => !tab.enabled),
      isTrue,
    );
    expect(statusNotice(tester), ConfirmDaysWords.picking(9));
    await click(tester, toolbarKey('Back'));
    await settleSheet(tester);
    expect(_window, findsNothing);
    expect(shellOf(tester).location.sheet, WorkSheetKind.shifts);
  });

  testWidgets('untick, confirm, and the counts follow', (tester) async {
    await pumpShiftsSheet(tester);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    // Clicking a row ticks or unticks it.
    await click(tester, find.text('Tue 2026-10-06').first);
    await settleSheet(tester);
    expect(_grid(tester).footerLabel, 'Ticked (8 days)');
    await click(tester, find.widgetWithText(KeyButton, 'Confirm 8 days'));

    await settleSheet(tester);
    expect(_window, findsOneWidget);
    await click(
      tester,
      find.descendant(of: _window, matching: find.text('Confirm 8 days')),
    );
    await settleSheet(tester);
    expect(find.byType(ActionPanel), findsNothing);
    expect(statusNotice(tester), ConfirmDaysWords.allDone(8));
    expect(shellOf(tester).pastDays[fixtureEmployment]!.toConfirm, 1);
    expect(_days(tester), [const LocalDate(2026, 10, 6)]);
  });

  testWidgets('a storage failure leaves results and Retry', (tester) async {
    await pumpShiftsSheet(
      tester,
      work: (fixture) {
        final plans = fixture.work.plans;
        return fixture.work.replacing(
          plans: DayPlanService(
            repository: plans.repository,
            shifts: _RefusesFirst(plans.shifts),
            ids: plans.ids,
            clock: plans.clock,
            zoneClocks: plans.zoneClocks,
          ),
        );
      },
    );
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    await click(tester, find.widgetWithText(KeyButton, 'Confirm 9 days'));
    await settleSheet(tester);
    await click(
      tester,
      find.descendant(of: _window, matching: find.text('Confirm 9 days')),
    );
    await settleSheet(tester);
    final results = _panel(tester).results;
    expect(results.first.outcome, ActionOutcome.failed);
    expect(results.first.detail, ConfirmDaysWords.unavailable);
    expect(
      results.skip(1).every((result) => result.outcome == ActionOutcome.done),
      isTrue,
    );
    expect(_panel(tester).primaryLabel, 'Retry 1 day');
    expect(_panel(tester).cancelLabel, 'Close');
    await click(tester, find.widgetWithText(KeyButton, 'Close'));
    await settleSheet(tester);
    expect(
      find.descendant(
        of: _window,
        matching: find.text(ConfirmDaysWords.closeLeft(8, 1)),
      ),
      findsOneWidget,
    );
    await click(
      tester,
      find.descendant(of: _window, matching: find.text('Keep open')),
    );
    await settleSheet(tester);
    expect(find.byType(ActionPanel), findsOneWidget);
  });

  testWidgets("a void shift on a day sent shows no result of the day's", (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(
      tester,
      work: (fixture) {
        final plans = fixture.work.plans;
        return fixture.work.replacing(
          plans: DayPlanService(
            repository: plans.repository,
            shifts: _RefusesFirst(plans.shifts),
            ids: plans.ids,
            clock: plans.clock,
            zoneClocks: plans.zoneClocks,
          ),
        );
      },
    );
    await tester.runAsync(() async {
      final shift = await fixture.finishShift(6);
      await fixture.work.shifts.voidShift(
        VoidShiftCommand(
          id: shift.id,
          expectedRevision: shift.revision,
          voidReason: 'Entered twice',
        ),
      );
    });
    await settleSheet(tester);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    await click(tester, find.widgetWithText(KeyButton, 'Confirm 9 days'));
    await settleSheet(tester);
    await click(
      tester,
      find.descendant(of: _window, matching: find.text('Confirm 9 days')),
    );
    await settleSheet(tester);
    expect(find.byType(ActionPanel), findsOneWidget);
    final sixth = [
      for (final line in _grid(tester).lines)
        if (line is GridRow<ShiftsLine> &&
            line.row.date == const LocalDate(2026, 10, 6))
          line.row,
    ];
    expect(sixth.map((line) => line.status), [ShiftsStatus.finalized]);
  });

  testWidgets("Details' To confirm warning opens the sheet", (tester) async {
    await pumpShiftsSheet(tester);
    await click(tester, find.text('To confirm: 9 days'));
    await settleSheet(tester);
    expect(shellOf(tester).location.sheet, WorkSheetKind.toConfirm);
  });

  testWidgets('Find does not hide days that pick mode would confirm', (
    tester,
  ) async {
    await pumpShiftsSheet(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('work-find')),
        matching: find.byType(EditableText),
      ),
      'Mon',
    );
    await settleSheet(tester);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    expect(_days(tester), hasLength(9));
    expect(_grid(tester).pickedIds, hasLength(9));
  });

  testWidgets('the panel holds no keyboard link; the group row extends', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() async {
      final current = (await fixture.reads.agreementsOf(fixtureEmployment))
          .single;
      await fixture.work.agreement.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: fixtureEmployment,
          end: const LocalDate(2026, 10, 6),
          expectedRevision: current.revision,
        ),
      );
    });
    await settleSheet(tester);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    expect(
      find.descendant(
        of: find.byType(ActionPanel),
        matching: find.byType(EraPressable),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataGrid<ShiftsLine>),
        matching: find.text('Extend pay agreement…'),
      ),
      findsOneWidget,
    );
  });
}
