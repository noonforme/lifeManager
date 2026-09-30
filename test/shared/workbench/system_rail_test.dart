import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/system_rail.dart';

void main() {
  testWidgets('rail exposes visible destinations and honest availability', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(highContrast: false),
        home: Scaffold(
          body: SystemRail(selectedPath: '/work', onNavigate: (_) {}),
        ),
      ),
    );

    for (final label in [
      'Today',
      'Work',
      'Money',
      'Habits',
      'Backup and Export',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Work, selected'), findsOneWidget);
    for (final label in ['Today', 'Money', 'Habits']) {
      expect(
        find.bySemanticsLabel('$label, Not available in this release'),
        findsOneWidget,
      );
    }
  });
}
