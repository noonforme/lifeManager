import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/desks/desk_repository.dart';
import 'package:lifeos/core/desks/desks.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

void main() {
  late AppDatabase database;
  late DeskRepository desks;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    var next = 0;
    desks = DeskRepository(database, newId: () => 'desk-${next++}');
  });

  tearDown(() => database.close());

  Future<Desk> named(String name) async =>
      (await desks.desks()).singleWhere((desk) => desk.name == name);

  test('first launch creates Today, Weekly review and Month close', () async {
    await desks.ensureStarters();
    await desks.ensureStarters();

    final all = await desks.desks();
    expect(all.map((desk) => desk.name), [
      'Today',
      'Weekly review',
      'Month close',
    ]);
    final today = all.first;
    expect(today.layout, DeskLayout.mainAndSide);
    expect(today.tiles.map((tile) => tile.sheetRef), [
      DeskSheets.journalRecent,
      DeskSheets.needsYou,
      DeskSheets.workThisPeriod,
    ]);
    expect(all[1].layout, DeskLayout.twoColumns);
    expect(all[2].tiles.map((tile) => tile.sheetRef), [
      DeskSheets.monthPeriods,
      DeskSheets.monthChecklist,
    ]);
  });

  test('Today cannot be deleted; other desks can', () async {
    await desks.ensureStarters();
    final today = await named('Today');

    final refused = await desks.deleteDesk(today.id, expected: today.revision);
    expect((refused as Invalid<Desk>).fields.keys, contains('desk.today'));

    final weekly = await named('Weekly review');
    expect(
      await desks.deleteDesk(weekly.id, expected: weekly.revision),
      isA<Committed<Desk>>(),
    );
    expect((await desks.desks()).map((desk) => desk.name), [
      'Today',
      'Month close',
    ]);
  });

  test('reset restores a starter desk', () async {
    await desks.ensureStarters();
    var today = await named('Today');
    today = (await desks.rename(
      today.id,
      expected: today.revision,
      name: 'My day',
    ) as Committed<Desk>).value;
    today = (await desks.removeTile(
      today.id,
      expected: today.revision,
      tileId: today.tiles.first.id,
    ) as Committed<Desk>).value;
    expect(today.tiles, hasLength(2));

    final reset = (await desks.resetStarter(
      today.id,
      expected: today.revision,
    ) as Committed<Desk>).value;
    expect(reset.name, 'Today');
    expect(reset.layout, DeskLayout.mainAndSide);
    expect(reset.tiles.map((tile) => tile.sheetRef), [
      DeskSheets.journalRecent,
      DeskSheets.needsYou,
      DeskSheets.workThisPeriod,
    ]);
  });

  test('adding a sheet to a full desk replaces the focused tile', () async {
    await desks.ensureStarters();
    final weekly = await named('Weekly review');
    final focused = weekly.tiles.first;

    final changed = (await desks.addSheet(
      weekly.id,
      expected: weekly.revision,
      sheetRef: DeskSheets.journalRecent,
      focusedTileId: focused.id,
    ) as Committed<Desk>).value;

    expect(changed.tiles.map((tile) => tile.sheetRef), [
      DeskSheets.journalRecent,
      DeskSheets.payPeriods,
    ]);
    expect(changed.revision, weekly.revision + 1);
  });

  test('a desk with room gains a tile; a new desk starts single', () async {
    final created =
        (await desks.createDesk(' Planning ') as Committed<Desk>).value;
    expect(created.name, 'Planning');
    expect(created.layout, DeskLayout.single);

    final withSheet = (await desks.addSheet(
      created.id,
      expected: created.revision,
      sheetRef: DeskSheets.payPeriods,
    ) as Committed<Desk>).value;
    expect(withSheet.tiles.single.sheetRef, DeskSheets.payPeriods);

    final narrowed = (await desks.setLayout(
      withSheet.id,
      expected: withSheet.revision,
      layout: DeskLayout.twoColumns,
    ) as Committed<Desk>).value;
    expect(narrowed.layout, DeskLayout.twoColumns);
  });

  test('concurrent edits return Stale and invalid input is refused', () async {
    await desks.ensureStarters();
    final today = await named('Today');
    await desks.rename(today.id, expected: today.revision, name: 'First');

    expect(
      await desks.rename(today.id, expected: today.revision, name: 'Second'),
      isA<Stale<Desk>>(),
    );
    expect(
      await desks.addSheet(
        today.id,
        expected: today.revision + 1,
        sheetRef: 'finance.everything',
      ),
      isA<Invalid<Desk>>(),
    );
    expect(await desks.createDesk('  '), isA<Invalid<Desk>>());
    expect(
      await desks.rename('missing', expected: 0, name: 'Nope'),
      isA<Missing<Desk>>(),
    );
  });
}
