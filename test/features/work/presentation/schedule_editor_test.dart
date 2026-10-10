import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/schedule_editor.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/ui/ui.dart';

import '../../../support/era_pickers.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

const _properties =
    '/work?employment={employment}&sheet=schedules'
    '&record=schedule:{schedule}&mode=properties';

Finder _inSubDialog(String text) =>
    find.descendant(of: find.byType(EraDialog).last, matching: find.text(text));

Future<void> _altArrow(WidgetTester tester, LogicalKeyboardKey arrow) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(arrow);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.pumpAndSettle();
}

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

  testWidgets('Alt+Down twice moves Day below two rows and keeps focus', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _properties);
    await _tab(tester, 'Cycle');
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    Finder count(int serial) => find.byKey(ValueKey('block-$serial-count'));
    await tester.tap(count(0));
    await _altArrow(tester, LogicalKeyboardKey.arrowDown);
    await _altArrow(tester, LogicalKeyboardKey.arrowDown);
    // Off, Night, Day, Off: the Day row (block 0) is third.
    final day = top(find.text('07:00–19:00, break 30 min'));
    expect(day, greaterThan(top(count(1))));
    expect(day, greaterThan(top(count(2))));
    expect(day, lessThan(top(count(3))));
    final field = tester.widget<EditableText>(
      find.descendant(of: count(0), matching: find.byType(EditableText)),
    );
    expect(field.focusNode.hasFocus, isTrue);
  });

  testWidgets('Alt+Up moves the Night block up one place', (tester) async {
    await pumpScheduledApp(tester, location: _properties);
    await _tab(tester, 'Cycle');
    double top(Finder finder) => tester.getTopLeft(finder).dy;
    Finder count(int serial) => find.byKey(ValueKey('block-$serial-count'));
    await tester.tap(count(2));
    await _altArrow(tester, LogicalKeyboardKey.arrowUp);
    // Day, Night, Off, Off.
    expect(top(count(2)), lessThan(top(count(1))));
    expect(top(count(2)), greaterThan(top(count(0))));
    expect(top(count(1)), lessThan(top(count(3))));
  });

  testWidgets('clicking into a field does not light Apply', (tester) async {
    await pumpScheduledApp(tester, location: _properties);
    final apply = find.widgetWithText(KeyButton, 'Apply');
    await tester.tap(find.byKey(const ValueKey('schedule-name')));
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(apply).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation 2',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(apply).onPressed, isNotNull);
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
