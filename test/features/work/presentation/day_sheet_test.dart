import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/presentation/day_sheet.dart';
import 'package:lifeos/ui/ui.dart';

import '../../../support/era_pickers.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

String _day(String date) =>
    '/work?employment={employment}&sheet=calendar&day=$date&mode=properties';

Finder _inSubDialog(String text) =>
    find.descendant(of: find.byType(EraDialog), matching: find.text(text));

void main() {
  testWidgets('a planned day shows its shift and its actions', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    expect(dialogTitled('Monday 5 October 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('Planned shift'), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
    for (final key in [
      'Confirm',
      'Change…',
      'Cancel shift…',
      'Mark as leave…',
    ]) {
      expect(find.text(key), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('a future day cannot be confirmed yet', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-10-17'));
    expect(find.text('Change…'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('an Off day offers an extra shift', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-10-08'));
    expect(find.text('No shift planned.'), findsOneWidget);
    expect(find.text('Add extra shift…'), findsOneWidget);
  });

  testWidgets('a day with no schedule in use says so', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-09-20'));
    expect(find.text('No schedule is in use on this date.'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('Confirm records the day and closes the sheet', (tester) async {
    final app = await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Confirm'));
    expect(locationOf(app), endsWith('mode=inspect'));
    expect(find.text('Day confirmed.'), findsOneWidget);
  });

  testWidgets('Change… edits the times in place and OK saves them', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Change…'));
    await setTime(tester, 'day-end', const LocalTime(20, 0));
    await tapInDialog(tester, find.text('OK'));
    expect(find.text('Day changed.'), findsOneWidget);
    expect(find.text('Day 07:00–20:00 changed'), findsOneWidget);
  });

  testWidgets('a break outside the shift is refused on the sheet', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Change…'));
    await setTime(tester, 'day-break-0-start', const LocalTime(21, 0));
    await tapInDialog(tester, find.text('Apply'));
    expect(
      find.text(
        'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
        'minutes.',
      ),
      findsOneWidget,
    );
    expect(dialogTitled('Monday 5 October 2026'), findsOneWidget);
  });

  testWidgets('Cancel shift… records a reason and can be undone', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-06'));
    await tapInDialog(tester, find.text('Cancel shift…'));
    await tester.tap(_inSubDialog('Day off'));
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Shift cancelled.'), findsOneWidget);
    expect(find.text('Day off'), findsOneWidget);
    await tapInDialog(tester, find.text('Restore shift'));
    expect(find.text('Cancel shift…'), findsOneWidget);
  });

  testWidgets('Mark as leave… makes the day sick leave from its date', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-06'));
    await tapInDialog(tester, find.text('Mark as leave…'));
    await tester.tap(_inSubDialog('Sick'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('leave-illness-start')), findsOneWidget);
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Marked as leave.'), findsOneWidget);
    expect(find.text('Sick'), findsWidgets);
    expect(find.text('Restore shift'), findsOneWidget);
  });

  testWidgets('Apply stays dark until a real change is made', (tester) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Change…'));
    Finder apply() => find.widgetWithText(KeyButton, 'Apply');
    await tester.ensureVisible(
      find.byKey(const ValueKey('day-break-0-minutes')),
    );
    await tester.tap(find.byKey(const ValueKey('day-break-0-minutes')));
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(apply()).onPressed, isNull);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('day-break-0-minutes')),
        matching: find.byType(EditableText),
      ),
      '45',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(apply()).onPressed, isNotNull);
  });

  testWidgets('Confirm is withheld while the times are being edited', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _day('2026-10-05'));
    await tapInDialog(tester, find.text('Change…'));
    // The keys sit below the form; reveal them so Confirm would be built.
    await revealInDialog(tester, find.text('Cancel shift…'));
    expect(find.text('Cancel shift…'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
  });

  testWidgets('an extra shift from 19:30 to 07:30 ends the next day', (
    tester,
  ) async {
    final sent = <DayTimes>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              height: 600,
              child: DayTimesForm(
                types: const [],
                initial: dayTimesOfType(null),
                extra: true,
                submitLabel: 'Add extra shift',
                describe: (_) => null,
                onSubmit: (times) async {
                  sent.add(times);
                  return const Invalid<DayException>({});
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('day-next-day')), findsNothing);
    await setTime(tester, 'day-start', const LocalTime(19, 30));
    await setTime(tester, 'day-end', const LocalTime(7, 30));
    expect(find.text('Ends the next day.'), findsOneWidget);
    await tester.tap(find.text('Add extra shift'));
    await tester.pumpAndSettle();
    expect(sent.single.endDayOffset, 1);
    expect(sent.single.end, const LocalTime(7, 30));
  });
}
