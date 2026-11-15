import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/day_action.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show
        click,
        comboChoice,
        gridCell,
        press,
        propertyValue,
        pushKey,
        showProperties,
        toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';

/// The day actions of plan 4d-1 on the depot's October, driven through the
/// shell with the mouse: toolbar keys, panel keys, Add ▾ and the
/// confirmation window. The depot plans Day on 5–7, 17–19 and 29–31, Night
/// on 11–13 and 23–25; today is the 20th.

String _day(int day) => plannedRowId(LocalDate(2026, 10, day));

/// The key labelled [label] in the open action panel.
Finder _panelKey(String label) =>
    find.descendant(of: find.byType(ActionPanel), matching: pushKey(label));

/// The key labelled [label] in the confirmation window.
Finder _windowKey(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is ConfirmWindow),
  matching: pushKey(label),
);

Future<void> _expectStatus(
  WidgetTester tester,
  String row,
  String words,
) async {
  expect(
    find.descendant(
      of: await gridCell(tester, row, 'status'),
      matching: find.text(words),
    ),
    findsOneWidget,
    reason: '$row reads $words',
  );
}

/// The count the tree shows beside [label], as " (9)"; null when none.
String? _treeCount(WidgetTester tester, String label) {
  final row = find
      .ancestor(
        of: find.descendant(
          of: find.byType(TreeView),
          matching: find.text(label),
        ),
        matching: find.byType(Row),
      )
      .first;
  return tester
      .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .map((text) => text.data)
      .where((text) => text != null && text.startsWith(' ('))
      .firstOrNull;
}

/// What the tree and the status bar say waits to be confirmed.
void _expectWaiting(WidgetTester tester, int days) {
  expect(_treeCount(tester, 'To confirm'), ' ($days)');
  expect(
    tester.widget<StatusBar>(find.byType(StatusBar)).warning,
    days == 1 ? '1 day to confirm' : '$days days to confirm',
  );
}

/// Chooses [choice] in [combo] with the mouse; Enter takes it.
Future<void> _choose(WidgetTester tester, Finder combo, String choice) async {
  await click(tester, combo);
  await settleSheet(tester);
  await click(tester, comboChoice(choice));
  await press(tester, LogicalKeyboardKey.enter);
  await settleSheet(tester);
}

/// The open action panel's combo number [index].
Finder _panelCombo(int index) => find
    .descendant(
      of: find.byType(ActionPanel),
      matching: find.byType(EraCombo<Object?>),
    )
    .at(index);

/// Chooses [choice] for the selected record's property [key].
Future<void> _chooseProperty(
  WidgetTester tester,
  String key,
  String choice,
) async {
  await showProperties(tester);
  // The first click opens the value's editor.
  await click(tester, propertyValue(key));
  await settleSheet(tester);
  await _choose(
    tester,
    find.descendant(
      of: propertyValue(key),
      matching: find.byType(EraCombo<Object?>),
    ),
    choice,
  );
}

void main() {
  testWidgets('every day action from the toolbar, Add ▾ and the panels', (
    tester,
  ) async {
    await pumpShiftsSheet(tester);
    final sheet = sheetOf(tester);
    _expectWaiting(tester, 9);

    // A planned day's type: Night instead of Day, saved as a change.
    await selectShiftsRow(tester, _day(6));
    await _chooseProperty(tester, ShiftsField.type, 'Night');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await _expectStatus(tester, _day(6), 'Changed, to confirm');

    // Confirm one day: it is finalized at once and the count drops.
    await selectShiftsRow(tester, _day(5));
    await click(tester, toolbarKey('Confirm'));
    await settleSheet(tester);
    expect(sheet.selectedRow, isA<StoredRow>());
    final confirmed = (sheet.selectedRow! as StoredRow).shift;
    expect(confirmed.state, ShiftState.finalized);
    _expectWaiting(tester, 8);

    // Cancel shift… then Restore shift.
    await selectShiftsRow(tester, _day(7));
    await click(tester, toolbarKey('Cancel shift…'));
    await settleSheet(tester);
    await _choose(tester, _panelCombo(0), 'Day off');
    await click(tester, _panelKey(DayActionWords.cancelTitle));
    await settleSheet(tester);
    await _expectStatus(tester, _day(7), 'Cancelled · Day off');
    _expectWaiting(tester, 7);
    await click(tester, toolbarKey('Restore shift'));
    await settleSheet(tester);
    await _expectStatus(tester, _day(7), 'To confirm');
    _expectWaiting(tester, 8);

    // Mark as leave…, then Change leave in the property column.
    await selectShiftsRow(tester, _day(11));
    await click(tester, toolbarKey('Mark as leave…'));
    await settleSheet(tester);
    await _choose(tester, _panelCombo(0), 'Sick');
    await click(tester, _panelKey(DayActionWords.leaveTitle));
    await settleSheet(tester);
    await _expectStatus(tester, _day(11), 'Sick, to confirm');
    await _chooseProperty(tester, ShiftsField.leaveType, 'Vacation');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await _expectStatus(tester, _day(11), 'Vacation, to confirm');

    // An extra shift on an Off day, from Add ▾, counted as overtime.
    await click(tester, find.text('Off days'));
    await settleSheet(tester);
    await selectShiftsRow(tester, 'off:2026-10-09');
    await click(tester, toolbarKey('Add'));
    await settleSheet(tester);
    await click(tester, find.text('Extra shift on Fri 2026-10-09'));
    await settleSheet(tester);
    expect(sheet.selectedId, newExtraRowId);
    await showProperties(tester);
    await click(tester, propertyValue(ShiftsField.overtime));
    await settleSheet(tester);
    await click(
      tester,
      find.descendant(
        of: propertyValue(ShiftsField.overtime),
        matching: find.byKey(const ValueKey('era-check-box')),
      ),
    );
    await press(tester, LogicalKeyboardKey.enter);
    await settleSheet(tester);
    expect(sheet.edit!.value(ShiftsField.overtime), isTrue);
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    await _expectStatus(tester, _day(9), 'Extra, to confirm');

    // Correct… the confirmed day, then Finalize its unchanged draft.
    await selectShiftsRow(tester, shiftRowId(confirmed.id));
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    final reason = find.byKey(const ValueKey('action-reason'));
    await click(tester, reason);
    await tester.enterText(reason, 'Wrong type');
    await tester.pump();
    await click(tester, _panelKey(ShiftsActionWords.correctPrimary));
    await settleSheet(tester);
    expect((sheet.selectedRow as StoredRow?)?.shift.state, ShiftState.draft);
    await click(tester, toolbarKey('Finalize'));
    await settleSheet(tester);
    await click(tester, _windowKey('Save and finalize'));
    await settleSheet(tester);
    expect(sheet.edit, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets("an archived employment's Day keys are greyed with why", (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() async {
      final employment = (await fixture.reads.employment(fixtureEmployment))!
          .value;
      await fixture.work.employment.archiveEmployment(
        ArchiveEmploymentCommand(
          employmentId: fixtureEmployment,
          expectedRevision: employment.revision,
        ),
      );
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, _day(6));
    for (final label in [
      'New shift',
      'Confirm',
      'Restore shift',
      'Cancel shift…',
      'Mark as leave…',
      'Finalize',
    ]) {
      final key = tester.widget<KeyButton>(toolbarKey(label));
      expect(key.onPressed, isNull, reason: label);
      expect(key.tooltip, EmploymentsWords.archivedReadOnly, reason: label);
    }
  });
}
