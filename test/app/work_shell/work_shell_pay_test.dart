import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/pay_sheet_part.dart'
    show PayLine, PaySheetPart;
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart' show panelKey, windowKey;
import '../../support/pay_sheet_driver.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

Finder node(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));
Future<void> actionText(WidgetTester tester, String id, String text) async {
  final field = find.descendant(
    of: find.byType(ActionPanel),
    matching: find.byWidgetPredicate(
      (w) => w is CellEditor && w.field.id.field == id,
    ),
  );
  await click(tester, field);
  await tester.enterText(
    find.descendant(of: field, matching: find.byType(EditableText)),
    text,
  );
  await press(tester, LogicalKeyboardKey.enter);
  await tester.pump();
}

void main() {
  testWidgets(
    'empty database: create period, record evidence, review/reopen, correct and follow History links',
    (tester) async {
      await pumpEmptyShell(tester, store: MemoryLocationStore());
      await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
      await settleSheet(tester);
      await typeProperty(tester, EmploymentField.name, 'Synthetic payroll');
      await click(tester, toolbarKey('Save'));
      await settleSheet(tester);
      await click(tester, node('Pay periods'));
      await settleSheet(tester);
      // The empty Pay periods grid adds through its * row.
      await click(tester, find.byKey(const ValueKey('grid-new-row')));
      await settleSheet(tester);
      expect(find.byType(EraDateField), findsWidgets);
      await typeProperty(tester, 'label', 'October');
      await click(tester, toolbarKey('Save'));
      await settleSheet(tester);
      final shell = shellOf(tester);
      final period = shell.paySheet!.selected!.period!;
      expect(period.label, 'October');
      expect(
        find.descendant(
          of: find.byType(StatusBar),
          matching: find.text('1 period'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PropertyGrid>(find.byType(PropertyGrid))
            .items
            .where((i) => i.editable),
        isEmpty,
      );
      await click(tester, toolbarKey('Mark reviewed'));
      await settleSheet(tester);
      expect(shell.paySheet!.selected!.period!.state, PayPeriodState.reviewed);
      expect(statusNotice(tester), 'Period marked reviewed.');
      await click(tester, toolbarKey('Reopen period'));
      await settleSheet(tester);
      expect(shell.paySheet!.selected!.period!.state, PayPeriodState.open);
      expect(statusNotice(tester), 'Period reopened.');
      await click(tester, toolbarKey('Record payslip…'));
      await settleSheet(tester);
      expect(shell.paySheet!.session!.draft.period, period.id);
      await typeProperty(tester, 'amount', '147.20');
      await click(tester, toolbarKey('Save'));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is ConfirmWindow), findsOneWidget);
      await click(tester, windowKey('Cancel'));
      await settleSheet(tester);
      expect(shell.paySheet!.session!.draft.amount, '147.20');
      await click(tester, toolbarKey('Save'));
      await tester.pumpAndSettle();
      await click(tester, windowKey('Record payslip'));
      await settleSheet(tester);
      final original = shell.paySheet!.selected!.payslip!;
      // A saved payslip reads its money with the currency and names its
      // period once, as a link.
      final saved = {
        for (final item
            in tester.widget<PropertyGrid>(find.byType(PropertyGrid)).items)
          item.key: item,
      };
      expect(saved['amount']!.value, 'EUR 147.20');
      await click(tester, find.text('EUR 147.20').first);
      await settleSheet(tester);
      expect(statusNotice(tester), PaySheetPart.readOnlyStatus);
      expect(saved.containsKey('period'), isFalse);
      expect(saved['periodLink']!.onFollow, isNotNull);
      final grid = tester.widget<DataGrid<PayLine>>(
        find.byWidgetPredicate((w) => w is DataGrid<PayLine>),
      );
      final line = grid.lines
          .whereType<GridRow<PayLine>>()
          .singleWhere((row) => row.row.record?.payslip?.id == original.id)
          .row;
      expect(
        grid.columns.singleWhere((c) => c.key == 'amount').value(line),
        'EUR 147.20',
      );
      await click(tester, toolbarKey('Correct…'));
      await settleSheet(tester);
      await actionText(tester, 'amount', '148.35');
      await click(tester, panelKey('Void and replace'));
      await settleSheet(tester);
      expect(shell.paySheet!.action!.errors, contains('reason'));
      await actionText(tester, 'reason', 'Correct transfer');
      await click(tester, panelKey('Void and replace'));
      await settleSheet(tester);
      final replacement = shell.paySheet!.selected!.payslip!;
      expect(replacement.amount.minorUnits, 14835);
      expect(replacement.replacedPayslipId, original.id);
      await click(tester, propertyValue('original'));
      await settleSheet(tester);
      expect(shell.paySheet!.selected!.payslip!.isEffective, isFalse);
      expect(shell.location.payStatus, 'all');
      expect(
        find.descendant(
          of: find.byType(StatusBar),
          matching: find.text('2 payslips'),
        ),
        findsOneWidget,
      );
      expect(find.text('Correct transfer'), findsWidgets);
      await click(tester, propertyValue('replacement'));
      await settleSheet(tester);
      expect(shell.location.payRecord, replacement.id);
      await click(tester, propertyValue('periodLink'));
      await settleSheet(tester);
      expect(shell.location.payRecord, period.id);
      await click(tester, dockTab('Payslips'));
      await settleSheet(tester);
      expect(find.text('EUR 148.35 Gross'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  for (final size in [
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(900, 600),
    const Size(800, 600),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('pay sheets and correction fit $size at $scale', (
        tester,
      ) async {
        final fixture = await pumpShiftsSheet(tester, size: size, scale: scale);
        final (_, slip) = await openPay(tester, fixture);
        await click(tester, dockTab('Reconciliation'));
        await settleSheet(tester);
        expect(find.text('EUR 147.20'), findsWidgets);
        unawaited(
          shellOf(tester).go(
            WorkLocation.pay(
              shellOf(tester).location.employmentId!,
              sheet: WorkSheetKind.payslips,
              payRecord: slip.id,
            ),
          ),
        );
        await settleSheet(tester);
        await click(tester, toolbarKey('Correct…'));
        await settleSheet(tester);
        await showProperties(tester);
        await click(tester, panelKey('Void and replace'));
        await settleSheet(tester);
        expect(shellOf(tester).paySheet!.action!.errors, contains('reason'));
        expect(tester.takeException(), isNull);
        await closeShiftsSheet(tester, fixture);
      });
    }
  }

  testWidgets('an empty Pay sheet says so and names how to start', (
    tester,
  ) async {
    // Audit 9pk.4.38: the empty sheets said only Ready.
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.pay(fixtureEmployment, sheet: WorkSheetKind.periods).toUri()}',
      ),
    );
    Future<void> go(WorkLocation location) async {
      unawaited(shellOf(tester).go(location));
      await settleSheet(tester);
    }

    expect(statusNotice(tester), PaySheetPart.noPeriods);
    await go(
      const WorkLocation.pay(fixtureEmployment, sheet: WorkSheetKind.payslips),
    );
    expect(statusNotice(tester), PaySheetPart.noPeriodForPayslip);
    await tester.runAsync(
      () => fixture.work.periods.createPeriod(
        const CreatePayPeriodCommand(
          employmentId: fixtureEmployment,
          start: LocalDate(2026, 10, 1),
          end: LocalDate(2026, 10, 31),
          label: 'October 2026',
        ),
      ),
    );
    await settleSheet(tester);
    expect(statusNotice(tester), PaySheetPart.noPayslips);
    await go(
      const WorkLocation.pay(
        fixtureEmployment,
        sheet: WorkSheetKind.periods,
        payStatus: 'reviewed',
      ),
    );
    expect(statusNotice(tester), PaySheetPart.noneMatch(true));
    await closeShiftsSheet(tester, fixture);
  });
}
