import 'package:drift/native.dart';
import 'package:flutter/services.dart';
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

/// The Work shell in every appearance at the two reference sizes, on
/// synthetic data. Text renders in the test font, so these guard colour,
/// painting and layout rather than glyphs.
void main() {
  const appearances = {
    'day': 'Office Machine Day',
    'night': 'Office Machine Night',
    'high_contrast': 'High contrast',
    'millennium': 'Millennium',
  };
  const sizes = [Size(1280, 800), Size(960, 760)];

  for (final MapEntry(key: name, value: menuLabel) in appearances.entries) {
    for (final size in sizes) {
      final file = 'shell_${name}_${size.width.round()}x${size.height.round()}';
      testWidgets(file, (tester) async {
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
        await tester.runAsync(() async {
          employment = (await work.employment.createEmployment(
            const CreateEmploymentCommand(
              name: 'Synthetic depot',
              legalLabel: null,
            ),
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
          await work.periods.createPeriod(
            CreatePayPeriodCommand(
              employmentId: employment.id,
              start: const LocalDate(2026, 9, 1),
              end: const LocalDate(2026, 9, 30),
              label: null,
            ),
          );
          for (final (day, start, end) in [
            (7, 8, 16),
            (8, 22, 6),
            (9, 9, 18),
          ]) {
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
          initialLocation: '/work?employment=${employment.id.value}',
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(menuLabel));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(LifeOsApp),
          matchesGoldenFile('$file.png'),
        );
      });
    }
  }
}

final class _Clock implements AppClock {
  @override
  DateTime nowUtc() => DateTime.utc(2026, 10, 3, 9);
}
