import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository pins the approved native toolchain', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(File('.fvmrc').readAsStringSync().trim(), '{"flutter":"3.47.5"}');
    expect(pubspec, contains('sdk: ">=3.13.4 <3.14.0"'));
    expect(pubspec, isNot(contains('http:')));
    expect(pubspec, isNot(contains('django')));
    expect(File('linux/CMakeLists.txt').existsSync(), isTrue);
    expect(Directory('web').existsSync(), isFalse);
  });
}
