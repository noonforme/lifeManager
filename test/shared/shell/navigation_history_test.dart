import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/shared/shell/navigation_history.dart';

void main() {
  group('NavigationHistory', () {
    test('back returns to the previous location and forward re-applies it', () {
      final history = NavigationHistory()
        ..visit('/work')
        ..visit('/finance');

      expect(history.back(), '/work');
      history.visit('/work'); // the router arrives there
      expect(history.current, '/work');
      expect(history.canGoForward, isTrue);

      expect(history.forward(), '/finance');
      history.visit('/finance');
      expect(history.current, '/finance');
      expect(history.canGoForward, isFalse);
    });

    test('a new location clears the forward entries', () {
      final history = NavigationHistory()
        ..visit('/work')
        ..visit('/finance');
      history.back();
      history.visit('/work');

      history.visit('/tracking');
      expect(history.canGoForward, isFalse);
      expect(history.back(), '/work');
    });

    test('revisiting the current location adds nothing', () {
      final history = NavigationHistory()
        ..visit('/work')
        ..visit('/work');
      expect(history.canGoBack, isFalse);
    });

    test('the history keeps at most 100 entries', () {
      final history = NavigationHistory();
      for (var index = 0; index < 150; index++) {
        history.visit('/work?step=$index');
      }
      var steps = 0;
      String? location;
      while (history.canGoBack) {
        location = history.back();
        history.visit(location!);
        steps++;
      }
      expect(steps, 99);
      expect(location, '/work?step=50');
    });
  });

  group('in the shell', () {
    Future<GoRouter> pumpApp(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.reset);
      final router = createAppRouter(initialLocation: '/work');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workQueryRepositoryProvider.overrideWithValue(_EmptyRepository()),
          ],
          child: LifeOsApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    String path(GoRouter router) =>
        router.routeInformationProvider.value.uri.path;

    testWidgets('toolbar Back and Forward travel the history', (tester) async {
      final router = await pumpApp(tester);
      expect(find.bySemanticsLabel('Back, unavailable'), findsOneWidget);
      expect(find.bySemanticsLabel('Forward, unavailable'), findsOneWidget);

      await tester.tap(find.text('Finance'));
      await tester.pumpAndSettle();
      expect(path(router), '/finance');

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(path(router), '/work');
      expect(find.bySemanticsLabel('Forward'), findsOneWidget);

      await tester.tap(find.text('Forward'));
      await tester.pumpAndSettle();
      expect(path(router), '/finance');
    });

    testWidgets('mouse back and forward buttons travel the history', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await tester.tap(find.text('Tracking'));
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.bySemanticsLabel('Desk workspace'));
      final back = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kBackMouseButton,
      );
      await back.up();
      await tester.pumpAndSettle();
      expect(path(router), '/work');

      final forward = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kForwardMouseButton,
      );
      await forward.up();
      await tester.pumpAndSettle();
      expect(path(router), '/tracking');
    });

    testWidgets('Window › Back follows the same history', (tester) async {
      final router = await pumpApp(tester);
      await tester.tap(find.text('Knowledge'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Window'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back').last);
      await tester.pumpAndSettle();
      expect(path(router), '/work');
    });
  });
}

final class _EmptyRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() => Stream.value(null);
}
