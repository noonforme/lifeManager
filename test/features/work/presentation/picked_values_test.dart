import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Picked dates and times are always well-formed, so no form may still
/// ask for a typed format (era pickers spec 4).
void main() {
  test('no parse message for dates or times remains in lib', () {
    const removed = [
      'Enter a valid ISO date.',
      'Enter a date as YYYY-MM-DD.',
      'Enter a time as HH:MM.',
      'Enter a valid local time.',
      'Enter valid break dates and times.',
      'Enter both dates as YYYY-MM-DD.',
      "hint: 'YYYY-MM-DD'",
    ];
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (removed.any(line.contains)) '${file.path}:${index + 1}',
    ];
    expect(offenders, isEmpty);
  });
}
