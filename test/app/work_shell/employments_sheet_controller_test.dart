import 'dart:async';

import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/agreement_edit.dart';
import 'package:lifeos/app/work_edit/employment_edit.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/employment_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/work_formats.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/failing_work.dart';
import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
import '../../support/read_gate.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';
import '../../support/work_shell_fixture.dart';

void main() {
  test('parseHourlyRate reads 18.40, 18,4, 18, .5 and 18.; nothing else', () {
    expect(parseHourlyRate('18.40'), 18400000);
    expect(parseHourlyRate(' 18,4 '), 18400000);
    expect(parseHourlyRate('18'), 18000000);
    expect(parseHourlyRate('.5'), 500000);
    expect(parseHourlyRate('18.'), 18000000);
    expect(parseHourlyRate('-18'), isNull);
    expect(parseHourlyRate('18.1234567'), isNull);
    expect(parseHourlyRate('EUR 18'), isNull);
    expect(parseHourlyRate(''), isNull);
  });

  test('a rate with a long integer part is not a rate and throws nothing', () {
    expect(parseHourlyRate('99999999999999999999'), isNull);
    expect(parseHourlyRate('9999999999999'), isNull);
    expect(parseHourlyRate('999999999'), 999999999000000);
  });

  group('from an empty database', () {
    late EmptyWorkFixture fixture;
    late ScriptedConfirm confirm;

    setUp(() async => fixture = await EmptyWorkFixture.create());
    tearDown(() => fixture.dispose());

    EmploymentsSheetController open([List<ConfirmAnswer> answers = const []]) {
      confirm = ScriptedConfirm(answers);
      final sheet = EmploymentsSheetController(
        work: fixture.work,
        reads: fixture.reads,
        today: ShiftsSheetFixture.today,
        confirm: confirm.call,
        coordinator: LeaveCoordinator(confirm: confirm.call),
      );
      addTearDown(sheet.dispose);
      return sheet;
    }

    test('Add employment, a name, Save: it is selected, and its next step is '
        'a pay agreement', () async {
      final sheet = open();
      expect(await sheet.addEmployment(), isTrue);
      expect(sheet.employment?.isNew, isTrue);
      expect(sheet.place, const WorkLocation.overview());
      expect(
        sheet.editEmployment(EmploymentField.name, 'Synthetic bakery'),
        isNull,
      );
      expect(await sheet.save(), SaveResult.committed);
      final stored = (await fixture.reads.employments()).single;
      expect(sheet.selected, stored.id);
      expect(sheet.place, WorkLocation.employment(stored.id));
      expect(sheet.employment?.isNew, isFalse);
      expect(sheet.notice, EmploymentsNotices.noAgreement);
    });

    test('a blank name is refused in its editor and on Save', () async {
      final sheet = open();
      await sheet.addEmployment();
      expect(
        sheet.editEmployment(EmploymentField.name, '  '),
        EmploymentProblems.name,
      );
      expect(sheet.editEmployment(EmploymentField.legalLabel, 'UAB'), isNull);
      expect(await sheet.save(), SaveResult.invalid);
      expect(await fixture.reads.employments(), isEmpty);
    });

    test('Undo on an untouched new employment leaves the overview', () async {
      final sheet = open();
      await sheet.addEmployment();
      expect(await sheet.undo(), SaveResult.clean);
      expect(sheet.employment, isNull);
      expect(sheet.place, const WorkLocation.overview());
    });

    test('leaving a new employment with a name asks Save, Discard or '
        'Cancel; Cancel keeps it', () async {
      final sheet = open([ConfirmAnswer.cancel]);
      await sheet.addEmployment();
      sheet.editEmployment(EmploymentField.name, 'Synthetic bakery');
      expect(await sheet.addEmployment(), isFalse);
      expect(confirm.asked.single.title, newRecordRequest.title);
      expect(sheet.employment?.draft.name, 'Synthetic bakery');
    });

    test('Set up pay agreement: a start and a rate, Save; the employment '
        'shows again', () async {
      final sheet = open();
      await sheet.addEmployment();
      sheet.editEmployment(EmploymentField.name, 'Synthetic bakery');
      await sheet.save();
      expect(await sheet.setUpAgreement(), isTrue);
      expect(sheet.agreement?.isNew, isTrue);
      expect(
        sheet.agreement?.draft.terms.effectiveStart,
        const LocalDate(2026, 10, 1),
      );
      expect(
        sheet.editAgreement(AgreementField.hourlyRate, '0'),
        AgreementProblems.rate,
      );
      expect(
        sheet.editAgreement(AgreementField.hourlyRate, 'lots'),
        AgreementProblems.rate,
      );
      expect(sheet.editAgreement(AgreementField.hourlyRate, '18.40'), isNull);
      expect(
        sheet.editAgreement(
          AgreementField.effectiveStart,
          const LocalDate(2026, 9, 1),
        ),
        isNull,
      );
      expect(await sheet.save(), SaveResult.committed);
      final stored = sheet.agreements.single;
      expect(stored.hourlyRateMicroEur, 18400000);
      expect(stored.effectiveStart, const LocalDate(2026, 9, 1));
      // The setup is done: the employment shows again (3c-3 decision 3).
      expect(sheet.place, WorkLocation.employment(sheet.selected!));
      expect(sheet.agreement, isNull);
      expect(sheet.employment?.baseline, isNotNull);
      expect(sheet.notice, EmploymentsNotices.agreementSaved);
    });
  });

  group('with the depot', () {
    late ShiftsSheetFixture fixture;

    setUp(() async => fixture = await ShiftsSheetFixture.create());
    tearDown(() => fixture.dispose());

    test('a sheet disposed while its reads run opens no session', () async {
      final confirm = ScriptedConfirm();
      final coordinator = LeaveCoordinator(confirm: confirm.call);
      final sheet = EmploymentsSheetController(
        work: fixture.work,
        reads: fixture.reads,
        today: ShiftsSheetFixture.today,
        confirm: confirm.call,
        coordinator: coordinator,
      );
      final pending = sheet.select(fixtureEmployment);
      sheet.dispose();
      await pending;
      await sheet.show(fixtureEmployment);
      expect(sheet.session, isNull);
      expect(sheet.employment, isNull);
      expect(await coordinator.quit(), isTrue);
      expect(confirm.asked, isEmpty);
    });

    /// A sheet over storage whose reads [hold] can slow, with two stored
    /// employments; the first is selected.
    Future<
      (EmploymentsSheetController, EmploymentId, EmploymentId, AppDatabase)
    >
    openHeld(ReadHold hold) async {
      final held = await EmptyWorkFixture.create(
        executor: NativeDatabase.memory().interceptWith(hold),
      );
      addTearDown(held.dispose);
      final sheet = EmploymentsSheetController(
        work: held.work,
        reads: held.reads,
        today: ShiftsSheetFixture.today,
        confirm: ScriptedConfirm().call,
        coordinator: LeaveCoordinator(confirm: ScriptedConfirm().call),
      );
      addTearDown(sheet.dispose);
      final ids = <EmploymentId>[];
      for (final name in ['Synthetic bakery', 'Synthetic depot']) {
        await sheet.addEmployment();
        sheet.editEmployment(EmploymentField.name, name);
        expect(await sheet.save(), SaveResult.committed);
        ids.add(sheet.selected!);
      }
      await sheet.select(ids.first);
      return (sheet, ids.first, ids.last, held.database);
    }

    test('while the next employment opens, the last one is let go', () async {
      final hold = ReadHold();
      final (sheet, first, second, _) = await openHeld(hold);
      expect(sheet.employment, isNotNull);
      hold.hold();
      final opening = sheet.select(second);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sheet.selected, second);
      expect(sheet.employment, isNull, reason: '$first is no longer editable');
      expect(sheet.notice, EmploymentsNotices.opening);
      hold.release();
      expect(await opening, isTrue);
      expect(sheet.employment?.baseline?.value.id, second);
    });

    test('choosing the last employment again while the next one opens '
        'keeps it', () async {
      final hold = ReadHold();
      final (sheet, first, second, _) = await openHeld(hold);
      hold.hold();
      final away = sheet.select(second);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final back = sheet.select(first);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      hold.release();
      await Future.wait([away, back]);
      expect(sheet.selected, first);
      expect(sheet.employment?.baseline?.value.id, first);
    });

    test('an employment deleted elsewhere keeps its values until Discard '
        'and return to sheet drops them and selects nothing', () async {
      final (sheet, first, _, database) = await openHeld(ReadHold());
      sheet.editEmployment(EmploymentField.name, 'Synthetic bakery 2');
      await database.customStatement('DELETE FROM employments WHERE id = ?', [
        first.value,
      ]);
      await sheet.reload();
      expect(sheet.employment!.gone, isTrue);
      expect(sheet.employment!.draft.name, 'Synthetic bakery 2');

      await sheet.discardAndReturn();
      expect(sheet.selected, isNull);
      expect(sheet.session, isNull);
      expect(await sheet.coordinator.quit(), isTrue);
    });

    test('a missing employment shows none and says so', () async {
      final sheet = EmploymentsSheetController(
        work: fixture.work,
        reads: fixture.reads,
        today: ShiftsSheetFixture.today,
        confirm: ScriptedConfirm().call,
        coordinator: LeaveCoordinator(confirm: ScriptedConfirm().call),
      );
      addTearDown(sheet.dispose);
      await sheet.show(
        const EmploymentId('0190f5d2-6a00-7000-8000-00000000dead'),
      );
      expect(sheet.selected, isNull);
      expect(sheet.notice, EmploymentsNotices.gone);
    });
  });

  group('archive and delete', () {
    late EmptyWorkFixture fixture;
    late ScriptedConfirm confirm;

    setUp(() async {
      fixture = await EmptyWorkFixture.create();
      confirm = ScriptedConfirm();
    });
    tearDown(() => fixture.dispose());

    EmploymentsSheetController open({ProductionWorkProviders? work}) {
      final sheet = EmploymentsSheetController(
        work: work ?? fixture.work,
        reads: fixture.reads,
        today: ShiftsSheetFixture.today,
        confirm: (request) => confirm(request),
        coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
      );
      addTearDown(sheet.dispose);
      return sheet;
    }

    /// A stored employment with one pay agreement, selected.
    Future<EmploymentsSheetController> withBakery({
      ProductionWorkProviders? work,
    }) async {
      final created = await fixture.work.employment.createEmployment(
        const CreateEmploymentCommand(
          name: 'Synthetic bakery',
          legalLabel: null,
        ),
      );
      final bakery = (created as Committed<Employment>).value;
      await fixture.work.agreement.createAgreement(
        CreateAgreementCommand(
          employmentId: bakery.id,
          version: 1,
          terms: const AgreementTerms(
            effectiveStart: LocalDate(2026, 9, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 18400000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      );
      final sheet = open(work: work);
      await sheet.show(bakery.id);
      return sheet;
    }

    test(
      'Archive asks with the days to confirm, then ends the employment',
      () async {
        final sheet = await withBakery();
        expect(sheet.archiveBlocked, isNull);
        confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
        await sheet.archive(daysToConfirm: 9);
        expect(
          confirm.asked.single.message,
          'Archive Synthetic bakery? It moves to Ended employments and becomes '
          'read-only; its records stay. LifeOS cannot make it active again. '
          'It still has 9 days to confirm.',
        );
        expect(confirm.asked.single.proceed, 'Archive');
        expect(sheet.selected, isNotNull);
        expect(
          sheet.employment!.baseline!.value.status,
          EmploymentStatus.archived,
        );
        expect(sheet.notice, EmploymentsCommandWords.archivedDone);
        expect(
          sheet.editEmployment(EmploymentField.name, 'x'),
          EmploymentsWords.archivedReadOnly,
        );
        expect(sheet.archiveBlocked, EmploymentsCommandWords.archived);
      },
    );

    test('Archive cancelled keeps it active', () async {
      final sheet = await withBakery();
      confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
      await sheet.archive(daysToConfirm: 0);
      expect(confirm.asked.single.message, isNot(contains('to confirm')));
      expect(sheet.employment!.baseline!.value.status, EmploymentStatus.active);
    });

    test(
      'Delete asks, then removes an employment and its agreements',
      () async {
        final sheet = await withBakery();
        final id = sheet.selected!;
        expect(sheet.deleteBlocked(hasHistory: false), isNull);
        confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
        await sheet.delete();
        expect(
          confirm.asked.single.message,
          'Delete Synthetic bakery? Nothing is recorded for it; its 1 pay '
          "agreement goes with it. This can't be undone.",
        );
        expect(await fixture.reads.employment(id), isNull);
        expect(sheet.selected, isNull);
        expect(sheet.notice, EmploymentsCommandWords.deleted);
      },
    );

    test('Delete is greyed while work is recorded', () async {
      final sheet = await withBakery();
      expect(
        sheet.deleteBlocked(hasHistory: true),
        EmploymentsCommandWords.hasHistory,
      );
      await sheet.delete(hasHistory: true);
      expect(confirm.asked, isEmpty);
    });

    test('a pending name edit is resolved before archiving', () async {
      final sheet = await withBakery();
      // A blank name cannot be saved: leaving can only stay or discard.
      sheet.editEmployment(EmploymentField.legalLabel, 'UAB Bakery');
      final edit = sheet.employment!;
      edit.edit(const EmploymentValues(name: '', legalLabel: 'UAB Bakery'));
      await sheet.archive(daysToConfirm: 0);
      expect(confirm.asked, isEmpty);
      expect(sheet.employment!.baseline!.value.status, EmploymentStatus.active);
      expect(sheet.employment!.draft.legalLabel, 'UAB Bakery');
    });

    test('a store that refuses says so and keeps the employment', () async {
      final sheet = await withBakery(
        work: fixture.work.replacing(
          employment: EmploymentService(
            RefusingCommands(),
            idFactory: UuidV7WorkIdFactory(),
            clock: fixture.work.clock,
          ),
        ),
      );
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.delete();
      expect(sheet.notice, EmploymentsCommandWords.unavailable);
      expect(sheet.selected, isNotNull);
    });

    test('closing waits for an archive that is running', () async {
      final gated = GatedCommands(fixture.work.workRepository);
      final sheet = await withBakery(
        work: fixture.work.replacing(
          employment: EmploymentService(
            gated,
            idFactory: UuidV7WorkIdFactory(),
            clock: fixture.work.clock,
          ),
        ),
      );
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      final archiving = sheet.archive(daysToConfirm: 0);
      for (var turn = 0; turn < 200 && !gated.waiting; turn++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(gated.waiting, isTrue);
      var settled = false;
      unawaited(sheet.settled().then((_) => settled = true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(settled, isFalse);
      gated.release();
      await archiving;
      await Future<void>.delayed(Duration.zero);
      expect(settled, isTrue);
    });

    test('a lost answer is settled by reading the employment again', () async {
      final sheet = await withBakery(
        work: fixture.work.replacing(
          employment: EmploymentService(
            LosingCommands(fixture.work.workRepository),
            idFactory: UuidV7WorkIdFactory(),
            clock: fixture.work.clock,
          ),
        ),
      );
      confirm = ScriptedConfirm([ConfirmAnswer.proceed]);
      await sheet.archive(daysToConfirm: 0);
      expect(sheet.notice, EmploymentsCommandWords.archivedDone);
      expect(
        sheet.employment!.baseline!.value.status,
        EmploymentStatus.archived,
      );
    });

    test('a save that ends Unavailable keeps the values', () async {
      final sheet = await withBakery(
        work: fixture.work.replacing(
          employment: EmploymentService(
            RefusingCommands(),
            idFactory: UuidV7WorkIdFactory(),
            clock: fixture.work.clock,
          ),
        ),
      );
      sheet.editEmployment(EmploymentField.name, 'Synthetic bakery 2');
      expect(await sheet.save(), SaveResult.unavailable);
      expect(sheet.employment!.problem, EditProblems.unavailable);
      expect(sheet.employment!.draft.name, 'Synthetic bakery 2');
    });

    test('an edit made while leaving is asked about, not dropped', () async {
      final sheet = await withBakery();
      final bakery = sheet.selected!;
      await sheet.addEmployment();
      sheet.editEmployment(EmploymentField.name, 'Synthetic cafe');
      // Typed while the window was open: it reaches the session only after
      // the session let go.
      sheet.coordinator.add(_LateEdit(() => sheet.employment!));
      confirm = ScriptedConfirm([ConfirmAnswer.revert, ConfirmAnswer.cancel]);
      expect(await sheet.select(bakery), isFalse);
      expect(confirm.asked, hasLength(2));
      expect(sheet.employment!.draft.name, 'Typed late');
    });

    test('a late save on a disposed sheet does nothing', () async {
      final created = await fixture.work.employment.createEmployment(
        const CreateEmploymentCommand(
          name: 'Synthetic bakery',
          legalLabel: null,
        ),
      );
      final bakery = (created as Committed<Employment>).value;
      final sheet = EmploymentsSheetController(
        work: fixture.work,
        reads: fixture.reads,
        today: ShiftsSheetFixture.today,
        confirm: (request) => confirm(request),
        coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
      );
      await sheet.show(bakery.id);
      sheet.editEmployment(EmploymentField.name, 'Synthetic bakery 2');
      final saving = sheet.save();
      sheet.dispose();
      // It settles without touching the disposed sheet (no assertion).
      expect(await saving, SaveResult.committed);
      expect(sheet.notice, EmploymentsNotices.noAgreement);
    });

    test('a stored employment says how it is ended', () async {
      final sheet = await withBakery();
      final editors = EditorSessionController();
      addTearDown(editors.dispose);
      final part = EmploymentsSheetPart(
        sheet: sheet,
        editors: editors,
        today: ShiftsSheetFixture.today,
        employments: await fixture.reads.watchEmployments().first,
        openAgreement: (_) {},
      );
      final items = (part.properties() as PropertyGrid).items;
      expect(
        items.singleWhere((item) => item.key == 'status').readOnlyReason,
        EmploymentsPropertyWords.statusActive,
      );
      expect(
        items.singleWhere((item) => item.key == 'schedule').value,
        EmploymentsPropertyWords.newSchedule,
      );
    });
  });
}

/// A participant asked after the session that edits it once, as a value
/// typed during the leave window would arrive.
final class _LateEdit implements LeaveParticipant {
  _LateEdit(this.session);

  @override
  bool get settled => true;

  final EmploymentSession Function() session;
  bool _done = false;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    if (!_done) {
      _done = true;
      session().edit(
        const EmploymentValues(name: 'Typed late', legalLabel: null),
      );
    }
    return LeaveDecision.proceed;
  }
}
