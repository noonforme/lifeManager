import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_edit/schedule_fields.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/schedules_sheet_controller.dart';
import 'package:lifeos/app/work_shell/schedules_sheet_part.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, propertyValue, pushKey, toolbarKey;
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

/// A store that starts on the depot's Schedules sheet.
MemoryLocationStore _onSchedules() => MemoryLocationStore(
  '${const WorkLocation.schedules(fixtureEmployment).toUri()}',
);

void main() {
  testWidgets('from an empty database: employment, agreement, schedule', (
    tester,
  ) async {
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

    // Next steps: New schedule… opens the Schedules sheet on a new one.
    await click(tester, propertyValue('schedule'));
    await settleSheet(tester);
    expect(shell.location.sheet, WorkSheetKind.schedules);
    final sheet = shell.schedulesSheet!;
    expect(sheet.selectedId, newScheduleId);
    await typeProperty(tester, ScheduleField.name, 'Bakery rotation');
    await tester.runAsync(() async {
      sheet.addType();
      sheet.addType();
      final types = sheet.session!.draft.types;
      sheet
        ..editType(types[0].id, ScheduleField.typeName, 'Day')
        ..editType(types[0].id, ScheduleField.typeStart, const LocalTime(7, 0))
        ..editType(types[0].id, ScheduleField.typeEnd, const LocalTime(19, 0))
        ..addBreak(types[0].id)
        ..editType(types[1].id, ScheduleField.typeName, 'Night')
        ..editType(types[1].id, ScheduleField.typeStart, const LocalTime(19, 0))
        ..editType(types[1].id, ScheduleField.typeEnd, const LocalTime(7, 0));
      for (final (count, type) in [
        (3, types[0].id),
        (3, types[1].id),
        (6, null),
      ]) {
        sheet.addBlock();
        final last = sheet.session!.draft.blocks.length - 1;
        sheet
          ..editBlock(last, ScheduleField.blockDays, '$count')
          ..editBlock(last, ScheduleField.blockType, type);
      }
    });
    await tester.pump();
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    expect(sheet.rows, hasLength(1));
    final saved = sheet.rows.single.schedule;
    expect(saved.cycleLength, 12);
    expect(
      shell.location,
      WorkLocation.schedules(employment, schedule: saved.id, version: 1),
    );
    expect(
      tester
          .widget<TreeView>(find.byType(TreeView))
          .nodes
          .single
          .children
          .single
          .children
          .singleWhere((node) => node.label == 'Schedules')
          .count,
      1,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await settleSheet(tester);
    expect(details('Bakery rotation'), findsOneWidget);
  });

  testWidgets('drag reorders the cycle and Save keeps it', (tester) async {
    final fixture = await pumpShiftsSheet(tester, store: _onSchedules());
    final sheet = shellOf(tester).schedulesSheet!;
    await tester.runAsync(() => sheet.select(sheet.rows.single.rowId));
    await settleSheet(tester);
    final grip = find.byKey(const ValueKey('grid-grip:block:2'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('grid-grip:block:2'), skipOffstage: false),
    );
    await settleSheet(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(grip),
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(0, -2));
      await tester.pump();
    }
    await gesture.up();
    await settleSheet(tester);
    await click(tester, toolbarKey('Save'));
    await settleSheet(tester);
    expect(
      [for (final b in sheet.rows.single.schedule.blocks) b.shiftTypeId?.value],
      ['day', 'night', null, null],
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Change schedule from… from the toolbar', (tester) async {
    final fixture = await pumpShiftsSheet(tester, store: _onSchedules());
    final sheet = shellOf(tester).schedulesSheet!;
    await tester.runAsync(() async {
      await fixture.schedule.markUsed(sheet.rows.single.schedule);
    });
    await settleSheet(tester);
    await tester.runAsync(() => sheet.select(sheet.rows.single.rowId));
    await settleSheet(tester);
    expect(sheet.editBlocked, SchedulesCommandWords.used);
    await click(tester, toolbarKey(SchedulesPartWords.change));
    await settleSheet(tester);
    expect(find.byType(ActionPanel), findsOneWidget);
    sheet
      ..editField(ScheduleField.versionFrom, const LocalDate(2026, 10, 19))
      ..editBlock(0, ScheduleField.blockDays, '4');
    await tester.pump();
    await click(tester, panelKey(SchedulesPartWords.changePrimary));
    await settleSheet(tester);
    expect(sheet.rows, hasLength(2));
    expect(
      statusNotice(tester),
      'Schedule changed: version 2 starts on 2026-10-19.',
    );
    expect(shellOf(tester).location.version, 2);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Delete schedule… from the Record menu', (tester) async {
    final fixture = await pumpShiftsSheet(tester, store: _onSchedules());
    final sheet = shellOf(tester).schedulesSheet!;
    await tester.runAsync(() => sheet.select(sheet.rows.single.rowId));
    await settleSheet(tester);
    await click(tester, find.text('Record'));
    await settleSheet(tester);
    await click(
      tester,
      find.descendant(
        of: find.byType(EraMenuLabel),
        matching: find.text(SchedulesPartWords.delete),
      ),
    );
    await settleSheet(tester);
    await click(tester, windowKey('Delete'));
    await settleSheet(tester);
    expect(sheet.rows, isEmpty);
    expect(statusNotice(tester), SchedulesNotices.deleted);
    expect(
      shellOf(tester).location,
      const WorkLocation.schedules(fixtureEmployment),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Details schedule links to it; Back returns', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final before = shellOf(tester).location;
    await click(tester, details('Depot rotation'));
    await settleSheet(tester);
    final place = shellOf(tester).location;
    expect(place.sheet, WorkSheetKind.schedules);
    expect(place.schedule, isNotNull);
    expect(shellOf(tester).schedulesSheet!.session, isNotNull);
    await click(tester, toolbarKey('Back'));
    await settleSheet(tester);
    expect(shellOf(tester).location, before);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the Schedules sheet waits for an invalid edit', (tester) async {
    final fixture = await pumpShiftsSheet(tester, store: _onSchedules());
    final sheet = shellOf(tester).schedulesSheet!;
    await tester.runAsync(() => sheet.select(sheet.rows.single.rowId));
    await settleSheet(tester);
    sheet.editBreak(
      const ShiftTypeId('day'),
      0,
      ScheduleField.breakStart,
      const LocalTime(18, 50),
    );
    await tester.pump();
    final place = shellOf(tester).location;
    await click(tester, treeNode('Shifts'));
    await settleSheet(tester);
    expect(shellOf(tester).location, place);
    expect(
      statusNotice(tester),
      '${EditProblems.invalid} Day: ${ScheduleProblems.breaks}',
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('quitting with a half-made new version asks to discard it', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester, store: _onSchedules());
    final sheet = shellOf(tester).schedulesSheet!;
    await tester.runAsync(() async {
      await fixture.schedule.markUsed(sheet.rows.single.schedule);
    });
    await settleSheet(tester);
    await tester.runAsync(() async {
      await sheet.select(sheet.rows.single.rowId);
      await sheet.changeFrom();
    });
    sheet.editBlock(0, ScheduleField.blockDays, '4');
    await tester.pump();
    var quit = false;
    final asking = shellOf(tester).mayQuit().then((value) => quit = value);
    await settleSheet(tester);
    await click(tester, windowKey('Discard input and quit'));
    await settleSheet(tester);
    await asking;
    expect(quit, isTrue);
    await tester.runAsync(() async {
      expect(await fixture.reads.scheduleRows(fixtureEmployment), hasLength(1));
    });
    await closeShiftsSheet(tester, fixture);
  });
}
