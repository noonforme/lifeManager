import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Overtime is derived from the agreement; nothing may store or ask for it.
void main() {
  test('no source file mentions manual overtime', () {
    const forbidden = [
      'overtimeMinutes',
      'overtime_minutes',
      'suggestedOvertimeMinutes',
      'OvertimeConfirmation',
    ];
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      for (final word in forbidden) {
        if (text.contains(word)) offenders.add('${entity.path}: $word');
      }
    }
    expect(offenders, isEmpty);
  });
}
