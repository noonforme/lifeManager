import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/explain/explanation.dart';
import 'package:lifeos/shared/workbench/cell_selection.dart';
import 'package:lifeos/shared/workbench/data_register.dart';
import 'package:lifeos/shared/workbench/era_scrollbar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';

const _first = _Row(id: 'shift:1', label: 'First shift', amount: '123.45');
const _second = _Row(id: 'shift:2', label: 'Second shift', amount: '67.89');
const _void = _Row(id: 'shift:3', label: 'Voided shift', amount: '10.00');

void main() {
  testWidgets('a long list keeps its rows whole beside the era scrollbar', (
    tester,
  ) async {
    for (final width in [400.0, 500.0, 510.0]) {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const EraScrollBehavior(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: 200,
                  child: DataRegister<int>(
                    label: 'Many rows',
                    lines: [for (var i = 0; i < 40; i++) RowLine(i)],
                    columns: [
                      RegisterColumn<int>(
                        key: 'a',
                        label: 'A',
                        kind: ColumnKind.text,
                        width: 300,
                        value: (row) => 'Row $row',
                      ),
                      RegisterColumn<int>(
                        key: 'b',
                        label: 'B',
                        kind: ColumnKind.money,
                        width: 200,
                        value: (row) => 'EUR $row.00',
                      ),
                    ],
                    rowId: (row) => '$row',
                    rowLabel: (row) => 'Row $row',
                    selectedId: null,
                    onOpen: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'at $width px');
      // The vertical bar stays at the list's right edge, not past a
      // horizontally scrolled table.
      final bars = find.byKey(const ValueKey('era-scrollbar'));
      final vertical = tester
          .widgetList<SizedBox>(bars)
          .where((box) => box.width == EraScrollbar.thickness);
      expect(vertical, isNotEmpty, reason: 'at $width px');
      final right = tester
          .getRect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.key == const ValueKey('era-scrollbar') &&
                  widget.width == EraScrollbar.thickness,
            ),
          )
          .right;
      expect(right, width, reason: 'at $width px');
    }
  });

  testWidgets('headers are not uppercased and the sorted column says so', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestRegister(onOpen: (_) {}, sortedColumn: 'record'),
    );
    expect(find.text('Record'), findsOneWidget);
    expect(find.bySemanticsLabel('sorted ascending'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('RECORD'), findsNothing);
  });

  testWidgets('rows are 20 px and a selected row is solid blue', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestRegister(selectedId: 'shift:2', onOpen: (_) {}),
    );
    // The list takes focus at the end of its first frame; a focused list
    // draws its selection blue.
    await tester.pump();
    expect(tester.getSize(find.bySemanticsLabel('First shift')).height, 20);
    final fills = tester
        .widgetList<Container>(
          find.descendant(
            of: find.bySemanticsLabel('Second shift'),
            matching: find.byType(Container),
          ),
        )
        .map((value) => value.decoration)
        .whereType<BoxDecoration>()
        .map((value) => value.color);
    expect(fills, contains(LifeOSTokens.millennium.selWash));
  });

  testWidgets('the cell cursor on a selected row is dotted in white', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestRegister(selectedId: 'shift:2', onOpen: (_) {}),
    );
    await tester.tap(find.text('67.89'));
    await tester.pump();
    final cursor = tester
        .widgetList<Container>(find.byType(Container))
        .map((value) => value.foregroundDecoration)
        .whereType<DottedFocusRectangle>()
        .single;
    expect(cursor.color, LifeOSTokens.millennium.selInk);
  });

  testWidgets('arrow keys move the cursor and only Enter opens a row', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(_TestRegister(onOpen: opened.add));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(opened, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, ['shift:1']);
  });

  testWidgets('Enter activates the row under the cursor; Space only opens', (
    tester,
  ) async {
    final opened = <String>[];
    final activated = <String>[];
    await tester.pumpWidget(
      _TestRegister(onOpen: opened.add, onActivate: activated.add),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(opened, ['shift:1']);
    expect(activated, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(activated, ['shift:1']);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(activated, ['shift:1', 'shift:1'], reason: 'Alt+Enter too');
  });

  testWidgets('a double-click activates; two slow clicks only open', (
    tester,
  ) async {
    final opened = <String>[];
    final activated = <String>[];
    await tester.pumpWidget(
      _TestRegister(onOpen: opened.add, onActivate: activated.add),
    );
    final cell = tester.getCenter(find.text('First shift'));
    Future<void> click(Duration at) async {
      final gesture = await tester.createGesture();
      await gesture.down(cell, timeStamp: at);
      await gesture.up(timeStamp: at + const Duration(milliseconds: 40));
      await tester.pump();
    }

    await click(const Duration(seconds: 1));
    await click(const Duration(seconds: 2));
    expect(activated, isEmpty, reason: 'a second apart is two clicks');
    await click(const Duration(seconds: 2, milliseconds: 200));
    expect(activated, ['shift:1']);
    expect(opened.length, 2, reason: 'the activating click does not reopen');
  });

  testWidgets('a click places the cursor and opens the row', (tester) async {
    final opened = <String>[];
    final cells = CellSelectionController();
    await tester.pumpWidget(_TestRegister(onOpen: opened.add, cells: cells));

    await tester.tap(find.text('67.89'));
    expect(opened, ['shift:2']);
    expect(cells.value?.columnLabel, 'Amount');
    expect(cells.value?.display, '67.89');
  });

  testWidgets('the open row and the cursor are announced separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestRegister(selectedId: 'shift:2', onOpen: (_) {}),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    final cursor = tester.getSemantics(find.bySemanticsLabel('First shift'));
    final open = tester.getSemantics(find.bySemanticsLabel('Second shift'));
    expect(cursor.flagsCollection.isFocused, Tristate.isTrue);
    expect(cursor.flagsCollection.isSelected, Tristate.isFalse);
    expect(open.flagsCollection.isSelected, Tristate.isTrue);
    expect(open.flagsCollection.isFocused, Tristate.isFalse);
  });

  testWidgets('cursor moves publish the cell with its explanation', (
    tester,
  ) async {
    final cells = CellSelectionController();
    await tester.pumpWidget(_TestRegister(onOpen: (_) {}, cells: cells));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    // Line 1 is the group heading, so the first row is line 2.
    expect(cells.value?.reference, 'A2');
    expect(cells.value?.isDerived, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cells.value?.reference, 'B2');
    expect(cells.value?.explanation?.plainText, 'Amount = 123.45');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(cells.value?.reference, 'B3');
  });

  testWidgets('group and subtotal lines are not selectable', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(_TestRegister(onOpen: opened.add));

    await tester.tap(find.text('September 2026'));
    await tester.tap(find.text('201.34'));
    expect(opened, isEmpty);

    // Arrow navigation skips them: three downs reach the third row.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, ['shift:3']);
  });

  testWidgets('a voided row is struck and announced as Void', (tester) async {
    await tester.pumpWidget(_TestRegister(onOpen: (_) {}));

    final text = tester.widget<Text>(find.text('10.00'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
    final node = tester.getSemantics(find.bySemanticsLabel('Voided shift'));
    expect(node.value, 'Void');
    expect(node.flagsCollection.isButton, isTrue);
  });

  testWidgets(
    'the sorted column is tinted; amber marks only the hovered header',
    (tester) async {
      await tester.pumpWidget(
        _TestRegister(onOpen: (_) {}, sortedColumn: 'record'),
      );
      final tinted = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('First shift'),
              matching: find.byType(Container),
            ),
          )
          .map((value) => value.color)
          .whereType<Color>();
      expect(tinted, contains(MillenniumColors.sortTint));
      expect(find.byKey(const ValueKey('header-hot-record')), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.text('Record')));
      await tester.pump();
      expect(find.byKey(const ValueKey('header-hot-record')), findsOneWidget);
    },
  );

  testWidgets('a selected row turns grey when the list loses focus', (
    tester,
  ) async {
    final elsewhere = FocusNode();
    addTearDown(elsewhere.dispose);
    await tester.pumpWidget(
      _TestRegister(
        onOpen: (_) {},
        selectedId: 'shift:2',
        elsewhere: elsewhere,
      ),
    );
    await tester.tap(find.text('First shift'));
    await tester.pump();
    Color? fill() =>
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('register-row-shift:2')),
                    )
                    .decoration
                as BoxDecoration?)
            ?.color;
    expect(fill(), LifeOSTokens.millennium.selWash);
    elsewhere.requestFocus();
    // Focus moves at the end of a frame; the list repaints on the next.
    await tester.pump();
    await tester.pump();
    expect(fill(), LifeOSTokens.millennium.chrome);
  });

  testWidgets('right-click lists the row actions', (tester) async {
    final invoked = <String>[];
    await tester.pumpWidget(
      _TestRegister(
        onOpen: (_) {},
        actions: (row) => [
          RowAction(
            label: 'Open',
            onInvoke: () => invoked.add('open ${row.id}'),
          ),
          const RowAction(label: 'Void and replace…', onInvoke: null),
        ],
      ),
    );

    await tester.tap(find.text('First shift'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Void and replace…'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(invoked, ['open shift:1']);
  });

  testWidgets('optional columns hide before the table scrolls', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_TestRegister(width: 640, onOpen: (_) {}));
    expect(find.text('Note'), findsNothing);
    expect(find.text('Amount'), findsOneWidget);

    await tester.pumpWidget(_TestRegister(width: 1200, onOpen: (_) {}));
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('a table still too wide scrolls inside its own viewport', (
    tester,
  ) async {
    await tester.pumpWidget(_TestRegister(width: 300, onOpen: (_) {}));
    final viewport = find.descendant(
      of: find.bySemanticsLabel('Work rows, horizontally scrollable'),
      matching: find.byType(Scrollable),
    );
    expect(viewport, findsWidgets);
    expect(tester.getSize(viewport.first).width, lessThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('numeric cells use tabular figures and align right', (
    tester,
  ) async {
    await tester.pumpWidget(_TestRegister(onOpen: (_) {}));
    final value = tester.widget<Text>(find.text('123.45'));
    expect(
      value.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(value.textAlign, TextAlign.right);
  });

  testWidgets('leaving clears only this register\'s selection', (tester) async {
    final cells = CellSelectionController();
    await tester.pumpWidget(_TestRegister(onOpen: (_) {}, cells: cells));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(cells.value, isNotNull);

    await tester.pumpWidget(
      CellSelectionScope(controller: cells, child: const SizedBox()),
    );
    expect(cells.value, isNull);
  });
}

final class _TestRegister extends StatelessWidget {
  const _TestRegister({
    required this.onOpen,
    this.onActivate,
    this.elsewhere,
    this.width = 900,
    this.selectedId,
    this.cells,
    this.actions,
    this.sortedColumn,
  });

  final ValueChanged<String> onOpen;
  final ValueChanged<String>? onActivate;

  /// Focus beside the list, to take focus away from it.
  final FocusNode? elsewhere;
  final double width;
  final String? selectedId;
  final CellSelectionController? cells;
  final List<RowAction> Function(_Row row)? actions;
  final String? sortedColumn;

  @override
  Widget build(BuildContext context) {
    final register = MaterialApp(
      home: LifeOSSkinScope(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (elsewhere case final node?)
                  Focus(focusNode: node, child: const SizedBox(height: 4)),
                SizedBox(
                  width: width,
                  height: 400,
                  child: DataRegister<_Row>(
                    label: 'Work rows',
                    lines: [
                      const GroupLine(
                        label: 'September 2026',
                        summary: '3 shifts',
                      ),
                      const RowLine(_first),
                      const RowLine(_second),
                      const RowLine(_void, state: RowState.voided),
                      const SubtotalLine(
                        label: 'Expected',
                        cells: {'amount': '201.34'},
                      ),
                    ],
                    columns: [
                      RegisterColumn(
                        key: 'record',
                        label: 'Record',
                        kind: ColumnKind.text,
                        width: 300,
                        value: (row) => row.label,
                      ),
                      RegisterColumn(
                        key: 'amount',
                        label: 'Amount',
                        kind: ColumnKind.derived,
                        width: 200,
                        value: (row) => row.amount,
                        explain: (row) => Explanation(
                          label: 'Amount',
                          tokens: [ResultToken(row.amount)],
                        ),
                      ),
                      RegisterColumn(
                        key: 'note',
                        label: 'Note',
                        kind: ColumnKind.text,
                        width: 400,
                        value: (row) => 'Synthetic note',
                        optional: true,
                      ),
                    ],
                    rowId: (row) => row.id,
                    rowLabel: (row) => row.label,
                    selectedId: selectedId,
                    onOpen: (row) => onOpen(row.id),
                    onActivate: onActivate == null
                        ? null
                        : (row) => onActivate!(row.id),
                    actions: actions,
                    sortedColumn: sortedColumn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final controller = cells;
    return controller == null
        ? register
        : CellSelectionScope(controller: controller, child: register);
  }
}

final class _Row {
  const _Row({required this.id, required this.label, required this.amount});

  final String id;
  final String label;
  final String amount;
}
