import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/agreement_edit.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/agreement_properties.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/agreement_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

void main() {
  late ShiftsSheetFixture fixture;

  setUp(() async => fixture = await ShiftsSheetFixture.create());
  tearDown(() => fixture.dispose());

  Future<AgreementSession> open({bool stored = true}) async {
    final record = await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    );
    final session = AgreementSession(
      adapter: AgreementAdapter(
        employmentId: fixtureEmployment,
        defaults: AgreementTerms.of(record!.value),
        service: fixture.work.agreement,
        preview: fixture.work.workRepository,
        reads: fixture.reads,
        clock: fixture.work.clock,
      ),
      baseline: stored ? record : null,
    );
    addTearDown(session.dispose);
    return session;
  }

  PropertyItem find(List<PropertyItem> items, String key) =>
      items.singleWhere((item) => item.key == key);

  test('a stored version lists every term', () async {
    await fixture.finishShift(20);
    final edit = await open();
    final row = (await fixture.reads.agreementRows(fixtureEmployment)).single;
    final items = agreementPropertyItems(
      edit: edit,
      row: row,
      employmentName: 'Synthetic depot',
      onEmployment: () {},
    );
    final keys = {for (final item in items) item.key};
    expect(
      keys,
      containsAll([
        'version',
        AgreementField.effectiveStart,
        AgreementField.effectiveEnd,
        AgreementField.hourlyRate,
        AgreementField.basis,
        AgreementField.label,
        AgreementField.note,
        AgreementField.overtimeHours,
        AgreementField.overtimeMultiplier,
        AgreementField.nightEnabled,
        AgreementField.nightStart,
        AgreementField.nightEnd,
        AgreementField.nightMultiplier,
        AgreementField.holidays,
        AgreementField.holidayMultiplier,
        AgreementField.stacking,
        AgreementField.vacationPercent,
        AgreementField.sickPercent,
        AgreementField.sickDays,
        'paidShifts',
        'paysLeave',
        'firstUse',
        'lastUse',
        'employment',
      ]),
    );
    expect(find(items, AgreementField.overtimeHours).display, '8 h');
    expect(find(items, AgreementField.overtimeMultiplier).display, '×1.5');
    expect(find(items, AgreementField.hourlyRate).display, '18.40/h');
    expect(find(items, AgreementField.hourlyRate).text, '18.40');
    expect(find(items, 'paidShifts').display, '1');
    expect(find(items, 'lastUse').value, const LocalDate(2026, 10, 20));
    expect(find(items, 'paidShifts').editable, isFalse);
    expect(find(items, 'version').editable, isFalse);
    expect(
      find(items, AgreementField.label).description,
      endsWith(AgreementPropertyWords.corrects),
    );
  });

  test('a changed term shows what it was', () async {
    final edit = await open();
    edit.edit(
      AgreementValues(edit.draft.terms.change(hourlyRateMicroEur: 19000000)),
    );
    final items = agreementPropertyItems(
      edit: edit,
      row: null,
      employmentName: null,
      onEmployment: null,
    );
    expect(find(items, AgreementField.hourlyRate).was, '18.40/h');
    expect(find(items, AgreementField.label).was, isNull);
    expect(items.where((item) => item.key == 'employment'), isEmpty);
  });

  test('a new version has no version, use or correction words', () async {
    final edit = await open(stored: false);
    final items = agreementPropertyItems(
      edit: edit,
      row: null,
      employmentName: 'Synthetic depot',
      onEmployment: () {},
    );
    final keys = {for (final item in items) item.key};
    expect(keys, isNot(contains('version')));
    expect(keys, isNot(contains('paidShifts')));
    expect(
      find(items, AgreementField.label).description,
      AgreementPropertyWords.label,
    );
    expect(agreementCorrectionReason, isNotEmpty);
  });
}
