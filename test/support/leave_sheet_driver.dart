import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/day_plan_service.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/features/work/domain/leave.dart';
import 'package:lifeos/ui/ui.dart';

import 'app_frame_harness.dart';
import 'schedule_fixture.dart';
import 'shifts_sheet_driver.dart';
import 'shifts_sheet_fixture.dart';

Finder panelKey(String label) =>
    find.descendant(of: find.byType(ActionPanel), matching: pushKey(label));
Finder panelField(String id) => find.byKey(ValueKey('action-field:$id'));
Finder windowKey(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is ConfirmWindow),
  matching: pushKey(label),
);
Finder leaveGrid = find.byWidgetPredicate(
  (w) => w is DataGrid && w.label == 'Leave',
);

Future<LeaveRecord> confirmLeave(
  ShiftsSheetFixture fixture,
  int day, {
  LeaveType type = LeaveType.vacation,
}) async {
  final date = LocalDate(2026, 10, day);
  await fixture.work.plans.markLeave(
    fixtureEmployment,
    date,
    leaveType: type,
    illnessStartedOn: null,
  );
  return ((await fixture.work.plans.confirm(
            fixtureEmployment,
            date,
          ) as Committed<ConfirmedDay>).value
          as ConfirmedLeave)
      .leave;
}

Future<LeaveRecord> openLeave(
  WidgetTester tester,
  ShiftsSheetFixture fixture,
) async {
  late LeaveRecord leave;
  await tester.runAsync(() async {
    leave = await confirmLeave(fixture, 6);
    await shellOf(tester).go(
      WorkLocation.leave(
        fixtureEmployment,
        month: const LocalDate(2026, 10, 1),
        leave: leave.id,
      ),
    );
  });
  await settleSheet(tester);
  return leave;
}

Future<void> reasonText(WidgetTester tester, String reason) async {
  final field = find.byKey(const ValueKey('leave-correct-reason'));
  await click(tester, field);
  await tester.enterText(field, reason);
  await tester.pump();
}
