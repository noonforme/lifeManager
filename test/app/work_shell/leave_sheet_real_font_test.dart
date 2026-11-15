@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart';
import '../../support/leave_sheet_driver.dart';
import '../../support/shifts_sheet_driver.dart';

void main() {
  setUpAll(() async {
    for (final (family, dir) in [
      ('EraSans', 'assets/fonts/era_sans'),
      ('NotoSans', 'assets/fonts/noto_sans'),
    ]) {
      final loader = FontLoader(family);
      for (final file in Directory(dir).listSync().whereType<File>().where(
        (file) => file.path.endsWith('.ttf'),
      )) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
      await loader.load();
    }
  });
  testWidgets('real_font/Leave facts and Working', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await openLeave(tester, fixture);
    await click(tester, dockTab('Working'));
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile(
        '../../goldens/real_font/work_shell_leave_1280x800.png',
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });
  testWidgets('real_font/Correct leave validation', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    await openLeave(tester, fixture);
    await click(tester, toolbarKey('Correct…'));
    await settleSheet(tester);
    await click(tester, panelKey('Void and replace'));
    await settleSheet(tester);
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile(
        '../../goldens/real_font/work_shell_leave_correct_1280x800.png',
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });
}
