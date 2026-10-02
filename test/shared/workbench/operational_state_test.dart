import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/operational_state.dart';

void main() {
  for (final kind in OperationalStateKind.values) {
    testWidgets('$kind keeps its words and uses no Material icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: OperationalState(
                kind: kind,
                title: 'Work record unavailable',
                message: 'The requested record is not available.',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Work record unavailable'), findsOneWidget);
      expect(
        find.text('The requested record is not available.'),
        findsOneWidget,
      );
      expect(find.byType(Icon), findsNothing);
    });
  }
}
