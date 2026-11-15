import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/edit_session/window_close_guard.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/core/time/local_date.dart';

import 'shifts_sheet_driver.dart' show settleSheet;
import 'shifts_sheet_fixture.dart';

/// Pumps the production app as `main` composes it, on [location]: the
/// LifeOS app, its one `/work` route and the Work shell over [work] and
/// [reads], remembering its place in [store].
Future<void> pumpProductionApp(
  WidgetTester tester, {
  required ProductionWorkProviders work,
  required WorkReads reads,
  required LocationStore store,
  LocalDate today = ShiftsSheetFixture.today,
  WindowCloseApi? closeApi,
  Future<void> Function()? release,
  ValueChanged<String>? onTitle,
  String location = '/work',
  Size size = const Size(1280, 800),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = createAppRouter(
    initialLocation: location,
    work: (link) => WorkShell(
      work: work,
      reads: reads,
      today: today,
      timezoneId: ShiftsSheetFixture.zone,
      store: store,
      closeApi: closeApi,
      release: release,
      link: link,
      onTitle: onTitle,
    ),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(LifeOsApp(router: router));
  if (settle) await settleSheet(tester);
}
