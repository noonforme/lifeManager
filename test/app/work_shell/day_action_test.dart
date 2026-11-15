import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/work_edit/planned_day_edit.dart';
import 'package:lifeos/app/work_shell/day_action.dart';
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const _night = LocalDate(2026, 10, 11);

void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async => fixture = await ShiftsSheetFixture.create());
  tearDown(() => fixture.dispose());

  Future<List<DayException>> exceptions() async =>
      (await fixture.work.plans.repository.planInputs(fixtureEmployment))
          .exceptions;

  Future<DayAction> open(
    DayActionKind kind, {
    LocalDate date = _night,
    DayActionSend? send,
    Future<List<DayException>> Function()? readExceptions,
  }) async {
    final record = (await readPlannedDay(
      fixture.work.plans,
      fixtureEmployment,
      date,
    ))!;
    final action = DayAction(
      kind: kind,
      employmentId: fixtureEmployment,
      day: record.day,
      exception: record.exception,
      plans: fixture.work.plans,
      send: send,
      readExceptions: readExceptions,
    );
    addTearDown(action.dispose);
    return action;
  }

  test('Cancel shift stores the reason and note', () async {
    final action = await open(DayActionKind.cancel);
    expect(action.title, 'Cancel shift');
    expect(action.primaryLabel, 'Cancel shift');
    action
      ..setReason(CancelReason.dayOff)
      ..setNote('Asked for it');
    expect(await action.submit(), isTrue);
    final saved = (await exceptions()).single as CancelledDay;
    expect(saved.reason, CancelReason.dayOff);
    expect(saved.note, 'Asked for it');
  });

  test('Mark as leave stores sick leave with its illness start', () async {
    final action = await open(DayActionKind.leave);
    expect(action.title, 'Mark as leave');
    action
      ..setLeaveType(LeaveType.sick)
      ..setIllnessStartedOn(const LocalDate(2026, 10, 10));
    expect(await action.submit(), isTrue);
    final saved = (await exceptions()).single as LeaveDay;
    expect(saved.leaveType, LeaveType.sick);
    expect(saved.illnessStartedOn, const LocalDate(2026, 10, 10));
  });

  test('an illness that starts after the day is refused; nothing is '
      'written', () async {
    final action = await open(DayActionKind.leave);
    action
      ..setLeaveType(LeaveType.sick)
      ..setIllnessStartedOn(const LocalDate(2026, 10, 12));
    expect(await action.submit(), isFalse);
    expect(action.fieldError(DayActionField.illness), DayActionWords.illness);
    expect(await exceptions(), isEmpty);
  });

  test('vacation has no illness start', () async {
    final action = await open(DayActionKind.leave);
    action
      ..setLeaveType(LeaveType.sick)
      ..setIllnessStartedOn(const LocalDate(2026, 10, 10))
      ..setLeaveType(LeaveType.vacation);
    expect(action.illnessStartedOn, isNull);
  });

  test('a day changed since the panel opened is refused as changed', () async {
    final changed = await fixture.work.plans.changeDay(
      fixtureEmployment,
      _night,
      start: const LocalTime(19, 0),
      end: const LocalTime(6, 0),
      endDayOffset: 1,
      breaks: const [],
      shiftTypeId: null,
    );
    final action = await open(DayActionKind.cancel);
    await fixture.work.plans.changeDay(
      fixtureEmployment,
      _night,
      start: const LocalTime(19, 0),
      end: const LocalTime(5, 0),
      endDayOffset: 1,
      breaks: const [],
      shiftTypeId: null,
      expected: (changed as Committed<DayException>).value.revision,
    );
    expect(await action.submit(), isFalse);
    expect(action.error, DayActionWords.changed);
    expect(action.phase, DayActionPhase.blocked);
  });

  test('a change stored but not opened is kept: Reload and check opens it '
      'without sending it again', () async {
    var sent = 0;
    final action = await open(
      DayActionKind.cancel,
      send: (_) {
        sent++;
        return fixture.work.plans.cancelDay(
          fixtureEmployment,
          _night,
          reason: CancelReason.swapped,
          note: '',
        );
      },
    );
    expect(await action.submit(), isTrue);
    expect(action.phase, DayActionPhase.opening);
    expect(action.busy, isTrue);
    expect(action.canSubmit, isFalse);
    action.openingFailed();
    expect(action.phase, DayActionPhase.committed);
    expect(action.error, DayActionWords.openFailed);
    expect(action.primaryLabel, ShiftsActionWords.check);
    expect(action.canSubmit, isTrue);
    expect(await action.leave(ScriptedConfirm().call), LeaveDecision.proceed);
    expect(await action.submit(), isTrue);
    expect(action.phase, DayActionPhase.opening);
    expect(sent, 1);
  });

  group('a result that is not known', () {
    DayActionSend lost({required bool wrote}) => (action) async {
      if (wrote) {
        await fixture.work.plans.cancelDay(
          fixtureEmployment,
          action.date,
          reason: action.reason,
          note: action.note,
        );
      }
      return const Uncertain<DayException>(SafeFailureCode.storageUnavailable);
    };

    test('a check that finds the change stored says it went through', () async {
      final action = await open(DayActionKind.cancel, send: lost(wrote: true));
      action.setReason(CancelReason.other);
      expect(await action.submit(), isFalse);
      expect(action.phase, DayActionPhase.uncertain);
      expect(action.primaryLabel, ShiftsActionWords.check);
      expect(await action.submit(), isTrue);
    });

    test('a check that finds nothing says it did not go through', () async {
      final action = await open(DayActionKind.cancel, send: lost(wrote: false));
      await action.submit();
      expect(await action.submit(), isFalse);
      expect(action.error, ShiftsActionWords.notDone);
      expect(action.phase, DayActionPhase.input);
    });

    test('a check that cannot read stays unknown', () async {
      var reads = 0;
      final action = await open(
        DayActionKind.cancel,
        send: lost(wrote: false),
        readExceptions: () async {
          reads++;
          throw StateError('storage');
        },
      );
      await action.submit();
      expect(await action.submit(), isFalse);
      expect(reads, 1);
      expect(action.phase, DayActionPhase.uncertain);
      expect(action.error, ShiftsActionWords.unknown);
    });
  });

  test(
    'leaving with input asks to discard it; without input it does not',
    () async {
      final quiet = await open(DayActionKind.cancel);
      final confirm = ScriptedConfirm();
      expect(await quiet.leave(confirm.call), LeaveDecision.proceed);
      expect(confirm.asked, isEmpty);
      final entered = await open(DayActionKind.cancel)
        ..setNote('Typed');
      expect(entered.entered, isTrue);
      final asked = ScriptedConfirm([ConfirmAnswer.revert]);
      expect(await entered.leave(asked.call), LeaveDecision.proceed);
      expect(asked.asked.single.message, DayActionWords.discard);
      expect(asked.asked.single.revert, 'Discard');
      expect(asked.asked.single.cancel, 'Keep editing');
    },
  );
}
