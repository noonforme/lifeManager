import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/pay_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/payslip_service.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart' show panelKey, windowKey;
import '../../support/pay_scripted_repository.dart';
import '../../support/pay_sheet_driver.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

void main() {
  for (final lose in [false, true]) {
    testWidgets('native close settles pay correction (lost response=$lose)', (
      tester,
    ) async {
      final window = FakeWindowClose();
      final gate = Completer<void>();
      late ScriptedPayslips repo;
      final fixture = await pumpShiftsSheet(
        tester,
        closeApi: window,
        work: (f) {
          repo = ScriptedPayslips(
            f.work.payslips,
            f.reads.payslip,
            write: true,
            gate: gate.future,
            result: lose
                ? const Uncertain(SafeFailureCode.commitOutcomeUnknown)
                : null,
          );
          return f.work.replacing(
            payslips: PayslipService(
              repo,
              idFactory: f.schedule.ids,
              clock: f.schedule.clock,
            ),
          );
        },
      );
      await openPay(tester, fixture, payslips: true);
      await click(tester, toolbarKey('Correct…'));
      await settleSheet(tester);
      shellOf(tester).paySheet!.action!.set('reason', 'Transfer correction');
      await tester.pump();
      await click(tester, panelKey('Void and replace'));
      await settleSheet(tester);
      unawaited(window.pressClose());
      await settleSheet(tester);
      expect(window.destroyed, 0);
      gate.complete();
      await settleSheet(tester);
      if (lose) {
        expect(
          shellOf(tester).paySheet!.action!.phase,
          PayActionPhase.uncertain,
        );
        await click(tester, windowKey('Reload and check'));
        await settleSheet(tester);
        expect(window.destroyed, 0);
        expect(shellOf(tester).paySheet!.action, isNull);
        unawaited(window.pressClose());
        await settleSheet(tester);
      }
      expect(window.destroyed, 1);
      expect(repo.calls, 1);
      expect(
        shellOf(tester).location.payRecord,
        shellOf(tester).paySheet!.recordId,
      );
      expect(find.byWidgetPredicate((w) => w is ConfirmWindow), findsNothing);
      await closeShiftsSheet(tester, fixture);
    });
  }
}
