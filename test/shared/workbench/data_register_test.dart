import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/explain/explanation.dart';
import 'package:lifeos/shared/workbench/cell_selection.dart';
import 'package:lifeos/shared/workbench/data_register.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

const _first = _Row(id: 'shift:1', label: 'First shift', amount: '123.45');
const _second = _Row(id: 'shift:2', label: 'Second shift', amount: '67.89');
const _void = _Row(id: 'shift:3', label: 'Voided shift', amount: '10.00');

void main() {
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

  testWidgets('the entry line opens the create form', (tester) async {
    var entries = 0;
    await tester.pumpWidget(
      _TestRegister(onOpen: (_) {}, onEntry: () => entries++),
    );
    await tester.tap(find.text('Click to add a shift'));
    expect(entries, 1);
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
    expect(find.text('NOTE'), findsNothing);
    expect(find.text('AMOUNT'), findsOneWidget);

    await tester.pumpWidget(_TestRegister(width: 1200, onOpen: (_) {}));
    expect(find.text('NOTE'), findsOneWidget);
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
    this.width = 900,
    this.selectedId,
    this.cells,
    this.onEntry,
    this.actions,
  });

  final ValueChanged<String> onOpen;
  final double width;
  final String? selectedId;
  final CellSelectionController? cells;
  final VoidCallback? onEntry;
  final List<RowAction> Function(_Row row)? actions;

  @override
  Widget build(BuildContext context) {
    final register = MaterialApp(
      home: LifeOSSkinScope(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 400,
              child: DataRegister<_Row>(
                label: 'Work rows',
                lines: [
                  const GroupLine(label: 'September 2026', summary: '3 shifts'),
                  const RowLine(_first),
                  const RowLine(_second),
                  const RowLine(_void, state: RowState.voided),
                  const SubtotalLine(
                    label: 'Expected',
                    cells: {'amount': '201.34'},
                  ),
                  EntryLine(
                    hint: 'Click to add a shift',
                    onOpen: onEntry ?? () {},
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
                actions: actions,
              ),
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
