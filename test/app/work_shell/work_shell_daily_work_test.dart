import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_shell/confirm_days_action.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, propertyValue, pushKey, toolbarKey;
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

Finder _treeNode(String label) =>
    find.descendant(of: find.byType(TreeView), matching: find.text(label));

Finder _windowKey(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is ConfirmWindow),
  matching: pushKey(label),
);

Finder _day(LocalDate date) => find.byKey(ValueKey('day-calendar-$date'));

List<String> _words(WidgetTester tester, LocalDate date) => [
  for (final line
      in tester.widget<DayCalendar>(find.byType(DayCalendar)).days[date]!.lines)
    line.spoken,
];

/// The To confirm count in the tree and the status bar.
(int?, String?) _counts(WidgetTester tester) => (
  tester
      .widget<TreeView>(find.byType(TreeView))
      .nodes
      .single
      .children
      .single
      .children
      .singleWhere((node) => node.label == 'To confirm')
      .count,
  tester.widget<StatusBar>(find.byType(StatusBar)).warning,
);

LocalDate _oct(int day) => LocalDate(2026, 10, day);

/// Calendar and To confirm end to end from an empty database, with the
/// mouse (plan 4d-2, Task 8).
void main() {
  testWidgets('from an empty database: set up, Calendar first, confirm one '
      'day, then several on To confirm', (tester) async {
    final store = MemoryLocationStore();
    final fixture = await pumpEmptyShell(tester, store: store);
    var shell = shellOf(tester);
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
    await tester.runAsync(() async {
      // From the 5th, so some days are past.
      schedules
        ..editField(ScheduleField.cycleStart, _oct(5))
        ..editField(ScheduleField.inUseFrom, _oct(5))
        ..addType()
        ..addType();
      final types = schedules.session!.draft.types;
      schedules
        ..editType(types[0].id, ScheduleField.typeName, 'Day')
        ..editType(types[0].id, ScheduleField.typeStart, const LocalTime(7, 0))
        ..editType(types[0].id, ScheduleField.typeEnd, const LocalTime(19, 0))
        ..editType(types[1].id, ScheduleField.typeName, 'Night')
        ..editType(types[1].id, ScheduleField.typeStart, const LocalTime(19, 0))
        ..editType(types[1].id, ScheduleField.typeEnd, const LocalTime(7, 0));
      for (final (count, type) in [
        (3, types[0].id),
        (3, types[1].id),
        (6, null),
      ]) {
        schedules.addBlock();
        final last = schedules.session!.draft.blocks.length - 1;
        schedules
          ..editBlock(last, ScheduleField.blockDays, '$count')
          ..editBlock(last, ScheduleField.blockType, type);
      }
    });
    await tester.pump();
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    expect(schedules.rows, hasLength(1));

    // A new run with nothing remembered opens on Calendar.
    await pumpShellOver(tester, fixture, store: MemoryLocationStore());
    shell = shellOf(tester);
    expect(shell.location.sheet, WorkSheetKind.calendar);
    expect(shell.location.month, _oct(1));
    expect(_counts(tester), (9, '9 days to confirm'));

    // Confirm one day on the calendar.
    await click(tester, _day(_oct(6)));
    await settleSheet(tester);
    await click(tester, toolbarKey('Confirm'));
    await settleSheet(tester);
    expect(_words(tester, _oct(6)).last, 'Confirmed');
    expect(_counts(tester), (8, '8 days to confirm'));

    // To confirm from the tree, then Confirm worked days for all but one.
    await click(tester, _treeNode('To confirm'));
    await settleSheet(tester);
    expect(shell.location.sheet, WorkSheetKind.toConfirm);
    await click(tester, toolbarKey('Confirm worked days…'));
    await settleSheet(tester);
    await click(tester, find.text('Wed 2026-10-07').first);
    await settleSheet(tester);
    await click(tester, find.widgetWithText(KeyButton, 'Confirm 7 days'));
    await settleSheet(tester);
    await click(tester, _windowKey('Confirm 7 days'));
    await settleSheet(tester);
    expect(statusNotice(tester), ConfirmDaysWords.allDone(7));
    expect(_counts(tester), (1, '1 day to confirm'));

    // The calendar shows them confirmed.
    await click(tester, _treeNode('Calendar'));
    await settleSheet(tester);
    expect(shell.location.sheet, WorkSheetKind.calendar);
    expect(_words(tester, _oct(5)).last, 'Confirmed');
    expect(_words(tester, _oct(7)).last, 'To confirm');
  });
}
