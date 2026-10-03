import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/database/sqlite_errors.dart';

import '../../support/owned_test_root.dart';

/// Errors as the app sees them: from a database opened in the background,
/// where SQLite failures arrive wrapped for the isolate boundary.
void main() {
  late DatabaseConnection connection;

  setUp(() async {
    final root = await OwnedTestRoot.create();
    addTearDown(root.dispose);
    connection = DatabaseConnection(
      NativeDatabase.createInBackground(
        File('${root.directory.path}/errors.sqlite'),
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    addTearDown(() => connection.executor.close());
    await connection.executor.ensureOpen(_NoUser());
    await connection.executor.runCustom(
      'CREATE TABLE parent (id TEXT PRIMARY KEY)',
    );
    await connection.executor.runCustom(
      'CREATE TABLE child (id TEXT PRIMARY KEY, '
      'parent_id TEXT REFERENCES parent (id))',
    );
    await connection.executor.runInsert(
      "INSERT INTO parent VALUES ('a')",
      const [],
    );
  });

  Future<Object> failing(String sql) async {
    try {
      await connection.executor.runInsert(sql, const []);
    } on Object catch (error) {
      return error;
    }
    fail('expected $sql to fail');
  }

  test('a duplicate key is a unique violation, even when wrapped', () async {
    expect(
      isUniqueViolation(await failing("INSERT INTO parent VALUES ('a')")),
      isTrue,
    );
  });

  test('a missing parent is not a unique violation', () async {
    expect(
      isUniqueViolation(
        await failing("INSERT INTO child VALUES ('c', 'missing')"),
      ),
      isFalse,
    );
  });

  test('other errors are not unique violations', () {
    expect(isUniqueViolation(StateError('x')), isFalse);
  });
}

final class _NoUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
