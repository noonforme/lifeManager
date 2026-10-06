import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_menu.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';

final _menuKey = GlobalKey<EraContextMenuState>();

/// The menu panel around [label]: the Material with the era menu edge.
Finder _panel(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Material &&
        widget.shape is OutlinedBorder &&
        (widget.shape! as OutlinedBorder).side.color ==
            MillenniumColors.menuEdge,
  ),
);

Future<FocusNode> _pump(WidgetTester tester, List<EraMenuItem> items) async {
  final list = FocusNode(debugLabel: 'List');
  addTearDown(list.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: EraContextMenu(
            key: _menuKey,
            child: Focus(
              focusNode: list,
              autofocus: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapUp: (details) =>
                    _menuKey.currentState!.show(details.globalPosition, items),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return list;
}

Future<void> _rightClick(WidgetTester tester, Offset at) async {
  final press = await tester.startGesture(
    at,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await press.up();
  await tester.pump();
}

/// The colour behind [label]'s row.
Color? _rowColor(WidgetTester tester, String label) {
  final material = tester.widget<Material>(
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
  );
  return material.color;
}

void main() {
  testWidgets('a right-click opens the menu at once, at the pointer', (
    tester,
  ) async {
    await _pump(tester, [EraMenuItem('Properties', () {})]);
    await _rightClick(tester, const Offset(200, 150));
    // One frame: no fade or grow, motion is immediate.
    expect(_panel('Properties'), findsOneWidget);
    final first = tester.getRect(_panel('Properties'));
    expect(first.topLeft, const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(tester.getRect(_panel('Properties')), first);
  });

  testWidgets('the panel fits its items, flat, with the era edge', (
    tester,
  ) async {
    await _pump(tester, [EraMenuItem('Open', () {})]);
    await _rightClick(tester, const Offset(200, 150));
    expect(tester.widget<Material>(_panel('Open')).elevation, 0);
    // No Material 112 px minimum: the panel is about its text's width.
    expect(tester.getSize(_panel('Open')).width, lessThan(112));
  });

  testWidgets('hover lights a row selection blue with white text', (
    tester,
  ) async {
    final skin = LifeOSSkinData.standard.tokens;
    await _pump(tester, [
      EraMenuItem('Open', () {}),
      EraMenuItem('Rename…', () {}),
    ]);
    // One mouse right-clicks, then moves onto a row.
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(mouse.removePointer);
    await mouse.down(const Offset(200, 150));
    await mouse.up();
    await tester.pump();
    expect(_rowColor(tester, 'Rename…'), isNot(skin.selWash));
    await mouse.moveTo(tester.getCenter(find.text('Rename…')));
    await tester.pump();
    expect(_rowColor(tester, 'Rename…'), skin.selWash);
    expect(
      tester
          .widget<DefaultTextStyle>(
            find
                .ancestor(
                  of: find.text('Rename…'),
                  matching: find.byType(DefaultTextStyle),
                )
                .first,
          )
          .style
          .color,
      skin.selInk,
    );
  });

  testWidgets('the default item is bold; a disabled one is grey and inert', (
    tester,
  ) async {
    var picked = 0;
    await _pump(tester, [
      EraMenuItem('Open', () => picked++, isDefault: true),
      const EraMenuItem('Delete', null),
    ]);
    await _rightClick(tester, const Offset(200, 150));
    TextStyle style(String label) => tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style('Open').fontWeight, FontWeight.w700);
    expect(style('Delete').color, LifeOSSkinData.standard.tokens.muted);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(picked, 0);
  });

  testWidgets('a click on an item closes the menu and runs it once', (
    tester,
  ) async {
    var picked = 0;
    await _pump(tester, [EraMenuItem('Open', () => picked++)]);
    await _rightClick(tester, const Offset(200, 150));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
    expect(picked, 1);
  });

  testWidgets('Down lights the first item, Enter runs it, focus comes back', (
    tester,
  ) async {
    var picked = '';
    final list = await _pump(tester, [
      EraMenuItem('Open', () => picked = 'open'),
      EraMenuItem('Rename…', () => picked = 'rename'),
    ]);
    await _rightClick(tester, const Offset(200, 150));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_rowColor(tester, 'Open'), LifeOSSkinData.standard.tokens.selWash);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, 'open');
    expect(tester.binding.focusManager.primaryFocus, list);
  });

  testWidgets('Esc and a click outside close it; focus stays on the list', (
    tester,
  ) async {
    var picked = 0;
    final list = await _pump(tester, [EraMenuItem('Open', () => picked++)]);
    await _rightClick(tester, const Offset(200, 150));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
    expect(tester.binding.focusManager.primaryFocus, list);

    await _rightClick(tester, const Offset(200, 150));
    await tester.tapAt(const Offset(600, 500));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
    expect(picked, 0);
    expect(tester.binding.focusManager.primaryFocus, list);
  });

  testWidgets('rows are the era 24 px tall', (tester) async {
    await _pump(tester, [EraMenuItem('Open', () {})]);
    await _rightClick(tester, const Offset(200, 150));
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Open'),
              matching: find.byType(MenuItemButton),
            ),
          )
          .height,
      24,
    );
  });
}
