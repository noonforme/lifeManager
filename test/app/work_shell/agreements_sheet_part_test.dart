import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/work_edit/agreement_fields.dart';
import 'package:lifeos/app/work_shell/agreement_action.dart';
import 'package:lifeos/app/work_shell/agreements_sheet_controller.dart';
import 'package:lifeos/app/work_shell/agreements_sheet_part.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart'
    show EmploymentsWords;
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/fake_record_adapter.dart' show ScriptedConfirm;
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

  Future<AgreementsSheetController> open() async {
    final sheet = AgreementsSheetController(
      work: fixture.work,
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

  AgreementsSheetPart partOf(
    AgreementsSheetController sheet, {
    bool archived = false,
  }) {
    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    return AgreementsSheetPart(
      sheet: sheet,
      editors: editors,
      work: fixture.work,
      today: ShiftsSheetFixture.today,
      employmentName: 'Synthetic depot',
      onEmployment: () {},
      archived: archived,
    );
  }

  ToolbarItem key(AgreementsSheetPart part, String label) =>
      [for (final band in part.bands()) ...band.items]
          .whereType<ToolbarItem>()
          .singleWhere((item) => item.label == label);

  EraMenuItem row(List<EraMenuItem> items, String label) =>
      items.singleWhere((item) => item.label == label);

  Future<void> changeFromNovember() async {
    final v1 = (await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!.value;
    final changed = await fixture.work.agreement.changeAgreementTerms(
      ChangeAgreementTermsCommand(
        agreementId: v1.id,
        employmentId: fixtureEmployment,
        expectedRevision: v1.revision,
        from: const LocalDate(2026, 11, 1),
        terms: AgreementTerms.of(v1).change(hourlyRateMicroEur: 19200000),
      ),
    );
    expect(changed, isA<Committed<PayAgreement>>());
  }

  test('the grid lists versions with their status', () async {
    await fixture.finishShift(20);
    await changeFromNovember();
    final sheet = await open();
    final part = partOf(sheet);
    final grid = part.middle() as DataGrid<AgreementLine>;
    final lines = [
      for (final line in grid.lines)
        if (line is GridRow<AgreementLine>) line.row,
    ];
    expect([for (final line in lines) line.version], ['v1', 'v2']);
    expect([for (final line in lines) line.status], ['Current', 'Later']);
    expect(lines.first.paidShifts, 1);
    expect(lines.first.night, '×1.5, 22:00–06:00');
    expect(lines.last.rate, 19200000);
    expect(lines.first.ends, const LocalDate(2026, 10, 31));
  });

  test('a pending night change shows in its row', () async {
    final sheet = await open();
    await sheet.select(fixtureAgreement);
    expect(
      sheet.editField(
        fixtureAgreement.value,
        AgreementField.nightEnabled,
        false,
      ),
      isNull,
    );
    final line = partOf(sheet).lines.single;
    expect(line.night, 'Off');
  });

  test('an ended version is muted', () async {
    final v1 = (await fixture.reads.agreement(
      fixtureEmployment,
      fixtureAgreement,
    ))!.value;
    await fixture.work.agreement.closeAgreement(
      CloseAgreementCommand(
        agreementId: v1.id,
        employmentId: fixtureEmployment,
        end: const LocalDate(2026, 10, 10),
        expectedRevision: v1.revision,
      ),
    );
    final sheet = await open();
    await until(() => sheet.rows.single.agreement.effectiveEnd != null);
    final grid = partOf(sheet).middle() as DataGrid<AgreementLine>;
    final first = grid.lines.single as GridRow<AgreementLine>;
    expect(first.row.status, 'Ended');
    expect(first.state, GridRowState.muted);
  });

  test('the toolbar greys what does not apply and says why', () async {
    await fixture.finishShift(20);
    final sheet = await open();
    var part = partOf(sheet);
    expect(key(part, 'Change terms from…').onPressed, isNull);
    expect(
      key(part, 'Change terms from…').tooltip,
      AgreementsCommandWords.selectFirst,
    );
    expect(key(part, 'Delete').onPressed, isNull);
    await sheet.select(fixtureAgreement);
    part = partOf(sheet);
    expect(key(part, 'Change terms from…').onPressed, isNotNull);
    expect(key(part, 'End agreement…').onPressed, isNotNull);
    expect(key(part, 'Delete').tooltip, AgreementsCommandWords.inUse);
    final menu = part.recordMenu();
    expect(
      row(menu, 'Remove agreement…').disabledReason,
      AgreementsCommandWords.inUse,
    );
    expect(row(menu, 'Change terms from…').onSelected, isNotNull);
    expect(row(menu, 'Add pay agreement…').onSelected, isNotNull);
  });

  test('a selected version shows its properties and History', () async {
    final sheet = await open();
    await sheet.select(fixtureAgreement);
    final part = partOf(sheet);
    final grid = part.properties() as PropertyGrid;
    expect(grid.record, 'agreement:${fixtureAgreement.value}');
    expect(
      grid.items.map((item) => item.key),
      contains(AgreementField.nightMultiplier),
    );
    final tabs = part.subformTabs();
    expect([for (final tab in tabs) tab.label], ['History']);
    expect(part.addItems().single.label, 'Pay agreement');
  });

  test('an open panel takes the property column', () async {
    final sheet = await open();
    await sheet.select(fixtureAgreement);
    await sheet.openAction(AgreementActionKind.end);
    final part = partOf(sheet);
    final panel = part.properties() as ActionPanel;
    expect(panel.title, AgreementActionWords.endTitle);
    expect(panel.primaryLabel, AgreementActionWords.endPrimary);
    expect(part.notice(), AgreementActionWords.endHint);
  });

  test('an empty sheet is an empty grid with its * row', () async {
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
      confirm: (request) => confirm(request),
      coordinator: LeaveCoordinator(confirm: (request) => confirm(request)),
    )..start();
    addTearDown(sheet.dispose);
    await sheet.ready;
    final editors = EditorSessionController();
    addTearDown(editors.dispose);
    final part = AgreementsSheetPart(
      sheet: sheet,
      editors: editors,
      work: empty.work,
      today: ShiftsSheetFixture.today,
      employmentName: 'Synthetic site',
      onEmployment: () {},
    );
    final grid = part.middle() as DataGrid<AgreementLine>;
    expect(grid.lines, isEmpty);
    expect(grid.onNew, isNotNull);
    expect(part.notice(), AgreementsNotices.empty);
    await sheet.addAgreement();
    expect(part.notice(), AgreementsNotices.newAgreement);
  });

  test("an archived employment's agreements are read-only", () async {
    final sheet = await open();
    await sheet.select(fixtureAgreement);
    final part = partOf(sheet, archived: true);
    for (final label in ['Save', 'Delete', AgreementsPartWords.change]) {
      expect(key(part, label).onPressed, isNull, reason: label);
    }
    expect(
      key(part, AgreementsPartWords.change).tooltip,
      EmploymentsWords.archivedReadOnly,
    );
    final menu = part.recordMenu();
    expect(row(menu, AgreementsPartWords.add).onSelected, isNull);
    expect(
      row(menu, AgreementsPartWords.add).disabledReason,
      EmploymentsWords.archivedReadOnly,
    );
    expect(part.addItems(), isEmpty);
    final grid = part.middle() as DataGrid<AgreementLine>;
    expect(grid.onNew, isNull);
    final properties = (part.properties() as PropertyGrid).items;
    expect(
      properties
          .singleWhere((item) => item.key == AgreementField.hourlyRate)
          .readOnlyReason,
      EmploymentsWords.archivedReadOnly,
    );
  });
}
