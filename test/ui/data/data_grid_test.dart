import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/data_grid_harness.dart';

/// The grid's own key-holding node has the keyboard.
bool _regionFocused() =>
    FocusManager.instance.primaryFocus?.debugLabel == 'DataGrid';

/// The keyboard is inside the open CellEditor.
bool _editorFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var inside = false;
  context.visitAncestorElements((element) {
    if (element.widget is CellEditor) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

Finder get _rows => find.descendant(
  of: find.byType(DataGrid<TestShift>),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  ),
);

Finder get _columns => find.descendant(
  of: find.byType(DataGrid<TestShift>),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.right,
  ),
);

ScrollPosition _position(WidgetTester tester, Finder scrollable) =>
    tester.state<ScrollableState>(scrollable.first).position;

/// Every record line built, on stage or in the cache.
int _builtRows() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('grid-row:'),
      skipOffstage: false,
    )
    .evaluate()
    .length;

Future<void> _drag(WidgetTester tester, Finder finder, Offset by) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  for (var step = 1; step <= 10; step++) {
    await gesture.moveBy(by / 10);
    await tester.pump();
  }
  await gesture.up();
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

/// The open editor's text field.
EditableText _text(WidgetTester tester) => tester.widget<EditableText>(
  find.descendant(of: openEditor, matching: find.byType(EditableText)),
);

void main() {
  group('rendering and semantics', () {
    testWidgets('paints headers, groups, rows, the footer and the navigator', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1', groups: true),
      );
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Thu 2026-10-01'), findsOneWidget);
      expect(find.text('Total (3 shifts)'), findsOneWidget);
      expect(find.text('34:30'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('Filtered: Period'), findsOneWidget);
      expect(state.log, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('header, row and footer cells share their column edges', (
      tester,
    ) async {
      await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1', width: 500),
      );
      final header = tester.getRect(
        find.byKey(const ValueKey('grid-header:paid')),
      );
      final cell = tester.getRect(gridCell('s0', 'paid'));
      expect(cell.left, header.left);
      expect(cell.width, header.width);
      final total = tester.getRect(find.text('34:30'));
      expect(total.right, lessThanOrEqualTo(header.right));
      expect(total.left, greaterThanOrEqualTo(header.left));
      // Scrolled sideways, they move together.
      _position(tester, _columns).jumpTo(120);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(gridCell('s0', 'paid')).left,
        tester.getRect(find.byKey(const ValueKey('grid-header:paid'))).left,
      );
      expect(tester.getRect(gridCell('s0', 'paid')).left, header.left - 120);
    });

    testWidgets('announces selection, pending changes, checks, picks and '
        'errors', (tester) async {
      final handle = tester.ensureSemantics();
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1', pickMode: true),
      );
      state.update(() {
        state.pending.add('s1');
        state.changed.add(const GridCell('s1', 'note'));
        state.errors[const GridCell('s1', 'end')] = 'End is before start.';
        state.picked.add('s1');
        state.shifts[2].pickable = false;
        state.shifts[2].state = GridRowState.voided;
        state.shifts[0].confirmed = true;
      });
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Shift Fri 2026-10-02')),
        isSemantics(
          label: 'Shift Fri 2026-10-02',
          value: 'pending changes, picked, End is before start.',
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Shift Sat 2026-10-03')),
        isSemantics(value: 'Void, cannot be picked', isSelected: false),
      );
      expect(
        tester.getSemantics(gridCell('s0', 'ok')),
        isSemantics(label: 'Confirmed', value: 'ticked'),
      );
      expect(
        tester.getSemantics(gridCell('s1', 'end')),
        isSemantics(label: 'End', value: '19:00, End is before start.'),
      );
      // The selected row's derived cell says why it is read-only.
      expect(
        tester.getSemantics(gridCell('s1', 'paid')),
        isSemantics(
          label: 'Paid',
          hint: 'Paid time is calculated from start, end and break.',
          isReadOnly: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('grid-header:date'))),
        isSemantics(label: 'Date', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('the sorted header says its order', (tester) async {
      final handle = tester.ensureSemantics();
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, find.text('Start'));
      expect(state.log, ['sort start']);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('grid-header:start'))),
        isSemantics(label: 'Start, sorted ascending'),
      );
      await click(tester, find.text('Start'));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('grid-header:start'))),
        isSemantics(label: 'Start, sorted descending'),
      );
      handle.dispose();
    });
  });

  group('controlled selection', () {
    testWidgets('a click asks to select; the owner decides', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(4), selectedId: 's1'),
      );
      await click(tester, gridCell('s2', 'type'));
      expect(state.log, ['select s2']);
      expect(state.selectedId, 's2');
      expect(find.text('3 of 4'), findsOneWidget);
      expect(openEditor, findsNothing, reason: 'the first click only selects');
      expect(_regionFocused(), isTrue);
    });

    testWidgets('a refused request leaves the selection', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(4),
          selectedId: 's1',
          answer: SelectionAnswer.refuse,
        ),
      );
      await click(tester, gridCell('s3', 'note'));
      expect(state.log, ['select s3']);
      expect(find.text('2 of 4'), findsOneWidget);
      // A click on an editable cell of the unselected row edits nothing.
      await click(tester, gridCell('s3', 'note'));
      expect(openEditor, findsNothing);
    });

    testWidgets('two rapid requests while the owner delays: no editor, the '
        'old selection stays until answered', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(5),
          selectedId: 's1',
          answer: SelectionAnswer.delay,
        ),
      );
      await click(tester, gridCell('s2', 'note'));
      await click(tester, gridCell('s3', 'note'));
      expect(state.log, ['select s2', 'select s3']);
      expect(find.text('2 of 5'), findsOneWidget);
      expect(openEditor, findsNothing);
      state.answerDelayed();
      await tester.pumpAndSettle();
      expect(find.text('4 of 5'), findsOneWidget);
      await click(tester, gridCell('s3', 'note'));
      expect(openEditor, findsOneWidget);
      expect(state.controller.active, const GridCell('s3', 'note').identity);
    });

    testWidgets('the selector and the navigator ask to select too', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(4), selectedId: 's1'),
      );
      await click(tester, find.byKey(const ValueKey('grid-selector:s0')));
      await click(tester, find.byKey(const ValueKey('record-last')));
      expect(state.log, ['select s0', 'select s3']);
      expect(find.text('4 of 4'), findsOneWidget);
    });

    testWidgets('a secondary click neither selects nor edits', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s2', 'note'), buttons: kSecondaryButton);
      await click(tester, gridCell('s1', 'note'), buttons: kSecondaryButton);
      expect(state.log, isEmpty);
      expect(openEditor, findsNothing);
    });
  });

  group('read-only and disabled', () {
    testWidgets('a locked row shows its reason and opens nothing', (
      tester,
    ) async {
      final shifts = testShifts(3);
      shifts[1].lockReason = 'Finalized shifts are changed with Correct.';
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: shifts, selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'start'));
      expect(openEditor, findsNothing);
      expect(state.controller.session, isNull);
      expect(state.log, [
        'explain start: Finalized shifts are changed with Correct.',
      ]);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('grid-reason'))).data,
        'Finalized shifts are changed with Correct.',
      );
      // The same column of an open row edits.
      await click(tester, gridCell('s2', 'start'));
      await click(tester, gridCell('s2', 'start'));
      expect(openEditor, findsOneWidget);
      expect(find.byKey(const ValueKey('grid-reason')), findsNothing);
    });

    testWidgets('a derived cell explains itself', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'paid'));
      expect(openEditor, findsNothing);
      expect(state.log, [
        'explain paid: Paid time is calculated from start, end and break.',
      ]);
    });

    testWidgets('disabled: no request, edit, sort, pick, resize or new row', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(3),
          selectedId: 's1',
          enabled: false,
          pickMode: true,
        ),
      );
      await click(tester, gridCell('s2', 'note'));
      await click(tester, gridCell('s1', 'note'));
      await click(tester, find.text('Date'));
      await click(tester, find.byKey(const ValueKey('grid-pick:s0')));
      await click(tester, find.byKey(const ValueKey('grid-new-row')));
      await click(tester, find.byKey(const ValueKey('record-next')));
      await click(tester, find.byKey(const ValueKey('record-add')));
      expect(find.byKey(const ValueKey('grid-resize:date')), findsNothing);
      expect(state.log, isEmpty);
      expect(openEditor, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a locked form scope disables the grid as well', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      state.update(() => state.formEnabled = false);
      await tester.pumpAndSettle();
      await click(tester, gridCell('s2', 'note'));
      await click(tester, gridCell('s1', 'note'));
      await click(tester, find.text('Date'));
      expect(state.log, isEmpty);
      expect(openEditor, findsNothing);
    });
  });

  group('editing from the keyboard', () {
    testWidgets('Enter/Tab walk the eligible cells of the row, a rejected '
        'value stays, the last field closes and the grid keeps the keys', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      state.update(
        () => state.cellLocks[const GridCell('s1', 'end')] = 'Locked end.',
      );
      await click(tester, gridCell('s1', 'start'));
      expect(openEditor, findsOneWidget);
      expect(_editorFocused(), isTrue);
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(state.controller.session!.draft, const LocalTime(8, 0));
      await press(tester, LogicalKeyboardKey.tab);
      expect(state.log, ['commit s1.start=08:00:00']);
      // End is locked for this row: Tab skipped it to Break.
      expect(state.controller.active, const GridCell('s1', 'break').identity);
      expect(_editorFocused(), isTrue);
      await typeText(tester, '0:3x');
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.log.last, 'commit s1.break=0:3x');
      expect(state.controller.active, const GridCell('s1', 'break').identity);
      expect(state.controller.session!.error, 'Enter a break like 0:30.');
      expect(find.text('Enter a break like 0:30.'), findsOneWidget);
      expect(_text(tester).controller.text, '0:3x');
      expect(_editorFocused(), isTrue);
      // The open row grew to hold the editor and its error.
      final row = tester.getRect(gridRow('s1'));
      final error = tester.getRect(find.text('Enter a break like 0:30.'));
      expect(row.bottom, greaterThanOrEqualTo(error.bottom));
      await typeText(tester, '0:45');
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.log.last, 'commit s1.break=0:45');
      // Paid is derived: skipped; the check is eligible.
      expect(state.controller.active, const GridCell('s1', 'ok').identity);
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.controller.active, const GridCell('s1', 'note').identity);
      await typeText(tester, 'Late');
      await press(tester, LogicalKeyboardKey.tab);
      expect(state.log.last, 'commit s1.note=Late');
      expect(state.controller.session, isNull);
      expect(openEditor, findsNothing);
      expect(state.selectedId, 's1');
      expect(_regionFocused(), isTrue);
      // Outside an editor no key does anything.
      final log = [...state.log];
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.escape,
      ]) {
        await press(tester, key);
        expect(_regionFocused(), isTrue, reason: '$key');
      }
      expect(state.log, log);
      expect(openEditor, findsNothing);
      expect(find.text('Late'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: gridCell('s1', 'note'),
                matching: find.text('Late'),
              ),
            )
            .style!
            .fontWeight,
        FontWeight.w700,
        reason: 'a changed value is bold',
      );
    });

    for (final live in [false, true]) {
      testWidgets(
        'immutable commit updates next value and eligibility (currentRow: $live)',
        (tester) async {
          final state = await pumpGrid(
            tester,
            GridHarness(
              shifts: testShifts(3),
              selectedId: 's1',
              liveRows: live,
            ),
          );
          // A new start moves the end: End opens with the new value.
          await click(tester, gridCell('s1', 'start'));
          await press(tester, LogicalKeyboardKey.arrowUp);
          await press(tester, LogicalKeyboardKey.enter);
          expect(state.log, ['commit s1.start=08:00:00']);
          expect(state.controller.active, const GridCell('s1', 'end').identity);
          expect(state.controller.session!.original, const LocalTime(20, 0));
          expect(state.controller.session!.draft, const LocalTime(20, 0));
          await press(tester, LogicalKeyboardKey.escape);
          expect(state.shift('s1')!.end, const LocalTime(20, 0));
          // An off day locks the times: Enter from Type skips them.
          await click(tester, gridCell('s1', 'type'));
          await click(
            tester,
            find.descendant(of: openEditor, matching: find.text('Day')),
          );
          await click(tester, find.text('Off').last);
          await press(tester, LogicalKeyboardKey.enter);
          expect(state.log.last, 'commit s1.type=off');
          expect(state.controller.active, const GridCell('s1', 'ok').identity);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'the app going inactive and back leaves the open editor with the keys',
      (tester) async {
        final state = await pumpGrid(
          tester,
          GridHarness(shifts: testShifts(3), selectedId: 's1'),
        );
        await click(tester, gridCell('s1', 'note'));
        await typeText(tester, 'ab');
        expect(_editorFocused(), isTrue);
        for (final lifecycle in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(lifecycle);
          await tester.pumpAndSettle();
        }
        expect(_editorFocused(), isTrue);
        tester.testTextInput.enterText('abc');
        await tester.pumpAndSettle();
        expect(state.controller.session!.draft, 'abc');
        await press(tester, LogicalKeyboardKey.enter);
        expect(state.log, ['commit s1.note=abc']);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('Esc drops the typed value only and closes the editor', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '1:00');
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.controller.active, const GridCell('s1', 'ok').identity);
      await press(tester, LogicalKeyboardKey.enter);
      await typeText(tester, 'Swapped');
      await press(tester, LogicalKeyboardKey.escape);
      expect(state.controller.session, isNull);
      expect(state.shift('s1')!.note, '');
      expect(state.shift('s1')!.breakMinutes, 60, reason: 'kept');
      expect(_regionFocused(), isTrue);
      await press(tester, LogicalKeyboardKey.tab);
      expect(_regionFocused(), isTrue);
    });

    testWidgets('a click on a check of the selected row ticks it as a draft', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'ok'));
      expect(state.controller.session!.draft, isTrue);
      expect(state.log, isEmpty);
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.log, ['commit s1.ok=true']);
      expect(state.controller.active, const GridCell('s1', 'note').identity);
    });

    testWidgets('editing reaches the next column scrolled into view', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(3),
          selectedId: 's1',
          width: 420,
          columns: shiftColumns(noteWidth: 300),
        ),
      );
      expect(_position(tester, _columns).pixels, 0);
      await click(tester, gridCell('s1', 'break'));
      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.controller.active, const GridCell('s1', 'note').identity);
      expect(_position(tester, _columns).pixels, greaterThan(0));
      final grid = tester.getRect(find.byType(DataGrid<TestShift>));
      final editor = tester.getRect(openEditor);
      expect(editor.left, greaterThanOrEqualTo(grid.left));
      expect(editor.right, lessThanOrEqualTo(grid.right));
      expect(_editorFocused(), isTrue);
    });
  });

  group('commands flush the draft first', () {
    testWidgets('Save outside the grid commits the typed value', (
      tester,
    ) async {
      late GridHarnessState harness;
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(3),
          selectedId: 's1',
          extra: (state) {
            harness = state;
            return KeyButton(
              label: 'Save',
              onPressed: () {
                state.log.add(
                  'save ${state.controller.flush().isAccepted ? 'ok' : 'blocked'}',
                );
              },
            );
          },
        ),
      );
      expect(identical(harness, state), isTrue);
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '1:15');
      await click(tester, find.text('Save'));
      expect(state.log, ['commit s1.break=1:15', 'save ok']);
      expect(openEditor, findsNothing);
      expect(find.text('1:15'), findsOneWidget);
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '1x');
      await click(tester, find.text('Save'));
      expect(state.log.last, 'save blocked');
      expect(openEditor, findsOneWidget);
      expect(find.text('Enter a break like 0:30.'), findsOneWidget);
      expect(_editorFocused(), isTrue);
    });

    testWidgets('sort, new row, navigator, pick and selection flush first; '
        'a rejected draft blocks them', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(4), selectedId: 's1', pickMode: true),
      );
      Future<void> typeBreak(String text) async {
        await click(tester, gridCell(state.selectedId!, 'break'));
        await typeText(tester, text);
      }

      await typeBreak('1:00');
      await click(tester, find.text('Date'));
      expect(state.log, ['commit s1.break=1:00', 'sort date']);
      state.log.clear();

      await typeBreak('1:05');
      await click(tester, find.byKey(const ValueKey('grid-new-row')));
      expect(state.log, ['commit s1.break=1:05', 'new']);
      expect(state.selectedId, 'new1');
      state.log.clear();

      await typeBreak('1:10');
      await click(tester, find.byKey(const ValueKey('record-first')));
      expect(state.log, ['commit new1.break=1:10', 'select s0']);
      state.log.clear();

      await typeBreak('1:20');
      await click(tester, find.byKey(const ValueKey('grid-pick:s2')));
      expect(state.log, ['commit s0.break=1:20', 'pick s2 true']);
      expect(state.selectedId, 's0', reason: 'picking does not select');
      state.log.clear();

      await typeBreak('1:25');
      await click(tester, gridCell('s3', 'type'));
      expect(state.log, ['commit s0.break=1:25', 'select s3']);
      state.log.clear();

      // Rejected: every request is dropped and the editor stays red.
      await typeBreak('9x');
      for (final target in [
        find.text('Date'),
        find.byKey(const ValueKey('grid-new-row')),
        find.byKey(const ValueKey('record-first')),
        find.byKey(const ValueKey('grid-pick:s2')),
        gridCell('s2', 'type'),
        find.byKey(const ValueKey('grid-selector:s2')),
      ]) {
        await click(tester, target);
      }
      expect(state.log, everyElement('commit s3.break=9x'));
      expect(state.log, hasLength(6));
      expect(state.selectedId, 's3');
      expect(state.controller.session!.draft, '9x');
      expect(state.controller.session!.error, 'Enter a break like 0:30.');
      expect(_editorFocused(), isTrue);
    });

    testWidgets('a header drag keeps the draft open and uncommitted', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'note'));
      await typeText(tester, 'abc');
      final before = tester.getRect(gridCell('s1', 'note')).width;
      await _drag(
        tester,
        find.byKey(const ValueKey('grid-resize:note')),
        const Offset(60, 0),
      );
      expect(state.log, ['resize note ${(before + 60).round()}']);
      expect(state.controller.session!.draft, 'abc');
      expect(_text(tester).controller.text, 'abc');
      expect(tester.getRect(gridCell('s1', 'note')).width, before + 60);
    });
  });

  group('the shared editor', () {
    testWidgets('switching to a property editor of the same field keeps one '
        'draft; another field flushes first', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(3),
          selectedId: 's1',
          height: 300,
          extra: (state) => SizedBox(
            width: 340,
            child: EraFormScope(
              child: Column(
                children: [
                  for (final (field, label) in [
                    ('note', 'Note'),
                    ('break', 'Break'),
                  ])
                    CellEditor(
                      controller: state.controller,
                      field: EditField(
                        id: GridCell('s1', field).identity,
                        kind: field == 'note'
                            ? ValueKind.text
                            : ValueKind.duration,
                        value: field == 'note'
                            ? state.shift('s1')!.note
                            : minutesText(state.shift('s1')!.breakMinutes),
                        commit: (id, draft) => state.commit(
                          GridCell(id.record as String, id.field),
                          draft,
                        ),
                      ),
                      label: label,
                      bare: false,
                      host: 'properties',
                      fieldKey: ValueKey('property-$field'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await click(tester, gridCell('s1', 'note'));
      await typeText(tester, 'abc');
      final property = find.byKey(const ValueKey('property-note'));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: property,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'abc',
      );
      // The same field moves to the property editor: no commit.
      await click(tester, property);
      expect(state.log, isEmpty);
      expect(state.controller.session!.host, 'properties');
      await tester.enterText(property, 'abcd');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: gridCell('s1', 'note'),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'abcd',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(state.log, ['commit s1.note=abcd']);
      expect(state.controller.session, isNull);
      expect(
        find.descendant(
          of: gridCell('s1', 'note'),
          matching: find.text('abcd'),
        ),
        findsOneWidget,
      );
      // Another field: the grid's rejected draft blocks the property.
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '7x');
      await click(tester, find.byKey(const ValueKey('property-note')));
      expect(state.log.last, 'commit s1.break=7x');
      expect(state.controller.active, const GridCell('s1', 'break').identity);
      expect(state.controller.session!.host, isNot('properties'));
      expect(_editorFocused(), isTrue);
    });
  });

  group('identity and virtualisation', () {
    testWidgets('scrolling the open row away and back keeps the raw draft and '
        'the entry value', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(200), selectedId: 's1', height: 300),
      );
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '0:4');
      _text(tester).controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 3,
      );
      _position(tester, _rows).jumpTo(3000);
      await tester.pumpAndSettle();
      expect(gridRow('s1'), findsNothing);
      expect(openEditor, findsNothing);
      expect(state.controller.session!.draft, '0:4');
      expect(_regionFocused(), isTrue, reason: 'Tab cannot traverse away');
      await press(tester, LogicalKeyboardKey.tab);
      expect(_regionFocused(), isTrue);
      _position(tester, _rows).jumpTo(0);
      await tester.pumpAndSettle();
      expect(openEditor, findsOneWidget);
      expect(_text(tester).controller.text, '0:4');
      expect(
        _text(tester).controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
      expect(state.controller.session!.entry, '0:30');
      await click(tester, openEditor);
      await press(tester, LogicalKeyboardKey.escape);
      expect(state.shift('s1')!.breakMinutes, 30);
      expect(state.log, isEmpty);
    });

    testWidgets('a rejected flush brings the scrolled-away editor back', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(200), selectedId: 's1', height: 300),
      );
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, 'bad');
      _position(tester, _rows).jumpTo(3000);
      await tester.pumpAndSettle();
      final visible = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('grid-row:'),
      );
      await click(tester, visible.at(3));
      expect(state.log, ['commit s1.break=bad']);
      expect(openEditor, findsOneWidget);
      expect(find.text('Enter a break like 0:30.'), findsOneWidget);
      expect(_editorFocused(), isTrue);
    });

    testWidgets('rows keep their element and the editor its row through '
        'reorder, removal and reinsertion', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(5), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'note'));
      await typeText(tester, 'mine');
      final element = tester.element(gridRow('s1'));
      state.update(() => state.shifts = state.shifts.reversed.toList());
      await tester.pumpAndSettle();
      expect(identical(tester.element(gridRow('s1')), element), isTrue);
      expect(
        find.descendant(of: gridRow('s1'), matching: openEditor),
        findsOneWidget,
      );
      expect(_text(tester).controller.text, 'mine');
      final removed = state.shift('s1')!;
      state.update(
        () => state.shifts = [
          for (final shift in state.shifts)
            if (shift.id != 's1') shift,
        ],
      );
      await tester.pumpAndSettle();
      expect(openEditor, findsNothing, reason: 'no other row takes it');
      expect(state.controller.session!.draft, 'mine', reason: 'never cleared');
      expect(find.byKey(const ValueKey('grid-orphan')), findsOneWidget);
      state.update(() => state.shifts = [removed, ...state.shifts]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('grid-orphan')), findsNothing);
      expect(
        find.descendant(of: gridRow('s1'), matching: openEditor),
        findsOneWidget,
      );
      expect(_text(tester).controller.text, 'mine');
      expect(state.log, isEmpty);
    });

    testWidgets('a removed record keeps its draft until resolved; its commit '
        'names that record', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(4),
          selectedId: 's1',
          extra: (state) => KeyButton(
            label: 'Save',
            onPressed: () => state.controller.flush(),
          ),
        ),
      );
      await click(tester, gridCell('s1', 'note'));
      await typeText(tester, 'orphan');
      state.update(() => state.shifts.removeAt(1));
      await tester.pumpAndSettle();
      await click(tester, find.text('Save'));
      expect(state.log, ['commit s1.note=orphan']);
      expect(state.controller.session!.error, 'This shift was removed.');
      expect(find.byKey(const ValueKey('grid-orphan')), findsOneWidget);
      await click(tester, gridCell('s2', 'note'));
      expect(state.log, ['commit s1.note=orphan', 'commit s1.note=orphan']);
      expect(state.selectedId, 's1', reason: 'the request was blocked');
      state.controller.cancel();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('grid-orphan')), findsNothing);
      await click(tester, gridCell('s2', 'note'));
      expect(state.selectedId, 's2');
    });

    testWidgets('5,000 rows build only the viewport and cache; the navigator '
        'reaches the last one', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(5000), selectedId: 's0', height: 400),
      );
      expect(_builtRows(), lessThan(60));
      expect(
        state.rowBuilds,
        lessThan(160),
        reason: 'count all builds, not only mounted rows',
      );
      expect(find.text('1 of 5000'), findsOneWidget);
      await click(tester, find.byKey(const ValueKey('record-last')));
      expect(state.selectedId, 's4999');
      expect(
        state.rowBuilds,
        lessThan(240),
        reason: 'jumping must not build all intervening rows',
      );
      expect(_builtRows(), lessThan(60));
      final rows = tester.getRect(_rows.first);
      final last = tester.getRect(gridRow('s4999'));
      expect(rows.contains(last.topLeft) && rows.bottom >= last.bottom, isTrue);
      expect(find.text('5000 of 5000'), findsOneWidget);
    });
  });

  group('layout and scaling', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every editor kind fits its narrowest column at '
          '${(scale * 100).round()} %', (tester) async {
        final state = await pumpGrid(
          tester,
          GridHarness(shifts: testShifts(3), selectedId: 's1', width: 980),
          textScale: scale,
          view: const Size(1000, 700),
        );
        for (final column in ['date', 'type', 'start', 'end', 'break', 'ok']) {
          state.update(() => state.widths[column] = 1);
        }
        state.update(() => state.widths['note'] = 1);
        await tester.pumpAndSettle();
        for (final column in [
          'date',
          'type',
          'start',
          'end',
          'break',
          'ok',
          'note',
        ]) {
          state.controller.cancel();
          await tester.pumpAndSettle();
          await click(tester, gridCell('s1', column));
          if (column == 'ok') {
            state.controller.cancel();
            await tester.pumpAndSettle();
            state.controller.begin(
              EditField(
                id: const GridCell('s1', 'ok').identity,
                kind: ValueKind.check,
                value: false,
                commit: (_, _) => const EditResult.accepted(),
              ),
            );
            await tester.pumpAndSettle();
          }
          expect(openEditor, findsOneWidget, reason: column);
          expect(tester.takeException(), isNull, reason: column);
          final cell = tester.getRect(gridCell('s1', column));
          for (final button in [
            const ValueKey('era-date-drop'),
            const ValueKey('era-time-up'),
          ]) {
            final finder = find.descendant(
              of: openEditor,
              matching: find.byKey(button),
            );
            if (finder.evaluate().isEmpty) continue;
            final rect = tester.getRect(finder);
            expect(rect.right, lessThanOrEqualTo(cell.right), reason: column);
          }
          final box = tester.getRect(openEditor);
          expect(box.right, lessThanOrEqualTo(cell.right + 0.01));
        }
      });
    }

    testWidgets('200 % text widens the table, which scrolls sideways under '
        'the era scrollbar', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(30), selectedId: 's1', width: 600),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final columns = _position(tester, _columns);
      expect(columns.maxScrollExtent, greaterThan(0));
      expect(
        find.descendant(
          of: find.byType(DataGrid<TestShift>),
          matching: find.byKey(const ValueKey('era-scrollbar')),
        ),
        findsNWidgets(2),
      );
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '0:40');
      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.controller.active, const GridCell('s1', 'note').identity);
      expect(columns.pixels, greaterThan(0));
      final grid = tester.getRect(find.byType(DataGrid<TestShift>));
      expect(tester.getRect(openEditor).right, lessThanOrEqualTo(grid.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a column drags no narrower than its open editor needs', (
      tester,
    ) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await _drag(
        tester,
        find.byKey(const ValueKey('grid-resize:date')),
        const Offset(-400, 0),
      );
      final width = state.widths['date']!;
      expect(width, greaterThan(100), reason: 'the date editor needs room');
      // The editor opens at that width with its drop button inside.
      await click(tester, gridCell('s1', 'date'));
      final cell = tester.getRect(gridCell('s1', 'date'));
      expect(cell.width, width);
      final drop = tester.getRect(
        find.descendant(
          of: openEditor,
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
      );
      expect(drop.right, lessThanOrEqualTo(cell.right));
      expect(tester.takeException(), isNull);
      // A stored width below the minimum is restored at the minimum.
      state.update(() => state.widths['date'] = 10);
      await tester.pumpAndSettle();
      expect(tester.getRect(gridCell('s1', 'date')).width, width);
      // A read-only column keeps a small usable width.
      await _drag(
        tester,
        find.byKey(const ValueKey('grid-resize:paid')),
        const Offset(-400, 0),
      );
      expect(state.widths['paid'], 24);
    });
  });

  group('popups', () {
    testWidgets('a calendar day and a list row are picked by mouse inside the '
        'cell editor', (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1', height: 420),
        view: const Size(1000, 700),
      );
      await click(tester, gridCell('s1', 'date'));
      await click(
        tester,
        find.descendant(
          of: openEditor,
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
      );
      const day = LocalDate(2026, 10, 20);
      await click(tester, find.byKey(ValueKey('era-day-$day')));
      expect(state.controller.session!.draft, day);
      expect(state.log, isEmpty, reason: 'a pick is not a commit');
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.log, ['commit s1.date=$day']);
      // Enter moved on to Type, a choice.
      expect(state.controller.active, const GridCell('s1', 'type').identity);
      await click(
        tester,
        find.descendant(of: openEditor, matching: find.text('Day')),
      );
      await click(tester, find.text('Night').last);
      expect(state.controller.session!.draft, 'night');
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.log.last, 'commit s1.type=night');
      expect(tester.takeException(), isNull);
    });
  });

  group('pick mode', () {
    testWidgets('ticks eligible records only; the owner totals them', (
      tester,
    ) async {
      final shifts = testShifts(4);
      shifts[1].pickable = false;
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: shifts, selectedId: 's2', pickMode: true),
      );
      expect(find.text('Total (0 picked)'), findsOneWidget);
      expect(find.text('0 picked'), findsOneWidget);
      await click(tester, find.byKey(const ValueKey('grid-pick:s0')));
      await click(tester, find.byKey(const ValueKey('grid-pick:s1')));
      await click(tester, find.byKey(const ValueKey('grid-pick:s3')));
      expect(state.log, ['pick s0 true', 'pick s3 true']);
      expect(state.picked, {'s0', 's3'});
      expect(state.selectedId, 's2', reason: 'picks are not the selection');
      expect(find.text('Total (2 picked)'), findsOneWidget);
      expect(find.text('2 picked'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      await click(tester, find.byKey(const ValueKey('grid-pick:s0')));
      expect(state.log.last, 'pick s0 false');
      expect(find.text('11:30'), findsWidgets);
      expect(find.text('Total (1 picked)'), findsOneWidget);
    });
  });
}
