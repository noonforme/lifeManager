import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic_shell.dart';

/// The Working group box explains a figure on the first click, even when
/// that click also opens the figure's record (Millennium shell spec 5.5).
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
