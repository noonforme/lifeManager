import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:lifeos/core/history/record_event_dao.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../core/database/cutover_migration_test.dart' show releasedV3;
import '../support/owned_test_root.dart';

const _employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _retired = {'desk_tiles', 'desks', 'saved_views'};

Map<String, Object?> _rows(sqlite.Database raw) => {
  for (final row in raw.select(
    "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
  ))
    if (!_retired.contains(row['name']) && row['name'] != 'retention_guard')
      row['name'] as String: raw
          .select('SELECT * FROM "${row['name']}" ORDER BY rowid')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
};

void main() {
  test('failed released-3 upgrade restores records and writable application', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = releasedV3(root);
    final before = sqlite.sqlite3.open(file.path);
    final preserved = _rows(before);
    // Same deterministic failure as the cutover regression: first child DROP
    // executes, then this synthetic FK prevents DROP of the parent desks table.
    before.execute('PRAGMA foreign_keys=ON');
    before.execute(
      'CREATE TABLE retention_guard (id TEXT PRIMARY KEY, '
      'desk_id TEXT REFERENCES desks(id) ON DELETE RESTRICT)',
    );
    before.execute("INSERT INTO retention_guard VALUES ('guard', 'desk')");
    final shape = before
        .select('SELECT name, sql FROM sqlite_master ORDER BY name')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    before.close();

    Future<DriftDatabaseService> open(OwnedTestRoot owned) =>
        DriftDatabaseService.open(
          DatabaseConfig.test(root: owned.uri, markerToken: owned.token),
          location: DefaultDatabaseLocation(
            repositoryRoot: Directory.current,
            productionSupportDirectory: () async =>
                Directory('${owned.directory.path}/unused-support').create(),
          ),
        );
    // Production service creates its pre-upgrade snapshot before real migration.
    await expectLater(
      open(root),
      throwsA(
        predicate<Object>(
          (error) =>
              error.toString().contains('FOREIGN KEY constraint failed') &&
              error.toString().contains('DROP TABLE desks'),
          'wrapped SQLite foreign-key failure on DROP TABLE desks',
        ),
      ),
    );
    final failed = sqlite.sqlite3.open(file.path);
    expect(failed.userVersion, 3);
    expect(_rows(failed), preserved);
    expect(
      failed
          .select('SELECT name, sql FROM sqlite_master ORDER BY name')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      shape,
    );
    expect(failed.select('SELECT * FROM desk_tiles'), hasLength(1));
    expect(failed.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(failed.select('PRAGMA foreign_key_check'), isEmpty);
    failed.close();
    final snapshot = root.directory.listSync().whereType<File>().singleWhere(
      (f) => f.path.contains('.v3-backup-'),
    );
    final snapshotBytes = snapshot.readAsBytesSync();

    // Release 05 deliberately accepts only current-schema backups. For the
    // older service snapshot, clone via SQLite backup into a new owned root.
    // Never overwrite the failed source, and never decrement user_version.
    final recovered = await OwnedTestRoot.create();
    addTearDown(recovered.dispose);
    final from = sqlite.sqlite3.open(
      snapshot.path,
      mode: sqlite.OpenMode.readOnly,
    );
    final to = sqlite.sqlite3.open(
      '${recovered.directory.path}/${DefaultDatabaseLocation.databaseFilename}',
    );
    try {
      expect(from.userVersion, 3);
      expect(_rows(from), preserved);
      await from.backup(to).drain<void>();
      expect(_rows(to), preserved);
      // Remove only our known synthetic obstruction from the recovered clone.
      to.execute('DROP TABLE retention_guard');
    } finally {
      to.close();
      from.close();
    }
    final service = await open(recovered);
    try {
      expect(
        (await service.database.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        4,
      );
    } finally {
      await service.close();
    }
    final upgraded = sqlite.sqlite3.open(
      '${recovered.directory.path}/${DefaultDatabaseLocation.databaseFilename}',
    );
    expect(_rows(upgraded), preserved);
    expect(
      upgraded.select('PRAGMA integrity_check').single.values.single,
      'ok',
    );
    expect(upgraded.select('PRAGMA foreign_key_check'), isEmpty);
    upgraded.close();
    expect(snapshot.readAsBytesSync(), snapshotBytes);

    // Exercise current-schema recovery CLI as well, then actual application
    // reads/writes/history and reopen on the restored database.
    await File('${recovered.directory.path}/.lifeos-synthetic-root')
        .writeAsString('lifeos-synthetic-only-v1\n');
    Future<Directory> transfer(
      String operation,
      Directory source,
      String suffix,
    ) async {
      final destination = Directory(
        '/tmp/lifeos-recovery-${root.token}-drill-$suffix',
      );
      final result = await Process.run('tool/operations/db-recovery.sh', [
        operation,
        '--root',
        source.path,
        '--marker-token',
        recovered.token,
        '--destination',
        destination.path,
        '--destination-token',
        recovered.token,
      ]).timeout(const Duration(seconds: 15));
      if (result.exitCode == 0) {
        addTearDown(() async {
          expect(
            await File('${destination.path}/.lifeos-test-root').readAsString(),
            recovered.token,
          );
          await destination.delete(recursive: true);
        });
      }
      expect(result.stderr, isEmpty);
      expect(result.exitCode, 0, reason: '${result.stdout}');
      expect(
        (jsonDecode(result.stdout as String) as Map)['records_match'],
        true,
      );
      return destination;
    }

    final snapshotRoot = await transfer(
      'backup',
      recovered.directory,
      'snapshot',
    );
    final restoredRoot = await transfer('restore', snapshotRoot, 'restored');
    Future<DriftDatabaseService> openRestored() => DriftDatabaseService.open(
      DatabaseConfig.test(root: restoredRoot.uri, markerToken: recovered.token),
      location: DefaultDatabaseLocation(
        repositoryRoot: Directory.current,
        productionSupportDirectory: () async =>
            Directory('${root.directory.path}/unused-support').create(),
      ),
    );
    final app = await openRestored();
    try {
      final work = DriftWorkRepository(app.database);
      final original = (await WorkReads(app.database).employment(_employment))!
          .value;
      final history = await RecordEventDao(app.database)
          .forRecord('employment', _employment.value);
      final changed = original.renamed(
        name: 'Synthetic drill recovered',
        legalLabel: original.legalLabel,
        nowUtc: DateTime.utc(2026, 11, 14),
      );
      await work.updateEmployment(changed, expected: original.revision);
      expect(
        (await WorkReads(app.database).employment(_employment))!.value.name,
        changed.name,
      );
      expect(
        await RecordEventDao(app.database)
            .forRecord('employment', _employment.value),
        hasLength(history.length + 1),
      );
    } finally {
      await app.close();
    }
    final reopened = await openRestored();
    try {
      expect(
        (await WorkReads(reopened.database).employment(_employment))!
            .value
            .name,
        'Synthetic drill recovered',
      );
      expect((await reopened.readPragmas()).foreignKeys, true);
    } finally {
      await reopened.close();
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}
