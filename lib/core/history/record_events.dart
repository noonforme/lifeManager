import 'package:drift/drift.dart';

/// What happened to a record (shell spec section 8).
enum RecordEventKind { created, changed, finalized, voided, replaced, reviewed }

/// One field's display values before and after an event; null when the
/// field was empty.
final class FieldChange {
  const FieldChange(this.field, this.before, this.after);

  final String field;
  final String? before;
  final String? after;

  @override
  bool operator ==(Object other) =>
      other is FieldChange &&
      field == other.field &&
      before == other.before &&
      after == other.after;

  @override
  int get hashCode => Object.hash(field, before, after);

  @override
  String toString() => '$field: $before → $after';
}

/// An append-only history entry. Its changes are local record content: they
/// are never logged, never in diagnostics and never in routes.
final class RecordEvent {
  const RecordEvent({
    required this.id,
    required this.recordKind,
    required this.recordId,
    required this.atUtc,
    required this.kind,
    required this.changes,
    required this.revisionAfter,
    this.reason,
  });

  final int id;
  final String recordKind;
  final String recordId;
  final DateTime atUtc;
  final RecordEventKind kind;
  final List<FieldChange> changes;
  final String? reason;
  final int revisionAfter;
}

abstract interface class RecordHistory {
  /// The record's events, oldest first.
  Stream<List<RecordEvent>> watch(String recordKind, String recordId);
}

/// The fields whose display value differs between two fact snapshots, in
/// the order [after] lists them, then any fields only [before] has.
List<FieldChange> diffFacts(
  Map<String, String?> before,
  Map<String, String?> after,
) => [
  for (final MapEntry(:key, :value) in after.entries)
    if (before[key] != value) FieldChange(key, before[key], value),
  for (final MapEntry(:key, :value) in before.entries)
    if (!after.containsKey(key) && value != null) FieldChange(key, value, null),
];

@DataClassName('RecordEventRow')
class RecordEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordKind => text()();
  TextColumn get recordId => text()();
  IntColumn get atUtcMicros => integer()();
  TextColumn get kind => text().check(
    const CustomExpression<bool>(
      "kind IN ('created', 'changed', 'finalized', 'voided', 'replaced', "
      "'reviewed')",
    ),
  )();
  TextColumn get changesJson => text()();
  TextColumn get reason => text().nullable()();
  IntColumn get revisionAfter =>
      integer().check(const CustomExpression<bool>('revision_after >= 0'))();
}
