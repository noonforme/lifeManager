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

    expect(columns.containsKey('overtime_minutes'), isFalse);
    expect(columns['local_start_date'], 'TEXT');
    expect(columns.containsKey('expected_pay'), isFalse);
    await expectLater(
      database.customStatement('''
        INSERT INTO work_shifts (
          id, employment_id, agreement_id, state, start_utc_micros,
          end_utc_micros, timezone_id, local_start_date,
          note, void_reason, replacement_shift_id, replaced_shift_id,
          created_at_utc_micros, updated_at_utc_micros, revision
        ) VALUES (
          '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31',
          '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
          NULL, 'draft', 1, NULL, 'Europe/Berlin', '2026-09-29',
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

  group('agreement premium CHECK constraints', () {
    setUp(() => _insertEmployment(database));

    test('the defaults are accepted', () async {
      await _insertAgreement(database);
      final row = await database
          .customSelect('SELECT premium_stacking FROM pay_agreements')
          .getSingle();
      expect(row.read<String>('premium_stacking'), 'highest');
    });

    for (final (name, overrides) in <(String, Map<String, Object>)>[
      ('a night minute above 1439', {'night_start_minute': 1440}),
      ('a negative night minute', {'night_end_minute': -1}),
      (
        'a night start equal to its end',
        {'night_start_minute': 360, 'night_end_minute': 360},
      ),
      (
        'a night multiplier below 1',
        {'night_multiplier_numerator': 1, 'night_multiplier_denominator': 2},
      ),
      (
        'a holiday multiplier below 1',
        {
          'holiday_multiplier_numerator': 2,
          'holiday_multiplier_denominator': 3,
        },
      ),
      (
        'an overtime multiplier below 1',
        {
          'overtime_multiplier_numerator': 1,
          'overtime_multiplier_denominator': 2,
        },
      ),
      ('an unknown holiday calendar', {'holiday_calendar': 'atlantis'}),
      ('an unknown stacking mode', {'premium_stacking': 'sum'}),
    ]) {
      test('rejects $name', () async {
        await expectLater(
          _insertAgreement(database, overrides),
          throwsA(isA<SqliteException>()),
        );
      });
    }
  });
}

Future<void> _insertEmployment(AppDatabase database) =>
    database.customStatement('''
      INSERT INTO employments (
        id, name, legal_label, status, created_at_utc_micros,
        updated_at_utc_micros, revision
      ) VALUES (
        '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11', 'Synthetic employer',
        NULL, 'active', 1, 1, 0
      )
    ''');

Future<void> _insertAgreement(
  AppDatabase database, [
  Map<String, Object> overrides = const {},
]) {
  final values = <String, Object?>{
    'id': '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21',
    'employment_id': '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11',
    'version': 1,
    'effective_start': '2026-09-01',
    'effective_end': null,
    'hourly_rate_micro_eur': 18400000,
    'basis': 'gross',
    'overtime_threshold_minutes': 480,
    'overtime_multiplier_numerator': 3,
    'overtime_multiplier_denominator': 2,
    'night_enabled': 1,
    'night_start_minute': 1320,
    'night_end_minute': 360,
    'night_multiplier_numerator': 3,
    'night_multiplier_denominator': 2,
    'holiday_calendar': 'lithuania',
    'holiday_multiplier_numerator': 2,
    'holiday_multiplier_denominator': 1,
    'premium_stacking': 'highest',
    'label': null,
    'note': null,
    'created_at_utc_micros': 1,
    'revision': 0,
    ...overrides,
  };
  return database.customStatement(
    'INSERT INTO pay_agreements (${values.keys.join(', ')}) '
    'VALUES (${List.filled(values.length, '?').join(', ')})',
    values.values.toList(),
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
        end_utc_micros, timezone_id, local_start_date,
        note, void_reason, replacement_shift_id, replaced_shift_id,
        created_at_utc_micros, updated_at_utc_micros, revision
      ) VALUES (?, ?, NULL, 'running', 1, NULL, 'Europe/Berlin',
        '2026-09-29', NULL, NULL, NULL, NULL, 1, 1, 0)
    ''',
    [id, '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'],
  );
}
