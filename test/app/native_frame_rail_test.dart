import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/shared/workbench/system_rail.dart';

void main() {
  testWidgets('Backup and export keeps the shared system rail styling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: '/system/files');
    addTearDown(router.dispose);
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();

    final rail = tester.widget<SystemRail>(find.byType(SystemRail));
    expect(rail.selectedPath, '/system/files');
    expect(find.text('File tools are not available yet.'), findsOneWidget);
  });
}
