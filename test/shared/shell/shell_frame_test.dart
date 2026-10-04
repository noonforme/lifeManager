import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/address_bar.dart';
import 'package:lifeos/shared/shell/shell_dialog.dart';
import 'package:lifeos/shared/shell/shell_frame.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

const _landmarks = [
  'Menu bar',
  'Toolbar',
  'Address',
  'Task pane',
  'Desk workspace',
  'Status line',
];

Future<ShellViewController> _pump(
  WidgetTester tester, {
  required double width,
  double height = 800,
  bool dialogOpen = false,
  double textScale = 1,
  ShellViewController? view,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
  final controller = view ?? ShellViewController();
  await tester.pumpWidget(
    _Harness(view: controller, dialogOpen: dialogOpen, textScale: textScale),
  );
  return controller;
}

void main() {
  testWidgets('the body is the task pane and the content; no property sheet', (
    tester,
  ) async {
    await _pump(tester, width: 1280);
    for (final label in _landmarks) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('Record inspector'), findsNothing);
    expect(find.text('Desk content'), findsOneWidget);
    expect(find.text('Back to list'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    final desk = tester.getSize(find.bySemanticsLabel('Desk workspace'));
    expect(desk.width, 1280 - ShellMetrics.taskPaneWidth);
  });

  testWidgets('a dialog opens over the desk, which keeps its draft', (
    tester,
  ) async {
    await _pump(tester, width: 1100);
    await tester.enterText(find.byType(TextField), 'kept draft');

    await tester.tap(find.text('Open record'));
    await tester.pump();
    expect(find.text('New pay period'), findsOneWidget);
    expect(find.text('Dialog content'), findsOneWidget);
    expect(find.text('Desk content'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close New pay period'));
    await tester.pump();
    expect(find.text('Dialog content'), findsNothing);
    expect(find.text('kept draft'), findsOneWidget);
  });

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

  testWidgets('widening past 1024 docks the task pane and drops the overlay', (
    tester,
  ) async {
    final view = await _pump(tester, width: 960, height: 760);
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Tree content'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      _Harness(view: view, dialogOpen: false, textScale: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Close tasks'), findsNothing);
    expect(find.text('Tasks'), findsNothing);
    expect(find.text('Tree content'), findsOneWidget);
    expect(find.text('Desk content'), findsOneWidget);
    tester.view.physicalSize = const Size(960, 760);
    await tester.pumpWidget(
      _Harness(view: view, dialogOpen: false, textScale: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Tree content'), findsNothing);
    expect(find.text('Desk content'), findsOneWidget);
  });

  testWidgets('menu and status bars grow with 200 % text', (tester) async {
    await _pump(tester, width: 1280, textScale: 2);
    for (final (bar, content) in [
      ('Menu bar', 'Menu content'),
      ('Status line', 'Status content'),
    ]) {
      // A squeezed Text reports its clipped size; ask for the height it
      // needs instead.
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(content),
      );
      expect(
        tester.getSize(find.bySemanticsLabel(bar)).height,
        greaterThanOrEqualTo(
          paragraph.getMinIntrinsicHeight(paragraph.size.width),
        ),
        reason: bar,
      );
    }
  });

  testWidgets('choosing a task closes the Tasks overlay', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(960, 760);
    addTearDown(tester.view.reset);
    var done = 0;
    await tester.pumpWidget(
      _Harness(
        view: ShellViewController(),
        dialogOpen: false,
        textScale: 1,
        onTask: () => done++,
      ),
    );
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Do thing'));
    await tester.pumpAndSettle();
    expect(done, 1);
    expect(find.text('Do thing'), findsNothing);
    expect(find.text('Tasks'), findsOneWidget);
  });

  for (final width in [1280.0, 1100.0, 960.0, 800.0]) {
    testWidgets('no overflow at $width wide and 200% text', (tester) async {
      await _pump(tester, width: width, textScale: 2);
      expect(tester.takeException(), isNull);
      await _pump(tester, width: width, dialogOpen: true);
      expect(tester.takeException(), isNull);
    });
  }
}

final class _Harness extends StatefulWidget {
  const _Harness({
    required this.view,
    required this.dialogOpen,
    required this.textScale,
    this.onTask,
  });

  final ShellViewController view;
  final bool dialogOpen;
  final double textScale;

  /// When set, the frame shows a task group with one link, "Do thing".
  final VoidCallback? onTask;

  @override
  State<_Harness> createState() => _HarnessState();
}

final class _HarnessState extends State<_Harness> {
  late bool _dialogOpen = widget.dialogOpen;

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
                  dialog: _dialogOpen
                      ? ShellDialog(
                          title: 'New pay period',
                          onClose: () => setState(() => _dialogOpen = false),
                          child: const Text('Dialog content'),
                        )
                      : null,
                  desk: Column(
                    children: [
                      const Text('Desk content'),
                      const SizedBox(width: 200, child: TextField()),
                      TextButton(
                        onPressed: () => setState(() => _dialogOpen = true),
                        child: const Text('Open record'),
                      ),
                    ],
                  ),
                  tasks: [
                    if (widget.onTask case final onTask?)
                      TaskGroup(
                        title: 'Test tasks',
                        special: true,
                        child: TaskLink(label: 'Do thing', onPressed: onTask),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
