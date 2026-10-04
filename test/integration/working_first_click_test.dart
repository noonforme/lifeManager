import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic_shell.dart';

/// Details explains a figure on the first click, even when that click also
/// selects the figure's record (XP-authentic shell spec 4.2).
void main() {
  testWidgets('one click on a figure of an unopened record explains it', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await tester.tap(
      find.descendant(
        of: find.bySemanticsLabel('Work register'),
        matching: find.text('EUR 147.20'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Working: Est. pay'), findsOneWidget);
  });
}
