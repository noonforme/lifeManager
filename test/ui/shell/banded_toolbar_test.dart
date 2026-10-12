import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/banded_toolbar_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

/// Counts every command the long toolbar below can issue.
final class _Taps {
  final counts = <String, int>{};
  VoidCallback? call(String name) =>
      () => counts[name] = (counts[name] ?? 0) + 1;
  int of(String name) => counts[name] ?? 0;
  int get total => counts.values.fold(0, (a, b) => a + b);
}

BandedToolbar _long(_Taps taps, TextEditingController findBox) => BandedToolbar(
  bands: [
    ToolbarBand(
      items: [
        ToolbarItem(
          label: 'Tree',
          icon: EraIconKind.work,
          onPressed: taps.call('Tree'),
        ),
        ToolbarItem(
          label: 'Back',
          iconOnly: true,
          onPressed: taps.call('Back'),
        ),
      ],
    ),
    ToolbarBand(
      items: [
        ToolbarItem(label: 'Add', dropArrow: true, onPressed: taps.call('Add')),
      ],
    ),
    ToolbarBand(
      items: [
        ToolbarItem(
          label: 'Save',
          icon: EraIconKind.saveView,
          tooltip: 'Save the pending changes',
          onPressed: taps.call('Save'),
        ),
        ToolbarItem(label: 'Undo', onPressed: taps.call('Undo')),
        ToolbarItem(label: 'Delete', onPressed: null),
      ],
    ),
    ToolbarBand(
      items: [
        for (final label in [
          'Confirm all worked days of the pay period…',
          'Mark as leave…',
          'Correct the recorded shift…',
          'Filter by selection',
          'Remove filter',
          'Sort by start time',
        ])
          ToolbarItem(label: label, onPressed: taps.call(label)),
      ],
    ),
  ],
  trailing: EraField(controller: findBox, label: 'Find', semanticLabel: 'Find'),
);

Widget _host(Widget child, {double textScale = 1, bool enabled = true}) =>
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: LifeOSSkinScope(
          child: EraFormScope(
            labelWidth: 40,
            enabled: enabled,
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      ),
    );

/// The decoration of the key face that holds [label].
BoxDecoration _face(WidgetTester tester, String label) =>
    tester
            .widget<Container>(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byKey(const ValueKey('key-face')),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late TextEditingController findBox;
  setUp(() => findBox = TextEditingController());
  tearDown(() => findBox.dispose());

  testWidgets('an enabled key runs its command; a disabled one does nothing', (
    tester,
  ) async {
    final taps = _Taps();
    await _size(tester, const Size(800, 600));
    await tester.pumpWidget(_host(_long(taps, findBox)));
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Undo'));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(taps.of('Save'), 1);
    expect(taps.of('Undo'), 1);
    expect(taps.counts.keys, isNot(contains('Delete')));
    expect(
      tester.getSemantics(find.text('Delete')),
      matchesSemantics(
        label: 'Delete',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
  });

  testWidgets('an icon-only key keeps its label as semantics and tooltip', (
    tester,
  ) async {
    final taps = _Taps();
    await tester.pumpWidget(_host(_long(taps, findBox)));
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.bySemanticsLabel('Back')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Back'), findsOneWidget, reason: 'tooltip shows label');
    await mouse.moveTo(tester.getCenter(find.text('Save')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Save the pending changes'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('hover raises an enabled key; a disabled key stays flat', (
    tester,
  ) async {
    // Desktop highlight mode, as with a mouse attached.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    final taps = _Taps();
    await tester.pumpWidget(_host(_long(taps, findBox)));
    BoxDecoration face(String label) => _face(tester, label);
    expect(face('Save').gradient, isNull);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Save')));
    await tester.pump();
    expect(face('Save').gradient, isNotNull);
    await mouse.moveTo(tester.getCenter(find.text('Delete')));
    await tester.pump();
    expect(face('Delete').gradient, isNull);
    expect(face('Save').gradient, isNull);
    await mouse.removePointer();
  });

  testWidgets('pressing paints the key; moving off and releasing cancels', (
    tester,
  ) async {
    final taps = _Taps();
    await tester.pumpWidget(_host(_long(taps, findBox)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Save')));
    await mouse.down(tester.getCenter(find.text('Save')));
    await tester.pump();
    final pressed = _face(tester, 'Save').gradient! as LinearGradient;
    expect(pressed.colors.first, isNot(LifeOSTokens.millennium.paper));
    await mouse.moveTo(const Offset(700, 500));
    await mouse.up();
    await tester.pump();
    expect(taps.of('Save'), 0, reason: 'released off the key');
    await mouse.removePointer();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'the full long toolbar and Find fit at 800x600, ${scale * 100}%',
      (tester) async {
        final taps = _Taps();
        await _size(tester, const Size(800, 600));
        await tester.pumpWidget(_host(_long(taps, findBox), textScale: scale));
        expect(tester.takeException(), isNull);
        final bar = tester.getRect(find.byType(BandedToolbar));
        expect(bar.width, 800);
        expect(bar.height, lessThan(600), reason: 'leaves room for the page');
        // Every key and the Find box lie inside the bar.
        for (final key in find.byKey(const ValueKey('key-face')).evaluate()) {
          final rect = tester.getRect(find.byElementPredicate((e) => e == key));
          expect(bar.contains(rect.topLeft), isTrue);
          expect(rect.right, lessThanOrEqualTo(bar.right + 0.01));
          expect(rect.bottom, lessThanOrEqualTo(bar.bottom + 0.01));
        }
        expect(
          tester.getRect(find.byType(EraField)).right,
          lessThanOrEqualTo(800),
        );
        // Save and Undo are reachable by the mouse, and Find takes text.
        await tester.tap(find.text('Save'));
        await tester.tap(find.text('Undo'));
        await tester.enterText(find.byType(TextField), 'shift');
        await tester.pump();
        expect(taps.of('Save'), 1);
        expect(taps.of('Undo'), 1);
        expect(find.text('shift'), findsOneWidget);
      },
    );
  }

  testWidgets('one oversized band wraps within itself', (tester) async {
    final taps = _Taps();
    await _size(tester, const Size(320, 600));
    await tester.pumpWidget(
      _host(
        BandedToolbar(
          bands: [
            ToolbarBand(
              items: [
                for (var i = 0; i < 10; i++)
                  ToolbarItem(
                    label: 'Command number $i',
                    onPressed: taps.call('$i'),
                  ),
              ],
            ),
          ],
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(BandedToolbar));
    expect(bar.height, greaterThan(38 * 3), reason: 'wrapped into rows');
    await tester.tap(find.text('Command number 9'));
    expect(taps.of('9'), 1);
  });

  testWidgets('one key wider than the toolbar is cut to it, not overflowed', (
    tester,
  ) async {
    await _size(tester, const Size(200, 400));
    await tester.pumpWidget(
      _host(
        BandedToolbar(
          bands: [
            ToolbarBand(
              items: [ToolbarItem(label: 'A' * 80, onPressed: () {})],
            ),
          ],
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const ValueKey('key-face'))).right,
      lessThanOrEqualTo(200),
    );
  });

  testWidgets('the trailing slot is bounded to its width, and to the bar', (
    tester,
  ) async {
    await _size(tester, const Size(800, 600));
    await tester.pumpWidget(
      _host(
        const BandedToolbar(
          bands: [],
          trailing: SizedBox(key: ValueKey('slot'), width: 5000, height: 20),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('slot'))).width, 200);
    await _size(tester, const Size(120, 600));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('slot'))).width,
      lessThanOrEqualTo(120),
    );
  });

  testWidgets('no key operates a toolbar command; Find stays an editor', (
    tester,
  ) async {
    final taps = _Taps();
    await _size(tester, const Size(800, 600));
    await tester.pumpWidget(_host(_long(taps, findBox)));
    for (final key in [
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(taps.total, 0);
    // Tab reached only the Find editor, never a key.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EraField>(),
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps.total, 0);
  });

  testWidgets('a disabled form scope greys Find; keys follow their own state', (
    tester,
  ) async {
    final taps = _Taps();
    await tester.pumpWidget(_host(_long(taps, findBox), enabled: false));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.tap(find.text('Save'));
    expect(taps.of('Save'), 1);
  });

  testWidgets('a caller-supplied Tree item is an ordinary key', (tester) async {
    final taps = _Taps();
    await tester.pumpWidget(_host(_long(taps, findBox)));
    await tester.tap(find.text('Tree'));
    expect(taps.of('Tree'), 1);
  });

  testWidgets('the demo: Enabled off greys every key and Find', (tester) async {
    await pumpGalleryDemo(
      tester,
      bandedToolbarDemo,
      knobs: const GalleryKnobs(enabled: false, longText: true, textScale: 2),
    );
    expect(tester.takeException(), isNull);
    final keys = tester.widgetList<KeyButton>(find.byType(KeyButton));
    expect(keys, isNotEmpty);
    expect(keys.map((key) => key.onPressed), everyElement(isNull));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await pumpGalleryDemo(tester, bandedToolbarDemo);
    expect(
      tester
          .widgetList<KeyButton>(find.byType(KeyButton))
          .any((key) => key.onPressed != null),
      isTrue,
    );
  });
}
