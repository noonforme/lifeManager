import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/shared/workbench/inspector_parts.dart';

import '../support/era_pickers.dart';

/// Drives the Work core flow through the real router, controller, services
/// and Drift repositories on an in-memory database with synthetic facts.
void main() {
  testWidgets('Work core flow runs end to end on production composition', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1600);
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ids = UuidV7WorkIdFactory();
    final composition = buildWorkProviders(
      database: database,
      clock: _FixedClock(),
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Amsterdam',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    final router = createAppRouter();
    addTearDown(router.dispose);
    String location() => router.routeInformationProvider.value.uri.toString();

    await tester.pumpWidget(composition.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();

    await _setUpEmployment(tester);

    // Manual shift, finalized on save.
    await tester.tap(_inInspector(find.text('Add manual shift')));
    await tester.pumpAndSettle();
    expect(location(), contains('mode=edit'));
    await _enterShift(
      tester,
      start: const LocalTime(10, 0),
      end: const LocalTime(18, 0),
    );
    await tester.tap(find.byKey(const ValueKey('save-manual-shift')));
    await tester.pumpAndSettle();
    expect(location(), contains('record=shift:'));
    expect(location(), endsWith('mode=inspect'));
    expect(find.text('Shift finalized'), findsOneWidget);
    final shiftLocation = location();
    final employment = RegExp(r'employment=([0-9a-f-]+)')
        .firstMatch(shiftLocation)!
        .group(1)!;

    // Pay period covering the shift.
    router.go('/work?employment=$employment');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New pay period'));
    await tester.pumpAndSettle();
    await pickDate(tester, 'period-start', const LocalDate(2026, 9, 1));
    await pickDate(tester, 'period-end', const LocalDate(2026, 9, 30));
    await tester.tap(find.text('Create period'));
    await tester.pumpAndSettle();
    final periodLocation = location();
    expect(periodLocation, contains('record=payPeriod:'));
    expect(_summary('Expected under recorded agreement'), 'EUR 160.00');

    // Payslip and reconciliation.
    await tester.tap(
      find.descendant(
        of: find.bySemanticsLabel('Record inspector'),
        matching: find.text('Record payslip'),
      ),
    );
    await tester.pumpAndSettle();
    await pickDate(tester, 'payslip-issued-date', const LocalDate(2026, 9, 30));
    await tester.enterText(
      find.byKey(const ValueKey('payslip-amount')),
      '150.00',
    );
    await tester.tap(find.text('Save payslip'));
    await tester.pumpAndSettle();
    expect(location(), contains('record=payslip:'));
    expect(_summary('Paid evidence'), 'EUR 150.00');
    expect(_summary('Difference'), 'EUR -10.00');

    // Correct the shift: void it and revise the replacement draft.
    router.go(shiftLocation);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Correct shift'));
    await tester.pumpAndSettle();
    expect(location(), endsWith('mode=correct'));
    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'Synthetic end time correction',
    );
    await tester.tap(find.text('Void original and create replacement'));
    await tester.pumpAndSettle();
    expect(location(), endsWith('mode=edit'));
    expect(location(), isNot(shiftLocation.replaceFirst('inspect', 'edit')));
    expect(find.text('Revise replacement shift'), findsOneWidget);
    await setTime(tester, 'shift-end-time', const LocalTime(17, 0));
    await tester.tap(find.byKey(const ValueKey('save-manual-shift')));
    await tester.pumpAndSettle();
    expect(location(), endsWith('mode=inspect'));
    expect(find.text('Shift finalized'), findsOneWidget);

    // Totals count only the finalized replacement.
    router.go(periodLocation);
    await tester.pumpAndSettle();
    expect(_summary('Expected under recorded agreement'), 'EUR 140.00');
    expect(_summary('Difference'), 'EUR 10.00');
  });

  testWidgets('first launch to a night premium, with defaults only', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1600);
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ids = UuidV7WorkIdFactory();
    final composition = buildWorkProviders(
      database: database,
      clock: _FixedClock(),
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Vilnius',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    final router = createAppRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(composition.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();

    // First launch: one press opens the employment form.
    expect(find.text('Work'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Create employment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('employment-name')),
      'Synthetic warehouse',
    );
    await tester.tap(find.text('Save employment'));
    await tester.pumpAndSettle();

    // The agreement needs only a rate; it starts today, 2026-10-01.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('agreement-effective-start')),
        matching: find.text('Thu 2026-10-01'),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '20.00',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save-agreement')),
      240,
      scrollable: find
          .descendant(
            of: find.bySemanticsLabel('Create agreement'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('save-agreement')));
    await tester.pumpAndSettle();

    // A night shift, 22:00 to 06:00 local, finalized on save.
    await tester.tap(_inInspector(find.text('Add manual shift')));
    await tester.pumpAndSettle();
    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 10, 1));
    await setTime(tester, 'shift-start-time', const LocalTime(22, 0));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 10, 2));
    await setTime(tester, 'shift-end-time', const LocalTime(6, 0));
    await tester.tap(find.byKey(const ValueKey('save-manual-shift')));
    await tester.pumpAndSettle();

    // 8 night hours at EUR 20/h × 1.5.
    expect(find.text('Shift finalized'), findsOneWidget);
    expect(_fact('Expected pay'), 'EUR 240.00');
    expect(_fact('Night hours'), '8:00');
    expect(_fact('Overtime hours'), '0:00');
    expect(_fact('Regular hours'), '0:00');
  });

  testWidgets('saved employment stays selected and setup resumes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1600);
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final ids = UuidV7WorkIdFactory();
    final composition = buildWorkProviders(
      database: database,
      clock: _FixedClock(),
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Amsterdam',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    final router = createAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(composition.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();

    // One press opens the employment form directly.
    await tester.tap(find.text('Create employment'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('employment-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('employment-name')),
      'Synthetic studio',
    );
    await tester.tap(find.text('Save employment'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      contains('employment='),
    );
    expect(
      find.text(
        'Track shifts, see what you should be paid, and compare it with your payslips. Start by adding where you work.',
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.bySemanticsLabel('Work register'),
        matching: find.text('Synthetic studio'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Create agreement'), findsOneWidget);

    // Leaving Work and returning resumes setup for the saved employment.
    router.go('/finance');
    await tester.pumpAndSettle();
    router.go('/work');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Track shifts, see what you should be paid, and compare it with your payslips. Start by adding where you work.',
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.bySemanticsLabel('Work register'),
        matching: find.text('Synthetic studio'),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Create agreement'), findsOneWidget);
  });
}

/// The value beside [label] in the Work Details group of the task pane.
String _summary(String label) {
  final row = find
      .ancestor(
        of: find.descendant(
          of: find.bySemanticsLabel('Task pane'),
          matching: find.text(label),
        ),
        matching: find.byType(InspectorFactRow),
      )
      .first;
  final texts = find
      .descendant(of: row, matching: find.byType(Text))
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .toList();
  return texts.last!;
}

Future<void> _setUpEmployment(WidgetTester tester) async {
  await tester.tap(find.text('Create employment'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('employment-name')),
    'Synthetic studio',
  );
  await tester.tap(find.text('Save employment'));
  await tester.pumpAndSettle();
  await pickDate(
    tester,
    'agreement-effective-start',
    LocalDate.parse('2026-09-01'),
  );
  await tester.enterText(
    find.byKey(const ValueKey('agreement-hourly-rate')),
    '20.00',
  );
  final save = find.byKey(const ValueKey('save-agreement'));
  await tester.scrollUntilVisible(
    save,
    240,
    scrollable: find
        .descendant(
          of: find.bySemanticsLabel('Create agreement'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(find.byKey(const ValueKey('save-agreement')));
  await tester.pumpAndSettle();
  expect(_inInspector(find.text('Record work')), findsOneWidget);
}

/// The value beside a fact label in the inspector.
String _fact(String label) {
  final row = find.ancestor(
    of: _inInspector(find.text(label)),
    matching: find.byType(InspectorFactRow),
  );
  return find
      .descendant(of: row.first, matching: find.byType(Text))
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .last!;
}

Finder _inInspector(Finder finder) => find.descendant(
  of: find.bySemanticsLabel('Record inspector'),
  matching: finder,
);

Future<void> _enterShift(
  WidgetTester tester, {
  required LocalTime start,
  required LocalTime end,
}) async {
  await pickDate(tester, 'shift-start-date', const LocalDate(2026, 9, 29));
  await setTime(tester, 'shift-start-time', start);
  await pickDate(tester, 'shift-end-date', const LocalDate(2026, 9, 29));
  await setTime(tester, 'shift-end-time', end);
}

final class _FixedClock implements AppClock {
  DateTime now = DateTime.utc(2026, 10, 1, 8);

  @override
  DateTime nowUtc() => now;
}
