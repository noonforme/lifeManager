import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_controls.dart';
import 'package:lifeos/shared/workbench/inspector_parts.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  Widget host(Widget child, {double scale = 1}) => MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 292, height: 600, child: child),
        ),
      ),
    ),
  );

  testWidgets('facts with a legend sit in a group box', (tester) async {
    await tester.pumpWidget(
      host(
        const InspectorPane(
          children: [
            InspectorFacts([Fact('Date', '2026-09-09')], legend: 'Shift'),
          ],
        ),
      ),
    );
    expect(find.widgetWithText(GroupBox, 'Date'), findsOneWidget);
    expect(find.text('Shift'), findsOneWidget);
  });

  testWidgets('long facts hold at 200 % text in the property sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const InspectorPane(
          children: [
            InspectorTitle('Synthetic depot with a long employment name'),
            InspectorFacts([
              Fact.words('Timezone', 'America/Argentina/Buenos_Aires'),
              Fact('Expected under recorded agreement', 'EUR 12,345.67'),
            ], legend: 'Shift'),
          ],
        ),
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
