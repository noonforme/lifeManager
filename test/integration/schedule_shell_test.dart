import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../support/era_pickers.dart';
import '../support/scheduled_app.dart';

void main() {
  testWidgets('the status bar and Books count the days to confirm', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    // Today is 7 October: the 5th and 6th are past and unconfirmed.
    expect(find.text('2 days to confirm'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is CountBadge && widget.count == 2,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Books lists the open employment\'s sheets', (tester) async {
    final app = await pumpScheduledApp(tester);
    for (final sheet in ['Shifts', 'Leave', 'Schedules', 'Pay periods']) {
      expect(find.text(sheet), findsWidgets);
    }
    await tester.tap(find.text('Schedules').first);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('sheet=schedules'));
  });

  testWidgets('+ Add › Extra shift… adds one on an Off day', (tester) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra shift…').last);
    await tester.pumpAndSettle();
    await pickDate(tester, 'add-day-date', const LocalDate(2026, 10, 8));
    await tester.tap(find.text('Add extra shift'));
    await tester.pumpAndSettle();
    expect(find.text('Extra shift added.'), findsOneWidget);
    expect(find.text('Extra 07:00–19:00'), findsOneWidget);
  });

  testWidgets('+ Add › Extra shift… on a planned day says to change it', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra shift…').last);
    await tester.pumpAndSettle();
    await pickDate(tester, 'add-day-date', const LocalDate(2026, 10, 6));
    await tester.tap(find.text('Add extra shift'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The schedule plans a shift on this date. Open the day to change it '
        'instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('+ Add › Leave… marks a planned day as leave', (tester) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave…').last);
    await tester.pumpAndSettle();
    await pickDate(tester, 'add-day-date', const LocalDate(2026, 10, 11));
    await tester.tap(find.text('Mark as leave'));
    await tester.pumpAndSettle();
    expect(find.text('Marked as leave.'), findsOneWidget);
    expect(find.text('Vacation'), findsOneWidget);
  });

  testWidgets('+ Add lists the schedule entries in the spec\'s order', (
    tester,
  ) async {
    await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    final labels = [
      'Manual shift',
      'Extra shift…',
      'Leave…',
      'Pay period',
      'Payslip',
      'Employment',
      'Agreement',
      'Schedule',
    ];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label).last).dy,
    ];
    expect(tops, [...tops]..sort());
  });
}
