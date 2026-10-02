import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

Widget _host(Widget child, {double textScale = 1}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: LifeOSSkinScope(
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('KeyButton', () {
    testWidgets('pressing changes the face but never the size', (tester) async {
      await tester.pumpWidget(
        _host(KeyButton(label: 'Save', onPressed: () {})),
      );
      final before = tester.getSize(find.byKey(const ValueKey('key-face')));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Save')),
      );
      await tester.pump();
      expect(tester.getSize(find.byKey(const ValueKey('key-face'))), before);
      await gesture.up();
    });

    testWidgets('push buttons are at least 24 high and 24 wide', (
      tester,
    ) async {
      await tester.pumpWidget(_host(KeyButton(label: 'x', onPressed: () {})));
      final size = tester.getSize(find.byKey(const ValueKey('key-face')));
      expect(size.height, greaterThanOrEqualTo(24));
      expect(size.width, greaterThanOrEqualTo(24));
    });

    testWidgets('the default key carries the blue double ring', (tester) async {
      await tester.pumpWidget(
        _host(
          KeyButton(label: 'Save', kind: KeyKind.primary, onPressed: () {}),
        ),
      );
      final face = tester.widget<Container>(
        find.byKey(const ValueKey('key-face')),
      );
      expect(
        face.foregroundDecoration,
        const InsetRings(
          MillenniumColors.defaultRingOuter,
          MillenniumColors.defaultRingInner,
        ),
      );
    });

    testWidgets('a toolbar key is flat until hovered', (tester) async {
      // Desktop highlight mode, as with a mouse attached.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await tester.pumpWidget(
        _host(
          KeyButton(label: 'Back', kind: KeyKind.toolbar, onPressed: () {}),
        ),
      );
      BoxDecoration face() =>
          tester
                  .widget<Container>(find.byKey(const ValueKey('key-face')))
                  .decoration!
              as BoxDecoration;
      expect(face().gradient, isNull);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Back')));
      await tester.pump();
      expect(face().gradient, isNotNull);
      await mouse.removePointer();
    });
    testWidgets('pointer press calls the action', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(KeyButton(label: 'Start shift', onPressed: () => pressed++)),
      );
      await tester.tap(find.text('Start shift'));
      expect(pressed, 1);
    });

    testWidgets('a disabled key ignores presses and says so', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const KeyButton(label: 'Start shift', onPressed: null)),
      );
      await tester.tap(find.text('Start shift'), warnIfMissed: false);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Start shift')),
        matchesSemantics(
          label: 'Start shift',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isFocusable: false,
        ),
      );
      semantics.dispose();
    });

    testWidgets('keyboard focus shows a ring and Enter activates', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      var pressed = 0;
      await tester.pumpWidget(
        _host(KeyButton(label: 'Finalize shift', onPressed: () => pressed++)),
      );
      expect(find.byKey(const ValueKey('focus-ring')), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.byKey(const ValueKey('focus-ring')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('200% text scale in a narrow slot does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 120,
            child: KeyButton(label: 'Record payslip', onPressed: () {}),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Record payslip'), findsOneWidget);
    });
  });

  testWidgets('area keys are announced by their area name', (tester) async {
    await tester.pumpWidget(
      _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final area in LifeOSArea.values) AreaKey(area: area)],
        ),
      ),
    );
    for (final area in LifeOSArea.values) {
      expect(find.bySemanticsLabel(area.label), findsOneWidget);
      expect(find.text(area.letter), findsOneWidget);
    }
  });

  testWidgets('count badges announce what they count', (tester) async {
    await tester.pumpWidget(
      _host(const CountBadge(count: 3, semanticLabel: 'due to confirm')),
    );
    expect(find.bySemanticsLabel('3 due to confirm'), findsOneWidget);
  });

  testWidgets('segmented tabs mark the selected segment and switch', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selected = 0;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => SizedBox(
            width: 240,
            child: SegmentedTabs(
              labels: const ['Record', 'History'],
              selectedIndex: selected,
              onSelected: (index) => setState(() => selected = index),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Record')),
      matchesSemantics(
        label: 'Record',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.text('History'));
    await tester.pump();
    expect(selected, 1);
    final history = tester.widget<Text>(find.text('History'));
    expect(history.style!.color, LifeOSTokens.millennium.ink);
    // Selection is a filled segment, never the focus ring.
    expect(find.byKey(const ValueKey('focus-ring')), findsNothing);
    semantics.dispose();
  });
}
