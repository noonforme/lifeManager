// The background isolate's wrapper is only exported from drift's remote
// library, which drift marks experimental.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// Whether [error] is SQLite refusing a duplicate in a unique index or
/// primary key. A database opened in the background, as the app opens it,
/// delivers SQLite errors wrapped in [DriftRemoteException].
bool isUniqueViolation(Object error) => switch (error) {
  DriftRemoteException(:final remoteCause) => isUniqueViolation(remoteCause),
  // SQLITE_CONSTRAINT_UNIQUE and SQLITE_CONSTRAINT_PRIMARYKEY only; foreign
  // key, CHECK and NOT NULL failures are other faults.
  SqliteException(:final extendedResultCode) =>
    extendedResultCode == 2067 || extendedResultCode == 1555,
  _ => false,
};
