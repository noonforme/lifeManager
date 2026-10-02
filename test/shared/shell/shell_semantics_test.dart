import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_shell.dart';

/// Every region and key keeps its label at both reference sizes
/// (Millennium shell spec 6 and 9).
void main() {
  for (final size in const [Size(1280, 800), Size(960, 760)]) {
    testWidgets('every region and key keeps its label at $size', (
      tester,
    ) async {
      await pumpSyntheticShell(
        tester,
        size: size,
        screen: syntheticScreens['period']!,
      );
      for (final label in [
        'Menu bar',
        'Toolbar',
        'Address',
        'Record inspector',
        'Status line',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      // Below 1280 px the open record replaces the list (spec 4.1).
      expect(
        find.bySemanticsLabel('Desk workspace'),
        size.width >= 1280 ? findsOneWidget : findsNothing,
      );
      if (size.width < 1280) {
        expect(find.bySemanticsLabel('Back to list'), findsOneWidget);
      }
      if (size.width >= 1024) {
        expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
      } else {
        expect(find.text('Tasks'), findsOneWidget);
      }
      for (final key in ['Back, unavailable', 'Forward, unavailable', 'Go']) {
        expect(find.bySemanticsLabel(key), findsOneWidget, reason: key);
      }
      expect(find.bySemanticsLabel('General'), findsOneWidget);
      expect(find.bySemanticsLabel('History'), findsOneWidget);
    });
  }
}
