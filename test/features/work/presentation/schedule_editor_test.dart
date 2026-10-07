import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/schedule_editor.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';

import 'package:lifeos/shared/workbench/office_controls.dart';

import '../../../support/era_pickers.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

const _properties =
    '/work?employment={employment}&sheet=schedules'
    '&record=schedule:{schedule}&mode=properties';

Finder _inSubDialog(String text) =>
    find.descendant(of: find.byType(EraDialog).last, matching: find.text(text));

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(PropertySheetTabs),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('field issues are worded on their fields', () {
    final errors = scheduleErrors({
      'blocks[2].count': const [FieldIssue(FieldIssueCode.invalid)],
      'inUseFrom': const [FieldIssue(FieldIssueCode.conflict)],
    });
    expect(errors['blocks[2].count'], 'Enter 1 to 99.');
    expect(
      errors['inUseFrom'],
      'Another schedule of this employment is in use on these dates.',
    );
    expect(scheduleErrorTab(['blocks[2].count']), 1);
    expect(scheduleErrorTab(['blocks[2].count', 'name']), 0);
  });

  testWidgets('a schedule opens on its Properties with its tabs', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _properties);
    expect(dialogTitled('Depot rotation Properties'), findsOneWidget);
    for (final tab in ['Schedule', 'Cycle', 'Preview', 'History']) {
      expect(find.text(tab), findsWidgets);
    }
    await _tab(tester, 'Cycle');
    expect(find.text('Cycle — 12 days'), findsOneWidget);
    await _tab(tester, 'Preview');
    expect(find.text('Preview — October 2026'), findsOneWidget);
    expect(find.text('Day 07:00–19:00'), findsWidgets);
  });

  testWidgets('a count of 0 is refused on its row and brings Cycle forward', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _properties);
    await _tab(tester, 'Cycle');
    await tester.enterText(find.byKey(const ValueKey('block-1-count')), '0');
    await _tab(tester, 'Schedule');
    await tapInDialog(tester, find.text('Apply'));
    expect(find.text('Enter 1 to 99.'), findsOneWidget);
    expect(find.text('Cycle — 9 days'), findsOneWidget);
  });

  testWidgets('Alt+Down moves a block down the cycle', (tester) async {
    await pumpScheduledApp(tester, location: _properties);
    await _tab(tester, 'Cycle');
    await tester.tap(find.byKey(const ValueKey('block-0-count')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    // Day's row moved below the first row, which is now an Off block.
    expect(
      tester.getTopLeft(find.text('07:00–19:00, break 30 min')).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const ValueKey('block-0-count'))).dy + 10,
      ),
    );
  });

  testWidgets('a version a confirmed day uses asks where the new one starts; '
      'Cancel saves nothing', (tester) async {
    final app = await pumpScheduledApp(tester, location: _properties);
    await tester.runAsync(
      () => app.work.plans.confirm(
        EmploymentId(app.employment),
        const LocalDate(2026, 10, 5),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation 2',
    );
    await tapInDialog(tester, find.text('Apply'));
    expect(find.text('Schedule in use'), findsOneWidget);
    await tester.tap(_inSubDialog('Cancel'));
    await tester.pumpAndSettle();
    // Nothing saved; the sheet is still open and its edit still waiting.
    expect(dialogTitled('Depot rotation Properties'), findsOneWidget);
    expect(find.text('Schedule saved.'), findsNothing);
    await tapInDialog(tester, find.text('Apply'));
    await pickDate(tester, 'new-version-from', const LocalDate(2026, 10, 20));
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule saved.'), findsOneWidget);
  });

  testWidgets('New schedule… creates one and shows its Calendar', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester, withSchedule: false);
    await tester.tap(find.widgetWithText(TaskLink, 'New schedule…'));
    await tester.pumpAndSettle();
    expect(dialogTitled('New schedule'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation',
    );
    await pickDate(
      tester,
      'schedule-cycle-start',
      const LocalDate(2026, 10, 5),
    );
    await pickDate(tester, 'schedule-from', const LocalDate(2026, 10, 5));
    await _tab(tester, 'Cycle');
    await tester.tap(find.text('Shift types…'));
    await tester.pumpAndSettle();
    await tester.tap(_inSubDialog('Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('type-name')), 'Day');
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block-0-count')), '3');
    await tester.tap(find.byKey(const ValueKey('block-0-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add block'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('block-1-count')), '3');
    await tapInDialog(tester, find.text('Save schedule'));
    expect(find.text('Schedule saved.'), findsOneWidget);
    expect(locationOf(app), contains('sheet=calendar'));
    expect(find.text('Day 07:00–19:00'), findsWidgets);
  });
}
