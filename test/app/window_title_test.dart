import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic_shell.dart';

void main() {
  testWidgets('the window title names the place, then LifeOS', (tester) async {
    final titles = <String>[];
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
      onTitle: titles.add,
    );
    expect(titles.last, 'Shifts - LifeOS');
    await tester.tap(find.text('Journal').first);
    await tester.pumpAndSettle();
    expect(titles.last, 'Journal - LifeOS');
  });
}
