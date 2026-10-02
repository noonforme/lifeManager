import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../outcomes/mutation_outcome.dart';
import 'desks.dart';

/// Desks and their tiles. Every change bumps the desk's revision and is
/// checked against the revision the caller saw.
final class DeskRepository {
  DeskRepository(this._database, {required this._newId});

  final AppDatabase _database;
  final String Function() _newId;

  /// Creates the starter desks on first launch; later calls change nothing.
  Future<void> ensureStarters() => _database.transaction(() async {
    final existing = await _database.select(_database.desks).get();
    if (existing.isNotEmpty) return;
    for (final (position, starter) in StarterDesk.values.indexed) {
      final shape = starterDesk(starter);
      final id = _newId();
      await _database
          .into(_database.desks)
          .insert(
            DesksCompanion.insert(
              id: id,
              name: shape.name,
              starterKey: Value(starter.name),
              layout: shape.layout.name,
              position: position,
              revision: 0,
            ),
          );
      await _insertTiles(id, shape.sheets);
    }
  });

  Stream<List<Desk>> watchDesks() async* {
    yield await desks();
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables([_database.desks, _database.deskTiles]),
    )) {
      yield await desks();
    }
  }

  Future<List<Desk>> desks() async {
    final rows = await (_database.select(
      _database.desks,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    final tiles = await (_database.select(
      _database.deskTiles,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    return [
      for (final row in rows)
        Desk(
          id: row.id,
          name: row.name,
          starter: row.starterKey == null
              ? null
              : StarterDesk.values.byName(row.starterKey!),
          layout: DeskLayout.values.byName(row.layout),
          position: row.position,
          revision: row.revision,
          tiles: [
            for (final tile in tiles)
              if (tile.deskId == row.id)
                DeskTile(
                  id: tile.id,
                  position: tile.position,
                  sheetRef: tile.sheetRef,
                  viewId: tile.viewId,
                ),
          ],
        ),
    ];
  }

  Future<MutationOutcome<Desk>> createDesk(String name) =>
      _database.transaction(() async {
        final trimmed = name.trim();
        if (trimmed.isEmpty) {
          return const Invalid<Desk>({
            'name': [FieldIssue(FieldIssueCode.required)],
          });
        }
        final all = await desks();
        final id = _newId();
        await _database
            .into(_database.desks)
            .insert(
              DesksCompanion.insert(
                id: id,
                name: trimmed,
                layout: DeskLayout.single.name,
                position: all.isEmpty ? 0 : all.last.position + 1,
                revision: 0,
              ),
            );
        return Committed<Desk>(await _byId(id));
      });

  Future<MutationOutcome<Desk>> rename(
    String id, {
    required int expected,
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return Future.value(
        const Invalid<Desk>({
          'name': [FieldIssue(FieldIssueCode.required)],
        }),
      );
    }
    return _change(id, expected, (desk) => _bump(desk, name: trimmed));
  }

  Future<MutationOutcome<Desk>> setLayout(
    String id, {
    required int expected,
    required DeskLayout layout,
  }) => _change(id, expected, (desk) async {
    // Tiles beyond the new layout's capacity are removed.
    for (final tile in desk.tiles.skip(layout.capacity)) {
      await _deleteTile(tile.id);
    }
    await _bump(desk, layout: layout);
  });

  /// Shows [sheetRef] on the desk. A full desk replaces [focusedTileId], or
  /// its last tile when none is focused.
  Future<MutationOutcome<Desk>> addSheet(
    String id, {
    required int expected,
    required String sheetRef,
    String? focusedTileId,
    String? viewId,
  }) {
    if (viewId == null && !DeskSheets.all.contains(sheetRef)) {
      return Future.value(
        const Invalid<Desk>({
          'sheetRef': [FieldIssue(FieldIssueCode.invalid)],
        }),
      );
    }
    return _change(id, expected, (desk) async {
      if (desk.tiles.length < desk.layout.capacity) {
        await _insertTiles(
          id,
          [sheetRef],
          from: desk.tiles.length,
          viewId: viewId,
        );
      } else {
        final target =
            desk.tiles.where((tile) => tile.id == focusedTileId).firstOrNull ??
            desk.tiles.last;
        await (_database.update(
          _database.deskTiles,
        )..where((table) => table.id.equals(target.id))).write(
          DeskTilesCompanion(sheetRef: Value(sheetRef), viewId: Value(viewId)),
        );
      }
      await _bump(desk);
    });
  }

  /// Shows a saved view on the desk, placed as [addSheet] places a sheet.
  Future<MutationOutcome<Desk>> addView(
    String id, {
    required int expected,
    required String viewId,
    String? focusedTileId,
  }) async {
    final view = await (_database.select(
      _database.savedViews,
    )..where((table) => table.id.equals(viewId))).getSingleOrNull();
    if (view == null) {
      return const Invalid<Desk>({
        'viewId': [FieldIssue(FieldIssueCode.invalid)],
      });
    }
    return addSheet(
      id,
      expected: expected,
      sheetRef: view.sheetRef,
      focusedTileId: focusedTileId,
      viewId: viewId,
    );
  }

  Future<MutationOutcome<Desk>> removeTile(
    String id, {
    required int expected,
    required String tileId,
  }) => _change(id, expected, (desk) async {
    await _deleteTile(tileId);
    final rest = desk.tiles.where((tile) => tile.id != tileId).toList();
    for (final (position, tile) in rest.indexed) {
      await (_database.update(_database.deskTiles)
            ..where((table) => table.id.equals(tile.id)))
          .write(DeskTilesCompanion(position: Value(position)));
    }
    await _bump(desk);
  });

  /// Restores a starter desk's name, layout and tiles.
  Future<MutationOutcome<Desk>> resetStarter(
    String id, {
    required int expected,
  }) => _change(id, expected, (desk) async {
    final starter = desk.starter;
    if (starter == null) throw const _NotStarter();
    final shape = starterDesk(starter);
    for (final tile in desk.tiles) {
      await _deleteTile(tile.id);
    }
    await _insertTiles(id, shape.sheets);
    await _bump(desk, name: shape.name, layout: shape.layout);
  });

  /// Deletes a desk and its tiles; Today cannot be deleted.
  Future<MutationOutcome<Desk>> deleteDesk(
    String id, {
    required int expected,
  }) => _database.transaction(() async {
    final desk = await _maybeById(id);
    if (desk == null) return const Missing<Desk>();
    if (desk.revision != expected) return const Stale<Desk>();
    if (!desk.canDelete) {
      return const Invalid<Desk>({
        'desk.today': [FieldIssue(FieldIssueCode.conflict)],
      });
    }
    await (_database.delete(
      _database.desks,
    )..where((table) => table.id.equals(id))).go();
    return Committed<Desk>(desk);
  });

  Future<MutationOutcome<Desk>> _change(
    String id,
    int expected,
    Future<void> Function(Desk desk) apply,
  ) async {
    try {
      return await _database.transaction(() async {
        final desk = await _maybeById(id);
        if (desk == null) return const Missing<Desk>();
        if (desk.revision != expected) return const Stale<Desk>();
        await apply(desk);
        return Committed<Desk>(await _byId(id));
      });
    } on _NotStarter {
      return const Invalid<Desk>({
        'desk': [FieldIssue(FieldIssueCode.invalid)],
      });
    }
  }

  Future<void> _bump(Desk desk, {String? name, DeskLayout? layout}) async {
    final changed =
        await (_database.update(_database.desks)..where(
              (table) =>
                  table.id.equals(desk.id) &
                  table.revision.equals(desk.revision),
            ))
            .write(
              DesksCompanion(
                name: name == null ? const Value.absent() : Value(name),
                layout: layout == null
                    ? const Value.absent()
                    : Value(layout.name),
                revision: Value(desk.revision + 1),
              ),
            );
    if (changed != 1) throw StateError('Desk changed during its own write.');
  }

  Future<void> _insertTiles(
    String deskId,
    List<String> sheets, {
    int from = 0,
    String? viewId,
  }) async {
    for (final (index, sheet) in sheets.indexed) {
      await _database
          .into(_database.deskTiles)
          .insert(
            DeskTilesCompanion.insert(
              id: _newId(),
              deskId: deskId,
              position: from + index,
              sheetRef: sheet,
              viewId: Value(viewId),
            ),
          );
    }
  }

  Future<void> _deleteTile(String tileId) => (_database.delete(
    _database.deskTiles,
  )..where((table) => table.id.equals(tileId))).go();

  Future<Desk?> _maybeById(String id) async =>
      (await desks()).where((desk) => desk.id == id).firstOrNull;

  Future<Desk> _byId(String id) async => (await _maybeById(id))!;
}

final class _NotStarter implements Exception {
  const _NotStarter();
}
