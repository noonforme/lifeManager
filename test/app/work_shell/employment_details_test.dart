import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/employment_details.dart';
import 'package:lifeos/app/work_shell/work_details.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const _october = LocalDate(2026, 10, 1);

void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async => fixture = await ShiftsSheetFixture.create());
  tearDown(() => fixture.dispose());

  EmploymentDetailsSource open(ShiftsSheetFixture over) {
    final source = EmploymentDetailsSource(
      work: over.work,
      employmentId: fixtureEmployment,
      month: _october,
      today: ShiftsSheetFixture.today,
    );
    addTearDown(source.dispose);
    return source;
  }

  /// The source's details once [test] holds.
  Future<EmploymentDetails> once(
    EmploymentDetailsSource source, [
    bool Function(EmploymentDetails details)? test,
  ]) async {
    bool fits(EmploymentDetails details) => test?.call(details) ?? true;
    if (source.latest case final latest? when fits(latest)) return latest;
    return source.details.firstWhere(fits).timeout(const Duration(seconds: 5));
  }

  /// The value of the fact [label] in [sections].
  String? fact(List<DetailsSection> sections, String label) => sections
      .expand((section) => section.facts)
      .where((fact) => fact.label == label)
      .map((fact) => fact.value)
      .firstOrNull;

  List<DetailsSection> sectionsOf(EmploymentDetails details) =>
      workDetailsSections(
        details: details,
        employmentName: 'Synthetic depot',
        employmentCount: 1,
      );

  test(
    'details name the agreement, rate, night premium and schedule',
    () async {
      final details = await once(open(fixture));
      expect(details.agreement!.effectiveStart, const LocalDate(2026, 9, 1));
      expect(details.schedule!.name, 'Depot rotation');
      final sections = sectionsOf(details);
      expect(sections.first.title, 'Synthetic depot');
      expect(fact(sections, 'Agreement'), 'From 2026-09-01');
      expect(fact(sections, 'Hourly rate'), 'EUR 18.40/h gross');
      expect(fact(sections, 'Night premium'), '×1.5, 22:00–06:00');
      expect(fact(sections, 'Schedule'), 'Depot rotation');
    },
  );

  test("October's facts count each kind of day", () async {
    final source = open(fixture);
    final month = (await once(source)).month;
    expect(month.toConfirm, 9);
    expect(month.withoutAgreement, 0);
    expect(month.planned, 6, reason: 'Night 23-25, Day 29-31');
    expect(month.off, 12, reason: '8-10, 14-16, 20-22, 26-28');
    expect(month.leave, 0);
    expect(month.finalized, 0);
    final sections = sectionsOf(await once(source));
    expect(sections.last.title, 'October 2026');
    expect(sections.last.warnings.single.text, 'To confirm: 9 days');
    await fixture.finishShift(20);
    await once(source, (details) => details.month.finalized == 1);
  });

  test(
    'a non-voided linked draft agrees with the planner confirmation set',
    () async {
      await fixture.work.plans.confirm(
        fixtureEmployment,
        const LocalDate(2026, 10, 6),
      );
      await fixture.schedule.database.customStatement(
        "UPDATE work_shifts SET state = 'draft' WHERE planned_date = '2026-10-06'",
      );
      final details = await once(open(fixture));
      expect(details.month.toConfirm, 8);
      expect(details.month.finalized, 0);
    },
  );

  test('Details counts planned and confirmed leave once, including after correction', () async {
    final source = open(fixture);
    await once(source);
    await fixture.work.plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    await once(source, (details) => details.month.leave == 1);
    final leavesSeen = <int>[];
    final observing = source.details.listen(
      (value) => leavesSeen.add(value.month.leave),
    );
    addTearDown(observing.cancel);
    final confirmed = source.details.firstWhere(
      (details) => details.month.toConfirm == 8 && details.month.leave == 1,
    );
    await fixture.work.plans.confirm(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
    );
    expect((await confirmed).month.leave, 1);
    final leave = (await fixture.work.plans.repository.leaveFor(
      fixtureEmployment,
    )).single;
    await fixture.work.plans.correctLeave(
      leave.id,
      expected: leave.revision,
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
      reason: 'Was ill',
    );
    final fresh = await once(
      source,
      (details) => details.month.toConfirm == 8 && details.month.leave == 1,
    );
    expect(fresh.month.leave, 1);
    expect(leavesSeen, isNotEmpty);
    expect(
      leavesSeen,
      everyElement(1),
      reason: 'confirmation/correction never publishes a mixed snapshot with missing leave',
    );
  });

  test('the next shift follows the app clock', () async {
    final clock = fixture.schedule.clock;
    // A second before Friday's Day shift starts (07:00 in Vilnius).
    clock.value = DateTime.utc(2026, 12, 4, 4, 59, 59);
    final source = open(fixture);
    final first = await once(source);
    expect(fact(sectionsOf(first), 'Next shift'), 'Fri 12-04 Day 07:00');
    clock.value = DateTime.utc(2026, 12, 4, 5, 0, 1);
    final later = await once(
      source,
      (details) => details.nextShift?.date == const LocalDate(2026, 12, 5),
    );
    expect(fact(sectionsOf(later), 'Next shift'), 'Sat 12-05 Day 07:00');
  });

  test('the long autumn night is the next shift on its own day', () async {
    fixture.schedule.clock.value = DateTime.utc(2026, 10, 24, 12);
    final details = await once(open(fixture));
    expect(fact(sectionsOf(details), 'Next shift'), 'Sat 10-24 Night 19:00');
  });

  test('no next shift within the horizon shows none', () async {
    // Past the 62 days after today that the source plans.
    fixture.schedule.clock.value = DateTime.utc(2027, 1, 10);
    final details = await once(open(fixture));
    expect(details.nextShift, isNull);
    expect(fact(sectionsOf(details), 'Next shift'), isNull);
  });

  test('a disposed source cancels its timer and says nothing more', () async {
    final clock = fixture.schedule.clock;
    clock.value = DateTime.utc(2026, 12, 4, 4, 59, 59);
    final source = EmploymentDetailsSource(
      work: fixture.work,
      employmentId: fixtureEmployment,
      month: _october,
      today: ShiftsSheetFixture.today,
    );
    var emitted = 0;
    source.details.listen((_) => emitted++);
    await once(source);
    final before = emitted;
    source.dispose();
    clock.value = DateTime.utc(2026, 12, 4, 5, 0, 1);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(emitted, before);
  });

  test('unreadable storage leaves Details without figures', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final source = open(over);
    await once(source);
    gate.failing = true;
    final database = over.schedule.database;
    await database.customUpdate(
      'UPDATE employments SET name = name',
      updates: {database.employments},
    );
    for (var turn = 0; turn < 200 && !source.failed; turn++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(source.failed, isTrue);
    expect(source.latest, isNull);
  });

  test("the overview's Details count employments", () {
    final sections = workDetailsSections(
      details: null,
      employmentName: null,
      employmentCount: 2,
    );
    expect(fact(sections, 'Employments'), '2');
  });

  test('an employment whose details cannot be read shows its name only', () {
    final sections = workDetailsSections(
      details: null,
      employmentName: 'Synthetic depot',
      employmentCount: 1,
    );
    expect(sections.single.title, 'Synthetic depot');
    expect(sections.single.facts, isEmpty);
  });
}
