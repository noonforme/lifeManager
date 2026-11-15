import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';
import 'package:lifeos/app/work_shell/shifts_edit.dart';
import 'package:lifeos/app/work_shell/shifts_filter.dart';
import 'package:lifeos/app/work_shell/shifts_filter_strip.dart';
import 'package:lifeos/app/work_shell/shifts_lines.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell.dart' show WorkShellWords;
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart'
    show click, comboChoice, gridCell, press, toolbarKey;
import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';
import '../../support/work_shell_driver.dart';

/// The filter strip's combo announced as [label].
Finder combo(String label) => find.byWidgetPredicate(
  (widget) => widget is EraCombo && widget.semanticLabel == label,
);

/// Picks [choice] from the strip's combo [label] by mouse.
Future<void> pick(WidgetTester tester, String label, String choice) async {
  await click(tester, combo(label));
  await settleSheet(tester);
  await click(tester, comboChoice(choice));
  await settleSheet(tester);
}

DataGrid<Object?> shiftsGridOf(WidgetTester tester) =>
    tester.widget<DataGrid<Object?>>(shiftsGrid);

Iterable<String> gridIds(WidgetTester tester) =>
    shiftsLines(sheetOf(tester), sheetOf(tester).work.timezones)
        .map((line) => line.id)
        .where(
          (id) => shiftsGridOf(tester).lines.any(
            (line) => line is GridRow && (line.row as ShiftsLine).id == id,
          ),
        );

void main() {
  testWidgets('choosing November in the Period combo shows November and '
      'Back returns', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', 'November 2026');
    expect(shellOf(tester).location.from, const LocalDate(2026, 11, 1));
    expect(shellOf(tester).location.to, const LocalDate(2026, 11, 30));
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shellOf(tester).location.from, const LocalDate(2026, 10, 1));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('the status bar counts the rows the grid shows', (tester) async {
    // Audit 9pk.4.33: hidden Off days and filters were counted.
    final fixture = await pumpShiftsSheet(tester);
    String panel() =>
        tester.widget<StatusBar>(find.byType(StatusBar)).panels.first.text;
    int shown() =>
        shiftsGridOf(tester).lines.whereType<GridRow<Object?>>().length;
    expect(sheetOf(tester).rows.length, greaterThan(shown()));
    expect(panel(), '${shown()} rows');
    await pick(tester, 'Type', 'Night');
    expect(panel(), '${shown()} rows');
    expect(
      shiftsGridOf(tester).lines.whereType<GridGroup<Object?>>().single.summary,
      panel(),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a step keeps the sort', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, find.byKey(const ValueKey('grid-header:paid')));
    await settleSheet(tester);
    expect(shiftsGridOf(tester).sortColumn, 'paid');
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    expect(shellOf(tester).location.from, const LocalDate(2026, 11, 1));
    expect(shiftsGridOf(tester).sortColumn, 'paid');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a pay period in the combo shows its dates and the next '
      'step key steps to the next', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() async {
      for (final (start, end) in [
        (const LocalDate(2026, 10, 16), const LocalDate(2026, 11, 15)),
        (const LocalDate(2026, 11, 16), const LocalDate(2026, 12, 15)),
      ]) {
        await fixture.work.periods.createPeriod(
          CreatePayPeriodCommand(
            employmentId: fixtureEmployment,
            start: start,
            end: end,
            label: null,
          ),
        );
      }
    });
    await settleSheet(tester);
    await pick(
      tester,
      'Period',
      scopeTitle(const LocalDate(2026, 10, 16), const LocalDate(2026, 11, 15)),
    );
    expect(shellOf(tester).location.to, const LocalDate(2026, 11, 15));
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 11, 16), const LocalDate(2026, 12, 15)),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Date range… closes when the place moves another way', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', ShiftsFilterWords.range);
    expect(find.byKey(const ValueKey('filter-From')), findsOneWidget);
    await click(tester, find.text('Calendar').first);
    await settleSheet(tester);
    await click(tester, toolbarKey(WorkShellWords.back));
    await settleSheet(tester);
    expect(shellOf(tester).location.sheet, WorkSheetKind.shifts);
    expect(find.byKey(const ValueKey('filter-From')), findsNothing);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Date range… picked in the boxes\' calendars with the mouse', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', ShiftsFilterWords.range);
    Future<void> pickDay(String box, LocalDate day) async {
      await click(
        tester,
        find.descendant(
          of: find
              .ancestor(
                of: find.byKey(ValueKey('filter-$box')),
                matching: find.byType(EraDateField),
              )
              .first,
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
      );
      await settleSheet(tester);
      await click(tester, find.byKey(ValueKey('era-day-$day')).last);
      await settleSheet(tester);
    }

    await pickDay('From', const LocalDate(2026, 10, 12));
    await pickDay('To', const LocalDate(2026, 10, 25));
    await click(tester, find.widgetWithText(KeyButton, 'Apply'));
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 10, 12), const LocalDate(2026, 10, 25)),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Date range… shows From and To; Apply sets the range', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', ShiftsFilterWords.range);
    final from = find.byKey(const ValueKey('filter-From'));
    expect(from, findsOneWidget);
    // The date box's own typing is its library's to test; here the strip
    // takes the date it gives.
    tester
        .widget<EraDateField>(
          find.ancestor(of: from, matching: find.byType(EraDateField)).first,
        )
        .onChanged(const LocalDate(2026, 10, 20));
    await settleSheet(tester);
    tester
        .widget<EraDateField>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('filter-To')),
                matching: find.byType(EraDateField),
              )
              .first,
        )
        .onChanged(const LocalDate(2026, 11, 10));
    await settleSheet(tester);
    await click(tester, find.widgetWithText(KeyButton, 'Apply'));
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 10, 20), const LocalDate(2026, 11, 10)),
    );
    // The combo and the grid's heading name the range alike.
    final title = scopeTitle(
      const LocalDate(2026, 10, 20),
      const LocalDate(2026, 11, 10),
    );
    expect(
      tester
          .widget<EraCombo<String>>(combo('Period'))
          .items
          .map((item) => item.label),
      contains(title),
    );
    expect(
      shiftsGridOf(tester).lines.whereType<GridGroup<Object?>>().first.label,
      title,
    );
    final group = shiftsGridOf(tester).lines.first as GridGroup;
    expect(group.label, 'Tue 2026-10-20 – Tue 2026-11-10');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Status Finalized hides planned rows and sets the note', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.runAsync(() => fixture.finishShift(20));
    await settleSheet(tester);
    await pick(tester, 'Status', 'Finalized');
    expect(
      shellOf(tester).location.filter.status,
      ShiftsStatusFilter.finalized,
    );
    expect(gridIds(tester).where((id) => id.startsWith('day:')), isEmpty);
    expect(shiftsGridOf(tester).note, 'Filtered: Status');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Off days lists Off rows; Clear restores every default', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    expect(gridIds(tester).where((id) => id.startsWith('off:')), isEmpty);
    await click(tester, find.text('Off days'));
    await settleSheet(tester);
    expect(gridIds(tester).where((id) => id.startsWith('off:')), hasLength(12));
    await pick(tester, 'Type', 'Night');
    expect(shellOf(tester).location.filter.type, 'Night');
    await click(tester, find.widgetWithText(KeyButton, 'Clear'));
    await settleSheet(tester);
    expect(shellOf(tester).location.filter, ShiftsFilter.none);
    expect(shiftsGridOf(tester).note, isNull);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a period move with an invalid pending edit stays on the '
      'problem', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(tester, toolbarKey('New shift'));
    await settleSheet(tester);
    // A break the new end leaves outside the shift makes it invalid.
    final edit = sheetOf(tester).edit!;
    expect(edit.addBreak(), isNull);
    edit.set(ShiftsField.end, const LocalTime(10, 0));
    expect(edit.session.issues, isNotEmpty);
    await settleSheet(tester);
    final before = shellOf(tester).location;
    await click(tester, stepKey(ShiftsFilterWords.next));
    await settleSheet(tester);
    expect(shellOf(tester).location, before);
    expect(sheetOf(tester).selectedId, newRowId);
    expect(statusNotice(tester), EditProblems.invalid);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Filter by selection keeps rows like the selected one', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    expect(
      tester
          .widget<BandedToolbar>(find.byType(BandedToolbar))
          .bands
          .expand((band) => band.items)
          .firstWhere((item) => item.label == 'Filter by selection')
          .onPressed,
      isNull,
      reason: 'no row selected',
    );
    await selectShiftsRow(tester, plannedRowId(const LocalDate(2026, 10, 5)));
    await click(tester, toolbarKey('Filter by selection'));
    await settleSheet(tester);
    expect(
      shellOf(tester).location.filter,
      const ShiftsFilter(status: ShiftsStatusFilter.planned, type: 'Day'),
    );
    expect(
      gridIds(tester).every(
        (id) =>
            !id.startsWith('day:') ||
            {
              for (final day in [5, 6, 7, 17, 18, 19, 29, 30, 31])
                plannedRowId(LocalDate(2026, 10, day)),
            }.contains(id),
      ),
      isTrue,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Remove filter is Clear, greyed while nothing is set', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Status', 'Finalized');
    await click(tester, toolbarKey('Remove filter'));
    await settleSheet(tester);
    expect(shellOf(tester).location.filter, ShiftsFilter.none);
    expect(
      tester
          .widget<BandedToolbar>(find.byType(BandedToolbar))
          .bands
          .expand((band) => band.items)
          .firstWhere((item) => item.label == 'Remove filter')
          .onPressed,
      isNull,
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('a header click sorts and Sort reverses it', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await click(
      tester,
      find.descendant(of: shiftsGrid, matching: find.text('Type')),
    );
    await settleSheet(tester);
    List<String?> types() => [
      for (final line in shiftsGridOf(tester).lines)
        if (line is GridRow) (line.row as ShiftsLine).type,
    ];
    expect(shiftsGridOf(tester).sortColumn, 'type');
    expect(types().first, 'Day');
    await click(tester, toolbarKey('Sort'));
    await settleSheet(tester);
    expect(shiftsGridOf(tester).sortDescending, isTrue);
    expect(types().first, 'Night');
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Sort takes the open cell\'s value first, as a header does', (
    tester,
  ) async {
    // Audit 9pk.4.46: the toolbar sorted on the value before the edit.
    final fixture = await pumpShiftsSheet(tester);
    await click(
      tester,
      find.descendant(of: shiftsGrid, matching: find.text('End')),
    );
    await settleSheet(tester);
    expect(shiftsGridOf(tester).sortColumn, 'end');
    const day = 'day:2026-10-06';
    await selectShiftsRow(tester, day);
    final cell = await gridCell(tester, day, 'end');
    await click(tester, cell);
    await click(
      tester,
      find.descendant(
        of: cell,
        matching: find.byKey(const ValueKey('era-time-up')),
      ),
    );
    await settleSheet(tester);
    // No Enter: the stepped value is still the open editor's draft.
    await click(tester, toolbarKey('Sort'));
    await settleSheet(tester);
    final grid = shiftsGridOf(tester);
    expect(grid.sortDescending, isTrue);
    final first = grid.lines.whereType<GridRow<Object?>>().first.row;
    expect((first as ShiftsLine).id, day);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Find filters as it is typed', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('work-find')),
        matching: find.byType(EditableText),
      ),
      'night',
    );
    await settleSheet(tester);
    expect(
      {
        for (final line in shiftsGridOf(tester).lines)
          if (line is GridRow) (line.row as ShiftsLine).type,
      },
      {'Night'},
    );
    expect(shiftsGridOf(tester).note, 'Filtered: Find');
    await click(tester, find.widgetWithText(KeyButton, 'Clear'));
    await settleSheet(tester);
    expect(shiftsGridOf(tester).note, isNull);
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('no key changes a filter or the period (spec 4.6)', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Status', 'Draft');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await settleSheet(tester);
    expect(shellOf(tester).location.filter.status, ShiftsStatusFilter.draft);
    await pick(tester, 'Period', 'November 2026');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await settleSheet(tester);
    expect(shellOf(tester).location.from, const LocalDate(2026, 11, 1));
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Find is data entry: Esc drops the text, Tab stays in it', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    final box = find.descendant(
      of: find.byKey(const ValueKey('work-find')),
      matching: find.byType(EditableText),
    );
    await click(tester, box);
    await tester.enterText(box, 'night');
    await settleSheet(tester);
    expect(shiftsGridOf(tester).note, 'Filtered: Find');
    await press(tester, LogicalKeyboardKey.tab);
    await settleSheet(tester);
    expect(tester.widget<EditableText>(box).focusNode.hasFocus, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    await settleSheet(tester);
    expect(tester.widget<EditableText>(box).controller.text, isEmpty);
    expect(shiftsGridOf(tester).note, isNull);
    await closeShiftsSheet(tester, fixture);
  });

  EraDateField dateBox(WidgetTester tester, String label) =>
      tester.widget<EraDateField>(
        find
            .ancestor(
              of: find.byKey(ValueKey('filter-$label')),
              matching: find.byType(EraDateField),
            )
            .first,
      );

  /// Clicks the day digits of the date box [label] with the mouse: in
  /// "Thu 2026-10-01" they are 12–14.
  Future<void> clickDay(WidgetTester tester, String label) async {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(ValueKey('filter-$label')),
        matching: find.byType(RichText),
      ),
    );
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 12, extentOffset: 14),
        )
        .first;
    await tester.tapAt(
      paragraph.localToGlobal(box.toRect().center),
      kind: PointerDeviceKind.mouse,
    );
    await settleSheet(tester);
  }

  testWidgets('Esc in a date box puts its date back; the other end stays', (
    tester,
  ) async {
    // Audit 9pk.4.44: the typed day was applied after Esc.
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', ShiftsFilterWords.range);
    dateBox(tester, 'To').onChanged(const LocalDate(2026, 11, 10));
    await settleSheet(tester);
    await clickDay(tester, 'From');
    await press(tester, LogicalKeyboardKey.digit1);
    await press(tester, LogicalKeyboardKey.digit2);
    await settleSheet(tester);
    expect(dateBox(tester, 'From').value, const LocalDate(2026, 10, 12));
    await press(tester, LogicalKeyboardKey.escape);
    await settleSheet(tester);
    expect(dateBox(tester, 'From').value, const LocalDate(2026, 10, 1));
    expect(dateBox(tester, 'To').value, const LocalDate(2026, 11, 10));
    // The edit closed: digits typed now go nowhere.
    await press(tester, LogicalKeyboardKey.digit5);
    await settleSheet(tester);
    expect(dateBox(tester, 'From').value, const LocalDate(2026, 10, 1));
    await click(tester, find.widgetWithText(KeyButton, 'Apply'));
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 10, 1), const LocalDate(2026, 11, 10)),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Tab goes from From to To, and from To applies the range', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', ShiftsFilterWords.range);
    await clickDay(tester, 'From');
    await press(tester, LogicalKeyboardKey.digit1);
    await press(tester, LogicalKeyboardKey.digit2);
    await press(tester, LogicalKeyboardKey.tab);
    await settleSheet(tester);
    expect(shellOf(tester).location.from, const LocalDate(2026, 10, 1));
    // To took focus on its year; step to the day and type it.
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.digit2);
    await press(tester, LogicalKeyboardKey.digit0);
    await settleSheet(tester);
    expect(dateBox(tester, 'To').value, const LocalDate(2026, 10, 20));
    await press(tester, LogicalKeyboardKey.tab);
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 10, 12), const LocalDate(2026, 10, 20)),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('typed dates move nothing until Apply', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    final before = shellOf(tester).location;
    await pick(tester, 'Period', ShiftsFilterWords.range);
    // Each digit reports a date: none of them moves the sheet.
    dateBox(tester, 'From').onChanged(const LocalDate(2026, 1, 20));
    await settleSheet(tester);
    dateBox(tester, 'From').onChanged(const LocalDate(2026, 10, 20));
    await settleSheet(tester);
    dateBox(tester, 'To').onChanged(const LocalDate(2026, 11, 10));
    await settleSheet(tester);
    expect(shellOf(tester).location, before);
    expect(dateBox(tester, 'From').value, const LocalDate(2026, 10, 20));
    await click(tester, find.widgetWithText(KeyButton, 'Apply'));
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 10, 20), const LocalDate(2026, 11, 10)),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets('Enter in a date box applies the range; a backward one swaps', (
    tester,
  ) async {
    final fixture = await pumpShiftsSheet(tester);
    await pick(tester, 'Period', ShiftsFilterWords.range);
    dateBox(tester, 'From').onChanged(const LocalDate(2026, 11, 10));
    await settleSheet(tester);
    dateBox(tester, 'To').onChanged(const LocalDate(2026, 10, 20));
    await settleSheet(tester);
    await click(tester, find.byKey(const ValueKey('filter-To')));
    await settleSheet(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await settleSheet(tester);
    expect(
      (shellOf(tester).location.from, shellOf(tester).location.to),
      (const LocalDate(2026, 10, 20), const LocalDate(2026, 11, 10)),
    );
    await closeShiftsSheet(tester, fixture);
  });

  testWidgets("To confirm's ◂ rests on the oldest listed month, and an "
      'older month routed to is listed', (tester) async {
    const today = LocalDate(2026, 10, 20);
    Future<void> show(LocalDate month) => tester.pumpWidget(
      GalleryHost(
        home: Center(
          child: toConfirmFilterStrip(
            place: WorkLocation.toConfirm(
              fixtureEmployment,
              from: month,
              to: month.lastOfMonth,
            ),
            types: const [],
            today: today,
            onMonth: (_) {},
            onStep: (_) {},
            onFilter: (_) {},
            onClear: null,
          ),
        ),
      ),
    );
    StepKey back() =>
        tester.widget<StepKey>(stepKey(ShiftsFilterWords.previous));
    List<String> months() => [
      for (final item in tester.widget<EraCombo<String>>(combo('Period')).items)
        item.value,
    ];

    await show(const LocalDate(2025, 11, 1));
    expect(back().onPressed, isNotNull);
    await show(const LocalDate(2025, 10, 1));
    expect(back().onPressed, isNull);
    expect(months(), isNot(contains('2025-09-01')));
    await show(const LocalDate(2025, 9, 1));
    expect(back().onPressed, isNull);
    expect(months(), contains('2025-09-01'));
  });
}
