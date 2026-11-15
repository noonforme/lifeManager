import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/pay_edit.dart';
import 'package:lifeos/app/work_shell/pay_action.dart';
import 'package:lifeos/app/work_shell/pay_sheet_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/pay_period_service.dart';
import 'package:lifeos/features/work/application/payslip_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';

import '../../support/leave_sheet_driver.dart' show confirmLeave;
import '../../support/pay_scripted_repository.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

const day = LocalDate(2026, 10, 1);
const values = PayValues(start: day, end: LocalDate(2026, 10, 31), issued: day);

void main() {
  late ShiftsSheetFixture fixture;
  late PayPeriod period;
  late Payslip original;
  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    period = (await fixture.work.periods.createPeriod(
      const CreatePayPeriodCommand(
        employmentId: fixtureEmployment,
        start: day,
        end: LocalDate(2026, 10, 31),
        label: 'October',
      ),
    ) as Committed<PayPeriod>).value;
    original = (await fixture.work.payslips.recordPayslip(
      RecordPayslipCommand(
        periodId: period.id,
        issuedDate: day,
        paidDate: null,
        amountMinorUnits: 10000,
        basis: const GrossBasis(),
        grossMinorUnits: null,
        netMinorUnits: null,
        deductionMinorUnits: null,
        reference: null,
        note: null,
      ),
    ) as Committed<Payslip>).value;
  });
  tearDown(() => fixture.dispose());

  test('exact cents and malformed optional evidence', () {
    expect(parseCents(' 12.3 '), 1230);
    expect(parseCents('0.01'), 1);
    for (final invalid in [
      '1.234',
      '-1',
      '1e3',
      '1,23',
      'NaN',
      '900719925474100',
    ]) {
      expect(parseCents(invalid), isNull);
    }
    final v = values
        .withField('period', period.id)
        .withField('amount', '20.10')
        .withField('net', 'oops');
    expect(validatePay(PayKind.payslips, v).keys, ['net']);
    expect(
      validatePay(PayKind.periods, values.withField('end', day.addDays(-1))),
      contains('end'),
    );
    expect(values, values.withField('label', ''));
  });

  test(
    'atomic correction writes replacement values and preserves original facts',
    () async {
      final corrected = (await fixture.work.payslips.correctPayslip(
        CorrectPayslipCommand(
          originalId: original.id,
          replacementId: fixture.schedule.ids.payslipId(),
          expectedRevision: original.revision,
          voidReason: 'Wrong evidence',
          replacement: PayValues.ofPayslip(original)
              .withField('amount', '123.45')
              .withField('basis', const NetBasis())
              .withField('reference', ' revised ')
              .command(),
        ),
      ) as Committed<Payslip>).value;
      expect(corrected.amount.minorUnits, 12345);
      expect(corrected.basis, isA<NetBasis>());
      expect(corrected.reference, 'revised');
      expect(corrected.replacedPayslipId, original.id);
      final old = (await fixture.reads.payslip(original.id))!;
      expect(old.isEffective, isFalse);
      expect(old.amount, original.amount);
      expect(old.voidReason, 'Wrong evidence');
      expect(old.replacementPayslipId, corrected.id);
    },
  );

  test('correction cannot move periods and invalid evidence does not void original', () async {
    for (final draft in [
      PayValues.ofPayslip(original).withField(
        'period',
        const PayPeriodId('0190f5d2-6a00-7000-8000-000000000999'),
      ),
      PayValues.ofPayslip(original).withField('amount', '0'),
    ]) {
      final id = fixture.schedule.ids.payslipId();
      expect(
        await fixture.work.payslips.correctPayslip(
          CorrectPayslipCommand(
            originalId: original.id,
            replacementId: id,
            expectedRevision: original.revision,
            voidReason: 'Bad',
            replacement: draft.command(),
          ),
        ),
        isA<Invalid<Payslip>>(),
      );
      expect(await fixture.reads.payslip(id), isNull);
      expect((await fixture.reads.payslip(original.id))!.isEffective, isTrue);
    }
  });

  PaySession session({bool lost = false, bool write = false}) {
    final work = lost
        ? fixture.work.replacing(
            payslips: PayslipService(
              ScriptedPayslips(
                fixture.work.payslips,
                fixture.reads.payslip,
                onRecord: (value) async {
                  if (write) {
                    await fixture.work.payslips.recordPayslip(
                      PayValues.ofPayslip(value).command(id: value.id),
                    );
                  }
                  throw StateError('lost response');
                },
              ),
              idFactory: fixture.schedule.ids,
              clock: fixture.schedule.clock,
            ),
          )
        : fixture.work;
    final edit = PaySession(
      adapter: PayAdapter(
        kind: PayKind.payslips,
        work: work,
        reads: fixture.reads,
        employment: fixtureEmployment,
        defaults: values.withField('period', period.id),
      ),
    );
    addTearDown(edit.dispose);
    edit.edit(edit.draft.withField('amount', '12.34'), field: 'amount');
    return edit;
  }

  test('new payslip Save and leave use Record / Discard / Cancel and saved facts freeze', () async {
    final edit = session();
    ConfirmRequest? request;
    expect(
      await edit.save((r) async {
        request = r;
        return ConfirmAnswer.cancel;
      }),
      SaveResult.cancelled,
    );
    expect(request!.proceed, 'Record payslip');
    expect(request!.revert, 'Discard');
    expect(edit.dirty, isTrue);
    expect(
      await edit.leave((_) async => ConfirmAnswer.proceed),
      LeaveDecision.proceed,
    );
    expect(edit.baseline!.payslip!.amount.minorUnits, 1234);
    expect(edit.isNew, isFalse);
  });

  for (final wrote in [false, true]) {
    test(
      'lost creation response read-back uses the submitted id (write=$wrote)',
      () async {
        final edit = session(lost: true, write: wrote);
        await edit.save((_) async => ConfirmAnswer.proceed);
        expect(edit.phase, EditPhase.uncertain);
        expect(
          await edit.leave((_) async => ConfirmAnswer.proceed),
          LeaveDecision.stay,
        );
        await edit.check();
        expect(edit.phase, wrote ? EditPhase.committed : EditPhase.dirty);
        expect(edit.baseline != null, wrote);
        expect(edit.draft.amount, '12.34');
        expect(edit.dirty, !wrote);
      },
    );
  }

  for (final outcome in <MutationOutcome<Payslip>>[
    const Invalid({
      'amount': [FieldIssue(FieldIssueCode.invalid)],
    }),
    const Stale(),
    const Missing(),
    const Unavailable(SafeFailureCode.storageUnavailable),
    const Uncertain(SafeFailureCode.commitOutcomeUnknown),
  ]) {
    test(
      'correction handles ${outcome.runtimeType} without discarding input',
      () async {
        final repo = ScriptedPayslips(
          fixture.work.payslips,
          fixture.reads.payslip,
          result: outcome,
        );
        final work = fixture.work.replacing(
          payslips: PayslipService(
            repo,
            idFactory: fixture.schedule.ids,
            clock: fixture.schedule.clock,
          ),
        );
        final action =
            PayAction(
                kind: PayActionKind.correct,
                original: PayRecord.payslip(original),
                work: work,
                reads: fixture.reads,
              )
              ..set('amount', '150.00')
              ..set('reason', 'Correct amount');
        addTearDown(action.dispose);
        await action.submit();
        expect(action.values!.amount, '150.00');
        expect(action.reason, 'Correct amount');
        expect(repo.calls, 1);
        expect(
          action.phase,
          outcome is Uncertain
              ? PayActionPhase.uncertain
              : outcome is Stale || outcome is Missing
              ? PayActionPhase.blocked
              : PayActionPhase.input,
        );
        if (outcome is Uncertain) {
          await action.submit();
          expect(repo.calls, 1);
          expect(action.phase, PayActionPhase.input);
        }
      },
    );
  }

  test('correction single flight, exact read-back and discard guard', () async {
    final gate = Completer<void>();
    final repo = ScriptedPayslips(
      fixture.work.payslips,
      fixture.reads.payslip,
      gate: gate.future,
      write: true,
      result: const Uncertain(SafeFailureCode.commitOutcomeUnknown),
    );
    final action = PayAction(
      kind: PayActionKind.correct,
      original: PayRecord.payslip(original),
      work: fixture.work.replacing(
        payslips: PayslipService(
          repo,
          idFactory: fixture.schedule.ids,
          clock: fixture.schedule.clock,
        ),
      ),
      reads: fixture.reads,
    );
    addTearDown(action.dispose);
    expect(await action.submit(), isNull);
    expect(action.errors, contains('reason'));
    action
      ..set('reason', 'Fix')
      ..set('amount', '120.00');
    expect(
      await action.leave((_) async => ConfirmAnswer.cancel),
      LeaveDecision.stay,
    );
    expect(
      await action.leave((_) async => ConfirmAnswer.revert),
      LeaveDecision.proceed,
    );
    final running = action.submit();
    await action.submit();
    expect(action.phase, PayActionPhase.running);
    expect(
      await action.leave((_) async => ConfirmAnswer.revert),
      LeaveDecision.stay,
    );
    gate.complete();
    await running;
    expect(action.phase, PayActionPhase.uncertain);
    final saved = (await action.submit())!.payslip!;
    expect(saved.amount.minorUnits, 12000);
    expect(repo.calls, 1);
  });

  test(
    'overlapping period keeps the draft and attaches its date error',
    () async {
      final adapter = PayAdapter(
        kind: PayKind.periods,
        work: fixture.work,
        reads: fixture.reads,
        employment: fixtureEmployment,
        defaults: values,
      );
      final edit = PaySession(adapter: adapter);
      addTearDown(edit.dispose);
      expect(
        await edit.save((_) async => ConfirmAnswer.proceed),
        SaveResult.invalid,
      );
      expect(edit.issues, contains('end'));
      expect(edit.draft, values);
    },
  );

  test(
    'reconciliation includes leave, isolates bases and excludes void evidence',
    () async {
      await fixture.finishShift(6);
      await confirmLeave(fixture, 7);
      Future<WorkRegisterProjection> read() => fixture.work.workRepository
          .watchRegister(
            const WorkScope(employmentId: fixtureEmployment, temporal: null),
          )
          .first;
      final before = (await read()).periodSheet.single.groups.single;
      expect(before.expected!.minorUnits, 14720 + 21160);
      expect(before.paid!.minorUnits, 10000);
      expect(before.difference!.minorUnits, 10000 - 14720 - 21160);
      await fixture.work.payslips.correctPayslip(
        CorrectPayslipCommand(
          originalId: original.id,
          replacementId: fixture.schedule.ids.payslipId(),
          expectedRevision: original.revision,
          voidReason: 'Net evidence',
          replacement: PayValues.ofPayslip(original)
              .withField('basis', const NetBasis())
              .withField('amount', '125.00')
              .command(),
        ),
      );
      final after = (await read()).periodSheet.single.groups;
      expect(after, hasLength(2));
      final gross = after.singleWhere((g) => g.basis is GrossBasis);
      final net = after.singleWhere((g) => g.basis is NetBasis);
      expect(gross.expected!.minorUnits, 35880);
      expect(gross.paid, isNull);
      expect(gross.status, isA<MissingPayslip>());
      expect(net.expected, isNull);
      expect(net.paid!.minorUnits, 12500);
      expect(net.status, isA<UnmatchedPayslip>());
    },
  );

  for (final wrote in [false, true]) {
    test(
      'period state lost response checks its revision (write=$wrote)',
      () async {
        final repository = ScriptedPeriods(fixture.work.periods, write: wrote);
        final work = fixture.work.replacing(
          periods: PayPeriodService(
            repository,
            idFactory: fixture.schedule.ids,
            clock: fixture.schedule.clock,
          ),
        );
        final action = PayAction(
          kind: PayActionKind.review,
          original: PayRecord.period(period),
          work: work,
          reads: fixture.reads,
        );
        addTearDown(action.dispose);
        await action.submit();
        expect(action.phase, PayActionPhase.uncertain);
        final saved = await action.submit();
        expect(saved != null, wrote);
        expect(repository.calls, 1);
        expect(
          action.phase,
          wrote ? PayActionPhase.completed : PayActionPhase.input,
        );
      },
    );
  }

  test(
    'period state actions and archived guards retain fresh selection',
    () async {
      final coordinator = LeaveCoordinator(
        confirm: (_) async => ConfirmAnswer.cancel,
      );
      final sheet = PaySheetController(
        kind: PayKind.periods,
        work: fixture.work,
        reads: fixture.reads,
        employmentId: fixtureEmployment,
        today: day,
        coordinator: coordinator,
        confirm: (_) async => ConfirmAnswer.cancel,
      );
      addTearDown(sheet.dispose);
      sheet.start();
      await sheet.ready;
      sheet.show(period.id);
      await sheet.openAction(PayActionKind.review);
      expect(sheet.selected!.period!.state, PayPeriodState.reviewed);
      expect(await sheet.openAction(PayActionKind.review), isFalse);
      await sheet.openAction(PayActionKind.reopen);
      expect(sheet.selected!.period!.state, PayPeriodState.open);
      sheet.archived = true;
      expect(await sheet.add(), isFalse);
      expect(await sheet.openAction(PayActionKind.review), isFalse);
    },
  );
}

final class ScriptedPeriods implements PayPeriodRepository {
  ScriptedPeriods(this.real, {required this.write});
  final PayPeriodService real;
  final bool write;
  int calls = 0;
  @override
  Future<MutationOutcome<PayPeriod>> createPeriod(PayPeriod value) async =>
      throw UnimplementedError();
  @override
  Future<MutationOutcome<PayPeriod>> setPeriodState(
    PayPeriodId id, {
    required PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  }) async {
    calls++;
    if (write) {
      await real.setState(
        SetPayPeriodStateCommand(
          id: id,
          state: state,
          expectedRevision: expected,
        ),
      );
    }
    return const Uncertain(SafeFailureCode.commitOutcomeUnknown);
  }
}
