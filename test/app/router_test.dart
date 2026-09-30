import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';

void main() {
  test(
    'invalid record UUID remains unavailable instead of selecting a row',
    () {
      final result = parseWorkRoute(Uri.parse('/work?record=shift:not-a-uuid'));

      expect(result, isA<InvalidWorkRoute>());
      expect((result as InvalidWorkRoute).reason, WorkRouteProblem.malformedId);
    },
  );

  test('route parser rejects malformed and conflicting temporal scopes', () {
    expect(
      parseWorkRoute(Uri.parse('/work?period=not-a-uuid')),
      isA<InvalidWorkRoute>().having(
        (value) => value.reason,
        'reason',
        WorkRouteProblem.malformedScope,
      ),
    );
    expect(
      parseWorkRoute(
        Uri.parse(
          '/work?period=018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51'
          '&from=2026-09-01&to=2026-09-30',
        ),
      ),
      isA<InvalidWorkRoute>().having(
        (value) => value.reason,
        'reason',
        WorkRouteProblem.malformedScope,
      ),
    );
  });

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
