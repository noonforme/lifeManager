import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_combo.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

const _box = ValueKey('combo');

final class _Host extends StatefulWidget {
  const _Host({this.onCommand});

  final VoidCallback? onCommand;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  String value = 'Pay periods';

  @override
  Widget build(BuildContext context) => EraCombo<String>(
    key: _box,
    semanticLabel: 'View',
    value: value,
    items: [
      const EraComboItem('Shifts', 'Shifts'),
      const EraComboItem('Pay periods', 'Pay periods'),
      const EraComboItem('Payslips', 'Payslips'),
      const EraComboItem('range', 'Date range…', command: true),
    ],
    onSelected: (picked) {
      if (picked == 'range') {
        widget.onCommand?.call();
      } else {
        setState(() => value = picked);
      }
    },
  );
}

Future<void> _pump(WidgetTester tester, {VoidCallback? onCommand}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _Host(onCommand: onCommand),
              ),
            ),
          ),
        ),
      ),
    );

String _value(WidgetTester tester) =>
    tester.widget<EraCombo<String>>(find.byKey(_box)).value!;

Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(MenuItemButton));

Color? _rowColor(WidgetTester tester, String label) => tester
    .widget<Material>(
      find.descendant(of: _row(label), matching: find.byType(Material)).first,
    )
    .color;

void main() {
  testWidgets('the list drops directly below the box, as wide as it', (
    tester,
  ) async {
    await _pump(tester);
    final box = tester.getRect(find.byKey(_box));
    await tester.tap(find.byKey(_box));
    await tester.pump();
    final first = tester.getRect(_row('Shifts'));
    expect(first.top, greaterThanOrEqualTo(box.bottom));
    expect(first.top - box.bottom, lessThanOrEqualTo(2));
    final list = tester.getRect(
      find.ancestor(of: _row('Shifts'), matching: find.byType(Material)).first,
    );
    expect(list.left, box.left);
    expect(list.width, box.width);
  });

  testWidgets('the current value is lit when the list opens', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pump();
    await tester.pump();
    final selection = LifeOSSkinData.standard.tokens.selWash;
    expect(_rowColor(tester, 'Pay periods'), selection);
    expect(_rowColor(tester, 'Shifts'), isNot(selection));
  });

  testWidgets('a click on a row picks it and closes the list', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pump();
    await tester.tap(_row('Payslips'));
    await tester.pumpAndSettle();
    expect(_value(tester), 'Payslips');
    expect(_row('Shifts'), findsNothing);
  });

  testWidgets('Up and Down on the closed box step its value', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_row('Shifts'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_value(tester), 'Payslips');
    // A command row is never stepped onto.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_value(tester), 'Payslips');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_value(tester), 'Pay periods');
  });

  testWidgets('Alt+Down opens it; Down then Enter picks the next row', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(_row('Shifts'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_value(tester), 'Payslips');
  });

  testWidgets('a command row runs without becoming the value', (tester) async {
    var asked = 0;
    await _pump(tester, onCommand: () => asked++);
    await tester.tap(find.byKey(_box));
    await tester.pump();
    await tester.tap(_row('Date range…'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(_value(tester), 'Pay periods');
  });

  testWidgets('hover moves the light, so only one row is lit', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(_box));
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_row('Shifts')));
    await tester.pump();
    final selection = LifeOSSkinData.standard.tokens.selWash;
    expect(_rowColor(tester, 'Shifts'), selection);
    expect(_rowColor(tester, 'Pay periods'), isNot(selection));
  });
}
