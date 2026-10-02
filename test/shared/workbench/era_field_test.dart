import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_field.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> pump(WidgetTester tester, {String? error}) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: EraField(
                controller: controller,
                label: 'Start date',
                fieldKey: const ValueKey('start'),
                hint: 'YYYY-MM-DD',
                error: error,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the label sits above the field, not on its border', (
    tester,
  ) async {
    await pump(tester);
    final label = tester.getRect(find.text('Start date'));
    final field = tester.getRect(find.byKey(const ValueKey('start')));
    expect(label.bottom, lessThanOrEqualTo(field.top));
    expect(label.left, field.left);
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.labelText, isNull);
    expect(decoration.label, isNull);
  });

  testWidgets('the field is one node named by its label and error', (
    tester,
  ) async {
    await pump(tester, error: 'Enter a valid ISO date.');
    expect(
      find.bySemanticsLabel('Start date, Enter a valid ISO date.'),
      findsOneWidget,
    );
    expect(find.text('Enter a valid ISO date.'), findsOneWidget);
  });

  test('no field in lib floats its label on the border', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (line.contains('labelText:')) '${file.path}:${index + 1}',
    ];
    expect(offenders, isEmpty);
  });
}
