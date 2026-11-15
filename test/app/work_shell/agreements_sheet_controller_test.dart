import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/agreement_edit.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/agreement_action.dart'
    show AgreementActionKind;
import 'package:lifeos/app/work_shell/agreements_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/ids.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

/// Waits until [condition] holds, letting the database's streams run.
Future<void> until(bool Function() condition) async {
  for (var turn = 0; turn < 200 && !condition(); turn++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'condition never held');
}

void main() {
  late ShiftsSheetFixture fixture;
  late ScriptedConfirm confirm;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    confirm = ScriptedConfirm();
  });

  tearDown(() => fixture.dispose());

  Future<AgreementsSheetController> open({
    ProductionWorkProviders? work,
    WorkReads? reads,
    EmploymentId employment = fixtureEmployment,
  }) async {
    final sheet = AgreementsSheetController(
      work: work ?? fixture.work,
      reads: reads ?? fixture.reads,
      employmentId: employment,
      today: ShiftsSheetFixture.today,
      confirm: confirm.call,
      coordinator: LeaveCoordinator(confirm: confirm.call),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    return sheet;
  }

  Future<PayAgreement> v1() async => (await fixture.reads.agreement(
    fixtureEmployment,
    fixtureAgreement,
  ))!.value;

  test('the sheet lists the employment\'s versions and selects one', () async {
    final sheet = await open();
    expect(sheet.loaded, isTrue);
    expect(sheet.rows.single.agreement.id, fixtureAgreement);
    expect(sheet.selectedId, isNull);
    expect(sheet.place, const WorkLocation.agreements(fixtureEmployment));
    expect(await sheet.select(fixtureAgreement), isTrue);
    expect(sheet.selectedId, fixtureAgreement.value);
    expect(sheet.session!.baseline!.value.id, fixtureAgreement);
    expect(
      sheet.place,
      const WorkLocation.agreements(
        fixtureEmployment,
        agreement: fixtureAgreement,
      ),
    );
  });

  test('an open panel keeps its version in the place', () async {
    final sheet = await open();
    expect(await sheet.select(fixtureAgreement), isTrue);
    expect(await sheet.openAction(AgreementActionKind.end), isTrue);
    expect(sheet.session, isNull);
    expect(
      sheet.place,
      const WorkLocation.agreements(
        fixtureEmployment,
        agreement: fixtureAgreement,
      ),
    );
  });

  test('a rate change on an unused version saves without asking', () async {
    final sheet = await open();
    await sheet.select(fixtureAgreement);
    expect(
      sheet.editField(
        fixtureAgreement.value,
        AgreementField.hourlyRate,
        '19.00',
      ),
      isNull,
    );
    expect(await sheet.save(), SaveResult.committed);
    expect(confirm.asked, isEmpty);
    await until(
      () => sheet.rows.single.agreement.hourlyRateMicroEur == 19000000,
    );
    expect(sheet.selectedId, fixtureAgreement.value);
  });

  test('an edit of another row than the selected one is refused', () async {
    final sheet = await open();
    expect(
      sheet.editField(fixtureAgreement.value, AgreementField.label, 'x'),
      AgreementProblems.notEditable,
    );
  });

  test('a new version after an ended one starts the next day', () async {
    final current = await v1();
    await fixture.work.agreement.closeAgreement(
      CloseAgreementCommand(
        agreementId: current.id,
        employmentId: fixtureEmployment,
        end: const LocalDate(2026, 10, 31),
        expectedRevision: current.revision,
      ),
    );
    final sheet = await open();
    await until(() => sheet.rows.single.agreement.effectiveEnd != null);
    expect(await sheet.addAgreement(), isTrue);
    expect(sheet.selectedId, newAgreementId);
    expect(sheet.removeBlocked, AgreementsCommandWords.undoDropsNew);
    final terms = sheet.session!.draft.terms;
    expect(terms.effectiveStart, const LocalDate(2026, 11, 1));
    expect(terms.effectiveEnd, isNull);
    expect(terms.hourlyRateMicroEur, 18400000);
    expect(terms.overtimeThresholdMinutes, current.overtimeThresholdMinutes);
    // Defaults alone store nothing (spec 4.3); a value entered does.
    sheet.editField(newAgreementId, AgreementField.label, 'Winter');
    expect(await sheet.save(), SaveResult.committed);
    await until(() => sheet.rows.length == 2);
    final saved = sheet.rows.last.agreement;
    expect(saved.version, 2);
    expect(sheet.selectedId, saved.id.value);
  });

  test('an overlapping new version is refused on its dates', () async {
    final sheet = await open();
    await sheet.addAgreement();
    sheet.editField(newAgreementId, AgreementField.label, 'Winter');
    // v1 runs on, so this month is covered twice.
    expect(await sheet.save(), SaveResult.invalid);
    expect(sheet.session!.problem, AgreementProblems.overlap);
    expect(sheet.selectedId, newAgreementId);
  });

  test('a version changed behind the sheet is Stale', () async {
    final sheet = await open();
    await sheet.select(fixtureAgreement);
    sheet.editField(fixtureAgreement.value, AgreementField.hourlyRate, '19');
    final current = await v1();
    await fixture.work.agreement.updateAgreement(
      UpdateAgreementCommand(
        agreementId: fixtureAgreement,
        employmentId: fixtureEmployment,
        expectedRevision: current.revision,
        terms: AgreementTerms.of(current).change(label: () => 'Elsewhere'),
      ),
    );
    expect(await sheet.save(), SaveResult.stale);
    expect(sheet.session!.phase, EditPhase.stale);
  });

  test('a version removed behind the sheet is gone', () async {
    final current = await v1();
    final changed = await fixture.work.agreement.changeAgreementTerms(
      ChangeAgreementTermsCommand(
        agreementId: current.id,
        employmentId: fixtureEmployment,
        expectedRevision: current.revision,
        from: const LocalDate(2026, 11, 1),
        terms: AgreementTerms.of(current),
      ),
    );
    final v2 = (changed as Committed<PayAgreement>).value;
    final sheet = await open();
    await sheet.select(v2.id);
    sheet.editField(v2.id.value, AgreementField.label, 'Winter');
    await fixture.work.agreement.deleteAgreement(
      DeleteAgreementCommand(
        agreementId: v2.id,
        employmentId: fixtureEmployment,
        expectedRevision: v2.revision,
      ),
    );
    await sheet.save();
    expect(sheet.session!.gone, isTrue);
    await sheet.discardAndReturn();
    expect(sheet.selectedId, isNull);
    expect(sheet.session, isNull);
  });

  test(
    'a save the store refuses is Unavailable and can be tried again',
    () async {
      final refusing = fixture.work.replacing(
        agreement: AgreementService(
          RefusingCommands(),
          idFactory: fixture.schedule.ids,
          clock: fixture.work.clock,
        ),
      );
      final sheet = await open(work: refusing);
      await sheet.select(fixtureAgreement);
      sheet.editField(fixtureAgreement.value, AgreementField.label, 'Depot');
      expect(await sheet.save(), SaveResult.unavailable);
      expect(sheet.session!.problem, EditProblems.unavailable);
      expect(sheet.session!.draft.terms.label, 'Depot');
      expect(sheet.session!.frozen, isFalse);
    },
  );

  test('an employment without agreements is empty and quiet', () async {
    final empty = await EmptyWorkFixture.create();
    addTearDown(empty.dispose);
    final created = await empty.work.employment.createEmployment(
      const CreateEmploymentCommand(name: 'Synthetic site', legalLabel: null),
    );
    final site = (created as Committed<Employment>).value;
    final sheet = AgreementsSheetController(
      work: empty.work,
      reads: empty.reads,
      employmentId: site.id,
      today: ShiftsSheetFixture.today,
      confirm: confirm.call,
      coordinator: LeaveCoordinator(confirm: confirm.call),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    expect(sheet.rows, isEmpty);
    expect(sheet.loaded, isTrue);
    expect(sheet.notice, isNull);
    await sheet.addAgreement();
    expect(sheet.session!.draft.terms.hourlyRateMicroEur, 0);
    expect(
      sheet.session!.draft.terms.effectiveStart,
      ShiftsSheetFixture.today.firstOfMonth,
    );
  });

  test('unreadable storage keeps the last rows and says so', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final sheet = AgreementsSheetController(
      work: over.work,
      reads: over.reads,
      employmentId: fixtureEmployment,
      today: ShiftsSheetFixture.today,
      confirm: confirm.call,
      coordinator: LeaveCoordinator(confirm: confirm.call),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    expect(sheet.rows, hasLength(1));
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);
    gate.failing = true;
    final database = over.schedule.database;
    await database.customUpdate(
      'UPDATE pay_agreements SET revision = revision',
      updates: {database.payAgreements},
    );
    await until(() => sheet.failed);
    expect(sheet.rows, hasLength(1));
    expect(errors.single.library, 'agreements sheet');
  });

  test(
    'leaving a new agreement with a rate asks Save, Discard or Cancel',
    () async {
      confirm = ScriptedConfirm([ConfirmAnswer.cancel, ConfirmAnswer.revert]);
      final sheet = await open();
      await sheet.addAgreement();
      sheet.editField(newAgreementId, AgreementField.hourlyRate, '20');
      final coordinator = sheet.coordinator;
      expect(await coordinator.navigate(() {}), isFalse);
      expect(confirm.asked.single.revert, 'Discard');
      expect(sheet.selectedId, newAgreementId);
      expect(await coordinator.navigate(() {}), isTrue);
    },
  );
}
