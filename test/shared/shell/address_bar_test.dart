import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/address_bar.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

void main() {
  testWidgets('crumbs open their level and Go reloads', (tester) async {
    final opened = <String>[];
    var reloaded = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LifeOSSkinScope(
          child: SizedBox(
            width: 800,
            child: AddressBar(
              crumbs: const [
                AddressCrumb('Work', '/work'),
                AddressCrumb('Synthetic depot', '/work?employment=e1'),
                AddressCrumb('Shifts'),
              ],
              onNavigate: opened.add,
              onGo: () => reloaded++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Work'));
    expect(opened, ['/work']);
    await tester.tap(find.text('Go'));
    expect(reloaded, 1);
    expect(find.bySemanticsLabel('Address'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Work')),
      isSemantics(
        isLink: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
  });
}
