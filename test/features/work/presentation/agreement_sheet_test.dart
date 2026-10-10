import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

import '../../../support/synthetic_shell.dart';
import '../../../support/work_sheets.dart';

void main() {
  testWidgets('an agreement used by finished shifts opens editable, with '
      'History as its fifth tab recording a correction', (tester) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await chooseSheet(tester, 'Agreements');
    await tester.tap(find.text('v1').first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final tabs = find.byType(PropertySheetTabs);
    expect(tester.widget<PropertySheetTabs>(tabs).labels, [
      'Rate',
      'Premiums',
      'Leave',
      'Notes',
      'History',
    ]);
    final rate = tester.widget<TextField>(
      find.byKey(const ValueKey('agreement-hourly-rate')),
    );
    expect(rate.enabled, isTrue);
    // Apply waits for a change.
    expect(
      tester
          .widget<KeyButton>(find.widgetWithText(KeyButton, 'Apply'))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '20',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(KeyButton, 'Apply'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(EraDialog),
        matching: find.widgetWithText(KeyButton, 'Correct'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: tabs, matching: find.text('History')));
    // The history streams from the database; give it a few frames.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(
      find.text(
        'Reason: Corrected in place; the shifts and leave it pays were '
        'repriced.',
      ),
      findsOneWidget,
    );
    expect(find.text('Hourly rate: 18.40 EUR/h → 20.00 EUR/h'), findsOneWidget);
    // Closing the sheet ends the history's database stream.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PropertySheetTabs), findsNothing);
  });
}
