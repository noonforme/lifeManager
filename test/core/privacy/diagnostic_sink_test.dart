import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/privacy/diagnostic_sink.dart';
import 'package:lifeos/core/privacy/safe_diagnostic.dart';

void main() {
  const event = SafeDiagnostic(
    operation: SafeOperation.databaseOpen,
    outcome: SafeOutcome.unavailable,
    exceptionClass: SafeExceptionClass.sqliteException,
    appVersion: '0.1.0',
    schemaVersion: 1,
  );

  test('diagnostics serialize only closed safe fields', () {
    expect(
      event.toJson().keys,
      unorderedEquals([
        'operation',
        'outcome',
        'exceptionClass',
        'appVersion',
        'schemaVersion',
      ]),
    );
    expect(event.toJson(), {
      'operation': 'databaseOpen',
      'outcome': 'unavailable',
      'exceptionClass': 'sqliteException',
      'appVersion': '0.1.0',
      'schemaVersion': 1,
    });
  });

  test('disabled local sink writes nothing', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lifeos-diagnostic-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/operations.log');

    await FileDiagnosticSink(file: file, enabled: false).record(event);

    expect(await file.exists(), isFalse);
  });

  test('enabled local sink writes one bounded JSON line', () async {
    final directory = await Directory.systemTemp.createTemp(
      'lifeos-diagnostic-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/operations.log');

    await FileDiagnosticSink(file: file, enabled: true).record(event);

    final lines = await file.readAsLines();
    expect(lines, hasLength(1));
    expect(jsonDecode(lines.single), event.toJson());
  });
}
