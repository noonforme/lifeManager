import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/address_bar.dart';
import 'package:lifeos/shared/shell/shell_frame.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

const _landmarks = [
  'Menu bar',
  'Toolbar',
  'Address',
  'Formula bar',
  'Task pane',
  'Desk workspace',
  'Record inspector',
  'Status line',
];

Future<ShellViewController> _pump(
  WidgetTester tester, {
  required double width,
  double height = 800,
  bool inspectorOpen = false,
  bool hasInspector = true,
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
      hasInspector: hasInspector,
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
    expect(find.text('Back to list'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
  });

  testWidgets(
    'below full width an open record replaces the desk and keeps its draft',
    (tester) async {
      await _pump(tester, width: 1100);
      await tester.enterText(find.byType(TextField), 'kept draft');

      await tester.tap(find.text('Open record'));
      await tester.pump();
      expect(find.text('Inspector content'), findsOneWidget);
      expect(find.text('Back to list'), findsOneWidget);
      expect(find.text('Desk content'), findsNothing);

      await tester.tap(find.text('Back to list'));
      await tester.pump();
      expect(find.text('Desk content'), findsOneWidget);
      expect(find.text('kept draft'), findsOneWidget);
    },
  );

  testWidgets('narrow windows fold the task pane into Tasks', (tester) async {
    await _pump(tester, width: 960);
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Tasks'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pump();
    expect(find.text('Tree content'), findsOneWidget);

    // Opening a node returns to the desk.
    await tester.tap(find.text('Tree content'));
    await tester.pump();
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Desk content'), findsOneWidget);
  });

  testWidgets('hiding the task pane keeps navigation behind Tasks', (
    tester,
  ) async {
    final view = await _pump(tester, width: 1280);
    view.value = view.value.copyWith(showTaskPane: false);
    await tester.pump();
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Tasks'), findsOneWidget);
  });

  testWidgets('hiding the inspector makes records alternate with the desk', (
    tester,
  ) async {
    final view = await _pump(tester, width: 1280);
    view.value = view.value.copyWith(showPropertySheet: false);
    await tester.pump();
    expect(find.text('Inspector content'), findsNothing);

    await tester.tap(find.text('Open record'));
    await tester.pump();
    expect(find.text('Inspector content'), findsOneWidget);
    expect(find.text('Back to list'), findsOneWidget);
  });

  testWidgets('a surface without an inspector gives the desk the width', (
    tester,
  ) async {
    await _pump(tester, width: 1280, hasInspector: false);
    expect(find.bySemanticsLabel('Record inspector'), findsNothing);
    final desk = tester.getSize(find.bySemanticsLabel('Desk workspace'));
    expect(desk.width, greaterThan(1280 - 320));
  });

  testWidgets('widening past 1024 docks the task pane and drops the overlay', (
    tester,
  ) async {
    final view = await _pump(tester, width: 960, height: 760);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Tree content'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      _Harness(
        view: view,
        inspectorOpen: false,
        hasInspector: true,
        textScale: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Close tasks'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    expect(find.text('Tree content'), findsOneWidget);
    expect(find.text('Desk content'), findsOneWidget);
    tester.view.physicalSize = const Size(960, 760);
    await tester.pumpWidget(
      _Harness(
        view: view,
        inspectorOpen: false,
        hasInspector: true,
        textScale: 1,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Desk content'), findsOneWidget);
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
    required this.hasInspector,
    required this.textScale,
  });

  final ShellViewController view;
  final bool inspectorOpen;
  final bool hasInspector;
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
                crumbs: const [AddressCrumb('Work', '/work')],
                onNavigate: (_) {},
                child: ShellFrame(
                  inspectorOpen: _inspectorOpen,
                  onBackToList: () => setState(() => _inspectorOpen = false),
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
                  inspector: widget.hasInspector
                      ? const Text('Inspector content')
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
