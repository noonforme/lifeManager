import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../support/owned_test_root.dart';
import 'schedule_migration_test.dart' show releasedV1;

const _employment = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11';
const _agreement = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21';
const _retired = {'desks', 'desk_tiles', 'saved_views'};

/// Frozen released SQL, never generated from the schema under test.
File releasedV3(OwnedTestRoot root) {
  final old = releasedV1(root);
  final source = File('${old.path}.fixture-v1');
  old.renameSync(source.path);
  final raw = sqlite.sqlite3.open(old.path);
  raw.execute('PRAGMA application_id = $lifeOsApplicationId');
  raw.execute(
    File('test/core/database/fixtures/schema_v3.sql').readAsStringSync(),
  );
  raw.execute('ATTACH DATABASE ? AS old', [source.path]);
  for (final table in _tables(raw, schema: 'old')) {
    final columns = raw
        .select('PRAGMA old.table_info("$table")')
        .map((r) => '"${r['name']}"')
        .join(',');
    raw.execute(
      'INSERT INTO "$table" ($columns) SELECT $columns FROM old."$table"',
    );
  }
  // These are the released schema-3 tracker conversion results.
  raw.execute("UPDATE work_shifts SET state = 'draft' WHERE state = 'onBreak'");
  raw.execute('DELETE FROM shift_breaks WHERE end_utc_micros IS NULL');
  raw.execute(
    "INSERT INTO work_schedules VALUES ('schedule', 1, '$_employment', 'Synthetic rotation', 'Europe/Vilnius', '2026-09-01', '2026-09-01', NULL, 0, 0)",
  );
  raw.execute(
    "INSERT INTO work_schedule_shift_types VALUES ('schedule', 1, 'day', 0, 'Day', 480, 960, 0, '[]')",
  );
  raw.execute(
    "INSERT INTO work_schedule_blocks VALUES ('schedule', 1, 0, 3, 'day')",
  );
  raw.execute(
    "INSERT INTO work_day_exceptions (id, employment_id, date, kind, reason, created_at_utc_micros, updated_at_utc_micros, revision) VALUES ('exception', '$_employment', '2026-09-09', 'cancelled', 'Synthetic cancellation', 0, 0, 0)",
  );
  raw.execute(
    "INSERT INTO work_leave_records (id, employment_id, date, leave_type, paid_minutes, agreement_id, schedule_id, schedule_version, state, created_at_utc_micros, updated_at_utc_micros, revision) VALUES ('leave', '$_employment', '2026-09-10', 'vacation', 480, '$_agreement', 'schedule', 1, 'confirmed', 0, 0, 0)",
  );
  raw.execute("INSERT INTO preferences VALUES ('appearance', 'night')");
  raw.execute(
    "INSERT INTO desks VALUES ('desk', 'Synthetic desk', NULL, 'single', 0, 0)",
  );
  raw.execute(
    "INSERT INTO saved_views VALUES ('view', 'Synthetic view', 'work/shifts', '{}', NULL, NULL, 0, 0)",
  );
  raw.execute(
    "INSERT INTO desk_tiles VALUES ('tile', 'desk', 0, 'work/shifts', 'view')",
  );
  raw.execute('DETACH DATABASE old');
  raw.userVersion = 3;
  expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
  raw.close();
  source.deleteSync();
  return old;
}

Set<String> _tables(sqlite.Database raw, {String schema = 'main'}) => raw
    .select(
      "SELECT name FROM $schema.sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    )
    .map((r) => r['name'] as String)
    .toSet();

Map<String, Object?> _contents(sqlite.Database raw) => {
  for (final table in _tables(raw).difference(_retired))
    table: raw
        .select('SELECT * FROM "$table" ORDER BY rowid')
        .map((r) => Map<String, Object?>.from(r))
        .toList(),
};

Future<DriftDatabaseService> _open(OwnedTestRoot root) =>
    DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: DefaultDatabaseLocation(
        repositoryRoot: Directory.current,
        productionSupportDirectory: () => Directory(
          '${root.directory.parent.path}/production-support-test-only',
        ).create(),
      ),
    );

void main() {
  test('released 3 loses only desk/view tables, preserving every Work/history row and preferences; backup and reopen', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = releasedV3(root);
    final before = sqlite.sqlite3.open(file.path);
    final contents = _contents(before);
    final tables = _tables(before);
    before.close();
    final service = await _open(root);
    await service.database.customSelect('SELECT 1').get();
    await service.close();
    final after = sqlite.sqlite3.open(file.path);
    expect(after.userVersion, 4);
    expect(_tables(after), tables.difference(_retired));
    expect(_contents(after), contents);
    expect(after.select('PRAGMA foreign_key_check'), isEmpty);
    expect(after.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(
      after
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'one_confirmed_%'",
          )
          .length,
      2,
    );
    after.close();
    final backups = root.directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('.v3-backup-'))
        .toList();
    expect(backups, hasLength(1));
    final backup = sqlite.sqlite3.open(backups.single.path);
    expect(backup.userVersion, 3);
    expect(_tables(backup), tables);
    expect(_contents(backup), contents);
    backup.close();
    final reopened = await _open(root);
    await reopened.database.customSelect('SELECT 1').get();
    await reopened.close();
    expect(
      root.directory.listSync().whereType<File>().where(
        (f) => f.path.contains('.v3-backup-'),
      ),
      hasLength(1),
    );
  });

  test('failure after the first DROP rolls back the full released-3 schema and data', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = releasedV3(root);
    final before = sqlite.sqlite3.open(file.path);
    before.execute('PRAGMA foreign_keys = ON');
    before.execute(
      'CREATE TABLE retention_guard (id TEXT PRIMARY KEY, desk_id TEXT REFERENCES desks(id) ON DELETE RESTRICT)',
    );
    before.execute("INSERT INTO retention_guard VALUES ('guard', 'desk')");
    final contents = _contents(before);
    final shape = before
        .select('SELECT name, sql FROM sqlite_master ORDER BY name')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    before.close();
    final database = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    await expectLater(
      database.customSelect('SELECT 1').get(),
      throwsA(anything),
    );
    await database.close();
    final after = sqlite.sqlite3.open(file.path);
    expect(after.userVersion, 3);
    expect(_contents(after), contents);
    expect(
      after
          .select('SELECT name, sql FROM sqlite_master ORDER BY name')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      shape,
    );
    expect(after.select('SELECT * FROM desk_tiles'), hasLength(1));
    after.close();
  });
}
