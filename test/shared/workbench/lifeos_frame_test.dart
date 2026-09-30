import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/inspector_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_frame.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> pumpFrame(
    WidgetTester tester, {
    required double width,
    required double height,
    bool inspectorIsActive = false,
    double textScale = 1,
    bool disableAnimations = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _TestFrame(
        width: width,
        height: height,
        inspectorIsActive: inspectorIsActive,
        textScale: textScale,
        disableAnimations: disableAnimations,
      ),
    );
  }

  testWidgets('wide frame exposes rail register and inspector landmarks', (
    tester,
  ) async {
    await pumpFrame(tester, width: 1280, height: 760);

    expect(find.bySemanticsLabel('System navigation'), findsOneWidget);
    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
    expect(find.bySemanticsLabel('Record inspector'), findsOneWidget);
    expect(find.text('Back to register'), findsNothing);
  });

  testWidgets(
    'constrained frame keeps selection and provides Back to register',
    (tester) async {
      await pumpFrame(tester, width: 960, height: 760, inspectorIsActive: true);

      expect(find.bySemanticsLabel('Record inspector'), findsOneWidget);
      expect(find.text('Back to register'), findsOneWidget);
      await tester.tap(find.text('Back to register'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Work register'), findsOneWidget);
    },
  );

  testWidgets('two-times text scale keeps constrained return flow reachable', (
    tester,
  ) async {
    await pumpFrame(
      tester,
      width: 960,
      height: 760,
      inspectorIsActive: true,
      textScale: 2,
    );

    expect(find.text('Back to register'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion removes workbench transition duration', (
    tester,
  ) async {
    await pumpFrame(tester, width: 1280, height: 760, disableAnimations: true);

    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });
}

final class _TestFrame extends StatefulWidget {
  const _TestFrame({
    required this.width,
    required this.height,
    this.inspectorIsActive = false,
    this.textScale = 1,
    this.disableAnimations = false,
  });

  final double width;
  final double height;
  final bool inspectorIsActive;
  final double textScale;
  final bool disableAnimations;

  @override
  State<_TestFrame> createState() => _TestFrameState();
}

final class _TestFrameState extends State<_TestFrame> {
  late bool inspectorIsActive = widget.inspectorIsActive;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(widget.width, widget.height),
          textScaler: TextScaler.linear(widget.textScale),
          disableAnimations: widget.disableAnimations,
        ),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: LifeOSFrame(
            rail: const Text('Rail'),
            register: const Text('Register'),
            inspector: const InspectorPane(child: Text('Inspector')),
            inspectorIsActive: inspectorIsActive,
            onBackToRegister: () => setState(() => inspectorIsActive = false),
          ),
        ),
      ),
    );
  }
}
