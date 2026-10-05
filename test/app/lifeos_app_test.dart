import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/shared/shell/status_line.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

void main() {
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    late BuildContext captured;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();
    return captured;
  }

  testWidgets('the app paints in the one LifeOS style', (tester) async {
    final context = await pumpApp(tester);
    expect(LifeOSSkinScope.of(context).tokens, same(LifeOSTokens.millennium));
    expect(Theme.of(context).brightness, Brightness.light);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.highContrastTheme, isNull);
  });

  testWidgets('an appearance saved by an older build is ignored', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    // The table stays without a migration; an old row is simply never read.
    await tester.runAsync(
      () => database.customStatement(
        "INSERT INTO preferences (key, value) VALUES ('appearance', 'night')",
      ),
    );
    final context = await pumpApp(tester);
    expect(LifeOSSkinScope.of(context).tokens, same(LifeOSTokens.millennium));
  });

  testWidgets('a notice stays within its area and clears on leaving it', (
    tester,
  ) async {
    late BuildContext captured;
    Widget page() => Builder(
      builder: (context) {
        captured = context;
        return const SizedBox();
      },
    );
    final router = GoRouter(
      initialLocation: '/work?employment=a',
      routes: [
        GoRoute(path: '/work', builder: (_, _) => page()),
        GoRoute(path: '/today', builder: (_, _) => page()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(LifeOsApp(router: router));
    await tester.pumpAndSettle();
    final notices = StatusNoticeScope.read(captured)!;
    notices.value = 'Shift saved.';
    // Within Work (a record selected) the notice stays.
    router.go('/work?employment=a&record=shift:b');
    await tester.pumpAndSettle();
    expect(notices.value, 'Shift saved.');
    // Another area: the notice is not about anything shown there.
    router.go('/today');
    await tester.pumpAndSettle();
    expect(notices.value, isNull);
  });
}
