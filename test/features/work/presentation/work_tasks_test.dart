import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';

import '../../../support/synthetic_shell.dart';

Finder _group(String title) => find.widgetWithText(TaskGroup, title);
Finder _link(String label) => find.widgetWithText(TaskLink, label);
Finder _inDetails(Finder finder) => find.descendant(
  of: find.widgetWithText(TaskGroup, 'Details'),
  matching: finder,
);

void main() {
  testWidgets('nothing selected: Work tasks with the employment links', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    expect(_group('Work tasks'), findsOneWidget);
    expect(_link('Add a shift'), findsOneWidget);
    expect(_link('Employment properties'), findsOneWidget);
    expect(_link('Properties'), findsNothing);
    expect(_link('Set up pay agreement…'), findsNothing);
  });

  testWidgets('a finalized shift selected: Shift tasks', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(_group('Shift tasks'), findsOneWidget);
    expect(_group('Work tasks'), findsNothing);
    expect(_link('Correct this shift…'), findsOneWidget);
    expect(_link('Finalize this shift'), findsNothing);
    await tester.tap(_link('Properties'));
    await tester.pumpAndSettle();
    expect(find.text('Shift 2026-09-08 Properties'), findsOneWidget);
  });

  testWidgets('a pay period selected: Period tasks', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['period']!,
    );
    expect(_group('Period tasks'), findsOneWidget);
    expect(_link('Mark this period reviewed'), findsOneWidget);
    expect(_link('Record payslip…'), findsOneWidget);
    expect(_link('Properties'), findsOneWidget);
  });

  testWidgets('a selected row fills Details; a derived cell shows Working', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    expect(_inDetails(find.text('Shift 2026-09-08')), findsOneWidget);
    await tester.tap(find.text('EUR 220.80'));
    await tester.pumpAndSettle();
    expect(_inDetails(find.textContaining('Working')), findsOneWidget);
    expect(_inDetails(find.text('Shift 2026-09-08')), findsNothing);
  });
}
