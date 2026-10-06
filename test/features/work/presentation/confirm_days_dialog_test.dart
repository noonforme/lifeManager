import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/presentation/confirm_days_dialog.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import '../../../support/schedule_views.dart';
import '../../../support/scheduled_app.dart';
import '../../../support/work_dialogs.dart';

const _confirm = '/work?employment={employment}&confirm=1&mode=inspect';

void main() {
  testWidgets('every past unconfirmed day is listed and ticked', (
    tester,
  ) async {
    await pumpScheduledApp(tester, location: _confirm);
    expect(dialogTitled('Confirm worked days'), findsOneWidget);
    // Today is 7 October: the 5th and 6th are past Day shifts.
    expect(
      find.byKey(const ValueKey('confirm-row-2026-10-05')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirm-row-2026-10-06')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('confirm-row-2026-10-07')), findsNothing);
    expect(find.textContaining('2 days · 23:00 paid · EUR '), findsOneWidget);
  });

  testWidgets('unticked days stay; Confirm records the rest and closes', (
    tester,
  ) async {
    final app = await pumpScheduledApp(tester, location: _confirm);
    // The check box's label is the date as a date box shows it.
    await tester.tap(find.text('Tue 2026-10-06'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 day · 11:30 paid'), findsOneWidget);
    await tapInDialog(tester, find.text('Confirm'));
    expect(locationOf(app), endsWith('mode=inspect'));
    expect(locationOf(app), isNot(contains('confirm=1')));
    expect(find.text('1 day confirmed.'), findsOneWidget);
    app.router.go(_confirm.replaceAll('{employment}', app.employment));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-row-2026-10-05')), findsNothing);
    expect(
      find.byKey(const ValueKey('confirm-row-2026-10-06')),
      findsOneWidget,
    );
  });

  testWidgets('the Work tasks open it', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.widgetWithText(TaskLink, 'Confirm worked days…'));
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('confirm=1'));
  });

  testWidgets('a day confirmed elsewhere says so; the others commit', (
    tester,
  ) async {
    final rows = [
      for (final day in [5, 6])
        ConfirmRow(
          date: LocalDate(2026, 10, day),
          what: 'Day',
          times: '07:00–19:00',
          paidSeconds: 41400,
          pay: const Money(minorUnits: 21160),
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              width: 600,
              height: 480,
              child: ConfirmDaysDialog(
                rows: rows,
                onConfirm: (dates) async => {
                  const LocalDate(2026, 10, 5): const Stale<ConfirmedDay>(),
                  const LocalDate(2026, 10, 6): Committed<ConfirmedDay>(
                    ConfirmedShift(
                      confirmedDayRow(const LocalDate(2026, 10, 6)).shift,
                    ),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Already confirmed'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });
}
