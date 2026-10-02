import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/desks/desks.dart';
import 'package:lifeos/shared/shell/desk_view.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

void main() {
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester, {
    required List<Desk> desks,
    Desk? selected,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    calls = [];
    final current = selected ?? desks.first;
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: DeskView(
            desks: desks,
            selected: current,
            sheetNames: const {
              DeskSheets.journalRecent: 'Journal',
              DeskSheets.needsYou: 'Needs you',
              DeskSheets.payPeriods: 'Pay periods',
            },
            tile: (tile) => (
              title: 'Tile ${tile.sheetRef}',
              area: tile.sheetRef == DeskSheets.payPeriods
                  ? LifeOSArea.work
                  : null,
              body: Text('Body ${tile.sheetRef}'),
              fullSizeRoute: tile.sheetRef == DeskSheets.payPeriods
                  ? '/work?sheet=periods'
                  : null,
            ),
            onSelectDesk: (desk) => calls.add('select ${desk.name}'),
            onNewDesk: () => calls.add('new'),
            onRemoveTile: (tile) => calls.add('remove ${tile.sheetRef}'),
            onReplaceTile: (tile, sheet) =>
                calls.add('replace ${tile.sheetRef} with $sheet'),
            onAddSheet: (sheet) => calls.add('add $sheet'),
            onLayout: (layout) => calls.add('layout ${layout.name}'),
            onRename: () => calls.add('rename'),
            onReset: current.starter == null ? null : () => calls.add('reset'),
            onDelete: current.canDelete ? () => calls.add('delete') : null,
            onOpen: (route) => calls.add('open $route'),
            views: const {'view-1': 'October periods'},
            onAddView: (view) => calls.add('view $view'),
          ),
        ),
      ),
    );
  }

  testWidgets('desk tabs select a desk and + Desk creates one', (tester) async {
    await pump(tester, desks: [_today, _weekly]);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Weekly review'), findsOneWidget);
    await tester.tap(find.text('Weekly review'));
    await tester.tap(find.text('+ Desk'));
    expect(calls, ['select Weekly review', 'new']);
  });

  testWidgets('main and side shows every tile, the first widest', (
    tester,
  ) async {
    await pump(tester, desks: [_today]);

    final main = tester.getSize(find.text('Body ${DeskSheets.journalRecent}'));
    expect(main, isNotNull);
    final widths = [
      for (final sheet in _today.tiles.map((tile) => tile.sheetRef))
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Body $sheet'),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .width,
    ];
    expect(widths[0], greaterThan(widths[1]));
    expect(widths[1], widths[2]);
    // Only the Work tile carries an area key.
    expect(find.text('W'), findsOneWidget);
  });

  testWidgets('a tile closes, opens full size and is replaced from its menu', (
    tester,
  ) async {
    await pump(tester, desks: [_today]);

    await tester.tap(
      find.bySemanticsLabel('Close Tile ${DeskSheets.needsYou}'),
    );
    final menus = find.byTooltip('Tile menu');
    await tester.tap(menus.at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open full size'));
    await tester.pumpAndSettle();
    await tester.tap(menus.at(2));
    await tester.pumpAndSettle();
    expect(find.text('Replace with Pay periods'), findsNothing);
    await tester.tap(find.text('Replace with Journal'));
    await tester.pumpAndSettle();

    expect(calls, [
      'remove ${DeskSheets.needsYou}',
      'open /work?sheet=periods',
      'replace ${DeskSheets.payPeriods} with ${DeskSheets.journalRecent}',
    ]);
  });

  testWidgets('Today can be reset but not deleted; own desks can be deleted', (
    tester,
  ) async {
    await pump(tester, desks: [_today]);
    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    final delete = tester.widget<PopupMenuItem<Object>>(
      find.ancestor(
        of: find.text('Delete desk'),
        matching: find.byType(PopupMenuItem<Object>),
      ),
    );
    expect(delete.enabled, isFalse);
    await tester.tap(
      find.ancestor(
        of: find.text('Layout: Two columns'),
        matching: find.byType(CheckedPopupMenuItem<Object>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset starter desk'));
    await tester.pumpAndSettle();
    expect(calls, ['layout twoColumns', 'reset']);

    await pump(tester, desks: [_today, _own], selected: _own);
    expect(
      find.text('This desk is empty. Add a sheet from the desk menu.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Needs you'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add view: October periods'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desk menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete desk'));
    await tester.pumpAndSettle();
    expect(calls, ['add ${DeskSheets.needsYou}', 'view view-1', 'delete']);
  });
}

DeskTile _tile(int position, String sheet) =>
    DeskTile(id: 't$position-$sheet', position: position, sheetRef: sheet);

final _today = Desk(
  id: 'today',
  name: 'Today',
  starter: StarterDesk.today,
  layout: DeskLayout.mainAndSide,
  position: 0,
  revision: 0,
  tiles: [
    _tile(0, DeskSheets.journalRecent),
    _tile(1, DeskSheets.needsYou),
    _tile(2, DeskSheets.payPeriods),
  ],
);

final _weekly = Desk(
  id: 'weekly',
  name: 'Weekly review',
  starter: StarterDesk.weeklyReview,
  layout: DeskLayout.twoColumns,
  position: 1,
  revision: 0,
  tiles: [_tile(0, DeskSheets.payPeriods)],
);

const _own = Desk(
  id: 'own',
  name: 'Planning',
  starter: null,
  layout: DeskLayout.single,
  position: 2,
  revision: 0,
  tiles: [],
);
