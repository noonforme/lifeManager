import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/shell_frame.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

const _landmarks = [
  'Menu bar',
  'Toolbar',
  'Formula bar',
  'Books',
  'Desk workspace',
  'Record inspector',
  'Status line',
];

Future<ShellViewController> _pump(
  WidgetTester tester, {
  required double width,
  double height = 800,
  bool inspectorOpen = false,
  double textScale = 1,
  ShellViewController? view,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final controller = view ?? ShellViewController();
  await tester.pumpWidget(
    _Harness(
      view: controller,
      inspectorOpen: inspectorOpen,
      textScale: textScale,
    ),
  );
  return controller;
}

void main() {
  testWidgets('full width shows every landmark side by side', (tester) async {
    await _pump(tester, width: 1280);
    for (final label in _landmarks) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(find.text('Desk content'), findsOneWidget);
    expect(find.text('Inspector content'), findsOneWidget);
    expect(find.text('Back to desk'), findsNothing);
    expect(find.text('Books'), findsNothing);
  });

  testWidgets(
    'below full width an open record replaces the desk and keeps its draft',
    (tester) async {
      await _pump(tester, width: 1100);
      await tester.enterText(find.byType(TextField), 'kept draft');

      await tester.tap(find.text('Open record'));
      await tester.pump();
      expect(find.text('Inspector content'), findsOneWidget);
      expect(find.text('Back to desk'), findsOneWidget);
      expect(find.text('Desk content'), findsNothing);

      await tester.tap(find.text('Back to desk'));
      await tester.pump();
      expect(find.text('Desk content'), findsOneWidget);
      expect(find.text('kept draft'), findsOneWidget);
    },
  );

  testWidgets('narrow windows fold the tree into Books', (tester) async {
    await _pump(tester, width: 960);
    expect(find.text('Tree content'), findsNothing);
    expect(find.bySemanticsLabel('Books'), findsWidgets);

    await tester.tap(find.text('Books'));
    await tester.pump();
    expect(find.text('Tree content'), findsOneWidget);

    // Opening a node returns to the desk.
    await tester.tap(find.text('Tree content'));
    await tester.pump();
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Desk content'), findsOneWidget);
  });

  testWidgets('hiding the tree keeps navigation behind Books', (tester) async {
    final view = await _pump(tester, width: 1280);
    view.value = view.value.copyWith(showTree: false);
    await tester.pump();
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Books'), findsOneWidget);
  });

  testWidgets('hiding the inspector makes records alternate with the desk', (
    tester,
  ) async {
    final view = await _pump(tester, width: 1280);
    view.value = view.value.copyWith(showInspector: false);
    await tester.pump();
    expect(find.text('Inspector content'), findsNothing);

    await tester.tap(find.text('Open record'));
    await tester.pump();
    expect(find.text('Inspector content'), findsOneWidget);
    expect(find.text('Back to desk'), findsOneWidget);
  });

  testWidgets('the formula bar can be hidden', (tester) async {
    final view = await _pump(tester, width: 1280);
    view.value = view.value.copyWith(showFormulaBar: false);
    await tester.pump();
    expect(find.bySemanticsLabel('Formula bar'), findsNothing);
  });

  for (final width in [1280.0, 1100.0, 960.0, 800.0]) {
    testWidgets('no overflow at $width wide and 200% text', (tester) async {
      await _pump(tester, width: width, textScale: 2);
      expect(tester.takeException(), isNull);
      await _pump(tester, width: width, inspectorOpen: true);
      expect(tester.takeException(), isNull);
    });
  }
}

final class _Harness extends StatefulWidget {
  const _Harness({
    required this.view,
    required this.inspectorOpen,
    required this.textScale,
  });

  final ShellViewController view;
  final bool inspectorOpen;
  final double textScale;

  @override
  State<_Harness> createState() => _HarnessState();
}

final class _HarnessState extends State<_Harness> {
  late bool _inspectorOpen = widget.inspectorOpen;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(
        size: View.of(context).physicalSize,
        textScaler: TextScaler.linear(widget.textScale),
      ),
      child: MaterialApp(
        home: LifeOSSkinScope(
          child: ShellViewScope(
            controller: widget.view,
            child: Scaffold(
              body: ShellChrome(
                menuBar: const Text('Menu content'),
                tree: (onOpened) => GestureDetector(
                  onTap: onOpened,
                  child: const Text('Tree content'),
                ),
                status: const Text('Status content'),
                title: 'Work',
                child: ShellFrame(
                  inspectorOpen: _inspectorOpen,
                  onBackToDesk: () => setState(() => _inspectorOpen = false),
                  desk: Column(
                    children: [
                      const Text('Desk content'),
                      const SizedBox(width: 200, child: TextField()),
                      TextButton(
                        onPressed: () => setState(() => _inspectorOpen = true),
                        child: const Text('Open record'),
                      ),
                    ],
                  ),
                  inspector: const Text('Inspector content'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
