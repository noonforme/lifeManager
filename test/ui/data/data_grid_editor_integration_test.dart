import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/data_grid_harness.dart';

void main() {
  for (final live in [false, true]) {
    testWidgets(
      'rapid picks without a draft are delivered before a rebuild (currentRow: $live)',
      (tester) async {
        final state = await pumpGrid(
          tester,
          GridHarness(
            shifts: testShifts(3),
            selectedId: 's1',
            pickMode: true,
            liveRows: live,
          ),
        );
        for (final id in ['s0', 's2']) {
          final target = find.byKey(ValueKey('grid-pick:$id'));
          expect(target.hitTestable(), findsOneWidget);
          await tester.tap(target, kind: PointerDeviceKind.mouse);
        }
        expect(state.log, ['pick s0 true', 'pick s2 true']);
        expect(state.picked, {'s0', 's2'});
        await tester.pumpAndSettle();
        expect(find.text('2 picked'), findsOneWidget);
        expect(state.controller.session, isNull);
      },
    );
  }

  for (final live in [false, true]) {
    for (final change in ['removed', 'replaced', 'locked']) {
      testWidgets(
        'mouse destination $change by accepted commit (currentRow: $live)',
        (tester) async {
          final state = await pumpGrid(
            tester,
            GridHarness(
              shifts: testShifts(3),
              selectedId: 's1',
              liveRows: live,
            ),
          );
          state.afterCommit = (_) => state.update(
            () => state.columnOverride = [
              for (final column in shiftColumns())
                if (column.key != 'end')
                  column
                else if (change != 'removed')
                  GridColumn<TestShift>(
                    key: 'end',
                    label: 'Updated end',
                    kind: ValueKind.text,
                    width: 150,
                    value: (row) => 'Hour ${row.end.hour}',
                    editText: (row) => 'End at ${row.end.hour}',
                    editable: change == 'replaced',
                    description: 'The new end column is calculated.',
                  ),
            ],
          );
          await click(tester, gridCell('s1', 'start'));
          await click(tester, find.byKey(const ValueKey('era-time-up')));
          await click(tester, gridCell('s1', 'end'));
          expect(state.log.first, 'commit s1.start=08:00:00');
          expect(state.shift('s1')!.end, const LocalTime(20, 0));
          if (change == 'replaced') {
            final session = state.controller.session!;
            expect(session.id, const GridCell('s1', 'end').identity);
            expect(session.kind, ValueKind.text);
            expect(session.original, 'Hour 20');
            expect(session.entry, 'End at 20');
            expect(session.draft, 'End at 20');
            final input = find.descendant(
              of: gridCell('s1', 'end'),
              matching: find.byType(EditableText),
            );
            expect(
              tester.widget<EditableText>(input).controller.text,
              'End at 20',
            );
            expect(input.hitTestable(), findsOneWidget);
            await press(tester, LogicalKeyboardKey.escape);
            expect(state.shift('s1')!.end, const LocalTime(20, 0));
          } else {
            expect(
              state.controller.session,
              isNull,
              reason: 'No draft may attach to a removed or newly locked column',
            );
            expect(openEditor, findsNothing);
            if (change == 'locked') {
              expect(
                find.text('The new end column is calculated.'),
                findsOneWidget,
              );
            }
          }
          expect(state.selectedId, 's1');
          expect(state.log.where((entry) => entry.startsWith('commit')), [
            'commit s1.start=08:00:00',
          ]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final live in [false, true]) {
    testWidgets(
      'removed current column closes after immutable commit (currentRow: $live)',
      (tester) async {
        final state = await pumpGrid(
          tester,
          GridHarness(shifts: testShifts(3), selectedId: 's1', liveRows: live),
        );
        state.afterCommit = (_) => state.update(
          () => state.columnOverride = [
            for (final column in shiftColumns())
              if (column.key != 'start') column,
          ],
        );
        await click(tester, gridCell('s1', 'start'));
        await press(tester, LogicalKeyboardKey.arrowUp);
        await press(tester, LogicalKeyboardKey.enter);
        expect(state.log, ['commit s1.start=08:00:00']);
        expect(
          state.controller.session,
          isNull,
          reason: 'A removed field cannot wrap or choose an obsolete successor',
        );
        expect(openEditor, findsNothing);
        expect(state.selectedId, 's1');
      },
    );
  }

  for (final live in [false, true]) {
    testWidgets(
      'pick rechecks eligibility after accepting a draft (currentRow: $live)',
      (tester) async {
        final state = await pumpGrid(
          tester,
          GridHarness(
            shifts: testShifts(3),
            selectedId: 's1',
            pickMode: true,
            liveRows: live,
          ),
        );
        state.afterCommit = (_) => state.update(
          () => state.shifts = [
            for (final row in state.shifts)
              row.id == 's2' ? (row.copy()..pickable = false) : row,
          ],
        );
        await click(tester, gridCell('s1', 'note'));
        await typeText(tester, 'lock pick');
        await click(tester, find.byKey(const ValueKey('grid-pick:s2')));
        expect(state.log, ['commit s1.note=lock pick']);
        expect(state.picked, isEmpty);
      },
    );
  }

  for (final kind in [ValueKind.number, ValueKind.money]) {
    testWidgets(
      '$kind editor fits its restored minimum and accepts raw text at 200 percent',
      (tester) async {
        final state = await pumpGrid(
          tester,
          GridHarness(
            shifts: testShifts(3),
            selectedId: 's1',
            columns: [
              GridColumn<TestShift>(
                key: 'note',
                label: 'Value',
                kind: kind,
                width: 1,
                value: (row) => row.note,
                editable: true,
              ),
            ],
            footer: false,
          ),
          textScale: 2,
        );
        await click(tester, gridCell('s1', 'note'));
        await typeText(tester, '123.45');
        expect(
          tester
              .getRect(gridCell('s1', 'note'))
              .contains(tester.getCenter(find.byType(EditableText))),
          isTrue,
        );
        await press(tester, LogicalKeyboardKey.enter);
        expect(state.shift('s1')!.note, '123.45');
        expect(state.controller.session, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'optional date checkbox and popup are hit targets at 200 percent minimum',
    (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(3),
          selectedId: 's1',
          columns: [
            GridColumn<TestShift>(
              key: 'date',
              label: 'Date',
              kind: ValueKind.date,
              width: 1,
              value: (row) => row.date,
              editable: true,
              optional: true,
            ),
          ],
          footer: false,
        ),
        textScale: 2,
      );
      await click(tester, gridCell('s1', 'date'));
      await click(tester, find.byKey(const ValueKey('era-date-check')));
      expect(state.controller.session!.draft, isNull);
      await click(tester, find.byKey(const ValueKey('era-date-check')));
      await click(tester, find.byKey(const ValueKey('era-date-drop')));
      await click(tester, find.byKey(ValueKey('era-day-$testToday')));
      expect(state.controller.session!.draft, testToday);
      expect(state.log, isEmpty);
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.shift('s1')!.date, testToday);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mouse transition reads immutable values and locks after acceptance',
    (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'start'));
      await press(tester, LogicalKeyboardKey.arrowUp);
      await click(tester, gridCell('s1', 'end'));
      expect(state.controller.session!.original, const LocalTime(20, 0));
      await press(tester, LogicalKeyboardKey.escape);
      await click(tester, gridCell('s1', 'type'));
      await click(
        tester,
        find.descendant(of: openEditor, matching: find.text('Day')),
      );
      await click(tester, find.text('Off').last);
      await click(tester, gridCell('s1', 'start'));
      expect(state.controller.session, isNull);
      expect(state.log, [
        'commit s1.start=08:00:00',
        'commit s1.type=off',
        'explain start: An off day has no times.',
      ]);
    },
  );

  testWidgets(
    'external filter flushes first and rejected text blocks filtering',
    (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(3),
          selectedId: 's1',
          extra: (state) => KeyButton(
            label: 'Filter',
            onPressed: () {
              if (!state.controller.flush().isAccepted) return;
              state.log.add('filter');
              state.update(() => state.shifts = [state.shift('s1')!]);
            },
          ),
        ),
      );
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, 'invalid');
      await click(tester, find.text('Filter'));
      expect(state.shifts, hasLength(3));
      expect(state.log, ['commit s1.break=invalid']);
      expect(state.controller.session!.draft, 'invalid');
      await typeText(tester, '0:45');
      await click(tester, find.text('Filter'));
      expect(state.log, [
        'commit s1.break=invalid',
        'commit s1.break=0:45',
        'filter',
      ]);
      expect(state.shifts.single.breakMinutes, 45);
      expect(state.selectedId, 's1');
    },
  );

  testWidgets('another host supersedes a pending next-field request', (
    tester,
  ) async {
    final state = await pumpGrid(
      tester,
      GridHarness(
        shifts: testShifts(3),
        selectedId: 's1',
        extra: (state) => CellEditor(
          controller: state.controller,
          field: EditField(
            id: const EditIdentity(record: 'property', field: 'note'),
            kind: ValueKind.text,
            value: 'Property',
            commit: (_, _) => const EditResult.accepted(),
          ),
          label: 'Property',
          host: 'properties',
        ),
      ),
    );
    await click(tester, gridCell('s1', 'start'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    // Deliberately before the rebuild that would open End.
    state.controller.begin(
      EditField(
        id: const EditIdentity(record: 'property', field: 'note'),
        kind: ValueKind.text,
        value: 'Property',
        commit: (_, _) => const EditResult.accepted(),
      ),
      host: 'properties',
    );
    await tester.pumpAndSettle();
    expect(
      state.controller.active,
      const EditIdentity(record: 'property', field: 'note'),
    );
    expect(state.controller.session!.host, 'properties');
    expect(openEditor, findsNothing);
  });

  testWidgets(
    'caller refresh retains raw text and entry until explicit cancellation',
    (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1'),
      );
      await click(tester, gridCell('s1', 'break'));
      await typeText(tester, '0:x');
      state.update(
        () => state.shifts = [
          for (final row in state.shifts)
            row.id == 's1' ? (row.copy()..breakMinutes = 90) : row,
        ],
      );
      await tester.pumpAndSettle();
      expect(state.controller.session!.draft, '0:x');
      expect(state.controller.session!.entry, '0:30');
      expect(state.controller.session!.original, 30);
      await press(tester, LogicalKeyboardKey.escape);
      expect(state.shift('s1')!.breakMinutes, 90);
      expect(state.log, isEmpty);
      expect(
        find.descendant(
          of: gridCell('s1', 'break'),
          matching: find.text('1:30'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'disposal detaches both scroll positions and rejects retained drafts safely',
    (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(40),
          selectedId: 's1',
          controller: controller,
        ),
      );
      await click(tester, gridCell('s1', 'note'));
      await typeText(tester, 'kept');
      final scrollControllers = {
        tester
            .widget<ListView>(
              find.descendant(
                of: find.byType(DataGrid<TestShift>),
                matching: find.byType(ListView),
              ),
            )
            .controller!,
        tester
            .widget<SingleChildScrollView>(
              find.descendant(
                of: find.byType(DataGrid<TestShift>),
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .controller!,
      };
      expect(scrollControllers, hasLength(2));
      for (final scroll in scrollControllers) {
        expect(scroll.positions, hasLength(1));
      }
      await tester.pumpWidget(const SizedBox());
      expect(controller.flush().error, 'This list is no longer open.');
      expect(controller.session!.draft, 'kept');
      expect(state.log, isEmpty);
      for (final scroll in scrollControllers) {
        expect(scroll.positions, isEmpty);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inactive/resumed and grid scrolling never reclaim another field focus',
    (tester) async {
      final outside = FocusNode(debugLabel: 'outside');
      final text = TextEditingController();
      addTearDown(outside.dispose);
      addTearDown(text.dispose);
      final state = await pumpGrid(
        tester,
        GridHarness(
          shifts: testShifts(200),
          selectedId: 's1',
          extra: (_) =>
              EraField(controller: text, label: 'Outside', focusNode: outside),
        ),
      );
      await click(tester, gridCell('s1', 'note'));
      await typeText(tester, 'draft');
      await click(
        tester,
        find.descendant(
          of: find.byType(EraField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(outside.hasPrimaryFocus, isTrue);
      for (final lifecycle in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycle);
        await tester.pumpAndSettle();
      }
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(DataGrid<TestShift>),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      scroll.position.jumpTo(3000);
      await tester.pumpAndSettle();
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(outside.hasPrimaryFocus, isTrue);
      expect(state.controller.session!.draft, 'draft');
      expect(state.log, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'rejected check is visible, correctable and inside the row at 200 percent',
    (tester) async {
      final state = await pumpGrid(
        tester,
        GridHarness(shifts: testShifts(3), selectedId: 's1', height: 550),
        textScale: 2,
      );
      state.rejectChecks = 'Check the value.';
      await click(tester, gridCell('s1', 'ok'));
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.controller.session!.error, 'Check the value.');
      expect(find.text('Check the value.'), findsOneWidget);
      expect(
        tester.getRect(gridRow('s1')).bottom,
        greaterThanOrEqualTo(
          tester.getRect(find.text('Check the value.')).bottom,
        ),
      );
      await click(tester, openEditor);
      state.rejectChecks = null;
      await press(tester, LogicalKeyboardKey.enter);
      expect(state.controller.active, const GridCell('s1', 'note').identity);
      expect(tester.takeException(), isNull);
    },
  );
}
