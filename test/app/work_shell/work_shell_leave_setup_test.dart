import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/day_exception.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart' show panelKey, reasonText;
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

Finder _node(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));
void main() {
  testWidgets(
    'from an empty database: set up, mark and confirm leave, then correct it',
    (tester) async {
      await pumpEmptyShell(tester, store: MemoryLocationStore());
      final shell = shellOf(tester);
      await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
      await settleSheet(tester);
      await typeProperty(tester, EmploymentField.name, 'Synthetic bakery');
      await click(tester, toolbarKey('Save'));
      await settleSheet(tester);
      await click(tester, propertyValue('agreement'));
      await settleSheet(tester);
      await typeProperty(tester, AgreementField.hourlyRate, '18.40');
      await click(tester, toolbarKey('Save'));
      await settleSheet(tester);
      await click(tester, propertyValue('schedule'));
      await settleSheet(tester);
      final schedules = shell.schedulesSheet!;
      await typeProperty(tester, ScheduleField.name, 'Bakery rotation');
      schedules
        ..editField(ScheduleField.cycleStart, const LocalDate(2026, 10, 5))
        ..editField(ScheduleField.inUseFrom, const LocalDate(2026, 10, 5))
        ..addType();
      final type = schedules.session!.draft.types.single.id;
      schedules
        ..editType(type, ScheduleField.typeName, 'Day')
        ..addBlock();
      schedules
        ..editBlock(0, ScheduleField.blockDays, '1')
        ..editBlock(0, ScheduleField.blockType, type);
      await tester.pump();
      await click(tester, toolbarKey('Save'));
      await settleSheet(tester);
      await click(tester, _node('Calendar'));
      await settleSheet(tester);
      await click(
        tester,
        find.byKey(const ValueKey('day-calendar-2026-10-06')),
      );
      await settleSheet(tester);
      await click(tester, toolbarKey('Mark as leave…'));
      await settleSheet(tester);
      await click(tester, panelKey('Mark as leave'));
      await settleSheet(tester);
      await click(tester, toolbarKey('Confirm'));
      await settleSheet(tester);
      await click(tester, propertyValue('confirmedLeave'));
      await settleSheet(tester);
      final leave = shell.leaveSheet!.rows.single.record;
      await click(tester, await gridCell(tester, leave.id.value, 'date'));
      await settleSheet(tester);
      await click(tester, toolbarKey('Correct…'));
      await settleSheet(tester);
      final choice = find.descendant(
        of: find.byType(ActionPanel),
        matching: find.byType(EraCombo<Object?>),
      );
      await click(tester, choice);
      await click(tester, comboChoice('Sick'));
      await press(tester, LogicalKeyboardKey.enter);
      await reasonText(tester, 'Was ill');
      await click(tester, panelKey('Void and replace'));
      await settleSheet(tester);
      expect(shell.leaveSheet!.selectedRow!.record.leaveType, LeaveType.sick);
      expect(shell.leaveSheet!.rows, hasLength(2));
      expect(shell.leaveSheet!.selectedRow!.record.replacedId, leave.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
