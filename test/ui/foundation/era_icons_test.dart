import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  testWidgets('every icon paints at 16 and 32 px without text', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          children: [
            for (final kind in EraIconKind.values) ...[
              EraIcon(kind),
              EraIcon(kind, size: 32),
              EraIcon(kind, disabled: true),
            ],
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsNothing, reason: 'icons are painted');
    expect(tester.getSize(find.byType(EraIcon).first), const Size(16, 16));
  });

  testWidgets('an icon with a label is announced; without one it is silent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            EraIcon(EraIconKind.work, semanticLabel: 'Work'),
            EraIcon(EraIconKind.add),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Work'), findsOneWidget);
  });
}
