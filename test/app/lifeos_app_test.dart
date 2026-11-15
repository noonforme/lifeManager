import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  /// Pumps the production app and returns a context inside its Work route.
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    late BuildContext captured;
    final router = createAppRouter(
      work: (_) => Builder(
        builder: (context) {
          captured = context;
          return const SizedBox();
        },
      ),
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
    expect(app.title, 'LifeOS');
  });

  testWidgets('the Work shell gets a Material, cell selection and era '
      'scrolling', (tester) async {
    final context = await pumpApp(tester);
    expect(Material.maybeOf(context), isNotNull);
    expect(CellSelectionScope.maybeOf(context), isNotNull);
    expect(ScrollConfiguration.of(context), isA<EraScrollBehavior>());
  });
}
