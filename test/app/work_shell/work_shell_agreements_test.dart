import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/agreement_action.dart';
import 'package:lifeos/app/work_shell/agreement_commands.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, gridCell, propertyValue, pushKey, toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

/// The tree node labelled [label].
Finder treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

/// The key labelled [label] in the confirmation window.
Finder windowKey(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is ConfirmWindow),
  matching: pushKey(label),
);

/// The key labelled [label] in the open action panel.
Finder panelKey(String label) =>
    find.descendant(of: find.byType(ActionPanel), matching: pushKey(label));

/// The Details box's text [text].
Finder details(String text) => find.descendant(
  of: find.byType(DetailsBox),
  matching: find.textContaining(text, findRichText: true),
);

/// A store that starts on the depot's Agreements sheet.
MemoryLocationStore _onAgreements({
  AgreementId? agreement,
}) => MemoryLocationStore(
  '${WorkLocation.agreements(fixtureEmployment, agreement: agreement).toUri()}',
);

void main() {
  testWidgets('from an empty database: employment, agreement, then the '
      'Agreements sheet', (tester) async {
    await pumpEmptyShell(tester, store: MemoryLocationStore());
    final shell = shellOf(tester);
    await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
    await settleSheet(tester);
    await typeProperty(tester, EmploymentField.name, 'Synthetic bakery');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    final employment = shell.location.employmentId!;
    await click(tester, propertyValue('agreement'));
    await settleSheet(tester);
    await typeProperty(tester, AgreementField.hourlyRate, '18.40');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    // The setup is done: the employment shows again, with its agreement.
    expect(shell.location, WorkLocation.employment(employment));
    expect(statusNotice(tester), EmploymentsNotices.agreementSaved);
    expect(find.text('Pay agreement v1'), findsOneWidget);

    await click(tester, treeNode('Agreements'));
    await settleSheet(tester);
    expect(shell.location, WorkLocation.agreements(employment));
    expect(shell.location.toUri().query, contains('sheet=agreements'));
    final sheet = shell.agreementsSheet!;
    expect(sheet.rows, hasLength(1));
    final v1 = sheet.rows.single.agreement.id;
    await click(tester, await gridCell(tester, v1.value, 'version'));
    await settleSheet(tester);
    expect(shell.location, WorkLocation.agreements(employment, agreement: v1));
    expect(
      tester.widget<TreeView>(find.byType(TreeView)).selectedId,
      'agreements:${employment.value}',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the employment links to its agreement on the sheet', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.employment(fixtureEmployment).toUri()}',
      ),
    );
    await click(tester, propertyValue('agreement:${fixtureAgreement.value}'));
    await settleSheet(tester);
    expect(
      shellOf(tester).location,
      const WorkLocation.agreements(
        fixtureEmployment,
        agreement: fixtureAgreement,
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Change terms from… from the toolbar', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: _onAgreements(agreement: fixtureAgreement),
    );
    final shell = shellOf(tester);
    final sheet = shell.agreementsSheet!;
    expect(sheet.selectedId, fixtureAgreement.value);
    await click(tester, toolbarKey('Change terms from…'));
    await settleSheet(tester);
    expect(find.byType(ActionPanel), findsOneWidget);
    sheet.action!
      ..set('date', const LocalDate(2026, 11, 1))
      ..set(AgreementField.hourlyRate, '19.20');
    await tester.pump();
    await click(tester, panelKey(AgreementActionWords.changePrimary));
    await settleSheet(tester);
    expect(shellOf(tester).agreementsSheet!.rows, hasLength(2));
    expect(
      statusNotice(tester),
      'Terms changed: version 2 starts on 2026-11-01.',
    );
    expect(
      tester
          .widget<TreeView>(find.byType(TreeView))
          .nodes
          .single
          .children
          .single
          .children
          .singleWhere((node) => node.label == 'Agreements')
          .count,
      2,
    );
    expect(shell.location.agreement, sheet.rows.last.agreement.id);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a repricing correction asks with its impact and reprices', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: _onAgreements(agreement: fixtureAgreement),
    );
    await tester.runAsync(() => fixture.finishShift(20));
    await settleSheet(tester);
    await typeProperty(tester, AgreementField.hourlyRate, '19.00');
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    final window = tester.widget<ConfirmWindow<Object?>>(
      find.byWidgetPredicate((widget) => widget is ConfirmWindow),
    );
    expect(window.message, contains('1 finished shift'));
    await click(tester, windowKey('Save and reprice'));
    await settleSheet(tester);
    final stored = await tester.runAsync(
      () => fixture.reads.agreement(fixtureEmployment, fixtureAgreement),
    );
    expect(stored!.value.hourlyRateMicroEur, 19000000);
    // History shows the correction.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settleSheet(tester);
    expect(find.text('Changed'), findsOneWidget);
    expect(
      find.textContaining('Hourly rate: 18.40 EUR/h → 19.00 EUR/h'),
      findsOneWidget,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Remove agreement… from the Record menu', (tester) async {
    final fixture = await pumpShiftsSheet(tester, store: _onAgreements());
    final sheet = shellOf(tester).agreementsSheet!;
    await tester.runAsync(() async {
      await sheet.select(fixtureAgreement);
      await sheet.openAction(AgreementActionKind.changeTerms);
      sheet.action!.set('date', const LocalDate(2026, 11, 1));
      await sheet.submitAction();
    });
    await settleSheet(tester);
    final v2 = shellOf(tester).agreementsSheet!.rows.last.agreement;
    expect(shellOf(tester).location.agreement, v2.id);
    await click(tester, find.text('Record'));
    await settleSheet(tester);
    // The toolbar has the same words: click the open menu's row.
    await click(
      tester,
      find.descendant(
        of: find.byType(EraMenuLabel),
        matching: find.text('Remove agreement…'),
      ),
    );
    await settleSheet(tester);
    await click(tester, windowKey('Remove'));
    await settleSheet(tester);
    expect(shellOf(tester).agreementsSheet!.rows, hasLength(1));
    expect(statusNotice(tester), AgreementCommandWords.removed);
    expect(
      shellOf(tester).location,
      const WorkLocation.agreements(fixtureEmployment),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('clicking Agreements while on it keeps the selected version', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: _onAgreements(agreement: fixtureAgreement),
    );
    final before = shellOf(tester).location;
    expect(before.agreement, fixtureAgreement);
    await click(tester, treeNode('Agreements'));
    await settleSheet(tester);
    expect(shellOf(tester).location, before);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Details agreement links to its version; Back returns', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    final before = shellOf(tester).location;
    await click(tester, details('From 2026-09-01'));
    await settleSheet(tester);
    expect(
      shellOf(tester).location,
      const WorkLocation.agreements(
        fixtureEmployment,
        agreement: fixtureAgreement,
      ),
    );
    await click(tester, toolbarKey('Back'));
    await settleSheet(tester);
    expect(shellOf(tester).location, before);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Extend pay agreement… from Details', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final database = fixture.schedule.database;
    await tester.runAsync(
      () => database.customUpdate(
        "UPDATE pay_agreements SET effective_start = '2026-10-12'",
        updates: {database.payAgreements},
      ),
    );
    await settleSheet(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settleSheet(tester);
    expect(details('4 days'), findsOneWidget);
    await click(tester, details('4 days'));
    await settleSheet(tester);
    await click(tester, windowKey('Extend'));
    await settleSheet(tester);
    final stored = await tester.runAsync(
      () => fixture.reads.agreement(fixtureEmployment, fixtureAgreement),
    );
    expect(stored!.value.effectiveStart, const LocalDate(2026, 10, 5));
    expect(statusNotice(tester), AgreementCommandWords.extended);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Agreements sheet waits for an invalid edit', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: _onAgreements(agreement: fixtureAgreement),
    );
    await typeProperty(tester, AgreementField.hourlyRate, 'lots');
    await click(tester, treeNode('Shifts'));
    await settleSheet(tester);
    expect(
      shellOf(tester).location,
      const WorkLocation.agreements(
        fixtureEmployment,
        agreement: fixtureAgreement,
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });
}
