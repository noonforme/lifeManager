import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';

/// Today's desks on the production composition, with a fixed clock so
/// today is 2026-10-03 in Vilnius.
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

  Future<String Function()> launch(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: '/today');
    addTearDown(router.dispose);
    await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();
    return () => router.routeInformationProvider.value.uri.toString();
  }

  testWidgets('first launch opens Today with the starter desks', (
    tester,
  ) async {
    await launch(tester);

    for (final desk in ['Today', 'Weekly review', 'Month close']) {
      expect(
        find.descendant(
          of: find.bySemanticsLabel('Desk tabs'),
          matching: find.text(desk),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Journal, today and yesterday'), findsOneWidget);
    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('Work this period'), findsOneWidget);
    expect(
      find.text('Nothing waiting. Work is ready when you add an employment.'),
      findsOneWidget,
    );
    expect(find.text('Add an employment to see this period.'), findsOneWidget);
  });

  testWidgets('Work this period and the month checklist read the records', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final employment = (await work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Warehouse', legalLabel: null),
      ) as Committed<Employment>).value;
      await work.agreement.createAgreement(
        CreateAgreementCommand(
          employmentId: employment.id,
          version: 1,
          terms: const AgreementTerms(
            effectiveStart: LocalDate(2026, 9, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 18400000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      );
      await work.manualShifts.createAndFinalize(
        CreateManualShiftCommand(
          employmentId: employment.id,
          localStartDate: const LocalDate(2026, 10, 2),
          localStartTime: const LocalTime(8, 0),
          localEndDate: const LocalDate(2026, 10, 2),
          localEndTime: const LocalTime(16, 0),
          timezoneId: 'Europe/Vilnius',
          startFold: null,
          endFold: null,
          breaks: const [],
          note: null,
        ),
      );
      await work.periods.createPeriod(
        CreatePayPeriodCommand(
          employmentId: employment.id,
          start: const LocalDate(2026, 10, 1),
          end: const LocalDate(2026, 10, 31),
          label: 'October',
        ),
      );
    });
    final location = await launch(tester);

    expect(find.textContaining('Warehouse: 8:00 paid'), findsOneWidget);
    expect(find.text('October'), findsOneWidget);

    await tester.tap(find.text('Month close'));
    await tester.pumpAndSettle();
    expect(location(), startsWith('/today?desk='));
    expect(find.text('Month close checklist'), findsOneWidget);
    expect(find.text('Every shift this month is finalized'), findsOneWidget);
    expect(find.text('No drafts or running shifts'), findsOneWidget);
    expect(find.text('1 period without one'), findsOneWidget);
  });

  testWidgets('+ Desk adds a desk that can be deleted again', (tester) async {
    final location = await launch(tester);

    await tester.tap(find.text('+ Desk'));
    await tester.pumpAndSettle();
    expect(find.text('Desk 4'), findsOneWidget);
    expect(
      find.text('This desk is empty. Add a sheet from the desk menu.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Needs you'));
    await tester.pumpAndSettle();
    expect(find.text('Needs you'), findsOneWidget);

    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete desk'));
    await tester.pumpAndSettle();
    expect(find.text('Desk 4'), findsNothing);
    expect(location(), '/today');
  });
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 9);
}
