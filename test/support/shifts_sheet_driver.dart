import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/window_close_guard.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/app/work_edit/work_records.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/shifts_sheet_controller.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import 'app_frame_harness.dart' show click, gridCell, press;
import 'schedule_fixture.dart';
import 'shifts_sheet_fixture.dart';

/// The Shifts grid; the subform tabs hold grids of their own.
final shiftsGrid = find.byWidgetPredicate(
  (widget) => widget is DataGrid && widget.label == 'Shifts',
);

/// The subform's grid labelled [label] (Breaks, History, Working, Day
/// plan).
Finder subformGrid(String label) => find.byWidgetPredicate(
  (widget) => widget is DataGrid && widget.label == label,
);

/// Lets the database's work and streams finish, then settles the frame.
Future<void> settleSheet(WidgetTester tester) async {
  for (var turn = 0; turn < 3; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

/// The Work shell's controller.
WorkShellController shellOf(WidgetTester tester) =>
    tester.state<WorkShellState>(find.byType(WorkShell)).shell;

/// The Shifts sheet the Work shell shows.
ShiftsSheetController sheetOf(WidgetTester tester) => shellOf(tester).sheet!;

/// Pumps the Work shell on the depot's October Shifts at [size] (1280 x
/// 800) and text [scale], and returns its fixture: over [executor] when
/// given, the shell reading through [reads] when given.
Future<ShiftsSheetFixture> pumpShiftsSheet(
  WidgetTester tester, {
  WindowCloseApi? closeApi,
  LocationStore? store,
  Size size = const Size(1280, 800),
  double scale = 1,
  QueryExecutor? executor,
  WorkReads? reads,
  ProductionWorkProviders Function(ShiftsSheetFixture fixture)? work,
  ValueChanged<String>? onTitle,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late ShiftsSheetFixture fixture;
  await tester.runAsync(() async {
    fixture = await ShiftsSheetFixture.create(executor: executor);
  });
  await tester.pumpWidget(
    GalleryHost(
      home: textScaled(
        scale,
        WorkShell(
          work: work?.call(fixture) ?? fixture.work,
          reads: reads ?? fixture.reads,
          today: ShiftsSheetFixture.today,
          timezoneId: ShiftsSheetFixture.zone,
          store:
              store ??
              MemoryLocationStore(
                '${const WorkLocation.shifts(fixtureEmployment, month: ShiftsSheetFixture.month).toUri()}',
              ),
          closeApi: closeApi,
          onTitle: onTitle,
        ),
      ),
    ),
  );
  // A failing test still closes its sheet, so the next one starts clean.
  addTearDown(() => closeShiftsSheet(tester, fixture));
  await settleSheet(tester);
  return fixture;
}

final _closed = Expando<bool>('closed');

/// Unmounts the sheet before its database closes; closing twice does
/// nothing.
Future<void> closeShiftsSheet(
  WidgetTester tester,
  ShiftsSheetFixture fixture,
) async {
  if (_closed[fixture] ?? false) return;
  _closed[fixture] = true;
  await tester.pumpWidget(const SizedBox());
  // Cancelled database streams finish their clean-up in the test's own
  // time; closing the database waits for it.
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(fixture.dispose);
}

/// [child] at text [scale], as the owner's system text size sets it.
Widget textScaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

/// The status line's notice.
String statusNotice(WidgetTester tester) =>
    tester.widget<StatusBar>(find.byType(StatusBar)).notice ?? '';

/// Selects the Shifts row [id] with the mouse.
Future<void> selectShiftsRow(WidgetTester tester, String id) async {
  await click(tester, await gridCell(tester, id, 'date'));
  await settleSheet(tester);
}

/// Opens the time editor of [cell] with a click, steps it with its own
/// arrow [arrow] ('up' or 'down') [times] times and presses Enter, the
/// data-entry key that commits it. The other region may show the same open
/// field, so the arrow is found inside [cell].
Future<void> stepTimeIn(
  WidgetTester tester,
  Finder cell,
  String arrow, {
  int times = 1,
}) async {
  await click(tester, cell);
  final step = find.descendant(
    of: cell,
    matching: find.byKey(ValueKey('era-time-$arrow')),
  );
  for (var count = 0; count < times; count++) {
    await click(tester, step);
  }
  await press(tester, LogicalKeyboardKey.enter);
  await settleSheet(tester);
}

/// [stepTimeIn] on [column] of the Shifts row [id].
Future<void> stepGridTime(
  WidgetTester tester,
  String id,
  String column,
  String arrow, {
  int times = 1,
}) async =>
    stepTimeIn(tester, await gridCell(tester, id, column), arrow, times: times);

/// Shows the subform tab labelled [label] with a click.
Future<void> openSubformTab(WidgetTester tester, String label) async {
  await click(
    tester,
    find.descendant(of: find.byType(Subform), matching: find.text(label)),
  );
  await settleSheet(tester);
}
