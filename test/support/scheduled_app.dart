import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/schedule_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import 'schedule_fixture.dart';

/// The pumped app, its router and services, and the seeded ids.
typedef ScheduledApp = ({
  String employment,
  String? schedule,
  GoRouter router,
  ProductionWorkProviders work,
  FixedClock clock,
});

/// The app on an in-memory database with one employment paid EUR 18.40
/// gross from 1 September and, unless [withSchedule] is false, the depot
/// rotation from 5 October. "Now" is [now] (default 7 October 2026, 12:00
/// in Vilnius). `{employment}` and `{schedule}` in [location] become the
/// seeded ids.
Future<ScheduledApp> pumpScheduledApp(
  WidgetTester tester, {
  String location = '/work?employment={employment}',
  DateTime? now,
  bool withSchedule = true,
  Size size = const Size(1280, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final clock = FixedClock(now ?? DateTime.utc(2026, 10, 7, 9));
  final ids = UuidV7WorkIdFactory();
  final work = buildWorkProviders(
    database: database,
    clock: clock,
    timezones: IanaTimezoneService(),
    currentTimezoneId: () => 'Europe/Vilnius',
    workIds: ids,
    shiftIds: ids,
    evidenceIds: ids,
    scheduleIds: ids,
  );
  late String employment;
  String? schedule;
  await tester.runAsync(() async {
    final created = (await work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic depot', legalLabel: null),
    ) as Committed<Employment>).value;
    employment = created.id.value;
    await work.agreement.createAgreement(
      CreateAgreementCommand(
        employmentId: created.id,
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
    if (withSchedule) {
      final draft = depotDraft();
      final saved = await work.schedules.create(
        ScheduleDraft(
          employmentId: created.id,
          name: draft.name,
          timezoneId: draft.timezoneId,
          cycleStart: draft.cycleStart,
          inUseFrom: draft.inUseFrom,
          inUseUntil: null,
          shiftTypes: draft.shiftTypes,
          blocks: draft.blocks,
        ),
      );
      schedule = (saved as Committed<WorkSchedule>).value.id.value;
    }
  });
  final router = createAppRouter(
    initialLocation: location
        .replaceAll('{employment}', employment)
        .replaceAll('{schedule}', schedule ?? ''),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
  await tester.pumpAndSettle();
  return (
    employment: employment,
    schedule: schedule,
    router: router,
    work: work,
    clock: clock,
  );
}

/// Where the app is now.
String locationOf(ScheduledApp app) =>
    app.router.routeInformationProvider.value.uri.toString();
