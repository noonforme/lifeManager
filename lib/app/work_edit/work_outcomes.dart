import '../../core/outcomes/mutation_outcome.dart';

/// Words shared by the Work adapters.
abstract final class WorkProblems {
  /// A field the command refused that has no words of its own.
  static const unknownField = 'Check this value.';
}

/// [outcome] of a command on [T] as an outcome on the edited record [S]:
/// a commit is read back through [read] (null when the record is no longer
/// there), and every other outcome keeps its kind (spec 9).
Future<MutationOutcome<S>> settle<T, S>(
  MutationOutcome<T> outcome,
  Future<S?> Function(T value) read,
) async => switch (outcome) {
  Committed(:final value) => switch (await read(value)) {
    final record? => Committed(record),
    null => Missing<S>(),
  },
  Invalid(:final fields) => Invalid<S>(fields),
  Stale() => Stale<S>(),
  Missing() => Missing<S>(),
  Unavailable(:final code) => Unavailable<S>(code),
  Uncertain(:final code) => Uncertain<S>(code),
};
