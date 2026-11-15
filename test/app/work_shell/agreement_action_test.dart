import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/agreement_action.dart';
import 'package:lifeos/app/work_shell/agreements_sheet_controller.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

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
    ShiftsSheetFixture? over,
    ProductionWorkProviders? work,
  }) async {
    final on = over ?? fixture;
    final sheet = AgreementsSheetController(
      work: work ?? on.work,
      reads: on.reads,
      employmentId: fixtureEmployment,
      today: ShiftsSheetFixture.today,
      confirm: (request) => confirm(request),
      coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    await sheet.select(fixtureAgreement);
    return sheet;
  }

  /// [on]'s services with an agreement service that loses its answer: the
  /// first command runs (or not, [before]) and then throws.
  ProductionWorkProviders losing(
    ShiftsSheetFixture on, {
    bool before = false,
  }) => on.work.replacing(
    agreement: AgreementService(
      LosingCommands(on.work.workRepository, before: before),
      idFactory: on.schedule.ids,
      clock: on.work.clock,
    ),
  );

  test('Change terms from November makes version 2', () async {
    final sheet = await open();
    expect(sheet.changeBlocked, isNull);
    expect(await sheet.openAction(AgreementActionKind.changeTerms), isTrue);
    final action = sheet.action!;
    expect(sheet.session, isNull);
    expect(action.title, AgreementActionWords.changeTitle);
    expect(action.rate, 18400000);
    expect(action.set(AgreementField.hourlyRate, '19.20'), isNull);
    expect(action.set('date', const LocalDate(2026, 11, 1)), isNull);
    await sheet.submitAction();
    await until(() => sheet.rows.length == 2);
    final [v1, v2] = [for (final row in sheet.rows) row.agreement];
    expect(v1.effectiveEnd, const LocalDate(2026, 10, 31));
    expect(v2.effectiveStart, const LocalDate(2026, 11, 1));
    expect(v2.hourlyRateMicroEur, 19200000);
    expect(v2.overtimeThresholdMinutes, v1.overtimeThresholdMinutes);
    expect(v2.nightEnabled, v1.nightEnabled);
    expect(sheet.action, isNull);
    expect(sheet.selectedId, v2.id.value);
    expect(sheet.notice, 'Terms changed: version 2 starts on 2026-11-01.');
  });

  test('From on or before the last paid day says so', () async {
    await fixture.finishShift(20);
    final sheet = await open();
    await sheet.openAction(AgreementActionKind.changeTerms);
    final action = sheet.action!;
    // The 20th is paid, so the default From is the day after.
    expect(action.date, const LocalDate(2026, 10, 21));
    action.set('date', const LocalDate(2026, 10, 20));
    await sheet.submitAction();
    expect(
      action.errors['date'],
      'It paid days up to 2026-10-20 under these terms. Pick a later day.',
    );
    expect(action.phase, AgreementActionPhase.input);
    expect(sheet.rows, hasLength(1));
  });

  test('From on the start says so', () async {
    final sheet = await open();
    await sheet.openAction(AgreementActionKind.changeTerms);
    final action = sheet.action!..set('date', const LocalDate(2026, 9, 1));
    await sheet.submitAction();
    expect(action.errors['date'], 'Pick a day after it starts, 2026-09-01.');
  });

  test(
    'End agreement on a paid day before the last says so, then ends',
    () async {
      await fixture.finishShift(20);
      final sheet = await open();
      expect(await sheet.openAction(AgreementActionKind.end), isTrue);
      final action = sheet.action!;
      expect(action.date, ShiftsSheetFixture.today);
      action.set('date', const LocalDate(2026, 10, 19));
      await sheet.submitAction();
      expect(
        action.errors['date'],
        'It paid days up to 2026-10-20. Pick that day or a later one.',
      );
      action.set('date', const LocalDate(2026, 10, 31));
      await sheet.submitAction();
      await until(() => sheet.rows.single.agreement.effectiveEnd != null);
      expect(
        sheet.rows.single.agreement.effectiveEnd,
        const LocalDate(2026, 10, 31),
      );
      expect(sheet.action, isNull);
      expect(sheet.selectedId, fixtureAgreement.value);
      expect(sheet.notice, AgreementsNotices.ended);
    },
  );

  test(
    'a lost answer leaves the result unknown; Reload and check finds it',
    () async {
      final sheet = await open(work: losing(fixture));
      await sheet.openAction(AgreementActionKind.changeTerms);
      final action = sheet.action!..set('date', const LocalDate(2026, 11, 1));
      await sheet.submitAction();
      expect(action.phase, AgreementActionPhase.uncertain);
      expect(action.primaryLabel, AgreementActionWords.check);
      await sheet.submitAction();
      await until(() => sheet.action == null);
      expect(sheet.rows, hasLength(2));
      expect(sheet.selectedId, sheet.rows.last.agreement.id.value);
    },
  );

  test('a check that finds nothing done offers the action again', () async {
    final sheet = await open(work: losing(fixture, before: true));
    await sheet.openAction(AgreementActionKind.end);
    final action = sheet.action!..set('date', const LocalDate(2026, 10, 31));
    await sheet.submitAction();
    expect(action.phase, AgreementActionPhase.uncertain);
    await sheet.submitAction();
    expect(action.phase, AgreementActionPhase.input);
    expect(action.error, AgreementActionWords.notDone);
    await sheet.submitAction();
    await until(() => sheet.rows.single.agreement.effectiveEnd != null);
    expect(sheet.action, isNull);
    expect(
      sheet.rows.single.agreement.effectiveEnd,
      const LocalDate(2026, 10, 31),
    );
  });

  test('quitting while unknown offers the check, then Quit anyway', () async {
    final gate = ReadGate();
    final over = await ShiftsSheetFixture.create(
      executor: NativeDatabase.memory().interceptWith(gate),
    );
    addTearDown(over.dispose);
    final sheet = await open(over: over, work: losing(over, before: true));
    await sheet.openAction(AgreementActionKind.end);
    sheet.action!.set('date', const LocalDate(2026, 10, 31));
    await sheet.submitAction();
    expect(sheet.action!.phase, AgreementActionPhase.uncertain);
    gate.failing = true;
    confirm = ScriptedConfirm([ConfirmAnswer.proceed, ConfirmAnswer.proceed]);
    expect(await sheet.coordinator.quit(), isFalse);
    expect(confirm.asked.first, same(uncheckedQuitRequest));
    expect(sheet.action!.error, AgreementActionWords.unknown);
    expect(await sheet.coordinator.quit(), isTrue);
    expect(confirm.asked.last, same(unresolvedQuitRequest));
  });

  test('opening an action resolves a pending edit first', () async {
    await fixture.finishShift(20);
    final sheet = await open();
    // A rate change on a version in use asks before it reprices.
    sheet.editField(fixtureAgreement.value, AgreementField.hourlyRate, '19');
    confirm = ScriptedConfirm([ConfirmAnswer.cancel, ConfirmAnswer.revert]);
    expect(await sheet.openAction(AgreementActionKind.end), isFalse);
    expect(confirm.asked.single.proceed, 'Save and reprice');
    expect(sheet.action, isNull);
    expect(sheet.session!.draft.terms.hourlyRateMicroEur, 19000000);
    expect(await sheet.openAction(AgreementActionKind.end), isTrue);
    expect(sheet.action!.row.agreement.hourlyRateMicroEur, 18400000);
  });

  test('leaving a panel with input asks to discard', () async {
    final sheet = await open();
    await sheet.openAction(AgreementActionKind.end);
    sheet.action!.set('date', const LocalDate(2026, 10, 31));
    confirm = ScriptedConfirm([ConfirmAnswer.cancel, ConfirmAnswer.revert]);
    await sheet.cancelAction();
    expect(sheet.action, isNotNull);
    expect(confirm.asked.single.message, AgreementActionWords.discard);
    await sheet.cancelAction();
    expect(sheet.action, isNull);
    expect(sheet.session!.baseline!.value.id, fixtureAgreement);
  });

  test('an untouched panel cancels without asking', () async {
    final sheet = await open();
    await sheet.openAction(AgreementActionKind.changeTerms);
    await sheet.cancelAction();
    expect(confirm.asked, isEmpty);
    expect(sheet.action, isNull);
  });

  test('nothing to act on greys both actions', () async {
    final sheet = await open();
    await sheet.show(null);
    expect(sheet.changeBlocked, AgreementsCommandWords.selectFirst);
    expect(sheet.endBlocked, AgreementsCommandWords.selectFirst);
    expect(await sheet.openAction(AgreementActionKind.end), isFalse);
  });

  test('a one-day agreement cannot change terms', () async {
    final v1 = (await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!.value;
    await fixture.work.agreement.closeAgreement(
      CloseAgreementCommand(
        agreementId: v1.id,
        employmentId: fixtureEmployment,
        end: v1.effectiveStart,
        expectedRevision: v1.revision,
      ),
    );
    final sheet = await open();
    expect(sheet.changeBlocked, AgreementsCommandWords.changeNeedsDays);
    expect(sheet.endBlocked, isNull);
  });
}
