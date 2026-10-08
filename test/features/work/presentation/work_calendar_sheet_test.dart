import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_calendar.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../../../support/scheduled_app.dart';

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

  group('paging faster than the month loads', () {
    // One short frame between clicks, as a quick hand gives: the month
    // asked for must already be the one the header steps from.
    const calendar = '/work?employment={employment}&sheet=calendar';

    LocalDate shownMonth(WidgetTester tester) =>
        tester.widget<WorkCalendar>(find.byType(WorkCalendar)).month;

    Finder row(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(MenuItemButton),
    );

    testWidgets('› twice moves two months', (tester) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(shownMonth(tester), const LocalDate(2026, 12, 1));
      expect(find.text('December 2026'), findsWidgets);
      expect(locationOf(app), contains('from=2026-12-01'));
    });

    testWidgets('‹ twice moves two months back', (tester) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Previous month'));
      await tester.pumpAndSettle();
      expect(shownMonth(tester), const LocalDate(2026, 8, 1));
      expect(locationOf(app), contains('from=2026-08-01'));
    });

    testWidgets('the next month is drawn on the frame after ›', (tester) async {
      await pumpScheduledApp(tester, location: calendar);
      final sheet = tester.state(find.byType(WorkCalendar));
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pump();
      expect(shownMonth(tester), const LocalDate(2026, 11, 1));
      expect(find.text('November 2026'), findsWidgets);
      // The month's planned days come with it, not a frame later.
      expect(find.text('Day 07:00–19:00'), findsWidgets);
      // Nothing gives way while the rest of Work catches up.
      expect(find.text('Reading the schedule'), findsNothing);
      expect(find.text('Loading Work records'), findsNothing);
      expect(tester.state(find.byType(WorkCalendar)), same(sheet));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(WorkCalendar)), same(sheet));
    });

    testWidgets('Down on the Month box twice steps two months', (tester) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await tester.tap(find.byKey(const ValueKey('work-calendar-month')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(shownMonth(tester), const LocalDate(2026, 12, 1));
      expect(locationOf(app), contains('from=2026-12-01'));
    });

    testWidgets('› right after a month is picked steps from it', (
      tester,
    ) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await tester.tap(find.byKey(const ValueKey('work-calendar-month')));
      await tester.pump();
      await tester.tap(row('March'));
      // A menu row acts after the menu's closing frame.
      await tester.pump();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(shownMonth(tester), const LocalDate(2026, 4, 1));
      expect(locationOf(app), contains('from=2026-04-01'));
    });

    testWidgets('› right after a year is picked steps from it', (tester) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await tester.tap(find.byKey(const ValueKey('work-calendar-year')));
      await tester.pump();
      await tester.tap(row('2027'));
      // A menu row acts after the menu's closing frame.
      await tester.pump();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(shownMonth(tester), const LocalDate(2027, 11, 1));
      expect(locationOf(app), contains('from=2027-11-01'));
    });

    testWidgets('› right after Today steps from today', (tester) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(KeyButton, 'Today'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      expect(shownMonth(tester), const LocalDate(2026, 11, 1));
      expect(locationOf(app), contains('from=2026-11-01'));
    });

    testWidgets('Enter right after walking into the next month opens there', (
      tester,
    ) async {
      final app = await pumpScheduledApp(tester, location: calendar);
      await select(tester, '2026-10-29');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'WorkCalendar');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final location = locationOf(app);
      expect(location, contains('day=2026-11-05'));
      // The day opens in its own month; the calendar does not go back.
      expect(location, contains('from=2026-11-01'));
      expect(shownMonth(tester), const LocalDate(2026, 11, 1));
    });
  });
}
