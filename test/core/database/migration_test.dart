import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:lifeos/core/database/schema_versions.dart';

import '../../support/owned_test_root.dart';

void main() {
  test('released schema snapshot and fingerprints match version one', () async {
    final snapshot = File('drift_schemas/schema_v1.json');

    expect(await snapshot.exists(), isTrue);
    final document = jsonDecode(await snapshot.readAsString());
    expect(document, isA<Map<String, Object?>>());
    final map = document as Map<String, Object?>;
    expect(map['_meta'], isA<Map<String, Object?>>());
    expect(map['entities'], isA<List<Object?>>());
    expect(currentSchemaVersion, 1);
    final checksum = await Process.run('sha256sum', [snapshot.path]);
    expect(checksum.exitCode, 0);
    final digest = (checksum.stdout as String).split(RegExp(r'\s+')).first;
    expect(releasedMigrationFingerprints, {1: digest});
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
