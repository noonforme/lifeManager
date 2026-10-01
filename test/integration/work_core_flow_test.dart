import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';

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
    await _enterShift(tester, start: '10:00', end: '18:00');
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
    await tester.enterText(
      find.byKey(const ValueKey('period-start')),
      '2026-09-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('period-end')),
      '2026-09-30',
    );
    await tester.tap(find.text('Create period'));
    await tester.pumpAndSettle();
    final periodLocation = location();
    expect(periodLocation, contains('record=payPeriod:'));
    expect(_summary('Expected under recorded agreement'), 'EUR 160.00');

    // Payslip and reconciliation.
    await tester.tap(find.text('Record payslip'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('payslip-issued-date')),
      '2026-09-30',
    );
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
    await tester.enterText(
      find.byKey(const ValueKey('shift-end-time')),
      '17:00',
    );
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

  testWidgets('live shift recovers after restart and finalizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1600);
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final clock = _FixedClock()..now = DateTime.utc(2026, 9, 29, 7);
    final ids = UuidV7WorkIdFactory();
    final composition = buildWorkProviders(
      database: database,
      clock: clock,
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Amsterdam',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    var router = createAppRouter();
    String location() => router.routeInformationProvider.value.uri.toString();

    await tester.pumpWidget(composition.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();
    await _setUpEmployment(tester);

    await tester.tap(_inInspector(find.text('Start shift')));
    await tester.pumpAndSettle();
    expect(location(), contains('record=shift:'));
    final shiftLocation = location();
    clock.now = DateTime.utc(2026, 9, 29, 11);
    await tester.tap(find.text('Start break'));
    await tester.pumpAndSettle();
    expect(find.text('End break'), findsOneWidget);

    // Restart: a fresh router on plain /work restores the on-break shift.
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    router = createAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(composition.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();
    expect(location(), shiftLocation);
    expect(find.text('End break'), findsOneWidget);

    clock.now = DateTime.utc(2026, 9, 29, 11, 30);
    await tester.tap(find.text('End break'));
    await tester.pumpAndSettle();
    clock.now = DateTime.utc(2026, 9, 29, 16, 30);
    await tester.tap(find.text('End shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm finalization'));
    await tester.pumpAndSettle();
    expect(find.text('Shift finalized'), findsOneWidget);
    expect(location(), shiftLocation);
  });
}

/// The value text beside a register summary label.
String _summary(String label) {
  final row = find.ancestor(
    of: find.text(label),
    matching: find.byType(Row),
  ).first;
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
    await tester.tap(_inInspector(find.text('Create employment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('employment-name')),
      'Synthetic studio',
    );
    await tester.tap(find.text('Save employment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('agreement-effective-start')),
      '2026-09-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '20.00',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-threshold')),
      '480',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-multiplier-numerator')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-multiplier-denominator')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('save-agreement')));
    await tester.pumpAndSettle();
    expect(find.text('Agreement 1 is effective.'), findsOneWidget);

}

Finder _inInspector(Finder finder) => find.descendant(
  of: find.bySemanticsLabel('Record inspector'),
  matching: finder,
);

Future<void> _enterShift(
  WidgetTester tester, {
  required String start,
  required String end,
}) async {
  for (final (key, value) in [
    ('shift-start-date', '2026-09-29'),
    ('shift-start-time', start),
    ('shift-end-date', '2026-09-29'),
    ('shift-end-time', end),
  ]) {
    await tester.enterText(find.byKey(ValueKey(key)), value);
  }
}

final class _FixedClock implements AppClock {
  DateTime now = DateTime.utc(2026, 10, 1, 8);

  @override
  DateTime nowUtc() => now;
}
