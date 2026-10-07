import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_repository.dart';

import '../../../support/schedule_fixture.dart';

void main() {
  late ScheduleFixture fixture;
  late DriftWorkRepository repository;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    repository = DriftWorkRepository(fixture.database, clock: fixture.clock);
  });
  tearDown(() => fixture.dispose());

  Future<List<PlannedShiftRow>> planned(WorkTemporalScope? temporal) =>
      repository
          .watchPlannedShifts(
            WorkScope(employmentId: fixtureEmployment, temporal: temporal),
          )
          .first;

  test('planned rows run by start, the confirmed day left out', () async {
    // Today is 1 December 2026; a year of the depot rotation.
    final version = await fixture.saveDepot(from: const LocalDate(2025, 12, 1));
    await fixture.markUsed(version, date: const LocalDate(2026, 11, 5));

    final rows = await planned(null);
    // The open-ended scope: the first schedule date to the end of January.
    expect(rows.first.day.date, const LocalDate(2025, 12, 1));
    expect(
      rows.last.day.date.compareTo(const LocalDate(2027, 1, 31)),
      lessThanOrEqualTo(0),
    );
    expect(rows.length, greaterThan(180));
    final starts = [for (final row in rows) row.day.startUtc];
    expect(starts, [...starts]..sort());
    expect(
      rows.where((row) => row.day.date == const LocalDate(2026, 11, 5)),
      isEmpty,
    );
  });

  test('today is to confirm, tomorrow only planned', () async {
    await fixture.saveDepot(from: const LocalDate(2026, 12, 1));
    final rows = await planned(
      const DateRangeScope(
        start: LocalDate(2026, 12, 1),
        end: LocalDate(2026, 12, 2),
      ),
    );
    expect([for (final row in rows) row.toConfirm], [true, false]);
    expect(repository.plannedLoads, 1);
  });

  test('the register itself never plans', () async {
    await fixture.saveDepot(from: const LocalDate(2025, 12, 1));
    await repository
        .watchRegister(
          const WorkScope(employmentId: fixtureEmployment, temporal: null),
        )
        .first;
    expect(repository.plannedLoads, 0);
  });
}
