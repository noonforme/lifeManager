@Tags(['real-font'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_rows.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_driver.dart';

/// The production shell's Shifts and Calendar in EraSans, replacing the
/// old shell's real-font planned shifts and calendar (Phase 4g).
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
  testWidgets('real_font/work_shell_shifts', (tester) async {
    final fixture = await pumpShiftsSheet(tester);
    late WorkShift shift;
    await tester.runAsync(() async {
      shift = await fixture.finishShift(20);
    });
    await settleSheet(tester);
    await selectShiftsRow(tester, storedRowId(shift));
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile(
        '../../goldens/real_font/work_shell_shifts_1280x800.png',
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });
  testWidgets('real_font/work_shell_calendar', (tester) async {
    final fixture = await pumpShiftsSheet(
      tester,
      store: MemoryLocationStore(
        '${const WorkLocation.calendar(fixtureEmployment, month: LocalDate(2026, 10, 1), day: LocalDate(2026, 10, 19)).toUri()}',
      ),
    );
    await expectLater(
      find.byType(AppFrame),
      matchesGoldenFile(
        '../../goldens/real_font/work_shell_calendar_1280x800.png',
      ),
    );
    await closeShiftsSheet(tester, fixture);
  });
}
