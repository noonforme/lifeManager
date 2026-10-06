import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
