import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../outcomes/mutation_outcome.dart';
import 'saved_views.dart';

/// Saved views. Every change bumps the view's revision and is checked
/// against the revision the caller saw.
final class SavedViewRepository {
  SavedViewRepository(this._database, {required this._newId});

  final AppDatabase _database;
  final String Function() _newId;

  Stream<List<SavedView>> watchViews() async* {
    yield await views();
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onTable(_database.savedViews),
    )) {
      yield await views();
    }
  }

  /// Every view in the order saved. A row that no longer validates is left
  /// out rather than shown wrongly.
  Future<List<SavedView>> views() async {
    final rows = await (_database.select(
      _database.savedViews,
    )..orderBy([(table) => OrderingTerm.asc(table.position)])).get();
    return [
      for (final row in rows)
        if (ViewShape.decode(
              sheetRef: row.sheetRef,
              filtersJson: row.filtersJson,
              sortJson: row.sortJson,
              columnsJson: row.columnsJson,
            )
            case final shape?)
          SavedView(
            id: row.id,
            name: row.name,
            shape: shape,
            position: row.position,
            revision: row.revision,
          ),
    ];
  }

  Future<MutationOutcome<SavedView>> createView(String name, ViewShape shape) {
    final trimmed = name.trim();
    final issues = {
      if (trimmed.isEmpty) 'name': const [FieldIssue(FieldIssueCode.required)],
      ...viewShapeIssues(shape),
    };
    if (issues.isNotEmpty) return Future.value(Invalid<SavedView>(issues));
    return _database.transaction(() async {
      final all = await views();
      final id = _newId();
      await _database
          .into(_database.savedViews)
          .insert(
            SavedViewsCompanion.insert(
              id: id,
              name: trimmed,
              sheetRef: shape.sheetRef,
              filtersJson: shape.filtersJson,
              sortJson: Value(shape.sortJson),
              columnsJson: Value(shape.columnsJson),
              position: all.isEmpty ? 0 : all.last.position + 1,
              revision: 0,
            ),
          );
      return Committed<SavedView>((await _byId(id))!);
    });
  }

  Future<MutationOutcome<SavedView>> rename(
    String id, {
    required int expected,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Invalid<SavedView>({
        'name': [FieldIssue(FieldIssueCode.required)],
      });
    }
    return _database.transaction(() async {
      final view = await _byId(id);
      if (view == null) return const Missing<SavedView>();
      if (view.revision != expected) return const Stale<SavedView>();
      await (_database.update(
        _database.savedViews,
      )..where((table) => table.id.equals(id))).write(
        SavedViewsCompanion(
          name: Value(trimmed),
          revision: Value(view.revision + 1),
        ),
      );
      return Committed<SavedView>((await _byId(id))!);
    });
  }

  /// Deletes a view; tiles showing it leave their desks, and those desks'
  /// revisions move on.
  Future<MutationOutcome<SavedView>> deleteView(
    String id, {
    required int expected,
  }) => _database.transaction(() async {
    final view = await _byId(id);
    if (view == null) return const Missing<SavedView>();
    if (view.revision != expected) return const Stale<SavedView>();
    final tiles = await (_database.select(
      _database.deskTiles,
    )..where((table) => table.viewId.equals(id))).get();
    for (final deskId in {for (final tile in tiles) tile.deskId}) {
      await _database.customUpdate(
        'UPDATE desks SET revision = revision + 1 WHERE id = ?',
        variables: [Variable.withString(deskId)],
        updates: {_database.desks},
      );
    }
    await (_database.delete(
      _database.deskTiles,
    )..where((table) => table.viewId.equals(id))).go();
    await (_database.delete(
      _database.savedViews,
    )..where((table) => table.id.equals(id))).go();
    return Committed<SavedView>(view);
  });

  Future<SavedView?> _byId(String id) async =>
      (await views()).where((view) => view.id == id).firstOrNull;
}
