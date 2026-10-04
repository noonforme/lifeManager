import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/menu_bar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  testWidgets('no app label and no roadmap items in the menus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              height: 28,
              child: LifeOSMenuBar(onNavigate: (_) {}),
            ),
          ),
        ),
      ),
    );
    expect(find.text('LifeOS'), findsNothing);
    final roadmap = [
      'Copy row',
      'New desk',
      'Add sheet to desk',
      'Layout',
      'Rename desk',
      'Reset starter desk',
      'Show history',
    ];
    for (final menu in ['Edit', 'Desk', 'Record']) {
      await tester.tap(find.text(menu));
      await tester.pumpAndSettle();
      for (final label in roadmap) {
        expect(find.text(label), findsNothing, reason: '$menu › $label');
      }
      await tester.tapAt(const Offset(600, 500));
      await tester.pumpAndSettle();
    }
  });
}
