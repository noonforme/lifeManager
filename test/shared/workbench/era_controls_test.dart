import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_controls.dart';

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
}
