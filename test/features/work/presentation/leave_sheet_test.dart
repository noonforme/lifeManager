import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/ui/ui.dart';

import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';
import '../../../support/work_sheets.dart';

/// Marks 6 October as vacation and confirms it through the services.
Future<void> _vacation(WidgetTester tester, ScheduledApp app) async {
  await tester.runAsync(() async {
    final employment = EmploymentId(app.employment);
    await app.work.plans.markLeave(
      employment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await app.work.plans.confirm(employment, const LocalDate(2026, 10, 6));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Leave sheet lists confirmed leave with its pay', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    await _vacation(tester, app);
    await chooseSheet(tester, 'Leave');
    expect(find.text('2026-10-06'), findsOneWidget);
    expect(find.text('Vacation'), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
    // No confirmed work in July–September: the agreement rate, at 100 %.
    expect(find.text('Agreement rate'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('EUR 211.60'), findsOneWidget);
  });

  testWidgets('a confirmed leave day opens its Properties from the calendar', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    await _vacation(tester, app);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-06'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('record=leave:'));
    expect(dialogTitled('Vacation on 2026-10-06 Properties'), findsOneWidget);
    expect(
      find.text(
        'No confirmed work in the 3 months before; using the agreement rate.',
      ),
      findsOneWidget,
    );
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('Correct… voids the leave and records the replacement', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester);
    await _vacation(tester, app);
    await chooseSheet(tester, 'Leave');
    await openRowProperties(tester, '2026-10-06');
    await tapInDialog(tester, find.text('Correct…'));
    await tester.tap(
      find.descendant(of: find.byType(EraDialog), matching: find.text('Sick')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('leave-correct-reason')),
      'Was ill, not on holiday',
    );
    await tester.tap(
      find.descendant(of: find.byType(EraDialog), matching: find.text('OK')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave corrected.'), findsOneWidget);
    expect(find.text('Sick'), findsOneWidget);
  });
}
