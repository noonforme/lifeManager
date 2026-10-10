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

  testWidgets('facts read as "Label:" rows under an etched line', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const InspectorPane(
          children: [
            InspectorTitle('Shift 2026-09-08'),
            InspectorFacts([Fact('Date', '2026-09-08')], legend: 'Shift'),
          ],
        ),
      ),
    );
    expect(find.text('Date:'), findsOneWidget);
    expect(find.byType(EtchedLine), findsNWidgets(2));
    expect(find.byType(GroupBox), findsNothing);
    expect(find.text('Shift'), findsNothing, reason: 'blocks have no legend');
    expect(find.bySemanticsLabel('Shift'), findsOneWidget);
    final label = tester.getRect(find.text('Date:'));
    final value = tester.getRect(find.text('2026-09-08').last);
    expect(value.left, greaterThanOrEqualTo(label.left + 96));
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
