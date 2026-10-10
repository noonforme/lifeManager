import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Golden failure images are scratch output; git never picks them up.
void main() {
  test('golden failure folders are ignored wherever goldens live', () {
    for (final path in [
      'test/goldens/failures/shell_1280x800_testImage.png',
      'test/ui/gallery/failures/controls_key_button_testImage.png',
    ]) {
      final result = Process.runSync('git', ['check-ignore', '-q', path]);
      expect(result.exitCode, 0, reason: '$path is not ignored');
    }
  });
}
