import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/era_window_frame.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

import '../../support/fake_window_controls.dart';

Future<FakeWindowControls> _pump(WidgetTester tester, {String? title}) async {
  final controls = FakeWindowControls();
  final titles = WindowTitleController()..value = title;
  addTearDown(titles.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: LifeOSSkinScope(
        child: EraWindowFrame(
          controls: controls,
          title: titles,
          child: const ColoredBox(color: Color(0xffece9d8)),
        ),
      ),
    ),
  );
  return controls;
}

void main() {
  testWidgets('the caption names the location and the app', (tester) async {
    final controls = await _pump(tester, title: 'Shifts');
    expect(find.text('Shifts - LifeOS'), findsOneWidget);
    await tester.pump();
    expect(controls.calls, contains('title Shifts - LifeOS'));
  });

  testWidgets('caption keys minimize, maximize and close', (tester) async {
    final controls = await _pump(tester);
    expect(find.text('LifeOS'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Minimize'));
    await tester.tap(find.bySemanticsLabel('Maximize'));
    await tester.tap(find.bySemanticsLabel('Close'));
    expect(
      controls.calls,
      containsAllInOrder(['minimize', 'toggleMaximize', 'close']),
    );
  });

  testWidgets('dragging the caption moves; double-clicking maximizes', (
    tester,
  ) async {
    final controls = await _pump(tester);
    await tester.drag(find.text('LifeOS'), const Offset(40, 0));
    expect(controls.calls, contains('drag'));
    await tester.tap(find.text('LifeOS'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('LifeOS'));
    await tester.pumpAndSettle();
    expect(controls.calls, contains('toggleMaximize'));
  });

  testWidgets('maximized: Restore, no border, no resize edges', (tester) async {
    final controls = await _pump(tester);
    expect(
      find.byKey(const ValueKey('window-edge-bottomRight')),
      findsOneWidget,
    );
    controls.frame = const WindowFrameState(maximized: true);
    await tester.pump();
    expect(find.bySemanticsLabel('Restore'), findsOneWidget);
    expect(find.byKey(const ValueKey('window-edge-bottomRight')), findsNothing);
  });

  testWidgets('a border edge starts a resize from that edge', (tester) async {
    final controls = await _pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('window-edge-right')),
      const Offset(20, 0),
    );
    expect(controls.calls, contains('resize WindowEdge.right'));
  });
}
