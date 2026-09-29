final class DatabasePragmas {
  const DatabasePragmas({
    required this.applicationId,
    required this.foreignKeys,
    required this.journalMode,
    required this.busyTimeoutMilliseconds,
    required this.synchronous,
  });

  final int applicationId;
  final bool foreignKeys;
  final String journalMode;
  final int busyTimeoutMilliseconds;
  final int synchronous;
}
