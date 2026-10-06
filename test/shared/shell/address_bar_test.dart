import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/address_bar.dart';
import 'package:lifeos/shared/shell/book_tree.dart';
import 'package:lifeos/shared/workbench/era_icons.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

Widget _host(Widget child) => MaterialApp(
  home: LifeOSSkinScope(
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 800, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('the location reads as a path, without crumbs', (tester) async {
    await tester.pumpWidget(
      _host(
        AddressBar(
          crumbs: const [
            AddressCrumb('Work', '/work'),
            AddressCrumb('Synthetic depot', '/work?employment=e'),
            AddressCrumb('Shifts', '/work?employment=e&sheet=shifts'),
          ],
          tree: const [],
          icon: EraIconKind.work,
          onNavigate: (_) {},
          onGo: () {},
        ),
      ),
    );
    expect(find.text(r'Work\Synthetic depot\Shifts'), findsOneWidget);
    expect(find.textContaining('›'), findsNothing);
    expect(find.byType(EraIcon), findsOneWidget);
  });

  testWidgets('the drop arrow lists the locations and opens one', (
    tester,
  ) async {
    final opened = <String>[];
    var reloaded = 0;
    await tester.pumpWidget(
      _host(
        AddressBar(
          crumbs: const [AddressCrumb('Today', '/today')],
          tree: const [
            AddressLocation('Today', '/today'),
            AddressLocation('Journal', '/journal'),
            AddressLocation('Work', '/work', icon: EraIconKind.work),
            AddressLocation('Synthetic depot', '/work?employment=e', depth: 1),
          ],
          onNavigate: opened.add,
          onGo: () => reloaded++,
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Address, Today'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic depot'), findsOneWidget);
    await tester.tap(find.text('Synthetic depot'));
    await tester.pumpAndSettle();
    expect(opened, ['/work?employment=e']);
    await tester.tap(find.text('Go'));
    expect(reloaded, 1);
  });

  test('the tree follows the book nodes', () {
    final tree = addressTreeFrom(const [
      TreeSheet(label: 'Today', route: '/today'),
      TreeGroup(
        label: 'Views',
        children: [TreeSheet(label: 'Night shifts', route: '/work?view=1')],
      ),
      TreeArea(
        area: LifeOSArea.work,
        route: '/work',
        built: true,
        children: [
          TreeSheet(label: 'Synthetic depot', route: '/work?employment=e'),
        ],
      ),
      TreeArea(area: LifeOSArea.finance, route: '/finance', built: false),
    ]);
    expect(
      [for (final entry in tree) '${entry.depth}:${entry.label}'],
      [
        '0:Today',
        '0:Night shifts',
        '0:Work',
        '1:Synthetic depot',
        '0:Finance (not built yet)',
      ],
    );
    // An unbuilt area reads as it does in Books: greyed.
    expect(
      [for (final entry in tree) entry.unbuilt],
      [false, false, false, false, true],
    );
  });

  testWidgets('the list shows the current sheet under its parent, lit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AddressBar(
          crumbs: const [
            AddressCrumb('Work', '/work'),
            AddressCrumb('Synthetic depot', '/work?employment=e'),
            AddressCrumb('Shifts', '/work?employment=e&sheet=shifts'),
          ],
          tree: const [
            AddressLocation('Today', '/today'),
            AddressLocation('Work', '/work', icon: EraIconKind.work),
            AddressLocation('Synthetic depot', '/work?employment=e', depth: 1),
            AddressLocation('Finance', '/finance'),
          ],
          onNavigate: (_) {},
          onGo: () {},
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^Address, ')));
    await tester.pump();
    await tester.pump();
    final rows = find.byType(MenuItemButton);
    final labels = [
      for (final row in rows.evaluate())
        (row.widget as MenuItemButton).semanticsLabel ??
            tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byWidget(row.widget),
                    matching: find.byType(Text),
                  ),
                )
                .first
                .data,
    ];
    expect(labels, ['Today', 'Work', 'Synthetic depot', 'Shifts', 'Finance']);
    final shifts = find.descendant(
      of: find.ancestor(
        of: find.text('Shifts'),
        matching: find.byType(MenuItemButton),
      ),
      matching: find.byType(Material),
    );
    expect(
      tester.widget<Material>(shifts.first).color,
      LifeOSSkinData.standard.tokens.selWash,
    );
    expect(
      tester.getTopLeft(find.text('Shifts')).dx,
      greaterThan(tester.getTopLeft(find.text('Synthetic depot')).dx),
    );
  });
}
