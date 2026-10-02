import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
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
import 'package:lifeos/features/work/domain/pay_period.dart';

/// The screens the shell checks cover, as locations built from the seeded
/// employment and pay period ids (Millennium shell spec 9).
final syntheticScreens = <String, String Function(String, String)>{
  'shell': (employment, _) => '/work?employment=$employment',
  'period': (employment, period) =>
      '/work?employment=$employment&record=payPeriod:$period',
  'form': (employment, _) => '/work?employment=$employment&mode=edit',
  'today': (_, _) => '/today',
};

/// Seeds synthetic Work records (one employment, its agreement, a pay
/// period and three finalized shifts) and pumps the app at [size] on the
/// location [screen] builds.
Future<void> pumpSyntheticShell(
  WidgetTester tester, {
  required Size size,
  required String Function(String employment, String period) screen,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final ids = UuidV7WorkIdFactory();
  final work = buildWorkProviders(
    database: database,
    clock: _Clock(),
    timezones: IanaTimezoneService(),
    currentTimezoneId: () => 'Europe/Vilnius',
    workIds: ids,
    shiftIds: ids,
    evidenceIds: ids,
  );
  late Employment employment;
  late PayPeriod period;
  await tester.runAsync(() async {
    employment = (await work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic depot', legalLabel: null),
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
          label: 'Standard',
          note: null,
        ),
      ),
    );
    period = (await work.periods.createPeriod(
      CreatePayPeriodCommand(
        employmentId: employment.id,
        start: const LocalDate(2026, 9, 1),
        end: const LocalDate(2026, 9, 30),
        label: null,
      ),
    ) as Committed<PayPeriod>).value;
    for (final (day, start, end) in [(7, 8, 16), (8, 22, 6), (9, 9, 18)]) {
      await work.manualShifts.createAndFinalize(
        CreateManualShiftCommand(
          employmentId: employment.id,
          localStartDate: LocalDate(2026, 9, day),
          localStartTime: LocalTime(start, 0),
          localEndDate: LocalDate(2026, 9, end < start ? day + 1 : day),
          localEndTime: LocalTime(end, 0),
          timezoneId: 'Europe/Vilnius',
          startFold: null,
          endFold: null,
          breaks: const [],
          note: null,
        ),
      );
    }
  });
  final router = createAppRouter(
    initialLocation: screen(employment.id.value, period.id.value),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
  await tester.pumpAndSettle();
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 9);
}
