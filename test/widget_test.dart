import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';

void main() {
  testWidgets('shows the native LifeOS workbench skeleton', (tester) async {
    await tester.pumpWidget(
      LifeOsApp(router: createAppRouter(initialLocation: '/work')),
    );
    await tester.pumpAndSettle();

    expect(find.text('LifeOS'), findsOneWidget);
    expect(find.text('Work records will appear here.'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
  });
}
