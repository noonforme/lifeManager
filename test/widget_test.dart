import 'package:flutter_test/flutter_test.dart';

import 'package:lifeos/main.dart';

void main() {
  testWidgets('shows the native LifeOS placeholder', (tester) async {
    await tester.pumpWidget(const LifeOsApp());

    expect(find.text('LifeOS'), findsOneWidget);
    expect(find.text('Native workspace foundation'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
  });
}
