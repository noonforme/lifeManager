import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

import '../../../support/era_pickers.dart';
import '../../../support/synthetic_shell.dart';

void main() {
  testWidgets('a pay period shows its dates greyed beside its actions', (
    tester,
  ) async {
    await pumpSyntheticShell(
      tester,
      size: const Size(1280, 800),
      screen: syntheticScreens['period']!,
    );
    expect(find.text('General'), findsOneWidget);
    expect(dateIn(tester, 'period-start'), const LocalDate(2026, 9, 1));
    expect(dateIn(tester, 'period-end'), const LocalDate(2026, 9, 30));
    await tester.tap(find.byKey(const ValueKey('period-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('era-calendar-title')), findsNothing);
    expect(find.text('Mark reviewed'), findsOneWidget);
    // Greyed as the era drew a disabled box: on the face colour.
    final face = LifeOSSkinData.standard.tokens.chrome;
    final box =
        tester
                .widget<Container>(find.byKey(const ValueKey('period-start')))
                .decoration!
            as BoxDecoration;
    expect(box.color, face);
  });
}
