sealed class MutationOutcome<T> {
  const MutationOutcome();
}

final class Committed<T> extends MutationOutcome<T> {
  const Committed(this.value);

  final T value;
}

final class Invalid<T> extends MutationOutcome<T> {
  const Invalid(this.fields);

  final Map<String, List<FieldIssue>> fields;
}

final class Stale<T> extends MutationOutcome<T> {
  const Stale();
}

final class Missing<T> extends MutationOutcome<T> {
  const Missing();
}

final class Unavailable<T> extends MutationOutcome<T> {
  const Unavailable(this.code);

  final SafeFailureCode code;
}

final class Uncertain<T> extends MutationOutcome<T> {
  const Uncertain(this.code);

  final SafeFailureCode code;
}

enum SafeFailureCode {
  storageUnavailable,
  databaseIdentityMismatch,
  migrationFailed,
  invalidTimezone,
  commitOutcomeUnknown,
}

enum FieldIssueCode { required, invalid, conflict, outOfRange, unavailable }

final class FieldIssue {
  const FieldIssue(this.code);

  final FieldIssueCode code;

  @override
  bool operator ==(Object other) => other is FieldIssue && code == other.code;

  @override
  int get hashCode => code.hashCode;
}
