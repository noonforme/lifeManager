import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/tab_strip_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

Widget _host(Widget child, {double width = 480, double textScale = 1}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );

const _abc = [
  TabItem(id: 'a', label: 'Alpha'),
  TabItem(id: 'b', label: 'Beta', count: 2, countLabel: 'to confirm'),
  TabItem(
    id: 'c',
    label: 'Gamma',
    enabled: false,
    disabledReason: 'Save the record first.',
  ),
];

Finder _tab(String label) => find.bySemanticsLabel(RegExp('^$label'));

void main() {
  testWidgets('a tap requests the id and the strip stays controlled', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      _host(TabStrip(tabs: _abc, selectedId: 'a', onSelect: requests.add)),
    );
    await tester.tap(find.text('Beta'));
    expect(requests, ['b']);
    // The owner refused: the selection is unchanged.
    expect(
      tester.getSemantics(_tab('Alpha')),
      matchesSemantics(
        label: 'Alpha',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: false,
      ),
    );
    await tester.tap(find.text('Alpha'));
    expect(requests, ['b'], reason: 'the selected tab requests nothing');
  });

  testWidgets('selection follows the id through reordering', (tester) async {
    Widget strip(List<TabItem> tabs) =>
        _host(TabStrip(tabs: tabs, selectedId: 'b', onSelect: (_) {}));
    await tester.pumpWidget(strip(_abc));
    await tester.pumpWidget(strip(_abc.reversed.toList()));
    expect(
      tester.getSemantics(_tab('Beta')).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(_tab('Alpha')).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    expect(
      tester.getTopLeft(find.text('Gamma')).dx <
          tester.getTopLeft(find.text('Alpha')).dx,
      isTrue,
    );
  });

  testWidgets('duplicate ids are rejected', (tester) async {
    await tester.pumpWidget(
      _host(
        TabStrip(
          tabs: const [
            TabItem(id: 'x', label: 'One'),
            TabItem(id: 'x', label: 'Two'),
          ],
          selectedId: 'x',
          onSelect: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('empty, removed and unknown selections do not index', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TabStrip(
          tabs: const [],
          selectedId: 'a',
          onSelect: (_) {},
          trailing: const Text('Nothing here'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing here'), findsOneWidget);
    await tester.pumpWidget(
      _host(TabStrip(tabs: _abc, selectedId: 'gone', onSelect: (_) {})),
    );
    expect(tester.takeException(), isNull);
    for (final label in ['Alpha', 'Beta', 'Gamma']) {
      expect(
        tester.getSemantics(_tab(label)).flagsCollection.isSelected,
        Tristate.isFalse,
      );
    }
    await tester.pumpWidget(
      _host(TabStrip(tabs: _abc, selectedId: null, onSelect: (_) {})),
    );
    expect(tester.takeException(), isNull);
  });

  test('resolveSelection keeps, falls back to the first enabled, or null', () {
    expect(TabStrip.resolveSelection(_abc, 'b'), 'b');
    expect(TabStrip.resolveSelection(_abc, 'c'), 'c');
    expect(TabStrip.resolveSelection(_abc, 'gone'), 'a');
    expect(TabStrip.resolveSelection(_abc, null), 'a');
    expect(TabStrip.resolveSelection(const [], 'a'), isNull);
    expect(
      TabStrip.resolveSelection(const [
        TabItem(id: 'z', label: 'Z', enabled: false),
      ], 'a'),
      isNull,
    );
  });

  testWidgets(
    'a disabled tab keeps its place, explains why, requests nothing',
    (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(
        _host(TabStrip(tabs: _abc, selectedId: 'a', onSelect: requests.add)),
      );
      expect(
        tester.getSemantics(_tab('Gamma')),
        matchesSemantics(
          label: 'Gamma',
          hint: 'Save the record first.',
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      await tester.tap(find.text('Gamma'));
      expect(requests, isEmpty);
      // Hovering shows the reason.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Gamma')));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Save the record first.'), findsOneWidget);
      await mouse.removePointer();
      expect(
        tester.getTopLeft(find.text('Gamma')).dx >
            tester.getTopLeft(find.text('Beta')).dx,
        isTrue,
      );
    },
  );

  testWidgets('counts are shown and announced with the label', (tester) async {
    await tester.pumpWidget(
      _host(TabStrip(tabs: _abc, selectedId: 'a', onSelect: (_) {})),
    );
    expect(find.text('2'), findsOneWidget);
    expect(tester.getSemantics(_tab('Beta')).label, 'Beta, 2 to confirm');
  });

  testWidgets('area and subform sizes use their minimum heights', (
    tester,
  ) async {
    Future<void> check(
      TabStripSize size,
      double inactive,
      double active,
    ) async {
      await tester.pumpWidget(
        _host(
          TabStrip(
            size: size,
            tabs: const [
              TabItem(id: 'a', label: 'Alpha'),
              TabItem(id: 'b', label: 'Beta'),
            ],
            selectedId: 'a',
            onSelect: (_) {},
          ),
        ),
      );
      expect(tester.getSize(_tab('Alpha')).height, active);
      expect(tester.getSize(_tab('Beta')).height, inactive);
    }

    await check(TabStripSize.area, 24, 27);
    await check(TabStripSize.subform, 20, 22);
  });

  testWidgets('tabs take no keyboard focus and keys do nothing', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      _host(
        TabStrip(
          tabs: _abc,
          selectedId: 'a',
          onSelect: requests.add,
          trailing: TextButton(onPressed: () {}, child: const Text('Sneaky')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus;
    expect(focus == null || !_isInside(focus), isTrue);
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pump();
    expect(requests, isEmpty);
  });

  testWidgets(
    'a long caption and long tabs at 200% stay visible and tappable',
    (tester) async {
      final requests = <String>[];
      const long = TabItem(
        id: 'long',
        label:
            'An exceptionally long tab label that must wrap within the strip',
      );
      await tester.pumpWidget(
        _host(
          TabStrip(
            tabs: const [
              long,
              TabItem(id: 'b', label: 'Beta'),
            ],
            selectedId: 'b',
            onSelect: requests.add,
            trailing: const Text(
              'A very long caption describing everything about the tabs here',
            ),
          ),
          width: 300,
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final strip = tester.getRect(find.byType(TabStrip));
      for (final finder in [
        find.textContaining('exceptionally'),
        find.textContaining('A very long caption'),
        find.text('Beta'),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(strip.left));
        expect(rect.right, lessThanOrEqualTo(strip.right + 0.01));
        expect(rect.bottom, lessThanOrEqualTo(strip.bottom + 0.01));
      }
      // The oversized label is wrapped, and its semantics carry all of it.
      expect(
        tester.getSize(find.textContaining('exceptionally')).height,
        greaterThan(30),
      );
      expect(tester.getSemantics(_tab('An exceptionally')).label, long.label);
      // The caption is on its own line, above the tabs.
      expect(
        tester.getRect(find.textContaining('A very long caption')).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Beta')).top + 0.01),
      );
      // Every tab is hit-testable.
      await tester.tap(find.text('Beta'), warnIfMissed: true);
      await tester.tap(
        find.textContaining('exceptionally'),
        warnIfMissed: true,
      );
      expect(requests, ['long']);
    },
  );

  testWidgets('a short caption sits on the tab row at the right', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TabStrip(
          tabs: _abc,
          selectedId: 'a',
          onSelect: (_) {},
          trailing: const Text('3 saved'),
        ),
      ),
    );
    final caption = tester.getRect(find.text('3 saved'));
    final tab = tester.getRect(find.text('Alpha'));
    expect((caption.center.dy - tab.center.dy).abs(), lessThan(8));
    expect(
      caption.right,
      greaterThan(tester.getRect(find.text('Gamma')).right),
    );
  });

  testWidgets('the demo: Enabled off refuses a tap on an unselected tab', (
    tester,
  ) async {
    await pumpGalleryDemo(
      tester,
      tabStripDemo,
      knobs: const GalleryKnobs(enabled: false, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    List<String?> selected() => tester
        .widgetList<TabStrip>(find.byType(TabStrip))
        .map((s) => s.selectedId)
        .toList();
    expect(selected(), everyElement('agreements'));
    await tester.tap(find.text('Details').first);
    await tester.pump();
    expect(selected(), everyElement('agreements'));
  });

  testWidgets('the demo: Enabled on, a tap changes the selected tab', (
    tester,
  ) async {
    await pumpGalleryDemo(
      tester,
      tabStripDemo,
      knobs: const GalleryKnobs(textScale: 2),
    );
    expect(
      tester
          .widgetList<TabStrip>(find.byType(TabStrip))
          .map((s) => s.selectedId),
      everyElement('agreements'),
    );
    await tester.tap(find.text('Details').first);
    await tester.pump();
    expect(
      tester
          .widgetList<TabStrip>(find.byType(TabStrip))
          .map((s) => s.selectedId),
      everyElement('details'),
    );
  });
}

bool _isInside(FocusNode node) {
  final context = node.context;
  if (context == null) {
    return false;
  }
  var inside = false;
  context.visitAncestorElements((e) {
    if (e.widget is TabStrip) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}
