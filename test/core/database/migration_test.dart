import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:lifeos/core/database/schema_versions.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../support/owned_test_root.dart';

void main() {
  test(
    'released schema snapshots and fingerprints match version two',
    () async {
      final observed = <int, String>{};
      for (var version = 1; version <= currentSchemaVersion; version++) {
        final snapshot = File('drift_schemas/schema_v$version.json');
        expect(await snapshot.exists(), isTrue, reason: snapshot.path);
        final document = jsonDecode(await snapshot.readAsString());
        expect(document, isA<Map<String, Object?>>());
        final map = document as Map<String, Object?>;
        expect(map['_meta'], isA<Map<String, Object?>>());
        expect(map['entities'], isA<List<Object?>>());
        final checksum = await Process.run('sha256sum', [snapshot.path]);
        expect(checksum.exitCode, 0);
        observed[version] = (checksum.stdout as String)
            .split(RegExp(r'\s+'))
            .first;
      }

      expect(currentSchemaVersion, 2);
      expect(releasedMigrationFingerprints, observed);
    },
  );

  test(
    'schema version one upgrades additively to Work schema version two',
    () async {
      final raw = sqlite.sqlite3.openInMemory();
      raw.execute('''
      CREATE TABLE core_metadata (
        id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY,
        application_version TEXT,
        snapshot_schema_version INTEGER,
        snapshot_created_at_utc TEXT
      )
    ''');
      raw.execute('INSERT INTO core_metadata (id) VALUES (1)');
      raw.userVersion = 1;
      final database = AppDatabase(NativeDatabase.opened(raw));
      addTearDown(database.close);

      await database.customSelect('SELECT 1').getSingle();

      expect(raw.userVersion, 2);
      expect(
        raw
            .select("SELECT name FROM sqlite_master WHERE type = 'table'")
            .map((row) => row['name']),
        containsAll(<String>{
          'core_metadata',
          'employments',
          'pay_agreements',
          'work_shifts',
          'shift_breaks',
          'pay_periods',
          'payslips',
        }),
      );
      expect(
        raw
            .select(
              "SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND name = 'one_active_shift'",
            )
            .single['name'],
        'one_active_shift',
      );
      expect(
        raw
            .select('SELECT COUNT(*) AS count FROM core_metadata')
            .single['count'],
        1,
      );
    },
  );

  test('snapshot embeds metadata and validates read-only', () async {
    final root = await OwnedTestRoot.create();
    final destinationRoot = await OwnedTestRoot.create();
    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(() async {
      await service.close();
      await root.dispose();
      await destinationRoot.dispose();
    });
    final destination = File.fromUri(
      destinationRoot.uri.resolve('snapshot.sqlite'),
    );
    final metadata = SnapshotMetadata(
      applicationVersion: '0.1.0',
      schemaVersion: currentSchemaVersion,
      createdAtUtc: DateTime.utc(2026, 9, 29, 12),
    );

    await service.createSnapshot(destination, metadata);
    final identity = await service.validateReadOnly(destination);

    expect(identity.applicationId, lifeOsApplicationId);
    expect(identity.schemaVersion, currentSchemaVersion);
    expect(identity.snapshotMetadata?.applicationVersion, '0.1.0');
    expect(identity.snapshotMetadata?.createdAtUtc, metadata.createdAtUtc);
  });

  test('transaction rolls back all writes when the operation fails', () async {
    final root = await OwnedTestRoot.create();
    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(() async {
      await service.close();
      await root.dispose();
    });

    await expectLater(
      service.transaction(() async {
        await service.writeSnapshotApplicationVersionForTest('must-rollback');
        throw StateError('synthetic failure');
      }),
      throwsStateError,
    );

    expect(await service.readSnapshotApplicationVersionForTest(), isNull);
  });
}

DefaultDatabaseLocation _locationFor(OwnedTestRoot root) {
  return DefaultDatabaseLocation(
    repositoryRoot: Directory.current,
    productionSupportDirectory: () =>
        Directory('${root.directory.parent.path}/production-support-test-only')
            .create(),
  );
}
