import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/database_config.dart';
import 'package:lifeos/core/database/database_identity.dart';
import 'package:lifeos/core/database/database_location.dart';
import 'package:lifeos/core/database/database_service.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/data/work_repository.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../../support/owned_test_root.dart';

/// A released schema-1 database with synthetic records, as an owner
/// would have it before upgrading.
File releasedV1(OwnedTestRoot root) {
  final file = File.fromUri(root.uri.resolve('lifeos-native-v1.sqlite'));
  final raw = sqlite.sqlite3.open(file.path);
  raw.execute('PRAGMA application_id = $lifeOsApplicationId');
  raw.execute(
    File('test/core/database/fixtures/schema_v1.sql').readAsStringSync(),
  );
  raw.execute('INSERT INTO core_metadata (id) VALUES (1)');
  raw.execute(
    "INSERT INTO employments VALUES ('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', 'Synthetic depot', NULL, "
    "'active', 0, 0, 0)",
  );
  raw.execute(
    'INSERT INTO pay_agreements (id, employment_id, version, effective_start, '
    'effective_end, hourly_rate_micro_eur, basis, overtime_threshold_minutes, '
    'overtime_multiplier_numerator, overtime_multiplier_denominator, '
    'night_enabled, night_start_minute, night_end_minute, '
    'night_multiplier_numerator, night_multiplier_denominator, '
    'holiday_calendar, holiday_multiplier_numerator, '
    'holiday_multiplier_denominator, premium_stacking, label, note, '
    "created_at_utc_micros, revision) VALUES ('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', 1, '2026-09-01', "
    "NULL, 18400000, 'gross', 480, 3, 2, 1, 1320, 360, 3, 2, 'lithuania', "
    "2, 1, 'highest', NULL, NULL, 0, 0)",
  );
  raw.execute(
    'INSERT INTO work_shifts (id, employment_id, agreement_id, state, '
    'start_utc_micros, end_utc_micros, timezone_id, local_start_date, note, '
    'void_reason, replacement_shift_id, replaced_shift_id, '
    'created_at_utc_micros, updated_at_utc_micros, revision) VALUES '
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21', 'finalized', 1788753600000000, 1788782400000000, "
    "'Europe/Vilnius', "
    "'2026-09-07', NULL, NULL, NULL, NULL, 0, 0, 2), "
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', NULL, "
    "'onBreak', 1788840000000000, NULL, 'Europe/Vilnius', "
    "'2026-09-08', NULL, NULL, NULL, NULL, 0, 0, 3)",
  );
  raw.execute(
    'INSERT INTO shift_breaks VALUES '
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32', "
    '1788854400000000, 1788856200000000, 0, 0, 1), '
    "('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c52', '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32', "
    '1788865200000000, NULL, 0, 0, 0)',
  );
  raw.execute(
    "INSERT INTO pay_periods VALUES ('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', '2026-09-01', '2026-09-30', NULL, "
    "'open', 0, 0, 0)",
  );
  raw.execute(
    "INSERT INTO payslips VALUES ('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c71', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61', '2026-10-05', NULL, 14720, 'EUR', "
    "'gross', 14720, NULL, NULL, NULL, NULL, 'effective', NULL, NULL, NULL, "
    '0, 0, 0)',
  );
  raw.execute(
    'INSERT INTO record_events (record_kind, record_id, at_utc_micros, kind, '
    "changes_json, reason, revision_after) VALUES ('shift', "
    "'018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31', 0, 'finalized', '[]', NULL, 2)",
  );
  raw.userVersion = 1;
  raw.close();
  return file;
}

void main() {
  test('a released schema-1 database is backed up, then migrated to 3', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = releasedV1(root);

    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(service.close);

    final raw = service.database;
    final shifts = await raw
        .customSelect(
          'SELECT id, state, end_utc_micros FROM work_shifts ORDER BY id',
        )
        .get();
    expect(shifts.map((row) => row.data['state']), ['finalized', 'draft']);
    expect(shifts.last.data['end_utc_micros'], isNull);
    final breaks = await raw
        .customSelect('SELECT id FROM shift_breaks ORDER BY id')
        .get();
    // The unfinished break is dropped; the finished one is kept.
    expect(breaks.map((row) => row.data['id']), [
      '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51',
    ]);
    final agreement = await raw
        .customSelect(
          'SELECT sick_pay_numerator, sick_pay_denominator, sick_employer_days '
          'FROM pay_agreements',
        )
        .getSingle();
    expect(agreement.data, {
      'sick_pay_numerator': 3103,
      'sick_pay_denominator': 5000,
      'sick_employer_days': 2,
    });
    for (final table in [
      'work_schedules',
      'work_schedule_shift_types',
      'work_schedule_blocks',
      'work_day_exceptions',
      'work_leave_records',
    ]) {
      final found = await raw
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(table)],
          )
          .get();
      expect(found, hasLength(1), reason: table);
    }

    final backups = root.directory
        .listSync()
        .whereType<File>()
        .where((value) => value.path.contains('.v1-backup-'))
        .toList();
    expect(backups, hasLength(1));
    final backup = sqlite.sqlite3.open(
      backups.single.path,
      mode: sqlite.OpenMode.readOnly,
    );
    addTearDown(backup.close);
    expect(backup.userVersion, 1);
    expect(
      backup
          .select(
            "SELECT state FROM work_shifts WHERE id = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32'",
          )
          .single['state'],
      'onBreak',
    );
    expect(file.existsSync(), isTrue);

    // The migrated records load through the app's own repository.
    final register = await DriftWorkRepository(service.database)
        .watchRegister(
          const WorkScope(
            employmentId: EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
            temporal: DateRangeScope(
              start: LocalDate(2026, 9, 1),
              end: LocalDate(2026, 9, 30),
            ),
          ),
        )
        .first;
    // The Shifts sheet lists drafts too: the finalized shift and the
    // former on-break shift, now a draft.
    expect(register.shiftSheet, hasLength(2));
    expect(register.periodSheet, hasLength(1));
    expect(register.payslipSheet.single.amount.minorUnits, 14720);
    final history = await raw
        .customSelect(
          "SELECT COUNT(*) AS n FROM record_events WHERE record_kind = 'shift'",
        )
        .getSingle();
    expect(history.data['n'], 1);
  });

  test('a migration that fails part-way leaves schema 1 intact', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final file = releasedV1(root);
    // A stray table makes one of the new CREATE TABLEs fail after others ran.
    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('CREATE TABLE work_leave_records (id TEXT PRIMARY KEY)');
    raw.close();

    await expectLater(
      DriftDatabaseService.open(
        DatabaseConfig.test(root: root.uri, markerToken: root.token),
        location: _locationFor(root),
      ),
      throwsA(anything),
    );

    final after = sqlite.sqlite3.open(
      file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    addTearDown(after.close);
    expect(after.userVersion, 1);
    expect(
      after.select(
        "SELECT name FROM sqlite_master WHERE name = 'work_schedules'",
      ),
      isEmpty,
    );
    expect(
      after
          .select(
            "SELECT state FROM work_shifts WHERE id = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32'",
          )
          .single['state'],
      'onBreak',
    );
  });

  test('a migrated database has exactly the schema of a fresh one', () async {
    Future<Map<String, Object>> shape(DriftDatabaseService service) async {
      final db = service.database;
      final objects = await db
          .customSelect(
            'SELECT type, name, tbl_name FROM sqlite_master '
            "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
          )
          .get();
      final result = <String, Object>{};
      for (final row in objects) {
        final type = row.read<String>('type');
        final name = row.read<String>('name');
        if (type == 'table') {
          final columns = await db
              .customSelect('PRAGMA table_info("$name")')
              .get();
          final keys = await db
              .customSelect('PRAGMA foreign_key_list("$name")')
              .get();
          result['table $name'] = [
            for (final column in columns)
              '${column.data['name']} ${column.data['type']} '
                  'notnull=${column.data['notnull']} '
                  'default=${column.data['dflt_value']} pk=${column.data['pk']}',
            for (final key in keys)
              'fk ${key.data['from']}->${key.data['table']}.${key.data['to']} '
                  '${key.data['on_delete']}',
          ]..sort();
        } else {
          final columns = await db
              .customSelect('PRAGMA index_info("$name")')
              .get();
          result['$type $name'] =
              '${row.read<String>('tbl_name')}: '
              '${columns.map((column) => column.data['name']).join(',')}';
        }
      }
      return result;
    }

    final migratedRoot = await OwnedTestRoot.create();
    addTearDown(migratedRoot.dispose);
    releasedV1(migratedRoot);
    final migrated = await DriftDatabaseService.open(
      DatabaseConfig.test(
        root: migratedRoot.uri,
        markerToken: migratedRoot.token,
      ),
      location: _locationFor(migratedRoot),
    );
    addTearDown(migrated.close);
    final freshRoot = await OwnedTestRoot.create();
    addTearDown(freshRoot.dispose);
    final fresh = await DriftDatabaseService.open(
      DatabaseConfig.test(root: freshRoot.uri, markerToken: freshRoot.token),
      location: _locationFor(freshRoot),
    );
    addTearDown(fresh.close);

    expect(await shape(migrated), await shape(fresh));
  });

  test('a fresh database starts at 3 with no active-shift index', () async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    final service = await DriftDatabaseService.open(
      DatabaseConfig.test(root: root.uri, markerToken: root.token),
      location: _locationFor(root),
    );
    addTearDown(service.close);
    final version = await service.database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 3);
    final index = await service.database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'one_active_shift'",
        )
        .get();
    expect(index, isEmpty);
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
