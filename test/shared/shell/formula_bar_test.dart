import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/explain/explanation.dart';
import 'package:lifeos/shared/shell/formula_bar.dart';
import 'package:lifeos/shared/shell/menu_bar.dart';
import 'package:lifeos/shared/workbench/cell_selection.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

final _source = SourceRef(Uri.parse('/work?record=agreement:a&mode=inspect'));

final _derived = CellSelection(
  owner: Object(),
  reference: 'J5',
  columnLabel: 'Est. pay',
  display: 'EUR 154.10',
  explanation: Explanation(
    label: 'Est. pay, 2026-09-29',
    tokens: [
      const TextToken('regular '),
      OperandToken('8:00', _source),
      const TextToken(' × '),
      OperandToken('18.40/h', _source),
      const TextToken(' = '),
      const ResultToken('EUR 154.10'),
    ],
    source: _source,
    sourceLabel: 'Agreement “Standard” v1',
  ),
);

Future<List<Uri>> _pump(
  WidgetTester tester,
  CellSelectionController cells, {
  bool withMenu = false,
}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: CellSelectionScope(
        controller: cells,
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Column(
              children: [
                if (withMenu)
                  SizedBox(
                    height: 28,
                    child: LifeOSMenuBar(onNavigate: (_) {}),
                  ),
                SizedBox(height: 34, child: FormulaBar(onNavigate: opened.add)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return opened;
}

TapGestureRecognizer _operand(WidgetTester tester, String text) {
  TapGestureRecognizer? found;
  final texts = tester.widgetList<RichText>(
    find.descendant(
      of: find.byType(FormulaBar),
      matching: find.byType(RichText),
    ),
  );
  for (final rich in texts) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.recognizer as TapGestureRecognizer?;
      }
      return found == null;
    });
  }
  return found!;
}

void main() {
  testWidgets('shows nothing without a selection', (tester) async {
    await _pump(tester, CellSelectionController());
    expect(
      find.descendant(of: find.byType(FormulaBar), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('a derived cell shows its reference, label and working', (
    tester,
  ) async {
    final cells = CellSelectionController()..value = _derived;
    await _pump(tester, cells);

    expect(find.text('J5'), findsOneWidget);
    expect(
      find.text(
        'Est. pay, 2026-09-29 = regular 8:00 × 18.40/h = EUR 154.10',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Agreement “Standard” v1'), findsOneWidget);
  });

  testWidgets('clicking an operand or the source opens it', (tester) async {
    final cells = CellSelectionController()..value = _derived;
    final opened = await _pump(tester, cells);

    _operand(tester, '18.40/h').onTap!();
    await tester.tap(find.text('Agreement “Standard” v1'));
    expect(opened, [_source.route, _source.route]);
  });

  testWidgets('a recorded cell says it is a recorded fact', (tester) async {
    final cells = CellSelectionController()
      ..value = CellSelection(
        owner: Object(),
        reference: 'D4',
        columnLabel: 'Start',
        display: '07:00',
      );
    await _pump(tester, cells);
    expect(find.text('Start: 07:00'), findsOneWidget);
    expect(find.text('Recorded fact'), findsOneWidget);
  });

  testWidgets('Edit › Copy explanation copies the plain text', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final cells = CellSelectionController()..value = _derived;
    await _pump(tester, cells, withMenu: true);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy explanation'));
    await tester.pumpAndSettle();
    expect(copied, [_derived.explanation!.plainText]);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy cell'));
    await tester.pumpAndSettle();
    expect(copied.last, 'EUR 154.10');
  });
}
