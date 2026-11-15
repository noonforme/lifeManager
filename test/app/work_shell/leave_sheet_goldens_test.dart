import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart';
import '../../support/shifts_sheet_driver.dart';

void main() {
  testWidgets('Leave: confirmed facts and History', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await openLeave(tester, fixture);
    final confirming = confirmLeave(fixture, 7, type: LeaveType.sick);
    await settleSheet(tester);
    await confirming;
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_leave_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });
  testWidgets('Leave: Correct leave with a validation error', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await openLeave(tester, fixture);
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    await click(tester, panelKey('Void and replace'));
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile('../../goldens/work_shell_leave_correct_1280x800.png'),
    );
    await closeShiftsSheet(tester, fixture);
  });
}
