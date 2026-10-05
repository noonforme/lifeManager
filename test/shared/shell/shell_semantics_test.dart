import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_shell.dart';

/// Every region and key keeps its label at both reference sizes
/// (Millennium shell spec 6 and 9; XP-authentic shell spec 10).
void main() {
  for (final size in const [Size(1280, 800), Size(960, 760)]) {
    testWidgets('every region and key keeps its label at $size', (
      tester,
    ) async {
      await pumpSyntheticShell(
        tester,
        size: size,
        screen: syntheticScreens['shell']!,
      );
      for (final label in ['Menu bar', 'Toolbar', 'Address', 'Status line']) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      // The desk keeps its place at every width (XP-authentic spec 3.1).
      expect(find.bySemanticsLabel('Desk workspace'), findsOneWidget);
      expect(find.bySemanticsLabel('Back to list'), findsNothing);
      if (size.width >= 1024) {
        expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
      } else {
        expect(find.text('Tasks'), findsOneWidget);
      }
      for (final key in ['Back, unavailable', 'Forward, unavailable', 'Go']) {
        expect(find.bySemanticsLabel(key), findsOneWidget, reason: key);
      }
      expect(
        find.bySemanticsLabel('Address, Work, Synthetic depot, Shifts'),
        findsOneWidget,
      );
      // A record's Properties sheet is announced by its caption, with its
      // tabs inside it.
      await tester.tap(find.text('2026-09-08'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Shift 2026-09-08 Properties'),
        findsWidgets,
      );
      expect(find.bySemanticsLabel('General'), findsOneWidget);
      expect(find.bySemanticsLabel('History'), findsOneWidget);
    });
  }
}
