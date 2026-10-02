import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/desks/saved_views.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';

/// Save as view, the Views tree and view tiles on the production
/// composition.
void main() {
  late AppDatabase database;
  late ProductionWorkProviders work;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    final ids = UuidV7WorkIdFactory();
    work = buildWorkProviders(
      database: database,
      clock: _Clock(),
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Vilnius',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
  });

  tearDown(() => database.close());

  testWidgets('a saved view reopens, sits on a desk, renames and deletes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    late Employment employment;
    late PayPeriod october;
    await tester.runAsync(() async {
      employment = (await work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Warehouse', legalLabel: null),
      ) as Committed<Employment>).value;
      october = (await work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: employment.id,
          start: const LocalDate(2026, 10, 1),
          end: const LocalDate(2026, 10, 31),
          label: 'October',
        ),
      ) as Committed<PayPeriod>).value;
    });
    final start =
        '/work?employment=${employment.id.value}'
        '&period=${october.id.value}&sheet=periods&void=1&mode=inspect';
    final router = createAppRouter(initialLocation: start);
    addTearDown(router.dispose);
    await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();
    String location() => router.routeInformationProvider.value.uri.toString();

    await tester.tap(find.text('Save view'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('name-field')))
          .controller!
          .text,
      'Pay periods view',
    );
    await tester.enterText(
      find.byKey(const ValueKey('name-field')),
      'October periods',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    late List<SavedView> stored;
    await tester.runAsync(() async => stored = await work.views.views());
    expect(stored.single.shape.sheetRef, ViewSheets.workPeriods);
    expect(stored.single.shape.filters, {
      'employment': employment.id.value,
      'period': october.id.value,
      'void': '1',
    });

    final books = find.bySemanticsLabel('Books');
    Finder inTree(String text) =>
        find.descendant(of: books, matching: find.text(text));
    expect(inTree('Views'), findsOneWidget);
    expect(inTree('October periods'), findsOneWidget);

    // Opening the view elsewhere returns to the same sheet and filters.
    router.go('/journal');
    await tester.pumpAndSettle();
    await tester.tap(inTree('October periods'));
    await tester.pumpAndSettle();
    expect(location(), start);

    await tester.tap(inTree('October periods'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Weekly review'));
    await tester.pumpAndSettle();
    expect(location(), startsWith('/today?desk='));
    expect(
      find.descendant(
        of: find.bySemanticsLabel('Desk workspace'),
        matching: find.text('October periods'),
      ),
      findsOneWidget,
    );
    expect(find.text('2026-10-31'), findsOneWidget);

    await tester.tap(inTree('October periods'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename view…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Oct');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(inTree('Oct'), findsOneWidget);
    expect(
      find.descendant(
        of: find.bySemanticsLabel('Desk workspace'),
        matching: find.text('Oct'),
      ),
      findsOneWidget,
    );

    await tester.tap(inTree('Oct'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete view'));
    await tester.pumpAndSettle();
    expect(inTree('Views'), findsNothing);
    expect(find.text('Oct'), findsNothing);
    expect(find.text('2026-10-31'), findsNothing);
  });
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 9);
}
