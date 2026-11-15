import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/agreement_commands.dart';
import 'package:lifeos/app/work_shell/agreements_sheet_controller.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

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

  Future<PayAgreement> v1() async => (await fixture.reads.agreement(
    fixtureEmployment,
    fixtureAgreement,
  ))!.value;

  Future<PayAgreement> changeFromNovember() async {
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
    return (changed as Committed<PayAgreement>).value;
  }

  Future<void> endV1(LocalDate end) async {
    final current = await v1();
    await fixture.work.agreement.closeAgreement(
      CloseAgreementCommand(
        agreementId: current.id,
        employmentId: fixtureEmployment,
        end: end,
        expectedRevision: current.revision,
      ),
    );
  }

  Future<AgreementsSheetController> open({
    ProductionWorkProviders? work,
  }) async {
    final sheet = AgreementsSheetController(
      work: work ?? fixture.work,
      reads: fixture.reads,
      employmentId: fixtureEmployment,
      today: ShiftsSheetFixture.today,
      confirm: (request) => confirm(request),
      coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    return sheet;
  }

  Future<String> extendOver(List<LocalDate> days) => extendAgreement(
    work: fixture.work,
    reads: fixture.reads,
    confirm: (request) => confirm(request),
    employmentId: fixtureEmployment,
    days: days,
  );

  Future<String> extend(LocalDate date) => extendOver([date]);

  group('Remove agreement…', () {
    test('asks, then removes an unused version', () async {
      final v2 = await changeFromNovember();
      final sheet = await open();
      await sheet.select(v2.id);
      expect(sheet.removeBlocked, isNull);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.remove();
      final asked = confirm.asked.single;
      expect(asked.message, removeAgreementRequest(v2).message);
      expect(asked.proceed, 'Remove');
      await until(() => sheet.rows.length == 1);
      expect(sheet.selectedId, isNull);
      expect(sheet.notice, AgreementCommandWords.removed);
    });

    test('a pending edit is saved first, then the version removed', () async {
      final v2 = await changeFromNovember();
      final sheet = await open();
      await sheet.select(v2.id);
      sheet.editField(v2.id.value, AgreementField.label, 'Winter');
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.remove();
      expect(sheet.notice, AgreementCommandWords.removed);
      await until(() => sheet.rows.length == 1);
    });

    test('is greyed for a version in use', () async {
      await fixture.finishShift(20);
      final sheet = await open();
      await sheet.select(fixtureAgreement);
      expect(sheet.removeBlocked, AgreementsCommandWords.inUse);
      await sheet.remove();
      expect(confirm.asked, isEmpty);
      expect(sheet.rows, hasLength(1));
    });

    test('cancelled changes nothing', () async {
      final v2 = await changeFromNovember();
      final sheet = await open();
      await sheet.select(v2.id);
      confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      await sheet.remove();
      expect(sheet.rows, hasLength(2));
      expect(sheet.selectedId, v2.id.value);
    });

    test('a lost answer is settled by reading the versions again', () async {
      final v2 = await changeFromNovember();
      final sheet = await open(
        work: fixture.work.replacing(
          agreement: AgreementService(
            LosingCommands(fixture.work.workRepository),
            idFactory: fixture.schedule.ids,
            clock: fixture.work.clock,
          ),
        ),
      );
      await sheet.select(v2.id);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.remove();
      expect(sheet.notice, AgreementCommandWords.removed);
      expect(sheet.selectedId, isNull);
    });

    test('a write that never ran says it was not removed', () async {
      final v2 = await changeFromNovember();
      final sheet = await open(
        work: fixture.work.replacing(
          agreement: AgreementService(
            LosingCommands(fixture.work.workRepository, before: true),
            idFactory: fixture.schedule.ids,
            clock: fixture.work.clock,
          ),
        ),
      );
      await sheet.select(v2.id);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.remove();
      expect(sheet.notice, AgreementCommandWords.notRemoved);
      expect(sheet.rows, hasLength(2));
    });

    test('a store that refuses says so', () async {
      final v2 = await changeFromNovember();
      final sheet = await open(
        work: fixture.work.replacing(
          agreement: AgreementService(
            RefusingCommands(),
            idFactory: fixture.schedule.ids,
            clock: fixture.work.clock,
          ),
        ),
      );
      await sheet.select(v2.id);
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.remove();
      expect(sheet.notice, AgreementCommandWords.unavailable);
    });
  });

  group('Extend pay agreement…', () {
    test('to an earlier day moves the start', () async {
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(
        await extend(const LocalDate(2026, 8, 25)),
        AgreementCommandWords.extended,
      );
      expect(
        confirm.asked.single.message,
        startsWith('Extend pay agreement v1 to start on 2026-08-25?'),
      );
      expect((await v1()).effectiveStart, const LocalDate(2026, 8, 25));
    });

    test('after an ended agreement moves the end', () async {
      await endV1(const LocalDate(2026, 10, 15));
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(
        await extend(const LocalDate(2026, 10, 19)),
        AgreementCommandWords.extended,
      );
      expect(
        confirm.asked.single.message,
        startsWith('Extend pay agreement v1 to end on 2026-10-19?'),
      );
      expect((await v1()).effectiveEnd, const LocalDate(2026, 10, 19));
    });

    test('a gap between two versions is covered in one go', () async {
      await changeFromNovember();
      await endV1(const LocalDate(2026, 10, 10));
      // v2 from November; the gap ends there, so v1 widens to its eve.
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      expect(
        await extendOver([
          for (var day = 11; day <= 31; day++) LocalDate(2026, 10, day),
        ]),
        AgreementCommandWords.extended,
      );
      expect(
        confirm.asked.single.message,
        startsWith('Extend pay agreement v1 to end on 2026-10-31?'),
      );
      expect((await v1()).effectiveEnd, const LocalDate(2026, 10, 31));
    });

    test('days split by another version stop before it', () async {
      await changeFromNovember();
      await endV1(const LocalDate(2026, 10, 10));
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await extendOver([
        const LocalDate(2026, 10, 12),
        const LocalDate(2026, 11, 20),
      ]);
      expect((await v1()).effectiveEnd, const LocalDate(2026, 10, 12));
    });

    test('cancelled changes nothing', () async {
      await endV1(const LocalDate(2026, 10, 15));
      confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      expect(await extend(const LocalDate(2026, 10, 19)), '');
      expect((await v1()).effectiveEnd, const LocalDate(2026, 10, 15));
    });

    test('a day already paid needs nothing', () async {
      expect(
        await extend(const LocalDate(2026, 10, 19)),
        AgreementCommandWords.covered,
      );
      expect(confirm.asked, isEmpty);
    });

    test(
      'a check that fails before anything is sent says unavailable',
      () async {
        final gate = ReadGate();
        final gated = await ShiftsSheetFixture.create(
          executor: NativeDatabase.memory().interceptWith(gate),
        );
        addTearDown(gated.dispose);
        expect(
          await extendAgreement(
            work: gated.work,
            reads: gated.reads,
            // Storage stops answering once the owner agreed.
            confirm: (request) async {
              gate.failing = true;
              return ConfirmAnswer.proceed;
            },
            employmentId: fixtureEmployment,
            days: const [LocalDate(2026, 8, 25)],
          ),
          AgreementCommandWords.unavailable,
        );
      },
    );

    test('with no agreement says to set one up', () async {
      final empty = await EmptyWorkFixture.create();
      addTearDown(empty.dispose);
      final created = await empty.work.employment.createEmployment(
        const CreateEmploymentCommand(name: 'Synthetic site', legalLabel: null),
      );
      final site = (created as Committed<Employment>).value;
      expect(
        await extendAgreement(
          work: empty.work,
          reads: empty.reads,
          confirm: (request) => confirm(request),
          employmentId: site.id,
          days: const [LocalDate(2026, 10, 7)],
        ),
        AgreementCommandWords.noAgreement,
      );
      expect(confirm.asked, isEmpty);
    });
  });
}
