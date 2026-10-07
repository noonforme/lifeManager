import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/scheduled_app.dart';

import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';

void main() {
  testWidgets('an employment with a schedule in use opens on its Calendar', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    expect(find.text('October 2026'), findsWidgets);
    expect(find.text('Day 07:00–19:00'), findsNWidgets(9));
  });

  testWidgets('the month status line sums the month', (tester) async {
    await pumpScheduledApp(tester);
    // October's 15 planned shifts, none confirmed yet.
    expect(find.textContaining('15 shifts · '), findsOneWidget);
    expect(find.textContaining('planned EUR '), findsOneWidget);
    expect(find.textContaining('confirmed EUR 0.00'), findsOneWidget);
  });

  testWidgets('› moves to November in the address', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();
    final location = locationOf(app);
    expect(location, contains('from=2026-11-01'));
    expect(location, contains('to=2026-11-30'));
    expect(location, contains('sheet=calendar'));
    expect(find.text('November 2026'), findsWidgets);
  });

  testWidgets('Enter on a planned day opens its Properties', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(
      find.byKey(const ValueKey('work-calendar-day-2026-10-05')),
    );
    // A day also opens on a double-click, so a single tap settles after the
    // double-tap window.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    final location = locationOf(app);
    expect(location, contains('day=2026-10-05'));
    expect(location, contains('mode=properties'));
  });

  testWidgets('Shifts is the default without a schedule', (tester) async {
    await pumpScheduledApp(tester, withSchedule: false);
    expect(find.text('Day 07:00–19:00'), findsNothing);
    expect(find.byKey(const ValueKey('work-calendar-totals')), findsNothing);
  });

  testWidgets('double-clicking a greyed neighbouring day moves to its month', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-11-01'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final location = locationOf(app);
    expect(location, contains('from=2026-11-01'));
    expect(location, isNot(contains('day=')));
  });

  Future<void> select(WidgetTester tester, String date) async {
    await tester.tap(find.byKey(ValueKey('work-calendar-day-$date')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('the arrow keys walk across a month edge', (tester) async {
    final app = await pumpScheduledApp(tester);
    await select(tester, '2026-10-29');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    // The next month loads without the grid giving way or losing focus.
    await tester.pump();
    expect(find.text('Reading the schedule'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsWidgets);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'WorkCalendar');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('day=2026-11-05'));
  });

  testWidgets('Page Down keeps the day of the month', (tester) async {
    final app = await pumpScheduledApp(tester);
    await select(tester, '2026-10-15');
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'WorkCalendar');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('day=2026-11-15'));
  });

  testWidgets('a pay-period or range scope does not hide confirmed days', (
    tester,
  ) async {
    final app = await pumpScheduledApp(
      tester,
      location:
          '/work?employment={employment}&from=2026-10-01&to=2026-10-05'
          '&sheet=calendar',
    );
    final outcome = await tester.runAsync(
      () => app.work.plans.confirm(
        EmploymentId(app.employment),
        const LocalDate(2026, 10, 6),
      ),
    );
    expect(outcome, isA<Committed<Object?>>());
    await tester.pumpAndSettle();
    expect(find.textContaining('15 shifts · '), findsOneWidget);
    expect(find.textContaining('confirmed EUR 0.00'), findsNothing);
    expect(find.textContaining('confirmed EUR '), findsOneWidget);
    expect(find.text('Day 07:00–19:00'), findsNWidgets(9));
  });
}
