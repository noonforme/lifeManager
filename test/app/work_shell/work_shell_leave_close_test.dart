import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_shell/correct_leave_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_driver.dart';

final class _Repository implements DayPlanRepository {
  _Repository(this.inner, {this.lose = false, this.gated = false});
  final DayPlanRepository inner;
  final bool lose;
  final bool gated;
  final gate = Completer<void>();
  bool failReads = false;
  int calls = 0;
  @override
  Future<PlanInputs> planInputs(EmploymentId id) => inner.planInputs(id);
  @override
  Stream<PlanInputs> watchPlanInputs(EmploymentId id) =>
      inner.watchPlanInputs(id);
  @override
  Future<List<LeaveRecord>> leaveFor(EmploymentId id) => inner.leaveFor(id);
  @override
  Future<LeaveRecord?> leaveById(LeaveRecordId id) async {
    if (failReads) throw StateError('read unavailable');
    return inner.leaveById(id);
  }

  @override
  Stream<List<LeaveRecord>> watchLeave(EmploymentId id) => inner.watchLeave(id);
  @override
  Future<MutationOutcome<DayException>> putException(
    DayException value, {
    Revision? expected,
  }) => inner.putException(value, expected: expected);
  @override
  Future<MutationOutcome<DayException>> removeException(
    DayExceptionId id, {
    required Revision expected,
  }) => inner.removeException(id, expected: expected);
  @override
  Future<MutationOutcome<LeaveRecord>> insertLeave(LeaveRecord value) =>
      inner.insertLeave(value);
  @override
  Future<MutationOutcome<LeaveRecord>> correctLeave(
    LeaveRecordId id, {
    required Revision expected,
    required LeaveRecord replacement,
    required String reason,
  }) async {
    calls++;
    if (gated) await gate.future;
    final outcome = await inner.correctLeave(
      id,
      expected: expected,
      replacement: replacement,
      reason: reason,
    );
    return lose
        ? const Uncertain(SafeFailureCode.commitOutcomeUnknown)
        : outcome;
  }
}

ProductionWorkProviders Function(ShiftsSheetFixture) _over(
  void Function(_Repository) save, {
  bool lose = false,
  bool gated = false,
}) => (fixture) {
  final plans = fixture.work.plans;
  final repository = _Repository(plans.repository, lose: lose, gated: gated);
  save(repository);
  return fixture.work.replacing(
    plans: DayPlanService(
      repository: repository,
      shifts: plans.shifts,
      ids: plans.ids,
      clock: plans.clock,
      zoneClocks: plans.zoneClocks,
    ),
  );
};

Future<void> _close(WidgetTester tester, FakeWindowClose window) async {
  unawaited(window.pressClose());
  await settleSheet(tester);
}

Future<void> _correct(WidgetTester tester) async {
  await click(tester, toolbarKey('Correct…'));
  await settleSheet(tester);
  await reasonText(tester, 'Was ill');
  await click(tester, panelKey(CorrectLeaveWords.primary));
  await settleSheet(tester);
}

void main() {
  testWidgets(
    'close waits for a running correction and remembers its replacement',
    (tester) async {
      final window = FakeWindowClose();
      late _Repository repository;
      final fixture = await pumpShiftsSheet(
        tester,
        closeApi: window,
        work: _over((value) => repository = value, gated: true),
      );
      await openLeave(tester, fixture);
      await _correct(tester);
      expect(repository.calls, 1);
      await _close(tester, window);
      expect(window.destroyed, 0);
      expect(find.byWidgetPredicate((w) => w is ConfirmWindow), findsNothing);
      repository.gate.complete();
      await settleSheet(tester);
      expect(window.destroyed, 1);
      expect(
        shellOf(tester).location.leave,
        shellOf(tester).leaveSheet!.selectedId,
      );
      expect(repository.calls, 1);
      await closeShiftsSheet(tester, fixture);
    },
  );

  testWidgets(
    'close with a lost response checks once and selects the saved replacement',
    (tester) async {
      final window = FakeWindowClose();
      late _Repository repository;
      final fixture = await pumpShiftsSheet(
        tester,
        closeApi: window,
        work: _over((value) => repository = value, lose: true),
      );
      await openLeave(tester, fixture);
      await _correct(tester);
      expect(
        shellOf(tester).leaveSheet!.action!.phase,
        CorrectLeavePhase.uncertain,
      );
      await _close(tester, window);
      await click(tester, windowKey('Reload and check'));
      await settleSheet(tester);
      expect(shellOf(tester).leaveSheet!.action, isNull);
      expect(window.destroyed, 0, reason: 'the check keeps the window open');
      expect(repository.calls, 1);
      await _close(tester, window);
      expect(window.destroyed, 1);
      await closeShiftsSheet(tester, fixture);
    },
  );

  testWidgets(
    'a failed check offers Quit anyway; File Quit uses the same guard',
    (tester) async {
      final window = FakeWindowClose();
      late _Repository repository;
      final fixture = await pumpShiftsSheet(
        tester,
        closeApi: window,
        work: _over((value) => repository = value, lose: true),
      );
      await openLeave(tester, fixture);
      await _correct(tester);
      repository.failReads = true;
      await click(tester, panelKey(CorrectLeaveWords.check));
      await settleSheet(tester);
      expect(
        shellOf(tester).leaveSheet!.action!.error,
        CorrectLeaveWords.unknown,
      );
      await click(tester, find.text('File').first);
      await click(tester, find.text('Quit').last);
      await settleSheet(tester);
      await click(tester, windowKey('Keep checking'));
      expect(window.destroyed, 0);
      await _close(tester, window);
      await click(tester, windowKey('Quit anyway'));
      await settleSheet(tester);
      expect(window.destroyed, 1);
      expect(repository.calls, 1);
      await closeShiftsSheet(tester, fixture);
    },
  );
}
