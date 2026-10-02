import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'record_events.dart';

/// Reads and appends `record_events` rows. Appends belong inside the
/// mutation's own transaction, so a failed write leaves no event.
final class RecordEventDao implements RecordHistory {
  const RecordEventDao(this._database);

  final AppDatabase _database;

  $RecordEventsTable get _table => _database.recordEvents;

  Future<void> append({
    required String recordKind,
    required String recordId,
    required DateTime atUtc,
    required RecordEventKind kind,
    required List<FieldChange> changes,
    required int revisionAfter,
    String? reason,
  }) async {
    if (!atUtc.isUtc) throw ArgumentError.value(atUtc, 'atUtc');
    await _database.customInsert(
      'INSERT INTO record_events (record_kind, record_id, at_utc_micros, '
      'kind, changes_json, reason, revision_after) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable(recordKind),
        Variable(recordId),
        Variable(atUtc.microsecondsSinceEpoch),
        Variable(kind.name),
        Variable(_encode(changes)),
        Variable(reason),
        Variable(revisionAfter),
      ],
      updates: {_table},
    );
  }

  /// Removes a deleted record's history with it.
  Future<int> deleteFor(String recordKind, String recordId) =>
      _database.customUpdate(
        'DELETE FROM record_events WHERE record_kind = ? AND record_id = ?',
        variables: [Variable(recordKind), Variable(recordId)],
        updates: {_table},
        updateKind: UpdateKind.delete,
      );

  /// Every event at or after [fromUtc] and before [toUtc], oldest first.
  Future<List<RecordEvent>> between(DateTime fromUtc, DateTime toUtc) async =>
      _decodeRows(
        await _database
            .customSelect(
              'SELECT * FROM record_events '
              'WHERE at_utc_micros >= ? AND at_utc_micros < ? ORDER BY id',
              variables: [
                Variable(fromUtc.microsecondsSinceEpoch),
                Variable(toUtc.microsecondsSinceEpoch),
              ],
              readsFrom: {_table},
            )
            .get(),
      );

  @override
  Stream<List<RecordEvent>> watch(String recordKind, String recordId) =>
      _query(recordKind, recordId).watch().map(_decodeRows);

  Future<List<RecordEvent>> forRecord(
    String recordKind,
    String recordId,
  ) async => _decodeRows(await _query(recordKind, recordId).get());

  Selectable<QueryRow> _query(String recordKind, String recordId) =>
      _database.customSelect(
        'SELECT * FROM record_events WHERE record_kind = ? AND record_id = ? '
        'ORDER BY id',
        variables: [Variable(recordKind), Variable(recordId)],
        readsFrom: {_table},
      );

  List<RecordEvent> _decodeRows(List<QueryRow> rows) => [
    for (final row in rows)
      RecordEvent(
        id: row.read<int>('id'),
        recordKind: row.read<String>('record_kind'),
        recordId: row.read<String>('record_id'),
        atUtc: DateTime.fromMicrosecondsSinceEpoch(
          row.read<int>('at_utc_micros'),
          isUtc: true,
        ),
        kind: RecordEventKind.values.byName(row.read<String>('kind')),
        changes: _decode(row.read<String>('changes_json')),
        reason: row.readNullable<String>('reason'),
        revisionAfter: row.read<int>('revision_after'),
      ),
  ];
}

String _encode(List<FieldChange> changes) => jsonEncode([
  for (final change in changes)
    {'field': change.field, 'before': change.before, 'after': change.after},
]);

List<FieldChange> _decode(String json) => [
  for (final item in jsonDecode(json) as List<Object?>)
    if (item case {
      'field': final String field,
      'before': final String? before,
      'after': final String? after,
    })
      FieldChange(field, before, after),
];
