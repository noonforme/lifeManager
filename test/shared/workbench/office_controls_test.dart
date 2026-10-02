import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

Widget _host(
  Widget child, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  LifeOSAppearance appearance = LifeOSAppearance.system,
}) {
  return MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      platformBrightness: brightness,
      highContrast: highContrast,
    ),
    child: MaterialApp(
      home: LifeOSSkinScope(
        appearance: appearance,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

BoxDecoration _faceDecoration(WidgetTester tester) =>
    tester.widget<Container>(find.byKey(const ValueKey('key-face'))).decoration!
        as BoxDecoration;

void main() {
  group('KeyButton', () {
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

    testWidgets('pressing narrows the bottom edge and lowers the face', (
      tester,
    ) async {
      await tester.pumpWidget(_host(KeyButton(label: 'Add', onPressed: () {})));
      Container edge() =>
          tester.widget<Container>(find.byKey(const ValueKey('key-edge')));
      final restingHeight = tester.getSize(find.byType(KeyButton)).height;
      expect(edge().padding, const EdgeInsets.only(bottom: 2));
      expect(edge().margin, EdgeInsets.zero);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Add')),
      );
      await tester.pump();
      expect(edge().padding, const EdgeInsets.only(bottom: 1));
      expect(edge().margin, const EdgeInsets.only(top: 1));
      expect(tester.getSize(find.byType(KeyButton)).height, restingHeight);

      await gesture.up();
      await tester.pump();
      expect(edge().padding, const EdgeInsets.only(bottom: 2));
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

    testWidgets('primary keys use the action fill and ink', (tester) async {
      await tester.pumpWidget(
        _host(
          KeyButton(label: '+ Add', kind: KeyKind.primary, onPressed: () {}),
        ),
      );
      expect(_faceDecoration(tester).color, LifeOSTokens.day.actionFill);
      final text = tester.widget<Text>(find.text('+ Add'));
      expect(text.style!.color, LifeOSTokens.day.actionInk);
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
    expect(history.style!.color, LifeOSTokens.day.headInk);
    // Selection is a filled segment, never the focus ring.
    expect(find.byKey(const ValueKey('focus-ring')), findsNothing);
    semantics.dispose();
  });

  group('LifeOSSkinScope', () {
    Future<LifeOSTokens> resolve(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      bool highContrast = false,
      LifeOSAppearance appearance = LifeOSAppearance.system,
    }) async {
      late LifeOSTokens tokens;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              tokens = LifeOSSkinScope.of(context).tokens;
              return const SizedBox();
            },
          ),
          brightness: brightness,
          highContrast: highContrast,
          appearance: appearance,
        ),
      );
      return tokens;
    }

    testWidgets('system appearance follows the platform', (tester) async {
      expect(await resolve(tester), LifeOSTokens.day);
      expect(
        await resolve(tester, brightness: Brightness.dark),
        LifeOSTokens.night,
      );
      expect(
        await resolve(tester, highContrast: true),
        LifeOSTokens.highContrast,
      );
    });

    testWidgets('a pinned appearance overrides the platform brightness', (
      tester,
    ) async {
      expect(
        await resolve(
          tester,
          brightness: Brightness.dark,
          appearance: LifeOSAppearance.day,
        ),
        LifeOSTokens.day,
      );
      expect(
        await resolve(tester, appearance: LifeOSAppearance.night),
        LifeOSTokens.night,
      );
      expect(
        await resolve(tester, appearance: LifeOSAppearance.highContrast),
        LifeOSTokens.highContrast,
      );
    });

    testWidgets('the platform high-contrast setting wins over day or night', (
      tester,
    ) async {
      expect(
        await resolve(
          tester,
          highContrast: true,
          appearance: LifeOSAppearance.night,
        ),
        LifeOSTokens.highContrast,
      );
    });
  });
}
