import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic_shell.dart';

Future<void> _open(WidgetTester tester, [String screen = 'shell']) =>
    pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens[screen]!,
    );

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

String _address(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.bySemanticsLabel(RegExp('^Address, ')),
        matching: find.byType(Text),
      ),
    )
    .data!;

void main() {
  testWidgets('Alt+Left and Alt+Right go back and forward; Alt+Home is '
      'Today', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Journal').first);
    await tester.pumpAndSettle();
    expect(_address(tester), 'Journal');
    await _chord(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowLeft,
    );
    expect(_address(tester), r'Work\Synthetic depot\Shifts');
    await _chord(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowRight,
    );
    expect(_address(tester), 'Journal');
    await _chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.home);
    expect(_address(tester), 'Today');
  });

  testWidgets('F4 drops the Address list; Alt+D puts focus in it', (
    tester,
  ) async {
    await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Journal'),
        matching: find.byType(MenuItemButton),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await _chord(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.keyD);
    expect(tester.binding.focusManager.primaryFocus?.debugLabel, 'EraCombo');
  });

  testWidgets('Shift+F10 and the Menu key open the row menu', (tester) async {
    await _open(tester);
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    await _chord(tester, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.f10);
    final menuRow = find.ancestor(
      of: find.text('Properties'),
      matching: find.byType(MenuItemButton),
    );
    expect(menuRow, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menuRow, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Properties'),
        matching: find.byType(MenuItemButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Alt and a menu letter opens that menu', (tester) async {
    await _open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    // The menu letters arm on the frame after Alt goes down.
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF, character: 'f');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(find.text('Backup and export…'), findsOneWidget);
  });

  testWidgets('a toolbar key names itself in an era tooltip', (tester) async {
    await _open(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Back')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Go back to the last place'), findsOneWidget);
  });

  testWidgets('a lit menu row describes itself in the status bar', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Backup and export…')));
    await tester.pumpAndSettle();
    expect(
      find.text('Saves a copy of your records to a file you choose.'),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.text('Saves a copy of your records to a file you choose.'),
      findsNothing,
    );
  });
}
