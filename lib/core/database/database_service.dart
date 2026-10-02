import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'app_database.dart';
import 'database_config.dart';
import 'database_identity.dart';
import 'database_location.dart';
import 'database_pragmas.dart';
import 'schema_versions.dart';

abstract interface class DatabaseService {
  static Future<DatabaseService> open(DatabaseConfig config) {
    return DriftDatabaseService.open(config);
  }

  AppDatabase get database;

  Future<T> transaction<T>(Future<T> Function() operation);
  Future<void> createSnapshot(File destination, SnapshotMetadata metadata);
  Future<DatabaseIdentity> validateReadOnly(File snapshot);
  Future<DatabasePragmas> readPragmas();
  Future<void> writeSnapshotApplicationVersionForTest(String value);
  Future<String?> readSnapshotApplicationVersionForTest();
  Future<void> close();
}

final class DriftDatabaseService implements DatabaseService {
  DriftDatabaseService._(this._file, this._database);

  final File _file;
  final AppDatabase _database;

  @override
  AppDatabase get database => _database;

  static Future<DriftDatabaseService> open(
    DatabaseConfig config, {
    DatabaseLocation? location,
  }) async {
    final file = await (location ?? DefaultDatabaseLocation()).resolve(config);
    final existed = await file.exists();
    final wasEmpty = !existed || await file.length() == 0;

    if (!wasEmpty) {
      _validateExistingIdentity(file);
    }

    final executor = NativeDatabase.createInBackground(
      file,
      setup: wasEmpty ? _configureFreshConnection : _configureConnection,
    );
    final database = AppDatabase(executor);
    final service = DriftDatabaseService._(file, database);

    try {
      await database.customSelect('SELECT 1').getSingle();
      await service._validatePragmas();
      return service;
    } on Object {
      await database.close();
      rethrow;
    }
  }

  static void _validateExistingIdentity(File file) {
    sqlite.Database? raw;
    try {
      raw = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
      final applicationId = _scalarInt(raw, 'PRAGMA application_id');
      if (applicationId != lifeOsApplicationId) {
        throw const DatabaseIdentityMismatch();
      }
      if (_isFromEarlierBuild(raw)) {
        throw DatabaseFromEarlierBuild(path: file.path);
      }
    } on DatabaseIdentityMismatch {
      rethrow;
    } on DatabaseFromEarlierBuild {
      rethrow;
    } on Object {
      throw const DatabaseOpenFailure();
    } finally {
      raw?.close();
    }
  }

  /// Before the reset, development builds wrote schema versions 1 and 2,
  /// and version 1 itself grew while unreleased. A version 1 database is
  /// current only if it has every table and column the schema now has.
  static bool _isFromEarlierBuild(sqlite.Database raw) {
    final version = raw.userVersion;
    if (version == 0) return false;
    if (version != currentSchemaVersion) return true;
    final tables = raw
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'])
        .toSet();
    if (!tables.containsAll(const [
      'record_events',
      'desks',
      'desk_tiles',
      'saved_views',
      'preferences',
    ])) {
      return true;
    }
    final columns = raw
        .select('PRAGMA table_info(pay_agreements)')
        .map((row) => row['name'])
        .toSet();
    return !columns.contains('premium_stacking');
  }

  static void _configureFreshConnection(sqlite.Database database) {
    database.execute('PRAGMA application_id = $lifeOsApplicationId');
    _configureConnection(database);
  }

  static void _configureConnection(sqlite.Database database) {
    database.execute('PRAGMA foreign_keys = ON');
    database.execute('PRAGMA journal_mode = WAL');
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA synchronous = FULL');
  }

  static int _scalarInt(sqlite.Database database, String sql) {
    return database.select(sql).single.values.single! as int;
  }

  @override
  Future<T> transaction<T>(Future<T> Function() operation) {
    return _database.transaction(operation);
  }

  @override
  Future<DatabasePragmas> readPragmas() async {
    return DatabasePragmas(
      applicationId: await _readInt('PRAGMA application_id'),
      foreignKeys: await _readInt('PRAGMA foreign_keys') == 1,
      journalMode: (await _readValue('PRAGMA journal_mode') as String)
          .toLowerCase(),
      busyTimeoutMilliseconds: await _readInt('PRAGMA busy_timeout'),
      synchronous: await _readInt('PRAGMA synchronous'),
    );
  }

  Future<void> _validatePragmas() async {
    final pragmas = await readPragmas();
    if (pragmas.applicationId != lifeOsApplicationId ||
        !pragmas.foreignKeys ||
        pragmas.journalMode != 'wal' ||
        pragmas.busyTimeoutMilliseconds < 5000 ||
        pragmas.synchronous != 2) {
      throw const DatabaseOpenFailure();
    }
  }

  Future<int> _readInt(String sql) async => await _readValue(sql) as int;

  Future<Object> _readValue(String sql) async {
    final row = await _database.customSelect(sql).getSingle();
    final value = row.data.values.single;
    if (value == null) {
      throw const DatabaseOpenFailure();
    }
    return value as Object;
  }

  @override
  Future<void> createSnapshot(
    File destination,
    SnapshotMetadata metadata,
  ) async {
    if (await destination.exists()) {
      await destination.delete();
    }

    final source = sqlite.sqlite3.open(
      _file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    final target = sqlite.sqlite3.open(destination.path);
    try {
      await source.backup(target).drain<void>();
      target.execute(
        'UPDATE core_metadata SET application_version = ?, '
        'snapshot_schema_version = ?, snapshot_created_at_utc = ? WHERE id = 1',
        [
          metadata.applicationVersion,
          metadata.schemaVersion,
          metadata.createdAtUtc.toUtc().toIso8601String(),
        ],
      );
    } finally {
      target.close();
      source.close();
    }
  }

  @override
  Future<DatabaseIdentity> validateReadOnly(File snapshot) async {
    sqlite.Database? database;
    try {
      database = sqlite.sqlite3.open(
        snapshot.path,
        mode: sqlite.OpenMode.readOnly,
      );
      final applicationId = _scalarInt(database, 'PRAGMA application_id');
      final schemaVersion = database.userVersion;
      if (applicationId != lifeOsApplicationId ||
          schemaVersion < 1 ||
          schemaVersion > currentSchemaVersion) {
        throw const DatabaseIdentityMismatch();
      }
      final integrity = database
          .select('PRAGMA integrity_check')
          .single
          .values
          .single;
      if (integrity != 'ok') {
        throw const DatabaseValidationFailure();
      }
      final row = database
          .select(
            'SELECT application_version, snapshot_schema_version, '
            'snapshot_created_at_utc FROM core_metadata WHERE id = 1',
          )
          .single;
      final applicationVersion = row['application_version'] as String?;
      final metadataSchemaVersion = row['snapshot_schema_version'] as int?;
      final createdAt = DateTime.tryParse(
        row['snapshot_created_at_utc'] as String? ?? '',
      );
      if (applicationVersion == null ||
          applicationVersion.isEmpty ||
          metadataSchemaVersion == null ||
          metadataSchemaVersion != schemaVersion ||
          createdAt == null ||
          !createdAt.isUtc) {
        throw const DatabaseValidationFailure();
      }
      return DatabaseIdentity(
        applicationId: applicationId,
        schemaVersion: schemaVersion,
        snapshotMetadata: SnapshotMetadata(
          applicationVersion: applicationVersion,
          schemaVersion: metadataSchemaVersion,
          createdAtUtc: createdAt,
        ),
      );
    } on DatabaseIdentityMismatch {
      rethrow;
    } on DatabaseValidationFailure {
      rethrow;
    } on Object {
      throw const DatabaseValidationFailure();
    } finally {
      database?.close();
    }
  }

  @override
  Future<void> writeSnapshotApplicationVersionForTest(String value) async {
    await (_database.update(_database.coreMetadata)
          ..where((row) => row.id.equals(1)))
        .write(CoreMetadataCompanion(applicationVersion: Value(value)));
  }

  @override
  Future<String?> readSnapshotApplicationVersionForTest() async {
    final row = await (_database.select(
      _database.coreMetadata,
    )..where((row) => row.id.equals(1))).getSingle();
    return row.applicationVersion;
  }

  @override
  Future<void> close() => _database.close();
}
