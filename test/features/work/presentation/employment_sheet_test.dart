import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/task_pane.dart';

import '../../../support/synthetic_shell.dart';

/// Opens the employment's Properties from the task pane: "Employment
/// properties" with nothing selected, "Properties" once it is.
Future<void> _openProperties(WidgetTester tester) async {
  final general = find.widgetWithText(TaskLink, 'Employment properties');
  await tester.tap(
    general.evaluate().isNotEmpty
        ? general
        : find.widgetWithText(TaskLink, 'Properties'),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('employment Properties edits the name in place with Apply', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await _openProperties(tester);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('employment-name')),
      'Night depot',
    );
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Night depot Properties'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('employment-name')),
      'Typo',
    );
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _openProperties(tester);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('employment-name')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Night depot',
    );
  });

  testWidgets('an empty name keeps the sheet open with its error', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['shell']!,
    );
    await _openProperties(tester);
    await tester.enterText(find.byKey(const ValueKey('employment-name')), '');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(find.text('Synthetic depot Properties'), findsOneWidget);
  });
}
