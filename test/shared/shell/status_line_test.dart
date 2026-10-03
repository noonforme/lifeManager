import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  testWidgets('shows only the local database when nothing is waiting', (
    tester,
  ) async {
    await _pump(tester, const StatusSnapshot());
    expect(find.text('Local database'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-panel')), findsOneWidget);
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

  testWidgets('every fact sits in its own sunken panel at 22 px', (
    tester,
  ) async {
    await _pump(tester, const StatusSnapshot(needsYou: 1, openDrafts: 2));
    expect(tester.getSize(find.byType(StatusLine)).height, 22);
    expect(find.text('Needs you: 1'), findsOneWidget);
    expect(find.text('2 drafts'), findsOneWidget);
    expect(find.text('Local database'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-panel')), findsNWidgets(3));
  });

  testWidgets('the status bar grows with 200 % text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: LifeOSSkinScope(
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: StatusLine(snapshot: StatusSnapshot()),
              ),
            ),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Local database'),
    );
    expect(
      tester.getSize(find.byType(StatusLine)).height,
      greaterThanOrEqualTo(
        paragraph.getMinIntrinsicHeight(paragraph.size.width) + 4,
      ),
    );
  });
}
