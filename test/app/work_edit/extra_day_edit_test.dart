import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/extra_day_edit.dart';
import 'package:lifeos/app/work_edit/planned_day_edit.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/schedule.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

/// An Off day of the depot rotation (3 Day, 3 Off, 3 Night, 3 Off from the
/// 5th).
const _offDay = LocalDate(2026, 10, 9);

const _day = PlannedDayValues(
  start: LocalTime(7, 0),
  end: LocalTime(19, 0),
  endDayOffset: 0,
  breaks: [FixedBreak(start: LocalTime(12, 0), dayOffset: 0, minutes: 30)],
  shiftTypeId: ShiftTypeId('day'),
);

void main() {
  late ScheduleFixture fixture;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    await fixture.saveDepot();
  });

  tearDown(() => fixture.dispose());

  RecordEditSession<PlannedDayRecord, PlannedDayValues> open(LocalDate date) {
    final session = RecordEditSession(
      adapter: ExtraDayAdapter(
        plans: fixture.plans,
        employmentId: fixtureEmployment,
        date: date,
        defaults: _day,
      ),
    );
    addTearDown(session.dispose);
    return session;
  }

  Future<List<DayException>> exceptions() async =>
      (await fixture.plans.repository.planInputs(fixtureEmployment)).exceptions;

  test('a new extra shift on an Off day starts from its defaults; untouched, '
      'it is not dirty', () {
    final session = open(_offDay);
    expect(session.isNew, isTrue);
    expect(session.draft, _day);
    expect(session.dirty, isFalse);
  });

  test('saving adds the extra day with Counts as overtime', () async {
    final session = open(_offDay);
    session.edit(session.draft.copyWith(countsAsOvertime: true));
    expect(await session.save(ScriptedConfirm().call), SaveResult.committed);
    final saved = (await exceptions()).single as ExtraDay;
    expect(saved.date, _offDay);
    expect(saved.countsAsOvertime, isTrue);
    expect(saved.shiftTypeId, const ShiftTypeId('day'));
    expect(session.baseline!.day.isExtra, isTrue);
    expect(session.isNew, isFalse);
  });

  test('a day the schedule works is refused with its words', () async {
    final session = open(const LocalDate(2026, 10, 6));
    session.edit(session.draft.copyWith(end: const LocalTime(18, 0)));
    expect(await session.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(session.issues.values, contains(ExtraDayProblems.notOff));
    expect(await exceptions(), isEmpty);
  });
}
