import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/window_close_guard.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_shell.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart' show StepKey;

import 'app_frame_harness.dart'
    show click, press, propertyEditor, propertyValue;
import 'shifts_sheet_driver.dart' show settleSheet, textScaled;
import 'shifts_sheet_fixture.dart';
import 'work_shell_fixture.dart';

/// Pumps the Work shell over an empty database at [size], remembering its
/// place in [store], and returns the fixture. The shell unmounts before
/// the database closes.
Future<EmptyWorkFixture> pumpEmptyShell(
  WidgetTester tester, {
  required LocationStore store,
  Size size = const Size(1280, 800),
  double scale = 1,
  WindowCloseApi? closeApi,
  Future<void> Function()? release,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late EmptyWorkFixture fixture;
  await tester.runAsync(() async {
    fixture = await EmptyWorkFixture.create();
  });
  await pumpShellOver(
    tester,
    fixture,
    store: store,
    closeApi: closeApi,
    release: release,
    scale: scale,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(fixture.dispose);
  });
  return fixture;
}

/// Mounts a Work shell over [fixture]'s database, as a fresh start.
Future<void> pumpShellOver(
  WidgetTester tester,
  EmptyWorkFixture fixture, {
  required LocationStore store,
  WindowCloseApi? closeApi,
  Future<void> Function()? release,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    GalleryHost(
      home: textScaled(
        scale,
        WorkShell(
          // A new key starts the shell again, as a new run would.
          key: UniqueKey(),
          work: fixture.work,
          reads: fixture.reads,
          today: ShiftsSheetFixture.today,
          timezoneId: ShiftsSheetFixture.zone,
          store: store,
          closeApi: closeApi,
          release: release,
        ),
      ),
    ),
  );
  await settleSheet(tester);
}

/// The window's close button as a test presses it: [destroyed] counts the
/// times the window closed.
final class FakeWindowClose implements WindowCloseApi {
  Future<void> Function()? _onClose;
  int destroyed = 0;

  /// Presses the window's close button: a guard decides, or with none the
  /// window simply closes.
  Future<void> pressClose() async {
    if (_onClose case final onClose?) return onClose();
    destroyed++;
  }

  @override
  Future<void> interceptClose(Future<void> Function() onCloseRequested) async =>
      _onClose = onCloseRequested;

  @override
  Future<void> releaseClose(Future<void> Function() onCloseRequested) async {
    if (_onClose == onCloseRequested) _onClose = null;
  }

  @override
  Future<void> destroy() async => destroyed++;
}

/// Opens the property [key] with a click, types [text] and presses Enter,
/// the data-entry key that takes it.
Future<void> typeProperty(WidgetTester tester, String key, String text) async {
  await click(tester, propertyValue(key));
  await tester.enterText(
    find.descendant(
      of: propertyEditor(key),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await press(tester, LogicalKeyboardKey.enter);
  await settleSheet(tester);
}

/// The step key announced as [label] (the filter strip's ◂ and ▸).
Finder stepKey(String label) => find.byWidgetPredicate(
  (widget) => widget is StepKey && widget.semanticLabel == label,
);
