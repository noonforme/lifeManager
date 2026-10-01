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
  test('the reset schema has one released snapshot, version one', () async {
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

    expect(currentSchemaVersion, 1);
    expect(releasedMigrationFingerprints, observed);
  });

  test(
    'a fresh database is created at version one without manual overtime',
    () async {
      final raw = sqlite.sqlite3.openInMemory();
      final database = AppDatabase(NativeDatabase.opened(raw));
      addTearDown(database.close);

      await database.customSelect('SELECT 1').getSingle();

      expect(raw.userVersion, 1);
      final shiftColumns = raw
          .select('PRAGMA table_info(work_shifts)')
          .map((row) => row['name']);
      expect(shiftColumns, isNot(contains('overtime_minutes')));
      final agreementColumns = raw
          .select('PRAGMA table_info(pay_agreements)')
          .map((row) => row['name']);
      expect(
        agreementColumns,
        containsAll(<String>[
          'night_enabled',
          'night_start_minute',
          'night_end_minute',
          'night_multiplier_numerator',
          'night_multiplier_denominator',
          'holiday_calendar',
          'holiday_multiplier_numerator',
          'holiday_multiplier_denominator',
          'premium_stacking',
        ]),
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
    },
  );

  group('a database from an earlier development build', () {
    Future<File> earlierBuild(OwnedTestRoot root, int userVersion) async {
      final file = File.fromUri(root.uri.resolve('lifeos-native-v1.sqlite'));
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('PRAGMA application_id = $lifeOsApplicationId');
      raw.execute('CREATE TABLE core_metadata (id INTEGER PRIMARY KEY)');
      raw.execute(
        'CREATE TABLE pay_agreements (id TEXT PRIMARY KEY, basis TEXT)',
      );
      raw.userVersion = userVersion;
      raw.close();
      return file;
    }

    for (final version in [1, 2]) {
      test('at user_version $version is refused, not migrated', () async {
        final root = await OwnedTestRoot.create();
        addTearDown(root.dispose);
        final file = await earlierBuild(root, version);

        await expectLater(
          DriftDatabaseService.open(
            DatabaseConfig.test(root: root.uri, markerToken: root.token),
            location: _locationFor(root),
          ),
          throwsA(
            isA<DatabaseFromEarlierBuild>().having(
              (error) => error.path,
              'path',
              file.path,
            ),
          ),
        );

        final unchanged = sqlite.sqlite3.open(file.path);
        addTearDown(unchanged.close);
        expect(unchanged.userVersion, version);
      });
    }
  });

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
