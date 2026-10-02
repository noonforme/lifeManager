import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_controls.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

void main() {
  testWidgets('orbs are decorative and sized as asked', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Orb(glyph: OrbGlyph.back, tone: OrbTone.green, size: 20),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Orb)), const Size(20, 20));
    final semantics = tester.getSemantics(find.byType(Orb));
    expect(semantics.label, isEmpty);
  });
  testWidgets('a group box announces its legend and shows its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scoped(const GroupBox(legend: 'Shift', child: Text('Date'))),
    );
    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.bySemanticsLabel('Shift'), findsOneWidget);
  });

  testWidgets('a combo face shows its value and a drop arrow', (tester) async {
    await tester.pumpWidget(_scoped(const EraComboFace(value: 'Shifts')));
    expect(find.text('Shifts'), findsOneWidget);
    expect(
      tester.getSize(find.byType(EraComboFace)).height,
      greaterThanOrEqualTo(24),
    );
  });

  testWidgets('a form footer keeps its keys at the right edge', (tester) async {
    await tester.pumpWidget(
      _scoped(
        SizedBox(
          width: 300,
          child: FormFooter(
            children: [KeyButton(label: 'Save', onPressed: () {})],
          ),
        ),
      ),
    );
    expect(
      tester.getTopRight(find.byKey(const ValueKey('key-face'))).dx,
      closeTo(300, 1),
    );
  });
}

Widget _scoped(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: LifeOSSkinScope(
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);
