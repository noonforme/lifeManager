import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_shell/agreement_action.dart';
import 'package:lifeos/app/work_shell/agreements_sheet_part.dart';
import 'package:lifeos/app/work_shell/day_action.dart';
import 'package:lifeos/app/work_shell/employments_sheet_controller.dart';
import 'package:lifeos/app/work_shell/employments_sheet_part.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/schedules_sheet_part.dart';
import 'package:lifeos/app/work_shell/schedules_subform.dart'
    show SchedulesSubformWords;
import 'package:lifeos/app/work_shell/shifts_action.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_filter_strip.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

/// The spec 10 layout matrix on the real Work shell: 1280 x 800,
/// 1024 x 768, 960 x 760, 860 x 600 and 800 x 600 at 100 and 200 % text,
/// with either side of the 1024 and 860 px fold breakpoints at 100 %. Each
/// size runs the Shifts sheet (a selected record, an open editor, a new
/// record, an open action panel) and the Employments sheet (an empty
/// database, a validation problem, 30 employments).
const _sizes = [
  (Size(1280, 800), 1.0),
  (Size(1025, 768), 1.0),
  (Size(1024, 768), 1.0),
  (Size(1023, 768), 1.0),
  (Size(960, 760), 1.0),
  (Size(861, 600), 1.0),
  (Size(860, 600), 1.0),
  (Size(859, 600), 1.0),
  (Size(800, 600), 1.0),
  (Size(1280, 800), 2.0),
  (Size(1024, 768), 2.0),
  (Size(960, 760), 2.0),
  (Size(860, 600), 2.0),
  (Size(800, 600), 2.0),
];

/// Scrolls [finder] into view, then asserts a mouse press reaches it.
Future<void> expectReachable(
  WidgetTester tester,
  Finder finder, {
  String? reason,
}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expectHittable(tester, finder, reason: reason);
}

/// Asserts [finder] lies inside the window, not clipped by its edge.
void expectInWindow(WidgetTester tester, Finder finder, String reason) {
  final rect = tester.getRect(finder);
  final window = Offset.zero & tester.view.physicalSize;
  expect(
    window.inflate(0.5).contains(rect.topLeft) &&
        window.inflate(0.5).contains(rect.bottomRight),
    isTrue,
    reason: '$reason: $rect outside $window',
  );
}

/// The property column's content: the docked tab is opened first.
Future<void> openProperties(WidgetTester tester) => showProperties(tester);

void main() {
  for (final (size, scale) in _sizes) {
    final name =
        '${size.width.toInt()} x ${size.height.toInt()} at '
        '${(scale * 100).toInt()} %';

    testWidgets('$name: Shifts', (tester) async {
      final fixture = await pumpShiftsSheet(tester, size: size, scale: scale);
      late WorkShift shift;
      await tester.runAsync(() async {
        shift = await fixture.finishShift(20);
      });
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      for (final key in [WorkShellWords.back, 'Save', 'Undo', 'Correct…']) {
        await expectReachable(tester, toolbarKey(key), reason: key);
      }
      await expectReachable(
        tester,
        stepKey(ShiftsFilterWords.next),
        reason: 'Next period',
      );

      // An open time editor is whole inside the window.
      final day = plannedRowId(const LocalDate(2026, 10, 5));
      await selectShiftsRow(tester, day);
      final end = await gridCell(tester, day, 'end');
      await click(tester, end);
      final editor = find.descendant(
        of: end,
        matching: find.byType(CellEditor),
      );
      expect(editor, findsOneWidget);
      expectInWindow(tester, editor, 'time editor');
      await press(tester, LogicalKeyboardKey.escape);

      // A new record: its Undo and the status line are reachable.
      await click(tester, toolbarKey('New shift'));
      await settleSheet(tester);
      expect(sheetOf(tester).selectedId, newRowId);
      await expectReachable(tester, find.byType(StatusBar), reason: 'status');
      await click(tester, toolbarKey('Undo'));
      await settleSheet(tester);

      // An open action panel: its keys are reachable, docked or not.
      await selectShiftsRow(tester, storedRowId(shift));
      await click(tester, toolbarKey('Correct…'));
      await settleSheet(tester);
      await openProperties(tester);
      await expectReachable(
        tester,
        pushKey(ShiftsActionWords.correctPrimary),
        reason: 'primary',
      );
      await expectReachable(tester, pushKey('Cancel'), reason: 'Cancel');
      await click(tester, pushKey('Cancel'));
      await settleSheet(tester);

      // A day panel (Mark as leave…): its keys are reachable too.
      await selectShiftsRow(tester, day);
      await click(tester, toolbarKey('Mark as leave…'));
      await settleSheet(tester);
      await openProperties(tester);
      await expectReachable(
        tester,
        pushKey(DayActionWords.leaveTitle),
        reason: 'Mark as leave',
      );
      await expectReachable(tester, pushKey('Cancel'), reason: 'day Cancel');
      await click(tester, pushKey('Cancel'));
      await settleSheet(tester);

      // The lower splitter is reachable; at 100 % it drags with the mouse.
      // At 200 %, or 600 px tall under the filter strip, the grid's and the
      // subform's minima can leave it no room (AppFrame's own tests drag it
      // on a larger window).
      await expectReachable(tester, splitter('lower'), reason: 'splitter');
      if (scale == 1 && size.height >= 700) {
        final lower = find.byType(Subform);
        final before = tester.getSize(lower).height;
        await drag(tester, splitter('lower'), const Offset(0, -20));
        expect(tester.getSize(lower).height, greaterThan(before));
      }
      // The filter strip: a typed range, Off days, a status and Find;
      // Clear, the step keys and the Find box stay reachable.
      final periodCombo = find.byWidgetPredicate(
        (widget) => widget is EraCombo && widget.semanticLabel == 'Period',
      );
      await expectReachable(tester, periodCombo, reason: 'Period');
      await click(tester, periodCombo);
      await settleSheet(tester);
      await click(tester, comboChoice(ShiftsFilterWords.range));
      await settleSheet(tester);
      await expectReachable(
        tester,
        find.byKey(const ValueKey('filter-To')),
        reason: 'To',
      );
      await expectReachable(tester, find.text('Off days'), reason: 'Off days');
      await click(tester, find.text('Off days'));
      await settleSheet(tester);
      final status = find.byWidgetPredicate(
        (widget) => widget is EraCombo && widget.semanticLabel == 'Status',
      );
      await expectReachable(tester, status, reason: 'Status');
      await click(tester, status);
      await settleSheet(tester);
      await click(tester, comboChoice('Effective'));
      await settleSheet(tester);
      expect(
        shellOf(tester).location.filter.status,
        ShiftsStatusFilter.effective,
      );
      // With the strip at its tallest, two rows of the grid stay in view.
      await expectReachable(tester, shiftsGrid, reason: 'grid');
      final window = Offset.zero & size;
      final gridRect = tester.getRect(shiftsGrid);
      final shown = [
        for (final row
            in find
                .descendant(
                  of: shiftsGrid,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget.key is ValueKey<String> &&
                        (widget.key! as ValueKey<String>).value.startsWith(
                          'grid-row:',
                        ),
                  ),
                )
                .evaluate())
          if (() {
            final rect = tester.getRect(find.byWidget(row.widget));
            return gridRect.top <= rect.top &&
                rect.bottom <= gridRect.bottom &&
                window.top <= rect.top &&
                rect.bottom <= window.bottom;
          }())
            row,
      ];
      expect(shown.length, greaterThanOrEqualTo(2), reason: 'grid rows');
      await expectReachable(
        tester,
        find.byKey(const ValueKey('work-find')),
        reason: 'Find',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('work-find')),
          matching: find.byType(EditableText),
        ),
        'night',
      );
      await settleSheet(tester);
      final clear = find.widgetWithText(KeyButton, 'Clear');
      await expectReachable(tester, clear, reason: 'Clear');
      await click(tester, clear);
      await settleSheet(tester);
      await expectReachable(
        tester,
        stepKey(ShiftsFilterWords.previous),
        reason: 'Previous period',
      );
      expect(tester.takeException(), isNull);

      // The Add menu opens under its key and its rows can be pressed.
      await expectReachable(tester, toolbarKey('Add'), reason: 'Add');
      await click(tester, toolbarKey('Add'));
      await settleSheet(tester);
      expectHittable(tester, find.text('Manual shift'), reason: 'Add menu');
      await press(tester, LogicalKeyboardKey.escape);
      await settleSheet(tester);

      // Details, where the tree column shows: its last fact is reachable.
      if (find
          .byKey(const ValueKey('app-frame-tree-column'))
          .evaluate()
          .isNotEmpty) {
        await expectReachable(
          tester,
          find.descendant(
            of: find.byType(DetailsBox),
            matching: find.textContaining('Next shift'),
          ),
          reason: 'Details',
        );
      }

      // Help › Licences shows its page; its Back key is reachable.
      await click(tester, find.text('Help'));
      await settleSheet(tester);
      await click(tester, find.text('Licences'));
      await settleSheet(tester);
      final back = find.descendant(
        of: find.byType(LicencesPage),
        matching: pushKey('Back'),
      );
      await expectReachable(tester, back, reason: 'Licences Back');
      await click(tester, back);
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      await closeShiftsSheet(tester, fixture);
    });

    testWidgets('$name: Calendar', (tester) async {
      await pumpShiftsSheet(
        tester,
        size: size,
        scale: scale,
        store: MemoryLocationStore(
          '${const WorkLocation.calendar(fixtureEmployment, month: LocalDate(2026, 10, 1)).toUri()}',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(DayCalendar), findsOneWidget);
      // Every day of the month shows its number whole inside its cell.
      for (var date = 1; date <= 31; date++) {
        final cell = find.byKey(
          ValueKey('day-calendar-${LocalDate(2026, 10, date)}'),
        );
        final number = find.descendant(of: cell, matching: find.text('$date'));
        expect(number, findsOneWidget, reason: 'day $date');
        final inside = tester.getRect(cell).inflate(0.5);
        final rect = tester.getRect(number);
        expect(
          inside.contains(rect.topLeft) && inside.contains(rect.bottomRight),
          isTrue,
          reason: 'day $date: $rect outside $inside',
        );
      }
      final day = find.byKey(
        ValueKey('day-calendar-${const LocalDate(2026, 10, 6)}'),
      );
      await expectReachable(tester, day, reason: 'a day');
      await click(tester, day);
      await settleSheet(tester);
      expect(
        sheetOf(tester).selectedId,
        plannedRowId(const LocalDate(2026, 10, 6)),
      );
      await expectReachable(
        tester,
        stepKey(ShiftsFilterWords.next),
        reason: 'Next month',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: Confirm worked days', (tester) async {
      await pumpShiftsSheet(tester, size: size, scale: scale);
      await click(tester, toolbarKey('Confirm worked days…'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      await openProperties(tester);
      await expectReachable(
        tester,
        pushKey('Confirm 9 days'),
        reason: 'primary',
      );
      await expectReachable(tester, pushKey('Cancel'), reason: 'Cancel');
      await click(tester, pushKey('Cancel'));
      await settleSheet(tester);
      expect(find.byType(ActionPanel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: Agreements', (tester) async {
      final fixture = await pumpShiftsSheet(
        tester,
        size: size,
        scale: scale,
        store: MemoryLocationStore(
          '${const WorkLocation.agreements(fixtureEmployment, agreement: fixtureAgreement).toUri()}',
        ),
      );
      expect(tester.takeException(), isNull);
      for (final key in ['Save', 'Delete', AgreementsPartWords.change]) {
        await expectReachable(tester, toolbarKey(key), reason: key);
      }
      // A term deep in the property column is reachable by scrolling it
      // (its rows are built as they come into view).
      await openProperties(tester);
      await tester.scrollUntilVisible(
        propertyValue(AgreementField.sickDays),
        60,
        scrollable: find
            .descendant(
              of: find.byType(PropertyGrid),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await expectReachable(
        tester,
        propertyValue(AgreementField.sickDays),
        reason: 'sick days',
      );

      // The Change terms panel: its keys are reachable, docked or not.
      await click(tester, toolbarKey(AgreementsPartWords.change));
      await settleSheet(tester);
      await openProperties(tester);
      await expectReachable(
        tester,
        pushKey(AgreementActionWords.changePrimary),
        reason: 'primary',
      );
      await expectReachable(tester, pushKey('Cancel'), reason: 'Cancel');
      await click(tester, pushKey('Cancel'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      await closeShiftsSheet(tester, fixture);
    });

    testWidgets('$name: Schedules', (tester) async {
      final fixture = await pumpShiftsSheet(
        tester,
        size: size,
        scale: scale,
        store: MemoryLocationStore(
          '${const WorkLocation.schedules(fixtureEmployment).toUri()}',
        ),
      );
      final sheet = shellOf(tester).schedulesSheet!;
      await tester.runAsync(() => sheet.select(sheet.rows.single.rowId));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      for (final key in [
        'Save',
        'Delete',
        SchedulesPartWords.shiftTypes,
        SchedulesPartWords.change,
      ]) {
        await expectReachable(tester, toolbarKey(key), reason: key);
      }
      // The Cycle tab: its strip and Remove block.
      await expectReachable(
        tester,
        pushKey(SchedulesSubformWords.removeBlock),
        reason: 'Remove block',
      );
      // Preview: the month strip scrolls sideways when narrow.
      await openSubformTab(tester, 'Preview');
      await tester.runAsync(() async {
        for (var turn = 0; turn < 100 && sheet.planInputs == null; turn++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await settleSheet(tester);
      expect(find.byType(MonthStrip), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The types view: Back to schedules is reachable.
      await click(tester, toolbarKey(SchedulesPartWords.shiftTypes));
      await settleSheet(tester);
      await expectReachable(
        tester,
        pushKey(SchedulesPartWords.backToSchedules),
        reason: 'Back to schedules',
      );
      await click(tester, pushKey(SchedulesPartWords.backToSchedules));
      await settleSheet(tester);
      // The Change schedule panel on a used version: its keys reachable.
      await tester.runAsync(() async {
        await fixture.schedule.markUsed(sheet.rows.single.schedule);
        for (var turn = 0; turn < 100 && !sheet.rows.single.used; turn++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        await sheet.show(
          sheet.rows.single.schedule.id,
          version: sheet.rows.single.schedule.version,
        );
      });
      await settleSheet(tester);
      await click(tester, toolbarKey(SchedulesPartWords.change));
      await settleSheet(tester);
      await openProperties(tester);
      await expectReachable(
        tester,
        pushKey(SchedulesPartWords.changePrimary),
        reason: 'primary',
      );
      await expectReachable(tester, pushKey('Cancel'), reason: 'Cancel');
      await click(tester, pushKey('Cancel'));
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      await closeShiftsSheet(tester, fixture);
    });

    testWidgets('$name: an archived employment', (tester) async {
      final fixture = await pumpShiftsSheet(
        tester,
        size: size,
        scale: scale,
        store: MemoryLocationStore(
          '${const WorkLocation.employment(fixtureEmployment).toUri()}',
        ),
      );
      await tester.runAsync(() async {
        final employment = (await fixture.reads.employment(fixtureEmployment))!
            .value;
        await fixture.work.employment.archiveEmployment(
          ArchiveEmploymentCommand(
            employmentId: fixtureEmployment,
            expectedRevision: employment.revision,
          ),
        );
      });
      await settleSheet(tester);
      expect(tester.takeException(), isNull);
      await openProperties(tester);
      await expectReachable(tester, propertyValue('status'), reason: 'status');
      await closeShiftsSheet(tester, fixture);
    });

    testWidgets('$name: Employments', (tester) async {
      final fixture = await pumpEmptyShell(
        tester,
        store: MemoryLocationStore(),
        size: size,
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      // The empty database's only way on is reachable.
      await expectReachable(
        tester,
        pushKey(EmploymentsPropertyWords.addEmployment),
        reason: 'Add employment',
      );
      await click(tester, pushKey(EmploymentsPropertyWords.addEmployment));
      await settleSheet(tester);
      // A validation problem on Save: the record-level text is shown and
      // reachable.
      await openProperties(tester);
      await typeProperty(tester, EmploymentField.legalLabel, 'UAB Synthetic');
      await click(tester, toolbarKey('Save'));
      await settleSheet(tester);
      expect(statusNotice(tester), EditProblems.invalid);
      await expectReachable(tester, find.byType(StatusBar), reason: 'status');
      // Undo on invalid entered values asks before it discards them.
      await click(tester, toolbarKey('Undo'));
      await settleSheet(tester);
      await expectReachable(tester, pushKey('Discard'), reason: 'Discard');
      await click(tester, pushKey('Discard'));
      await settleSheet(tester);

      // Many employments: the grid scrolls with the mouse wheel and the
      // last one is reachable.
      await tester.runAsync(() async {
        for (var number = 1; number <= 30; number++) {
          await fixture.work.employment.createEmployment(
            CreateEmploymentCommand(
              name: 'Synthetic site $number',
              legalLabel: null,
            ),
          );
        }
      });
      await settleSheet(tester);
      expect(shellOf(tester).employments, hasLength(30));
      final grid = find.byWidgetPredicate(
        (widget) => widget is DataGrid && widget.label == 'Employments',
      );
      final body = find.descendant(
        of: grid,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      final rows = tester
          .stateList<ScrollableState>(body)
          .reduce(
            (a, b) => a.position.maxScrollExtent >= b.position.maxScrollExtent
                ? a
                : b,
          );
      if (size.height <= 760) {
        expect(
          rows.position.maxScrollExtent,
          greaterThan(0),
          reason: 'short-window wheel coverage must not silently skip',
        );
      }
      if (rows.position.maxScrollExtent > 0) {
        // The wheel over the part of the rows that shows in the window.
        final list = find.byWidget(rows.widget);
        await tester.ensureVisible(list);
        await tester.pumpAndSettle();
        final shown = tester
            .getRect(list)
            .intersect(Offset.zero & tester.view.physicalSize);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: shown.center,
            scrollDelta: const Offset(0, 200),
          ),
        );
        await tester.pumpAndSettle();
        expect(rows.position.pixels, greaterThan(0), reason: 'mouse wheel');
      }
      final last = shellOf(tester).employments.last.employment.id.value;
      await click(tester, await gridCell(tester, last, 'name'));
      await settleSheet(tester);
      expect(shellOf(tester).location.employmentId?.value, last);

      // An ended employment: the tree gains its folder.
      await tester.runAsync(() async {
        final first = shellOf(tester).employments.first.employment;
        await fixture.work.employment.archiveEmployment(
          ArchiveEmploymentCommand(
            employmentId: first.id,
            expectedRevision: first.revision,
          ),
        );
      });
      await settleSheet(tester);
      // Its rows are lazy: the folder is checked in the tree's nodes.
      final tree = tester.widget<TreeView>(
        find.byType(TreeView, skipOffstage: false),
      );
      expect(tree.nodes.single.children.last.id, 'ended');
      expect(tester.takeException(), isNull);
    });
  }
}
