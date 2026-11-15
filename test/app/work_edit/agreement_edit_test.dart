import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/agreement_edit.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_correction.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/data/work_write_store.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/shift.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';

/// The fixture agreement's terms at EUR 20.00 an hour.
AgreementTerms _raised(AgreementRecord record) => AgreementTerms(
  effectiveStart: record.value.effectiveStart,
  effectiveEnd: record.value.effectiveEnd,
  hourlyRateMicroEur: 20000000,
  basis: record.value.basis,
  label: record.value.label,
  note: record.value.note,
  overtimeThresholdMinutes: record.value.overtimeThresholdMinutes,
  overtimeMultiplier: record.value.overtimeMultiplier,
);

void main() {
  late ScheduleFixture fixture;
  late WorkReads reads;
  late DriftWorkRepository work;
  late AgreementService service;
  late AgreementAdapter adapter;

  setUp(() async {
    fixture = await ScheduleFixture.create();
    reads = WorkReads(fixture.database);
    work = DriftWorkRepository(fixture.database, clock: fixture.clock);
    service = AgreementService(
      work,
      idFactory: fixture.ids,
      clock: fixture.clock,
    );
    adapter = AgreementAdapter(
      employmentId: fixtureEmployment,
      defaults: const AgreementTerms(
        effectiveStart: LocalDate(2026, 1, 1),
        effectiveEnd: LocalDate(2026, 8, 31),
        hourlyRateMicroEur: 17000000,
        basis: GrossBasis(),
        label: null,
        note: null,
      ),
      service: service,
      preview: work,
      reads: reads,
      clock: fixture.clock,
    );
  });

  tearDown(() => fixture.dispose());

  RecordEditSession<AgreementRecord, AgreementValues> open([
    AgreementRecord? record,
  ]) {
    final edit = RecordEditSession(adapter: adapter, baseline: record);
    addTearDown(edit.dispose);
    return edit;
  }

  Future<AgreementRecord> agreement() async =>
      (await reads.agreement(fixtureEmployment, fixtureAgreement))!;

  /// Finalizes an 8-hour manual shift on [day] of October, paid by the
  /// fixture agreement.
  Future<WorkShift> finishShift(int day) async {
    final start = DateTime.utc(2026, 10, day, 5);
    final outcome = await fixture.shifts.createAndFinalizeManual(
      WorkShift(
        id: fixture.ids.shiftId(),
        employmentId: fixtureEmployment,
        agreementId: null,
        state: ShiftState.draft,
        startUtc: start,
        endUtc: start.add(const Duration(hours: 8)),
        timezoneId: 'Europe/Vilnius',
        localStartDate: LocalDate(2026, 10, day),
        note: null,
        voidReason: null,
        replacementShiftId: null,
        replacedShiftId: null,
        createdAtUtc: fixture.clock.value,
        updatedAtUtc: fixture.clock.value,
        revision: const Revision(0),
      ),
      const [],
    );
    return (outcome as Committed<WorkShift>).value;
  }

  test('an unused agreement saves without asking', () async {
    final edit = open(await agreement());
    edit.edit(AgreementValues(_raised(edit.baseline!)));
    final confirm = ScriptedConfirm();
    expect(await edit.save(confirm.call), SaveResult.committed);
    expect(confirm.asked, isEmpty);
    expect((await agreement()).value.hourlyRateMicroEur, 20000000);
  });

  test('correcting an agreement in use asks Save and reprice with its '
      'impact, and reprices on Save', () async {
    await finishShift(20);
    final edit = open(await agreement());
    edit.edit(AgreementValues(_raised(edit.baseline!)));
    final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(await edit.save(confirm.call), SaveResult.committed);
    final asked = confirm.asked.single;
    expect(asked.proceed, 'Save and reprice');
    expect(asked.revert, 'Revert');
    expect(asked.cancel, 'Cancel');
    expect(
      asked.message,
      'Saving reprices 1 finished shift: EUR 147.20 → EUR 160.00.',
    );
    expect(asked.consent, isA<AgreementCorrectionImpact>());
    expect((await agreement()).value.hourlyRateMicroEur, 20000000);
  });

  test('Revert drops the correction; Cancel keeps it unsaved', () async {
    await finishShift(20);
    final edit = open(await agreement());
    edit.edit(AgreementValues(_raised(edit.baseline!)));
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.cancel]).call),
      SaveResult.cancelled,
    );
    expect(edit.dirty, isTrue);
    expect(
      await edit.save(ScriptedConfirm([ConfirmAnswer.revert]).call),
      SaveResult.reverted,
    );
    expect(edit.dirty, isFalse);
    expect((await agreement()).value.hourlyRateMicroEur, 18400000);
  });

  test('a repricing that changes before the commit is asked again with the '
      'fresh impact; the save passes only the last consent', () async {
    await finishShift(20);
    final edit = open(await agreement());
    edit.edit(AgreementValues(_raised(edit.baseline!)));
    final asked = <ConfirmRequest>[];
    Future<ConfirmAnswer> confirm(ConfirmRequest request) async {
      asked.add(request);
      // Another shift is finalized while the first window is open.
      if (asked.length == 1) await finishShift(21);
      return ConfirmAnswer.proceed;
    }

    expect(await edit.save(confirm), SaveResult.committed);
    expect(asked, hasLength(2));
    expect(asked.first.message, contains('1 finished shift:'));
    expect(asked.last.message, contains('2 finished shifts:'));
    expect((await agreement()).value.hourlyRateMicroEur, 20000000);
  });

  test('a repricing that disappears before the commit is asked once more '
      'and saves without consent', () async {
    final shift = await finishShift(20);
    final edit = open(await agreement());
    edit.edit(AgreementValues(_raised(edit.baseline!)));
    final asked = <ConfirmRequest>[];
    Future<ConfirmAnswer> confirm(ConfirmRequest request) async {
      asked.add(request);
      // The only shift it pays is voided while the first window is open.
      if (asked.length == 1) {
        await fixture.shifts.commitVoid(
          shift.id,
          expected: shift.revision,
          voidReason: 'Entered twice',
          nowUtc: fixture.clock.value,
        );
      }
      return ConfirmAnswer.proceed;
    }

    expect(await edit.save(confirm), SaveResult.committed);
    expect(asked, hasLength(2));
    expect(asked.last, same(repricingGoneRequest));
    expect((await agreement()).value.hourlyRateMicroEur, 20000000);
  });

  test('a correction that changes no pay asks nothing', () async {
    await finishShift(20);
    final edit = open(await agreement());
    final terms = edit.baseline!.value;
    edit.edit(
      AgreementValues(AgreementTerms.of(terms).withLabel('Depot rate')),
    );
    final confirm = ScriptedConfirm();
    expect(await edit.save(confirm.call), SaveResult.committed);
    expect(confirm.asked, isEmpty);
  });

  test(
    'an agreement changed elsewhere meanwhile is stale, not asked again',
    () async {
      await finishShift(20);
      final edit = open(await agreement());
      edit.edit(AgreementValues(_raised(edit.baseline!)));
      final current = await agreement();
      await service.updateAgreement(
        UpdateAgreementCommand(
          agreementId: fixtureAgreement,
          employmentId: fixtureEmployment,
          expectedRevision: current.value.revision,
          terms: AgreementTerms.of(current.value).withLabel('Elsewhere'),
        ),
      );
      final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(await edit.save(confirm.call), SaveResult.stale);
      expect(confirm.asked, hasLength(1));
      expect(edit.phase, EditPhase.stale);
    },
  );

  test('a new agreement saves as the next version', () async {
    final edit = open()
      ..edit(
        AgreementValues(
          AgreementTerms.of(
            (await agreement()).value,
            effectiveStart: const LocalDate(2026, 1, 1),
            effectiveEnd: () => const LocalDate(2026, 8, 31),
          ),
        ),
      );
    final confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
    expect(await edit.leave(confirm.call), LeaveDecision.proceed);
    expect(confirm.asked.single, same(newRecordRequest));
    expect(edit.baseline!.value.version, 2);
    expect(await reads.agreementsOf(fixtureEmployment), hasLength(2));
  });

  test('a new agreement over dates another covers is refused', () async {
    final edit = open()
      ..edit(
        AgreementValues(
          AgreementTerms.of(
            (await agreement()).value,
            effectiveStart: const LocalDate(2026, 10, 1),
          ),
        ),
      );
    expect(await edit.save(ScriptedConfirm().call), SaveResult.invalid);
    expect(edit.problem, AgreementProblems.overlap);
  });

  test('a rate of zero is refused before any write', () {
    final edit = open()
      ..edit(
        const AgreementValues(
          AgreementTerms(
            effectiveStart: LocalDate(2026, 1, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 0,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      );
    expect(edit.issues, {'hourlyRate': AgreementProblems.rate});
  });
  test("the constructor's rules are field problems before Save", () {
    final edit = open();
    edit.edit(
      const AgreementValues(
        AgreementTerms(
          effectiveStart: LocalDate(2026, 1, 1),
          effectiveEnd: null,
          hourlyRateMicroEur: 17000000,
          basis: GrossBasis(),
          label: null,
          note: null,
          overtimeThresholdMinutes: 0,
          nightEnabled: true,
          nightStartMinute: 1320,
          nightEndMinute: 1320,
          sickEmployerDays: 31,
        ),
      ),
    );
    expect(edit.issues, {
      AgreementField.overtimeHours: AgreementProblems.hours,
      AgreementField.nightEnd: AgreementProblems.nightWindow,
      AgreementField.sickDays: AgreementProblems.sickDays,
    });
  });

  test('a failing re-read after Stale is still Stale', () async {
    final gate = ReadGate();
    final gated = await ScheduleFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(gated.dispose);
    final gatedReads = WorkReads(gated.database);
    final gatedWork = DriftWorkRepository(gated.database, clock: gated.clock);
    final adapter = AgreementAdapter(
      employmentId: fixtureEmployment,
      defaults: _raised(
        (await gatedReads.agreement(fixtureEmployment, fixtureAgreement))!,
      ),
      service: AgreementService(
        _ThenFail(gatedWork, gate),
        idFactory: gated.ids,
        clock: gated.clock,
      ),
      preview: gatedWork,
      reads: gatedReads,
      clock: gated.clock,
    );
    final old = (await gatedReads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!;
    // Moved elsewhere: the adapter's command is Stale.
    await AgreementService(
      gatedWork,
      idFactory: gated.ids,
      clock: gated.clock,
    ).updateAgreement(
      UpdateAgreementCommand(
        agreementId: fixtureAgreement,
        employmentId: fixtureEmployment,
        expectedRevision: old.value.revision,
        terms: AgreementTerms.of(old.value).withLabel('Elsewhere'),
      ),
    );
    final result = await adapter.submit(old, AgreementValues(_raised(old)));
    expect(result, isA<Submitted<AgreementRecord>>());
    expect(
      (result as Submitted<AgreementRecord>).outcome,
      isA<Stale<AgreementRecord>>(),
    );
  });
}

/// Runs each transaction, then makes every later read fail.
final class _ThenFail implements WorkCommandRepository {
  _ThenFail(this._inner, this._gate);

  final WorkCommandRepository _inner;
  final ReadGate _gate;

  @override
  Future<T> transaction<T>(
    Future<T> Function(WorkWriteStore store) body,
  ) async {
    final result = await _inner.transaction(body);
    _gate.failing = true;
    return result;
  }
}

extension on AgreementTerms {
  AgreementTerms withLabel(String label) => AgreementTerms(
    effectiveStart: effectiveStart,
    effectiveEnd: effectiveEnd,
    hourlyRateMicroEur: hourlyRateMicroEur,
    basis: basis,
    label: label,
    note: note,
    overtimeThresholdMinutes: overtimeThresholdMinutes,
    overtimeMultiplier: overtimeMultiplier,
    nightEnabled: nightEnabled,
    nightStartMinute: nightStartMinute,
    nightEndMinute: nightEndMinute,
    nightMultiplier: nightMultiplier,
    holidayCalendar: holidayCalendar,
    holidayMultiplier: holidayMultiplier,
    premiumStacking: premiumStacking,
    vacationPay: vacationPay,
    sickPay: sickPay,
    sickEmployerDays: sickEmployerDays,
  );
}
