import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/work_shell/correct_leave_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/leave.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';

void main() {
  late ScheduleFixture fixture;
  late LeaveRecord original;
  setUp(() async {
    fixture = await ScheduleFixture.create();
    await fixture.saveDepot();
    await fixture.plans.markLeave(
      fixtureEmployment,
      const LocalDate(2026, 10, 6),
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
    );
    original =
        ((await fixture.plans.confirm(
                  fixtureEmployment,
                  const LocalDate(2026, 10, 6),
                ) as Committed<ConfirmedDay>).value
                as ConfirmedLeave)
            .leave;
  });
  tearDown(() => fixture.dispose());

  CorrectLeaveAction action({CorrectLeave? correct, bool failRead = false}) {
    final value = CorrectLeaveAction(
      original: original,
      service: fixture.plans,
      correct: correct,
      read: failRead ? (_) async => throw StateError('read unavailable') : null,
    );
    addTearDown(value.dispose);
    return value;
  }

  CorrectLeave scripted(
    MutationOutcome<LeaveRecord> result, {
    bool write = false,
    bool throws = false,
  }) =>
      (
        id, {
        required expected,
        required leaveType,
        required illnessStartedOn,
        required reason,
        replacementId,
      }) async {
        if (write) {
          await fixture.plans.correctLeave(
            id,
            expected: expected,
            leaveType: leaveType,
            illnessStartedOn: illnessStartedOn,
            reason: reason,
            replacementId: replacementId,
          );
        }
        if (throws) throw StateError('response lost');
        return result;
      };

  test('blank reason retains type and illness and never writes', () async {
    final edit = action();
    edit.set('type', LeaveType.sick);
    edit.set('illness', const LocalDate(2026, 10, 5));
    expect(await edit.submit(), isNull);
    expect(edit.errors['reason'], CorrectLeaveWords.reason);
    expect(edit.type, LeaveType.sick);
    expect(edit.illness, const LocalDate(2026, 10, 5));
    expect((await fixture.repository.leaveFor(fixtureEmployment)).length, 1);
    expect(
      edit.set('illness', const LocalDate(2026, 10, 7)),
      CorrectLeaveWords.illness,
    );
    edit.set('reason', '  Was ill  ');
    final result = (await edit.submit())!;
    expect(result.leaveType, LeaveType.sick);
    expect(result.illnessStartedOn, const LocalDate(2026, 10, 5));
    final old = (await fixture.repository.leaveById(original.id))!;
    expect(old.voidReason, 'Was ill');
    expect(old.replacementId, result.id);
    expect(result.replacedId, original.id);
    expect(await edit.submit(), isNull);
  });

  test(
    'Unavailable retains input and permits retry; Invalid attaches fields',
    () async {
      final edit = action(
        correct: scripted(
          const Unavailable(SafeFailureCode.storageUnavailable),
        ),
      )..set('reason', 'Wrong type');
      expect(await edit.submit(), isNull);
      expect(edit.phase, CorrectLeavePhase.input);
      expect(edit.error, CorrectLeaveWords.unavailable);
      expect(edit.reason, 'Wrong type');
      final invalid = action(
        correct: scripted(
          const Invalid({
            'illnessStartedOn': [FieldIssue(FieldIssueCode.invalid)],
          }),
        ),
      )..set('reason', 'Wrong day');
      await invalid.submit();
      expect(invalid.errors['illness'], CorrectLeaveWords.illness);
      expect(invalid.reason, 'Wrong day');
    },
  );

  for (final (outcome, words) in <(MutationOutcome<LeaveRecord>, String)>[
    (const Stale(), CorrectLeaveWords.stale),
    (const Missing(), CorrectLeaveWords.missing),
    (
      const Invalid({
        'state': [FieldIssue(FieldIssueCode.invalid)],
      }),
      CorrectLeaveWords.refused,
    ),
  ]) {
    test('$words blocks retry and allows leaving', () async {
      final edit = action(correct: scripted(outcome))..set('reason', 'Fix');
      await edit.submit();
      expect(edit.phase, CorrectLeavePhase.blocked);
      expect(edit.error, words);
      expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.proceed);
    });
  }

  for (final throws in [false, true]) {
    test(
      'lost result (throws=$throws) is checked by exact replacement id',
      () async {
        var calls = 0;
        final send = scripted(
          const Uncertain(SafeFailureCode.commitOutcomeUnknown),
          write: true,
          throws: throws,
        );
        final edit = action(
          correct:
              (
                id, {
                required expected,
                required leaveType,
                required illnessStartedOn,
                required reason,
                replacementId,
              }) {
                calls++;
                return send(
                  id,
                  expected: expected,
                  leaveType: leaveType,
                  illnessStartedOn: illnessStartedOn,
                  reason: reason,
                  replacementId: replacementId,
                );
              },
        )..set('reason', 'Wrong type');
        expect(await edit.submit(), isNull);
        expect(edit.phase, CorrectLeavePhase.uncertain);
        expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.stay);
        expect(edit.set('type', LeaveType.sick), isNotNull);
        final result = (await edit.submit())!;
        expect(result.replacedId, original.id);
        expect(calls, 1);
      },
    );
  }

  test('unchanged after an uncertain write means not done; another correction is stale', () async {
    final edit = action(
      correct: scripted(const Uncertain(SafeFailureCode.commitOutcomeUnknown)),
    )..set('reason', 'Fix');
    await edit.submit();
    expect(await edit.submit(), isNull);
    expect(edit.phase, CorrectLeavePhase.input);
    expect(edit.error, CorrectLeaveWords.notDone);
    await edit.submit();
    await fixture.plans.correctLeave(
      original.id,
      expected: original.revision,
      leaveType: LeaveType.vacation,
      illnessStartedOn: null,
      reason: 'Fix',
    );
    expect(await edit.submit(), isNull);
    expect(
      edit.phase,
      CorrectLeavePhase.blocked,
      reason: 'a different replacement with the same values is not ours',
    );
  });

  test('running is single flight and holds navigation', () async {
    final gate = Completer<MutationOutcome<LeaveRecord>>();
    var calls = 0;
    final edit = action(
      correct:
          (
            id, {
            required expected,
            required leaveType,
            required illnessStartedOn,
            required reason,
            replacementId,
          }) {
            calls++;
            return gate.future;
          },
    )..set('reason', 'Fix');
    final pending = edit.submit();
    expect(edit.busy, isTrue);
    expect(await edit.submit(), isNull);
    expect(await edit.leave(ScriptedConfirm().call), LeaveDecision.stay);
    expect(calls, 1);
    gate.complete(const Unavailable(SafeFailureCode.storageUnavailable));
    await pending;
  });

  test(
    'only changed input asks to discard; failed checks offer Quit anyway',
    () async {
      final edit = action();
      final confirm = ScriptedConfirm([
        ConfirmAnswer.cancel,
        ConfirmAnswer.revert,
        ConfirmAnswer.proceed,
      ]);
      expect(await edit.leave(confirm.call), LeaveDecision.proceed);
      edit.set('type', LeaveType.sick);

      expect(await edit.leave(confirm.call), LeaveDecision.stay);

      expect(await edit.leave(confirm.call), LeaveDecision.proceed);
      final unknown = action(
        correct: scripted(
          const Uncertain(SafeFailureCode.commitOutcomeUnknown),
        ),
        failRead: true,
      )..set('reason', 'Fix');
      await unknown.submit();
      await unknown.submit();
      expect(unknown.error, CorrectLeaveWords.unknown);

      expect(
        await unknown.leave(confirm.call, kind: LeaveKind.quit),
        LeaveDecision.proceed,
      );
      expect(confirm.asked.last.proceed, 'Quit anyway');
    },
  );
}
