import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/data_register.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets('arrow moves keyboard focus but Enter alone changes selection', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(_TestRegister(onSelect: selected.add));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(selected, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(selected, ['shift:00000000-0000-7000-8000-000000000001']);
  });

  testWidgets('single click selects a row', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(_TestRegister(onSelect: selected.add));

    await tester.tap(find.bySemanticsLabel('Second shift'));

    expect(selected, ['shift:00000000-0000-7000-8000-000000000002']);
  });

  testWidgets('selected and keyboard-focused rows remain distinct', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestRegister(
        selectedId: 'shift:00000000-0000-7000-8000-000000000002',
        onSelect: (_) {},
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    final focused = tester.getSemantics(find.bySemanticsLabel('First shift'));
    final selected = tester.getSemantics(find.bySemanticsLabel('Second shift'));
    expect(focused.flagsCollection.isFocused, Tristate.isTrue);
    expect(focused.flagsCollection.isSelected, Tristate.isFalse);
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(selected.flagsCollection.isFocused, Tristate.isFalse);
  });

  testWidgets('wide columns scroll inside the labeled table viewport only', (
    tester,
  ) async {
    await tester.pumpWidget(_TestRegister(width: 960, onSelect: (_) {}));

    expect(
      find.bySemanticsLabel('Work rows, horizontally scrollable'),
      findsOneWidget,
    );
    final viewport = find.descendant(
      of: find.bySemanticsLabel('Work rows, horizontally scrollable'),
      matching: find.byType(Scrollable),
    );
    expect(viewport, findsOneWidget);
    expect(tester.getSize(viewport).width, lessThanOrEqualTo(960));
  });

  testWidgets('numeric cells use tabular figures', (tester) async {
    await tester.pumpWidget(_TestRegister(onSelect: (_) {}));

    final value = tester.widget<Text>(find.text('123.45').first);
    expect(
      value.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}

final class _TestRegister extends StatelessWidget {
  const _TestRegister({
    required this.onSelect,
    this.width = 640,
    this.selectedId,
  });

  final ValueChanged<String> onSelect;
  final double width;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    const rows = [
      _Row(
        id: 'shift:00000000-0000-7000-8000-000000000001',
        label: 'First shift',
        amount: '123.45',
      ),
      _Row(
        id: 'shift:00000000-0000-7000-8000-000000000002',
        label: 'Second shift',
        amount: '67.89',
      ),
    ];
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 320,
            child: DataRegister<_Row>(
              label: 'Work rows',
              rows: rows,
              columns: [
                RegisterColumn(
                  label: 'Record',
                  width: 760,
                  value: (row) => row.label,
                ),
                RegisterColumn(
                  label: 'Amount',
                  width: 240,
                  value: (row) => row.amount,
                  numeric: true,
                ),
              ],
              rowId: (row) => row.id,
              rowLabel: (row) => row.label,
              selectedId: selectedId,
              onSelect: (row) => onSelect(row.id),
            ),
          ),
        ),
      ),
    );
  }
}

final class _Row {
  const _Row({required this.id, required this.label, required this.amount});

  final String id;
  final String label;
  final String amount;
}
