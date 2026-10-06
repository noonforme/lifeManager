import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/synthetic_shell.dart';
import '../../../support/work_dialogs.dart';

void main() {
  testWidgets('a finalized shift shows its fields greyed above its pay', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(find.text('2026-09-08'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const ValueKey('shift-start-time'))),
      isSemantics(label: 'Start time, 22:00', isEnabled: false),
    );
    expect(find.text('Add break'), findsNothing);
    await revealInDialog(tester, find.text('Correct shift'));
    expect(find.text('Overtime hours:'), findsOneWidget);
    expect(find.text('Correct shift'), findsOneWidget);
  });
}
