import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('work schema stores integer facts and enforces foreign keys', () async {
    final columns = await _tableInfo(database, 'work_shifts');

    expect(columns['overtime_minutes'], 'INTEGER');
    expect(columns['local_start_date'], 'TEXT');
    expect(columns.containsKey('expected_pay'), isFalse);
    await expectLater(
      database.customStatement('''
        INSERT INTO work_shifts (
          id, employment_id, agreement_id, state, start_utc_micros,
          end_utc_micros, timezone_id, local_start_date, overtime_minutes,
          note, void_reason, replacement_shift_id, replaced_shift_id,
          created_at_utc_micros, updated_at_utc_micros, revision
        ) VALUES (
          '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31',
          '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
          NULL, 'draft', 1, NULL, 'Europe/Berlin', '2026-09-29', 0,
          NULL, NULL, NULL, NULL, 1, 1, 0
        )
      '''),
      throwsA(isA<SqliteException>()),
    );
  });

  test(
    'schema omits derived Work values and permits only one active shift',
    () async {
      final agreementColumns = await _tableInfo(database, 'pay_agreements');
      expect(agreementColumns.containsKey('used_by_finalized_shift'), isFalse);

      await database.customStatement('''
      INSERT INTO employments (
        id, name, legal_label, status, created_at_utc_micros,
        updated_at_utc_micros, revision
      ) VALUES (
        '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', 'Synthetic employer',
        NULL, 'active', 1, 1, 0
      )
    ''');
      await _insertActiveShift(
        database,
        '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31',
      );
      await expectLater(
        _insertActiveShift(database, '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32'),
        throwsA(isA<SqliteException>()),
      );
    },
  );
}

Future<Map<String, String>> _tableInfo(
  AppDatabase database,
  String table,
) async {
  final rows = await database.customSelect('PRAGMA table_info($table)').get();
  return {
    for (final row in rows) row.read<String>('name'): row.read<String>('type'),
  };
}

Future<void> _insertActiveShift(AppDatabase database, String id) {
  return database.customStatement(
    '''
      INSERT INTO work_shifts (
        id, employment_id, agreement_id, state, start_utc_micros,
        end_utc_micros, timezone_id, local_start_date, overtime_minutes,
        note, void_reason, replacement_shift_id, replaced_shift_id,
        created_at_utc_micros, updated_at_utc_micros, revision
      ) VALUES (?, ?, NULL, 'running', 1, NULL, 'Europe/Berlin',
        '2026-09-29', 0, NULL, NULL, NULL, NULL, 1, 1, 0)
    ''',
    [id, '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'],
  );
}
