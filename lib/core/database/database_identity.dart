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

final class DatabaseOpenFailure implements Exception {
  const DatabaseOpenFailure();
}

final class DatabaseValidationFailure implements Exception {
  const DatabaseValidationFailure();
}
