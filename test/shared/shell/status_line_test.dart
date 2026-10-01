import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/status_line.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

Future<void> _pump(WidgetTester tester, StatusSnapshot snapshot) =>
    tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(body: StatusLine(snapshot: snapshot)),
        ),
      ),
    );

void main() {
  testWidgets('shows only the local database when nothing is running', (
    tester,
  ) async {
    await _pump(tester, const StatusSnapshot());
    expect(find.text('Local database'), findsOneWidget);
    expect(find.textContaining('Shift running'), findsNothing);
  });

  testWidgets('a running shift opens from its segment', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      StatusSnapshot(
        runningShift: RunningShiftStatus(
          label: 'Shift running since 07:02',
          onOpen: () => opened++,
        ),
      ),
    );
    await tester.tap(find.text('Shift running since 07:02'));
    expect(opened, 1);
  });

  testWidgets('reports the last save and an uncertain save', (tester) async {
    await _pump(tester, const StatusSnapshot(lastSave: '13:48'));
    expect(find.text('Local database · saved 13:48'), findsOneWidget);

    await _pump(
      tester,
      const StatusSnapshot(lastSave: '13:48', lastSaveUncertain: true),
    );
    expect(find.text('Last save uncertain. Reload to check'), findsOneWidget);
  });

  testWidgets('counts appear only when non-zero', (tester) async {
    await _pump(tester, const StatusSnapshot(needsYou: 3, openDrafts: 1));
    expect(find.text('Needs you: 3'), findsOneWidget);
    expect(find.text('1 draft'), findsOneWidget);

    await _pump(tester, const StatusSnapshot());
    expect(find.textContaining('Needs you'), findsNothing);
    expect(find.textContaining('draft'), findsNothing);
  });
}
