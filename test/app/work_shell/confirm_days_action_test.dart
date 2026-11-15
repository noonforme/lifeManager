import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/work_shell/agreement_commands.dart'
    show extendAgreement;
import 'package:lifeos/app/work_shell/basis_total.dart';
import 'package:lifeos/app/work_shell/confirm_days_action.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart'
    show EmploymentsWords;
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart'
    show CloseAgreementCommand;
import 'package:lifeos/features/work/domain/day_exception.dart' show LeaveType;
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/ui/ui.dart' show eraBoxDate;

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

LocalDate _oct(int day) => LocalDate(2026, 10, day);

ConfirmDayChoice _day(
  int date, {
  bool eligible = true,
  int pay = 21160,
  RateBasis basis = const GrossBasis(),
}) => ConfirmDayChoice(
  date: _oct(date),
  kind: ConfirmDayKind.planned,
  paidSeconds: 41400,
  pay: Money(minorUnits: pay),
  basis: basis,
  eligible: eligible,
);

/// A scripted `DayPlanService.confirm`: each date answers its outcome and
/// every call is counted.
final class _Confirms {
  _Confirms(this.outcomes);

  final Map<LocalDate, MutationOutcome<Object?>> outcomes;
  final calls = <LocalDate>[];

  Future<MutationOutcome<Object?>> call(EmploymentId id, LocalDate date) async {
    calls.add(date);
    return outcomes[date] ?? const Stale<Object?>();
  }
}

/// What a confirm wrote; the action reads only the outcome's kind.
const _committed = Committed<Object?>('written');

void main() {
  group('the model', () {
    ConfirmDaysAction action(
      List<ConfirmDayChoice> days,
      _Confirms confirms, {
      Future<Set<LocalDate>> Function()? confirmedDates,
    }) => ConfirmDaysAction(
      employmentId: fixtureEmployment,
      days: days,
      confirm: confirms.call,
      confirmedDates: confirmedDates ?? () async => {},
    );

    test('all eligible days start ticked; one without an agreement cannot '
        'be', () {
      final bulk = action([
        _day(5),
        _day(6),
        _day(7, eligible: false),
      ], _Confirms({}));
      expect(bulk.ticked, {_oct(5), _oct(6)});
      expect(bulk.canTick(_oct(7)), isFalse);
      bulk.toggle(_oct(7));
      expect(bulk.ticked, {_oct(5), _oct(6)});
      bulk.toggle(_oct(5));
      expect(bulk.ticked, {_oct(6)});
      expect(bulk.tickedPaidSeconds, 41400);
      expect(bulk.tickedPay.words, 'EUR 211.60');
      expect(bulk.primaryLabel, 'Confirm 1 day');
    });

    test('gross and net days are estimated apart, never as one sum', () {
      final bulk = action([
        _day(5, pay: 14720),
        _day(12, pay: 8000, basis: const NetBasis()),
      ], _Confirms({}));
      expect(bulk.tickedPay.mixed, isTrue);
      expect(bulk.tickedPay.cell, 'Mixed basis');
      expect(bulk.tickedPay.words, 'EUR 147.20 gross and EUR 80.00 net');
      expect(
        ConfirmDaysWords.windowMessage(2, _oct(5), _oct(12), bulk.tickedPay),
        contains('Their pay, EUR 147.20 gross and EUR 80.00 net, becomes'),
      );
    });

    test('run asks once, then confirms each ticked day', () async {
      final confirms = _Confirms({
        for (final date in [5, 6, 11]) _oct(date): _committed,
      });
      final bulk = action([_day(5), _day(6), _day(11)], confirms);
      final ask = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await bulk.run(ask.call), isTrue);
      expect(ask.asked.single.title, ConfirmDaysWords.title);
      expect(
        ask.asked.single.message,
        ConfirmDaysWords.windowMessage(
          3,
          _oct(5),
          _oct(11),
          BasisTotal([(const Money(minorUnits: 63480), const GrossBasis())]),
        ),
      );
      expect(ask.asked.single.proceed, 'Confirm 3 days');
      expect(confirms.calls, [_oct(5), _oct(6), _oct(11)]);
      expect(
        bulk.results.values.map((value) => value.result),
        everyElement(ConfirmDayResult.confirmed),
      );
      expect(bulk.allDone, isTrue);
      expect(bulk.ticked, isEmpty);
    });

    test('the result words count their days', () {
      expect(ConfirmDaysWords.summary(0, 2), '0 of 2 days confirmed.');
      expect(
        ConfirmDaysWords.summary(1, 2),
        '1 of 2 days confirmed. Its pay is final.',
      );
      expect(
        ConfirmDaysWords.summary(2, 3),
        '2 of 3 days confirmed. Their pay is final.',
      );
      expect(
        ConfirmDaysWords.notDone([_oct(5)]),
        '${eraBoxDate(_oct(5))} was not done.',
      );
      expect(
        ConfirmDaysWords.notDone([_oct(5), _oct(6)]),
        '${eraBoxDate(_oct(5))}, ${eraBoxDate(_oct(6))} were not done.',
      );
      expect(
        ConfirmDaysWords.notKnown([_oct(5)]),
        '${eraBoxDate(_oct(5))} is not known: Reload and check.',
      );
      expect(
        ConfirmDaysWords.notKnown([_oct(5), _oct(6)]),
        '${eraBoxDate(_oct(5))}, ${eraBoxDate(_oct(6))} are not known: Reload and check.',
      );
    });

    test('cancelling the window confirms nothing', () async {
      final confirms = _Confirms({});
      final bulk = action([_day(5)], confirms);
      expect(
        await bulk.run(ScriptedConfirm([ConfirmAnswer.cancel]).call),
        isFalse,
      );
      expect(confirms.calls, isEmpty);
      expect(bulk.results, isEmpty);
      expect(bulk.phase, ConfirmDaysPhase.picking);
    });

    test('mixed outcomes; Retry waits for the check and sends only what was '
        'not done', () async {
      final confirms = _Confirms({
        _oct(5): _committed,
        _oct(6): const Stale(),
        _oct(7): const Unavailable(SafeFailureCode.storageUnavailable),
        _oct(11): const Uncertain(SafeFailureCode.commitOutcomeUnknown),
        _oct(12): const Invalid({
          'agreement': [FieldIssue(FieldIssueCode.invalid)],
        }),
      });
      var confirmed = <LocalDate>{};
      final bulk = action(
        [
          for (final date in [5, 6, 7, 11, 12]) _day(date),
        ],
        confirms,
        confirmedDates: () async => confirmed,
      );
      await bulk.run(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      expect(bulk.results[_oct(5)]!.words, ConfirmDaysWords.confirmed);
      expect(bulk.results[_oct(6)]!.result, ConfirmDayResult.confirmed);
      expect(bulk.results[_oct(6)]!.words, ConfirmDaysWords.already);
      expect(bulk.results[_oct(7)]!.result, ConfirmDayResult.notDone);
      expect(bulk.results[_oct(7)]!.words, ConfirmDaysWords.unavailable);
      expect(bulk.results[_oct(11)]!.result, ConfirmDayResult.unknown);
      expect(bulk.results[_oct(11)]!.words, ConfirmDaysWords.unknown);
      expect(bulk.results[_oct(12)]!.words, ConfirmDaysWords.noAgreement);
      expect(bulk.primaryLabel, 'Reload and check');
      expect(bulk.left, 3);
      expect(bulk.hasUnknown, isTrue);
      // Retry cannot run while a day is not known.
      expect(
        await bulk.run(ScriptedConfirm([ConfirmAnswer.proceed]).call),
        isFalse,
      );
      confirmed = {_oct(5), _oct(6), _oct(11)};
      await bulk.check();
      expect(bulk.results[_oct(11)]!.result, ConfirmDayResult.confirmed);
      expect(bulk.primaryLabel, 'Retry 2 days');
      confirms.outcomes
        ..[_oct(7)] = _committed
        ..[_oct(12)] = _committed;
      confirms.calls.clear();
      await bulk.run(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      expect(confirms.calls, [_oct(7), _oct(12)]);
      expect(bulk.allDone, isTrue);
    });

    test('a check that cannot read leaves the day unknown', () async {
      final bulk = action(
        [_day(11)],
        _Confirms({
          _oct(11): const Uncertain(SafeFailureCode.commitOutcomeUnknown),
        }),
        confirmedDates: () async => throw StateError('unreadable'),
      );
      await bulk.run(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      await bulk.check();
      expect(bulk.results[_oct(11)]!.result, ConfirmDayResult.unknown);
      expect(bulk.unresolved, isTrue);
    });

    test('a check that finds the day not confirmed offers it again', () async {
      final bulk = action(
        [_day(11)],
        _Confirms({
          _oct(11): const Uncertain(SafeFailureCode.commitOutcomeUnknown),
        }),
      );
      await bulk.run(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      await bulk.check();
      expect(bulk.results[_oct(11)]!.result, ConfirmDayResult.notDone);
      expect(bulk.results[_oct(11)]!.words, ConfirmDaysWords.checkedNotDone);
      expect(bulk.primaryLabel, 'Retry 1 day');
    });

    test('a day an agreement now covers can be ticked, and is', () {
      final bulk = action([_day(5), _day(7, eligible: false)], _Confirms({}));
      expect(bulk.canTick(_oct(7)), isFalse);
      bulk.refreshEligible({_oct(5), _oct(7)});
      expect(bulk.canTick(_oct(7)), isTrue);
      expect(bulk.ticked, {_oct(5), _oct(7)});
      expect(bulk.isEligible(_oct(7)), isTrue);
    });

    test('leaving', () async {
      final quiet = action([_day(5), _day(6)], _Confirms({}));
      expect(await quiet.leave(ScriptedConfirm().call), LeaveDecision.proceed);

      final unticked = action([_day(5), _day(6)], _Confirms({}))
        ..toggle(_oct(5));
      final discard = ScriptedConfirm([ConfirmAnswer.revert]);
      expect(await unticked.leave(discard.call), LeaveDecision.proceed);
      expect(discard.asked.single.message, ConfirmDaysWords.discardTicks);

      final partial = action(
        [_day(5), _day(6)],
        _Confirms({
          _oct(5): _committed,
          _oct(6): const Unavailable(SafeFailureCode.storageUnavailable),
        }),
      );
      await partial.run(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      final keep = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(await partial.leave(keep.call), LeaveDecision.stay);
      expect(keep.asked.single.message, ConfirmDaysWords.closeLeft(1, 1));
      expect(keep.asked.single.cancel, 'Keep open');

      final unknown = action(
        [_day(11)],
        _Confirms({
          _oct(11): const Uncertain(SafeFailureCode.commitOutcomeUnknown),
        }),
      );
      await unknown.run(ScriptedConfirm([ConfirmAnswer.proceed]).call);
      final nothing = ScriptedConfirm();
      expect(await unknown.leave(nothing.call), LeaveDecision.stay);
      expect(nothing.asked, isEmpty);
      final quit = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(
        await unknown.leave(quit.call, kind: LeaveKind.quit),
        LeaveDecision.stay,
      );
      expect(quit.asked.single, same(uncheckedQuitRequest));
    });
  });

  group('on the To confirm sheet', () {
    late ShiftsSheetFixture fixture;
    late ScriptedConfirm confirm;

    setUp(() async {
      fixture = await ShiftsSheetFixture.create();
      confirm = ScriptedConfirm();
    });

    tearDown(() => fixture.dispose());

    Future<void> until(bool Function() condition) async {
      for (var turn = 0; turn < 200 && !condition(); turn++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(condition(), isTrue, reason: 'condition never held');
    }

    Future<ShiftsSheetController> open({
      WorkSheetKind kind = WorkSheetKind.toConfirm,
    }) async {
      final sheet = ShiftsSheetController(
        work: fixture.work,
        reads: fixture.reads,
        employmentId: fixtureEmployment,
        from: _oct(5),
        to: _oct(19),
        today: ShiftsSheetFixture.today,
        timezoneId: ShiftsSheetFixture.zone,
        confirm: (request) => confirm.call(request),
        kind: kind,
      )..start();
      addTearDown(sheet.dispose);
      await until(() => sheet.loaded);
      return sheet;
    }

    test('a day without an agreement is listed but not ticked', () async {
      final current = (await fixture.reads.agreementsOf(fixtureEmployment))
          .single;
      await fixture.work.agreement.closeAgreement(
        CloseAgreementCommand(
          agreementId: current.id,
          employmentId: fixtureEmployment,
          end: _oct(6),
          expectedRevision: current.revision,
        ),
      );
      final sheet = await open();
      await until(
        () => sheet.rows.whereType<PlannedRow>().any(
          (row) => row.planned.withoutAgreement,
        ),
      );
      expect(await sheet.openConfirmDays(), isTrue);
      final bulk = sheet.confirmDays!;
      expect(bulk.ticked, {_oct(5), _oct(6)});
      expect(bulk.canTick(_oct(7)), isFalse);
      expect(bulk.days.map((day) => day.date), contains(_oct(7)));
    });

    test(
      'an agreement extended while picking makes its days tickable',
      () async {
        final current = (await fixture.reads.agreementsOf(fixtureEmployment))
            .single;
        await fixture.work.agreement.closeAgreement(
          CloseAgreementCommand(
            agreementId: current.id,
            employmentId: fixtureEmployment,
            end: _oct(6),
            expectedRevision: current.revision,
          ),
        );
        final sheet = await open();
        await until(
          () => sheet.rows.whereType<PlannedRow>().any(
            (row) => row.planned.withoutAgreement,
          ),
        );
        expect(await sheet.openConfirmDays(), isTrue);
        final bulk = sheet.confirmDays!;
        expect(bulk.canTick(_oct(7)), isFalse);
        await extendAgreement(
          work: fixture.work,
          reads: fixture.reads,
          confirm: ScriptedConfirm([ConfirmAnswer.proceed]).call,
          employmentId: fixtureEmployment,
          days: [_oct(7)],
        );
        await until(() => bulk.canTick(_oct(7)));
        expect(bulk.ticked, contains(_oct(7)));
      },
    );

    test('a full success closes the panel and says so', () async {
      final sheet = await open();
      expect(await sheet.openConfirmDays(), isTrue);
      expect(sheet.confirmDays!.ticked, hasLength(9));
      expect(sheet.confirmBlocked, ShiftsCommandWords.actionOpen);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.runConfirmDays();
      expect(sheet.confirmDays, isNull);
      expect(sheet.notice, ConfirmDaysWords.allDone(9));
      await until(
        () => !sheet.rows.any(
          (row) =>
              (row is PlannedRow || row is LeaveRow) &&
              row.date.compareTo(ShiftsSheetFixture.today) < 0,
        ),
      );
    });

    test("a leave day's pay counts in the ticked pay", () async {
      await fixture.work.plans.markLeave(
        fixtureEmployment,
        _oct(12),
        leaveType: LeaveType.vacation,
        illnessStartedOn: null,
      );
      final sheet = await open();
      await until(
        () => sheet.rows.whereType<LeaveRow>().any((row) => row.pay != null),
      );
      final leave = sheet.rows.whereType<LeaveRow>().single;
      expect(await sheet.openConfirmDays(), isTrue);
      final choice = sheet.confirmDays!.days.singleWhere(
        (day) => day.date == _oct(12),
      );
      expect(choice.pay, leave.pay!.amount);
    });

    test('a selected day that a full success confirmed is selected as it is '
        'now', () async {
      final sheet = await open();
      final day = sheet.rows.whereType<PlannedRow>().firstWhere(
        (row) => row.date.compareTo(ShiftsSheetFixture.today) < 0,
      );
      expect(await sheet.select(day.id), isTrue);
      expect(await sheet.openConfirmDays(), isTrue);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.runConfirmDays();
      expect(sheet.confirmDays, isNull);
      expect(sheet.selectedId, startsWith('shift:'));
      expect(sheet.readOnlyReason, isNot(ShiftsCommandWords.actionOpen));
      expect(sheet.notice, ConfirmDaysWords.allDone(9));
      await until(() => sheet.selectedRow?.date == day.date);
    });

    test('Confirm worked days opens only on To confirm and not on an '
        'archived employment', () async {
      final shifts = await open(kind: WorkSheetKind.shifts);
      expect(await shifts.openConfirmDays(), isFalse);
      final sheet = await open();
      sheet.archived = true;
      expect(sheet.confirmDaysBlocked, EmploymentsWords.archivedReadOnly);
      expect(await sheet.openConfirmDays(), isFalse);
    });
  });
}
