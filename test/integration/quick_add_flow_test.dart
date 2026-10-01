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

/// + Add and "from last time" on the production composition, with a fixed
/// clock so today is 2026-10-03 in Vilnius.
void main() {
  late AppDatabase database;
  late ProductionWorkProviders work;

  Future<Employment> seed(WidgetTester tester, {bool withShift = true}) async {
    late Employment employment;
    await tester.runAsync(() async {
      employment = (await work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Warehouse', legalLabel: null),
      ) as Committed<Employment>).value;
      await work.agreement.createAgreement(
        CreateAgreementCommand(
          employmentId: employment.id,
          version: 1,
          terms: const AgreementTerms(
            effectiveStart: LocalDate(2026, 9, 1),
            effectiveEnd: LocalDate(2026, 10, 31),
            hourlyRateMicroEur: 18400000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      );
      if (withShift) {
        await work.manualShifts.createAndFinalize(
          CreateManualShiftCommand(
            employmentId: employment.id,
            localStartDate: const LocalDate(2026, 9, 28),
            localStartTime: const LocalTime(22, 0),
            localEndDate: const LocalDate(2026, 9, 29),
            localEndTime: const LocalTime(6, 0),
            timezoneId: 'Europe/Vilnius',
            startFold: null,
            endFold: null,
            breaks: const [
              ManualShiftBreak(
                localStartDate: LocalDate(2026, 9, 29),
                localStartTime: LocalTime(1, 0),
                localEndDate: LocalDate(2026, 9, 29),
                localEndTime: LocalTime(1, 30),
                startFold: null,
                endFold: null,
              ),
            ],
            note: 'Not copied',
          ),
        );
      }
    });
    return employment;
  }

  Future<String Function()> launch(WidgetTester tester, Employment e) async {
    final router = createAppRouter(
      initialLocation: '/work?employment=${e.id.value}',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();
    return () => router.routeInformationProvider.value.uri.toString();
  }

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

  testWidgets('"from last time" prefills the last shift on today', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    final employment = await seed(tester);
    final location = await launch(tester, employment);

    await tester.tap(find.text('Manual shift from last time'));
    await tester.pumpAndSettle();

    expect(location(), contains('template=last'));
    String field(String key) =>
        tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;
    expect(field('shift-start-date'), '2026-10-03');
    expect(field('shift-start-time'), '22:00');
    expect(field('shift-end-date'), '2026-10-04');
    expect(field('shift-end-time'), '06:00');
    expect(field('shift-timezone'), 'Europe/Vilnius');
    expect(field('shift-break-start-date-0'), '2026-10-04');
    expect(field('shift-break-start-0'), '01:00');
    expect(field('shift-break-end-0'), '01:30');
    expect(field('shift-note'), isEmpty);
  });

  testWidgets('with no finished shift there is no "from last time"', (
    tester,
  ) async {
    final employment = await seed(tester, withShift: false);
    await launch(tester, employment);
    expect(find.text('Manual shift from last time'), findsNothing);
    expect(find.text('+ Add'), findsOneWidget);
  });

  testWidgets('+ Add opens pay period and agreement forms by route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    final employment = await seed(tester);
    final location = await launch(tester, employment);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay period').last);
    await tester.pumpAndSettle();
    expect(location(), contains('add=payPeriod'));
    expect(find.byKey(const ValueKey('period-start')), findsOneWidget);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agreement').last);
    await tester.pumpAndSettle();
    expect(location(), contains('add=agreement'));
    await tester.enterText(
      find.byKey(const ValueKey('agreement-effective-start')),
      '2026-11-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '19.00',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
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
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Saved as version 2, and the inspector returns to the employment.
    expect(location(), isNot(contains('add=')));
    late List<int> versions;
    await tester.runAsync(() async {
      versions = [
        for (final agreement in await work.workRepository.agreementsFor(
          employment.id,
        ))
          agreement.version,
      ];
    });
    expect(versions, [1, 2]);
  });
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 9);
}
