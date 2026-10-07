import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/shared/shell/task_pane.dart';

import '../support/scheduled_app.dart';

/// The register row whose id is [rowId], such as "day:2026-10-06".
Finder _row(String rowId) => find.byKey(ValueKey('register-row-$rowId'));

/// Every planned row on the Shifts sheet.
Finder _plannedRows() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('register-row-day:'),
);

/// Every recorded shift row on the Shifts sheet.
Finder _shiftRows() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('register-row-shift:'),
);

void main() {
  // Today is 7 October 2026; the depot rotation runs from 5 October:
  // Day 5–7, Off 8–10, Night 11–13, Off 14–16, Day 17–19, …
  testWidgets(
    'the Shifts list shows unconfirmed planned days as Planned rows',
    (tester) async {
      final app = await pumpScheduledApp(
        tester,
        location:
            '/work?employment={employment}&from=2026-10-01&to=2026-10-31'
            '&sheet=shifts',
        size: const Size(1280, 1600),
      );
      await tester.runAsync(
        () => app.work.plans.confirm(
          EmploymentId(app.employment),
          const LocalDate(2026, 10, 5),
        ),
      );
      await tester.pumpAndSettle();

      // The confirmed 5th shows only its real row.
      expect(_shiftRows(), findsOneWidget);
      expect(_row('day:2026-10-05'), findsNothing);
      expect(
        find.descendant(of: _shiftRows(), matching: find.text('Finalized')),
        findsOneWidget,
      );
      // October's other fourteen work days are planned, never stored.
      expect(_plannedRows(), findsNWidgets(14));
      expect(_row('day:2026-10-08'), findsNothing, reason: 'an Off day');
      expect(
        find.descendant(
          of: _row('day:2026-10-06'),
          matching: find.text('To confirm'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('day:2026-10-11'),
          matching: find.text('Planned'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('day:2026-10-11'),
          matching: find.text('Night'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('day:2026-10-11'),
          matching: find.text('19:00'),
        ),
        findsOneWidget,
      );
      // Rows run by date: the confirmed 5th first, then the 6th.
      final fifth = tester.getTopLeft(_shiftRows()).dy;
      final sixth = tester.getTopLeft(_row('day:2026-10-06')).dy;
      final eleventh = tester.getTopLeft(_row('day:2026-10-11')).dy;
      expect(fifth, lessThan(sixth));
      expect(sixth, lessThan(eleventh));

      // Totals stay recorded-only; the planned count stands apart.
      expect(find.text('1 shift'), findsOneWidget);
      expect(find.text('14 planned shifts'), findsOneWidget);

      // Selecting a past planned day offers to confirm it.
      await tester.tap(
        find.descendant(
          of: _row('day:2026-10-06'),
          matching: find.text('To confirm'),
        ),
      );
      await tester.pumpAndSettle();
      expect(locationOf(app), contains('day=2026-10-06'));
      expect(locationOf(app), contains('mode=inspect'));
      expect(
        find.widgetWithText(TaskLink, 'Confirm this day…'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TaskLink, 'Remove this shift…'), findsNothing);

      // Enter opens that day's Properties, not a shift's.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(locationOf(app), contains('day=2026-10-06'));
      expect(locationOf(app), contains('mode=properties'));
      expect(locationOf(app), isNot(contains('record=')));
      expect(find.text('Confirm'), findsWidgets);
    },
  );

  testWidgets('a future planned day offers Open day… from the task pane', (
    tester,
  ) async {
    final app = await pumpScheduledApp(
      tester,
      location:
          '/work?employment={employment}&from=2026-10-01&to=2026-10-31'
          '&sheet=shifts',
      size: const Size(1280, 1600),
    );
    await tester.tap(
      find.descendant(of: _row('day:2026-10-11'), matching: find.text('Night')),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TaskLink, 'Confirm this day…'), findsNothing);
    await tester.tap(find.widgetWithText(TaskLink, 'Open day…'));
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('day=2026-10-11'));
    expect(locationOf(app), contains('mode=properties'));
  });

  testWidgets('the open-ended Shifts list plans through next month', (
    tester,
  ) async {
    await pumpScheduledApp(
      tester,
      location: '/work?employment={employment}&sheet=shifts',
      size: const Size(1280, 2400),
    );
    // From the first day to confirm, the 5th, to the end of November.
    expect(_row('day:2026-10-05'), findsOneWidget);
    expect(_row('day:2026-11-30'), findsOneWidget);
    expect(_row('day:2026-12-01'), findsNothing);
    // No recorded shifts yet, so the recorded figures stay at nothing.
    expect(find.text('0 shifts'), findsOneWidget);
  });

  testWidgets('without a schedule the Shifts list has no planned rows', (
    tester,
  ) async {
    await pumpScheduledApp(
      tester,
      withSchedule: false,
      location: '/work?employment={employment}&sheet=shifts',
    );
    expect(_plannedRows(), findsNothing);
    expect(find.textContaining('planned shift'), findsNothing);
  });

  testWidgets('a removed confirmed day lists as Void and again as planned', (
    tester,
  ) async {
    final app = await pumpScheduledApp(
      tester,
      location:
          '/work?employment={employment}&from=2026-10-01&to=2026-10-31'
          '&sheet=shifts&void=1',
      size: const Size(1280, 1600),
    );
    late ConfirmedDay confirmed;
    await tester.runAsync(() async {
      confirmed = (await app.work.plans.confirm(
        EmploymentId(app.employment),
        const LocalDate(2026, 10, 5),
      ) as Committed<ConfirmedDay>).value;
    });
    await tester.pumpAndSettle();
    expect(_row('day:2026-10-05'), findsNothing);

    final shift = (confirmed as ConfirmedShift).shift;
    await tester.runAsync(
      () => app.work.shifts.voidShift(
        VoidShiftCommand(
          id: shift.id,
          expectedRevision: shift.revision,
          voidReason: 'Synthetic',
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Including void: the struck Void row and its day planned once more,
    // whatever the Status filter shows.
    expect(
      find.descendant(of: _shiftRows(), matching: find.text('Void')),
      findsOneWidget,
    );
    expect(_row('day:2026-10-05'), findsOneWidget);
    expect(_plannedRows(), findsNWidgets(15));
    expect(find.text('0 shifts'), findsOneWidget);
  });
}
