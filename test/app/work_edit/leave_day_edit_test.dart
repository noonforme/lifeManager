import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/leave_day_edit.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

const _night = LocalDate(2026, 10, 11);

void main() {
  late ScheduleFixture fixture;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    await fixture.saveDepot();
    await fixture.plans.markLeave(
      fixtureEmployment,
      _night,
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
  });

  tearDown(() => fixture.dispose());

  Future<RecordEditSession<LeaveDayRecord, LeaveDayValues>> open() async {
    final session = RecordEditSession(
      adapter: LeaveDayAdapter(fixture.plans, date: _night),
      baseline: (await readLeaveDay(fixture.plans, fixtureEmployment, _night))!,
    );
    addTearDown(session.dispose);
    return session;
  }

  Future<LeaveDay> stored() async =>
      (await fixture.plans.repository.planInputs(fixtureEmployment))
              .exceptions
              .single
          as LeaveDay;

  test('a planned leave day reads as its leave', () async {
    final record = await readLeaveDay(fixture.plans, fixtureEmployment, _night);
    expect(record!.values, const LeaveDayValues(leaveType: LeaveType.vacation));
    expect(
      await readLeaveDay(
        fixture.plans,
        fixtureEmployment,
        const LocalDate(2026, 10, 12),
      ),
      isNull,
    );
  });

  test(
    'vacation becomes sick with its illness start, without asking',
    () async {
      final session = await open();
      session.edit(
        const LeaveDayValues(
          leaveType: LeaveType.sick,
          illnessStartedOn: LocalDate(2026, 10, 10),
        ),
      );
      final confirm = ScriptedConfirm();
      expect(await session.save(confirm.call), SaveResult.committed);
      expect(confirm.asked, isEmpty);
      final saved = await stored();
      expect(saved.leaveType, LeaveType.sick);
      expect(saved.illnessStartedOn, const LocalDate(2026, 10, 10));
    },
  );

  test('an illness after the day is refused with its words', () async {
    final session = await open();
    expect(
      session.edit(
        const LeaveDayValues(
          leaveType: LeaveType.sick,
          illnessStartedOn: LocalDate(2026, 10, 12),
        ),
        field: 'illnessStartedOn',
      ),
      LeaveDayProblems.illness,
    );
  });

  test('a leave changed elsewhere is Stale', () async {
    final session = await open();
    final first = await stored();
    await fixture.plans.markLeave(
      fixtureEmployment,
      _night,
      leaveType: LeaveType.sick,
      illnessStartedOn: null,
      expected: first.revision,
    );
    session.edit(const LeaveDayValues(leaveType: LeaveType.sick));
    expect(await session.save(ScriptedConfirm().call), SaveResult.stale);
  });
}
