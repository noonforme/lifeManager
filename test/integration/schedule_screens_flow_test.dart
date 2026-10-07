import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../support/era_pickers.dart';
import '../support/scheduled_app.dart';
import '../support/work_dialogs.dart';
import '../support/work_sheets.dart';

Finder _inSubDialog(String text) =>
    find.descendant(of: find.byType(EraDialog).last, matching: find.text(text));

Future<void> _addType(
  WidgetTester tester, {
  required String name,
  required LocalTime start,
  required LocalTime end,
  required LocalTime breakAt,
  bool nextDay = false,
}) async {
  await tester.tap(_inSubDialog('Add…'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('type-name')), name);
  await setTime(tester, 'type-start', start);
  await setTime(tester, 'type-end', end);
  if (nextDay) {
    await tester.tap(find.byKey(const ValueKey('type-next-day')));
    await tester.pumpAndSettle();
  }
  await tester.tap(_inSubDialog('Add'));
  await tester.pumpAndSettle();
  await setTime(tester, 'type-break-0-start', breakAt);
  await tester.tap(_inSubDialog('OK'));
  await tester.pumpAndSettle();
}

Future<void> _block(
  WidgetTester tester,
  int index, {
  required String count,
  String? type,
}) async {
  if (index > 0) {
    await tester.tap(find.text('Add block'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(ValueKey('block-$index-count')), count);
  await tester.pump();
  if (type != null) {
    await tester.tap(find.byKey(ValueKey('block-$index-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last);
    await tester.pumpAndSettle();
  }
}

Future<void> _markLeave(
  WidgetTester tester,
  ScheduledApp app,
  String date,
  String type,
) async {
  app.router.go(
    '/work?employment=${app.employment}&sheet=calendar&day=$date'
    '&mode=properties',
  );
  await tester.pumpAndSettle();
  await tapInDialog(tester, find.text('Mark as leave…'));
  await tester.tap(_inSubDialog(type));
  await tester.tap(_inSubDialog('OK'));
  await tester.pumpAndSettle();
  expect(find.text('Marked as leave.'), findsOneWidget);
}

void main() {
  testWidgets('a rotation is set up, confirmed, takes leave and reconciles', (
    tester,
  ) async {
    final app = await pumpScheduledApp(
      tester,
      withSchedule: false,
      now: DateTime.utc(2026, 9, 15, 9),
      size: const Size(1280, 900),
    );

    // 1. The rotation: 3 Day, 3 Off, 3 Night, 3 Off from 1 September.
    await tester.tap(find.widgetWithText(TaskLink, 'New schedule…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('schedule-name')),
      'Depot rotation',
    );
    await pickDate(tester, 'schedule-cycle-start', const LocalDate(2026, 9, 1));
    await pickDate(tester, 'schedule-from', const LocalDate(2026, 9, 1));
    await tester.tap(
      find.descendant(
        of: find.byType(PropertySheetTabs),
        matching: find.text('Cycle'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift types…'));
    await tester.pumpAndSettle();
    await _addType(
      tester,
      name: 'Day',
      start: const LocalTime(7, 0),
      end: const LocalTime(19, 0),
      breakAt: const LocalTime(12, 0),
    );
    await _addType(
      tester,
      name: 'Night',
      start: const LocalTime(19, 0),
      end: const LocalTime(7, 0),
      breakAt: const LocalTime(0, 0),
      nextDay: true,
    );
    await tester.tap(_inSubDialog('OK'));
    await tester.pumpAndSettle();
    await _block(tester, 0, count: '3', type: 'Day');
    await _block(tester, 1, count: '3');
    await _block(tester, 2, count: '3', type: 'Night');
    await _block(tester, 3, count: '3');
    expect(find.text('Cycle — 12 days'), findsOneWidget);
    await tapInDialog(tester, find.text('Save schedule'));
    expect(find.text('Schedule saved.'), findsOneWidget);
    expect(find.text('Day 07:00–19:00'), findsWidgets);
    expect(find.text('Night 19:00–07:00'), findsWidgets);

    // 2. A vacation day and a sick day before confirming.
    await _markLeave(tester, app, '2026-09-02', 'Vacation');
    await _markLeave(tester, app, '2026-09-03', 'Sick');

    // 3. Confirm every past day: Day 1, Vacation 2, Sick 3, Night 7–9,
    //    Day 13–14.
    app.router.go('/work?employment=${app.employment}&confirm=1&mode=inspect');
    await tester.pumpAndSettle();
    expect(find.textContaining('8 days · '), findsOneWidget);
    await tapInDialog(tester, find.text('Confirm'));
    expect(find.text('8 days confirmed.'), findsOneWidget);
    expect(find.textContaining('days to confirm'), findsNothing);

    // 4. The leave is priced: no confirmed work in June–August, so the
    //    agreement rate; vacation at 100 %, the illness's first day at
    //    62.06 %.
    await chooseSheet(tester, 'Leave');
    expect(find.text('Vacation'), findsOneWidget);
    expect(find.text('Sick'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    expect(find.text('62.06 %'), findsOneWidget);

    // 5. A payslip for September reconciles against the confirmed days.
    final employment = EmploymentId(app.employment);
    late PayPeriod period;
    await tester.runAsync(() async {
      period = (await app.work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: employment,
          start: const LocalDate(2026, 9, 1),
          end: const LocalDate(2026, 9, 30),
          label: null,
        ),
      ) as Committed<PayPeriod>).value;
      await app.work.payslips.recordPayslip(
        RecordPayslipCommand(
          periodId: period.id,
          issuedDate: const LocalDate(2026, 9, 30),
          paidDate: null,
          amountMinorUnits: 150000,
          basis: const GrossBasis(),
          grossMinorUnits: null,
          netMinorUnits: null,
          deductionMinorUnits: null,
          reference: null,
          note: null,
        ),
      );
    });
    app.router.go(
      '/work?employment=${app.employment}&period=${period.id.value}'
      '&record=payPeriod:${period.id.value}&mode=inspect',
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Expected under recorded agreement'),
      findsWidgets,
    );
    expect(find.textContaining('Difference'), findsWidgets);
    expect(find.textContaining('not yet confirmed'), findsNothing);
  });
}
