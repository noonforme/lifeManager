import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_form.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../support/scheduled_app.dart';

/// The register row whose id is [rowId], such as "day:2026-08-11".
Finder _row(String rowId) => find.byKey(ValueKey('register-row-$rowId'));

/// The depot rotation from 6 July; the agreement pays from 1 September.
/// July and August are planned but no agreement covers them: Day 11–13
/// August, Off 14–16, Night 17–19, …, 16 work days in August. Today is
/// 7 October 2026.
Future<ScheduledApp> _app(WidgetTester tester, String location) =>
    pumpScheduledApp(
      tester,
      location: location,
      scheduleFrom: const LocalDate(2026, 7, 6),
      size: const Size(1280, 1600),
    );

const _august =
    '/work?employment={employment}&from=2026-08-01&to=2026-08-31'
    '&sheet=shifts';

KeyButton _key(WidgetTester tester, String label) =>
    tester.widget<KeyButton>(find.widgetWithText(KeyButton, label).last);

void main() {
  testWidgets('the Calendar reads days before the agreement as unpaid', (
    tester,
  ) async {
    await _app(
      tester,
      '/work?employment={employment}&sheet=calendar'
      '&from=2026-08-01&to=2026-08-31',
    );
    final cell = tester.getSemantics(
      find.byKey(const ValueKey('work-calendar-day-2026-08-11')),
    );
    expect(cell.label, contains('Day 07:00–19:00, No pay agreement'));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-calendar-day-2026-08-11')),
        matching: find.text('No pay agreement'),
      ),
      findsOneWidget,
    );
    // The marker belongs to the entry above it and takes none of the two
    // places, so a night's continuation still shows.
    final sixth = find.byKey(const ValueKey('work-calendar-day-2026-08-06'));
    expect(
      find.descendant(of: sixth, matching: find.text('Night until 07:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sixth, matching: find.textContaining('more')),
      findsNothing,
    );
    // An Off day has nothing to pay and says nothing of it.
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('work-calendar-day-2026-08-14')),
          )
          .label,
      isNot(contains('agreement')),
    );
    final totals = tester.widget<Text>(
      find.byKey(const ValueKey('work-calendar-totals')),
    );
    expect(totals.data, endsWith('· 16 days without a pay agreement'));
    expect(totals.data, contains('planned EUR 0.00'));
  });

  testWidgets(
    'a planned row before the agreement offers to extend it, and then '
    'becomes a day to confirm',
    (tester) async {
      final app = await _app(tester, _august);
      expect(
        find.descendant(
          of: _row('day:2026-08-11'),
          matching: find.text('No pay agreement'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Scrollable).first,
          matching: find.text('To confirm'),
        ),
        findsNothing,
      );
      // Details counts them apart; none is a day to confirm.
      expect(find.text('16 days without a pay agreement'), findsOneWidget);
      expect(find.textContaining('not yet confirmed'), findsNothing);

      await tester.tap(
        find.descendant(
          of: _row('day:2026-08-11'),
          matching: find.text('No pay agreement'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TaskLink, 'Confirm this day…'), findsNothing);
      expect(
        find.widgetWithText(TaskLink, 'Set up pay agreement…'),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(TaskLink, 'Extend pay agreement…'));
      await tester.pumpAndSettle();
      expect(
        find.text('Extend pay agreement v1 to start on 2026-08-11?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(KeyButton, 'Extend'));
      await tester.pumpAndSettle();
      expect(find.text('Agreement extended.'), findsOneWidget);

      // Live: the 11th onwards is paid and to confirm; the days before it
      // still have no agreement.
      expect(
        find.descendant(
          of: _row('day:2026-08-11'),
          matching: find.text('To confirm'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('day:2026-08-01'),
          matching: find.text('No pay agreement'),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TaskLink, 'Confirm this day…'),
        findsOneWidget,
      );
      // 1 August Day and 5–7 August Night.
      expect(find.text('4 days without a pay agreement'), findsOneWidget);
      late MutationOutcome<ConfirmedDay> confirmed;
      await tester.runAsync(() async {
        confirmed = await app.work.plans.confirm(
          EmploymentId(app.employment),
          const LocalDate(2026, 8, 11),
        );
      });
      expect(confirmed, isA<Committed<ConfirmedDay>>());
    },
  );

  testWidgets('without any agreement a planned row offers to set one up', (
    tester,
  ) async {
    final app = await _app(tester, _august);
    await tester.runAsync(() async {
      final employment = EmploymentId(app.employment);
      final agreement = (await app.work.plans.repository.planInputs(employment))
          .agreements
          .single;
      final outcome = await app.work.agreement.deleteAgreement(
        DeleteAgreementCommand(
          agreementId: agreement.id,
          employmentId: employment,
          expectedRevision: agreement.revision,
        ),
      );
      expect(outcome, isA<Committed<PayAgreement>>());
    });
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: _row('day:2026-08-11'),
        matching: find.text('No pay agreement'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TaskLink, 'Extend pay agreement…'),
      findsNothing,
    );
    final links = find.widgetWithText(TaskLink, 'Set up pay agreement…');
    // The day's own, and the Work tasks' as before.
    expect(links, findsNWidgets(2));
    await tester.tap(links.first);
    await tester.pumpAndSettle();
    expect(locationOf(app), contains('add=agreement'));
  });

  testWidgets('Confirm worked days lists the unpaid days as unavailable', (
    tester,
  ) async {
    final app = await _app(
      tester,
      '/work?employment={employment}&sheet=shifts&confirm=1',
    );
    late int paid;
    await tester.runAsync(() async {
      paid = (await app.work.plans.daysToConfirm(
        EmploymentId(app.employment),
        today: const LocalDate(2026, 10, 7),
      )).length;
    });
    // 6 July – 31 August: 14 work days in July, 16 in August.
    final row = find.byKey(const ValueKey('confirm-row-2026-08-11'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('confirm-days-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('No pay agreement covers this day.'),
      ),
      findsOneWidget,
    );
    final box = tester.widget<EraCheckBox>(
      find.descendant(of: row, matching: find.byType(EraCheckBox)),
    );
    expect(box.value, isFalse);
    expect(box.onChanged, isNull);
    // Only the paid days are ticked and counted.
    expect(find.textContaining('$paid days ·'), findsOneWidget);
    expect(find.textContaining('30 days without a pay agreement'), findsOne);
    expect(
      find.widgetWithText(KeyButton, 'Extend pay agreement…'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Extend pay agreement…'));
    await tester.pumpAndSettle();
    // The earliest unpaid day: widening to it pays them all.
    expect(
      find.text('Extend pay agreement v1 to start on 2026-07-06?'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Extend'));
    await tester.pumpAndSettle();
    expect(find.text('No pay agreement covers this day.'), findsNothing);
    expect(find.textContaining('${paid + 30} days ·'), findsOneWidget);
  });

  testWidgets('a day before the agreement can not be confirmed, and says why', (
    tester,
  ) async {
    await _app(
      tester,
      '/work?employment={employment}&sheet=shifts'
      '&day=2026-08-11&mode=properties',
    );
    expect(_key(tester, 'Confirm').onPressed, isNull);
    expect(
      find.text('Unavailable: no pay agreement covers this day.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(KeyButton, 'Extend pay agreement…'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KeyButton, 'Extend'));
    await tester.pumpAndSettle();
    expect(_key(tester, 'Confirm').onPressed, isNotNull);
    expect(
      find.text('Unavailable: no pay agreement covers this day.'),
      findsNothing,
    );
  });
}
