import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:sqlite3/sqlite3.dart' hide DatabaseConfig;

import '../../support/owned_test_root.dart';

void main() {
  test('fresh database receives identity and required pragmas', () async {
    final root = await OwnedTestRoot.create();
    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(() async {
      await service.close();
      await root.dispose();
    });

    final pragmas = await service.readPragmas();

    expect(pragmas.applicationId, lifeOsApplicationId);
    expect(pragmas.foreignKeys, isTrue);
    expect(pragmas.journalMode, 'wal');
    expect(pragmas.busyTimeoutMilliseconds, greaterThanOrEqualTo(5000));
    expect(pragmas.synchronous, 2);
  });

  test(
    'nonempty SQLite with wrong identity is rejected before migration',
    () async {
      final root = await OwnedTestRoot.create();
      addTearDown(root.dispose);
      final file = File.fromUri(root.uri.resolve('lifeos-native-v1.sqlite'));
      final database = sqlite3.open(file.path);
      database.execute('CREATE TABLE foreign_data (value TEXT NOT NULL)');
      database.close();

      await expectLater(
        DriftDatabaseService.open(
          DatabaseConfig.test(root: root.uri, markerToken: root.token),
          location: _locationFor(root),
        ),
        throwsA(isA<DatabaseIdentityMismatch>()),
      );

      final unchanged = sqlite3.open(file.path);
      addTearDown(unchanged.close);
      expect(unchanged.userVersion, 0);
      expect(
        unchanged
            .select(
              "SELECT count(*) AS count FROM sqlite_master WHERE name = 'core_metadata'",
            )
            .single['count'],
        0,
      );
    },
  );

  test('nonempty SQLite with absent identity is rejected', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = File.fromUri(root.uri.resolve('lifeos-native-v1.sqlite'));
    await file.writeAsBytes(List<int>.filled(64, 1), flush: true);

    await expectLater(
      DriftDatabaseService.open(
        DatabaseConfig.test(root: root.uri, markerToken: root.token),
        location: _locationFor(root),
      ),
      throwsA(
        anyOf(isA<DatabaseIdentityMismatch>(), isA<DatabaseOpenFailure>()),
      ),
    );
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
