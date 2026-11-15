enum SafeOperation {
  bootstrap,
  databaseOpen,
  databaseMigration,
  databaseClose,
  backupCreate,
  exportCreate,
}

enum SafeOutcome { committed, unavailable, uncertain }

enum SafeExceptionClass {
  fileSystemException,
  sqliteException,
  stateError,
  formatException,
  unknown,
}

final class SafeDiagnostic {
  const SafeDiagnostic({
    required this.operation,
    required this.outcome,
    required this.exceptionClass,
    required this.appVersion,
    required this.schemaVersion,
  });

  final SafeOperation operation;
  final SafeOutcome outcome;
  final SafeExceptionClass exceptionClass;
  final String appVersion;
  final int schemaVersion;

  Map<String, Object> toJson() => {
    'operation': operation.name,
    'outcome': outcome.name,
    'exceptionClass': exceptionClass.name,
    'appVersion': appVersion,
    'schemaVersion': schemaVersion,
  };
}
