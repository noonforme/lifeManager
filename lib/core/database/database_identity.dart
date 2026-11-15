const lifeOsApplicationId = 0x4C49464F;

final class DatabaseIdentity {
  const DatabaseIdentity({
    required this.applicationId,
    required this.schemaVersion,
    required this.snapshotMetadata,
  });

  final int applicationId;
  final int schemaVersion;
  final SnapshotMetadata? snapshotMetadata;
}

final class SnapshotMetadata {
  const SnapshotMetadata({
    required this.applicationVersion,
    required this.schemaVersion,
    required this.createdAtUtc,
  });

  final String applicationVersion;
  final int schemaVersion;
  final DateTime createdAtUtc;
}

final class DatabaseIdentityMismatch implements Exception {
  const DatabaseIdentityMismatch();
}

/// A database made by a development build from before the schema reset.
/// It is never migrated; the owner removes it and starts again.
final class DatabaseFromEarlierBuild implements Exception {
  const DatabaseFromEarlierBuild({this.path, this.from, this.to});

  final String? path;
  final int? from;
  final int? to;
}

final class DatabaseOpenFailure implements Exception {
  const DatabaseOpenFailure();
}

final class DatabaseValidationFailure implements Exception {
  const DatabaseValidationFailure();
}
