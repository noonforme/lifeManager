import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/desks/desk_repository.dart';
import 'package:lifeos/core/desks/desks.dart';
import 'package:lifeos/core/desks/saved_view_repository.dart';
import 'package:lifeos/core/desks/saved_views.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

const _employment = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11';
const _period = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51';

void main() {
  late AppDatabase database;
  late SavedViewRepository views;
  late DeskRepository desks;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    var next = 0;
    String newId() => 'id-${next++}';
    views = SavedViewRepository(database, newId: newId);
    desks = DeskRepository(database, newId: newId);
  });

  tearDown(() => database.close());

  SavedView committed(MutationOutcome<SavedView> outcome) =>
      (outcome as Committed<SavedView>).value;

  test('a view round-trips its sheet, filters, sort and columns', () async {
    const shape = ViewShape(
      sheetRef: ViewSheets.workShifts,
      filters: {'void': '1', 'employment': _employment, 'period': _period},
      sort: ViewSort('pay', descending: true),
      columns: ['date', 'paid', 'pay', 'state'],
    );
    final saved = committed(await views.createView('  Night shifts ', shape));

    final read = (await views.views()).single;
    expect(read.id, saved.id);
    expect(read.name, 'Night shifts');
    expect(read.shape.sheetRef, ViewSheets.workShifts);
    expect(read.shape.filters, {
      'employment': _employment,
      'period': _period,
      'void': '1',
    });
    expect(read.shape.sort, const ViewSort('pay', descending: true));
    expect(read.shape.columns, ['date', 'paid', 'pay', 'state']);

    final plain = committed(
      await views.createView(
        'Periods',
        const ViewShape(sheetRef: ViewSheets.workPeriods),
      ),
    );
    expect(plain.shape.filters, isEmpty);
    expect(plain.shape.sort, isNull);
    expect(plain.shape.columns, isNull);
    expect(plain.position, saved.position + 1);
  });

  test('rename and delete check the revision', () async {
    final saved = committed(
      await views.createView(
        'Shifts',
        const ViewShape(sheetRef: ViewSheets.workShifts),
      ),
    );
    final renamed = committed(
      await views.rename(saved.id, expected: saved.revision, name: 'Mine'),
    );
    expect(renamed.name, 'Mine');
    expect(renamed.revision, saved.revision + 1);

    expect(
      await views.rename(saved.id, expected: saved.revision, name: 'Again'),
      isA<Stale<SavedView>>(),
    );
    expect(
      await views.deleteView(saved.id, expected: saved.revision),
      isA<Stale<SavedView>>(),
    );
    expect(
      await views.deleteView(saved.id, expected: renamed.revision),
      isA<Committed<SavedView>>(),
    );
    expect(await views.views(), isEmpty);
    expect(
      await views.deleteView(saved.id, expected: 0),
      isA<Missing<SavedView>>(),
    );
  });

  group('only structural values are stored', () {
    Future<Map<String, Object>> refused(ViewShape shape) async =>
        (await views.createView('View', shape) as Invalid<SavedView>).fields;

    test('free text in a filter is refused', () async {
      expect(
        (await refused(
          const ViewShape(
            sheetRef: ViewSheets.workShifts,
            filters: {'employment': 'Synthetic Person'},
          ),
        )).keys,
        ['filters.employment'],
      );
      expect(
        (await refused(
          const ViewShape(
            sheetRef: ViewSheets.workShifts,
            filters: {'note': 'anything'},
          ),
        )).keys,
        ['filters.note'],
      );
      expect(
        (await refused(
          const ViewShape(
            sheetRef: ViewSheets.workShifts,
            filters: {'from': '2026-10-01', 'to': 'next week'},
          ),
        )).keys,
        contains('filters.to'),
      );
      expect(
        (await refused(
          const ViewShape(
            sheetRef: ViewSheets.workShifts,
            filters: {'void': 'yes'},
          ),
        )).keys,
        ['filters.void'],
      );
    });

    test('ranges, sorts, columns and sheets must be known', () async {
      expect(
        (await refused(
          const ViewShape(
            sheetRef: ViewSheets.workShifts,
            filters: {'from': '2026-10-01'},
          ),
        )).keys,
        ['filters'],
      );
      expect(
        (await refused(
          const ViewShape(
            sheetRef: ViewSheets.workShifts,
            sort: ViewSort('salary'),
            columns: ['date', 'date'],
          ),
        )).keys,
        ['sort', 'columns'],
      );
      expect(
        (await refused(const ViewShape(sheetRef: 'finance.everything'))).keys,
        ['sheetRef'],
      );
      expect(await views.views(), isEmpty);
    });
  });

  test('a view sits on a desk and leaves it when deleted', () async {
    await desks.ensureStarters();
    final view = committed(
      await views.createView(
        'October',
        const ViewShape(
          sheetRef: ViewSheets.workShifts,
          filters: {'period': _period},
        ),
      ),
    );
    final planning =
        (await desks.createDesk('Planning') as Committed<Desk>).value;

    final placed = (await desks.addView(
      planning.id,
      expected: planning.revision,
      viewId: view.id,
    ) as Committed<Desk>).value;
    expect(placed.tiles.single.viewId, view.id);
    expect(placed.tiles.single.sheetRef, ViewSheets.workShifts);

    await views.deleteView(view.id, expected: view.revision);
    final after = (await desks.desks()).singleWhere(
      (desk) => desk.id == planning.id,
    );
    expect(after.tiles, isEmpty);
    expect(after.revision, placed.revision + 1);
    expect(
      await desks.addView(
        planning.id,
        expected: after.revision,
        viewId: view.id,
      ),
      isA<Invalid<Desk>>(),
    );
  });

  test('replacing a view tile with a sheet clears the view', () async {
    final view = committed(
      await views.createView(
        'Shifts',
        const ViewShape(sheetRef: ViewSheets.workShifts),
      ),
    );
    final desk = (await desks.createDesk('Solo') as Committed<Desk>).value;
    final placed = (await desks.addView(
      desk.id,
      expected: desk.revision,
      viewId: view.id,
    ) as Committed<Desk>).value;

    final replaced = (await desks.addSheet(
      desk.id,
      expected: placed.revision,
      sheetRef: DeskSheets.needsYou,
      focusedTileId: placed.tiles.single.id,
    ) as Committed<Desk>).value;
    expect(replaced.tiles.single.sheetRef, DeskSheets.needsYou);
    expect(replaced.tiles.single.viewId, isNull);
  });
}
