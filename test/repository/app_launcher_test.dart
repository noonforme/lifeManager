import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the launcher opens the widget gallery from its menu', () {
    final launcher = File('app.sh').readAsStringSync();
    expect(launcher, contains("printf '  5) Open widget gallery\\n'"));
    expect(launcher, contains("printf '  6) Exit\\n'"));
    expect(launcher, contains('5) start_gallery ;;'));
    expect(launcher, contains('6) exit 0 ;;'));
    expect(launcher, contains('run -d linux --dart-define=LIFEOS_GALLERY=1'));
  });
}
