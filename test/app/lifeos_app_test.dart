import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets('app exposes the stronger system high-contrast theme', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(LifeOsApp(router: router));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.highContrastTheme?.dividerColor,
      buildLifeOSTheme(highContrast: true).dividerColor,
    );
  });
}
