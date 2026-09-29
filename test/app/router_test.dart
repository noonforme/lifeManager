import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';

void main() {
  testWidgets('safe top-level routes keep the native frame mounted', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/work');
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('LifeOS'), findsOneWidget);
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Work records will appear here.'), findsOneWidget);

    router.go('/money');
    await tester.pumpAndSettle();

    expect(find.text('LifeOS'), findsOneWidget);
    expect(
      find.text('Money is not available in this release.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid Work date scope is explicit and not replaced', (
    tester,
  ) async {
    final router = createAppRouter(
      initialLocation: '/work?from=2026-09-31&to=2026-10-01',
    );
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('Invalid Work scope'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing);
  });

  testWidgets('routes never render unknown query content', (tester) async {
    final router = createAppRouter(
      initialLocation: '/work?note=private-marker&mode=inspect',
    );
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();

    expect(find.textContaining('private-marker'), findsNothing);
  });
}
