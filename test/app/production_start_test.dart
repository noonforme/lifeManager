import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/location_store.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/app/work_shell/work_shell_controller.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';

import '../support/production_app.dart';
import '../support/schedule_fixture.dart' show fixtureEmployment;
import '../support/shifts_sheet_driver.dart';
import '../support/shifts_sheet_fixture.dart';
import '../support/work_shell_driver.dart';

const _october = LocalDate(2026, 10, 1);
const _gone = EmploymentId('0190f5d2-6a00-7000-8000-00000000dead');

/// A place store whose first read answers only when the test lets it, and
/// whose writes are kept.
final class _HeldStore implements LocationStore {
  final answer = Completer<String?>();
  final writes = <String>[];

  @override
  Future<String?> read() => answer.future;

  @override
  Future<void> write(String route) async => writes.add(route);
}

/// A place store that cannot write.
final class _ReadOnlyStore implements LocationStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String route) async =>
      throw const FileSystemException('read-only folder');
}

void main() {
  late Directory folder;
  setUp(() => folder = Directory.systemTemp.createTempSync('lifeos-place'));
  tearDown(() => folder.deleteSync(recursive: true));

  /// Pumps the production app over the depot with the place file holding
  /// [stored], and returns its fixture.
  Future<ShiftsSheetFixture> start(
    WidgetTester tester, {
    required LocationStore store,
    FakeWindowClose? window,
    Future<void> Function()? release,
    bool settle = true,
  }) async {
    late ShiftsSheetFixture fixture;
    await tester.runAsync(() async {
      fixture = await ShiftsSheetFixture.create();
    });
    addTearDown(() => closeShiftsSheet(tester, fixture));
    await pumpProductionApp(
      tester,
      work: fixture.work,
      reads: fixture.reads,
      store: store,
      closeApi: window,
      release: release,
      settle: settle,
    );
    return fixture;
  }

  FileLocationStore placeFile(String text) {
    final database = File('${folder.path}/lifeos.sqlite');
    final store = FileLocationStore.beside(database);
    store.file.writeAsStringSync(text);
    return store;
  }

  const calendar = WorkLocation.calendar(fixtureEmployment, month: _october);
  for (final (stored, expected, notice) in [
    ('', calendar, null),
    ('%%%', calendar, WorkShellNotices.placeUnreadable),
    ('/today', calendar, WorkShellNotices.placeUnreadable),
    (
      '${WorkLocation.shifts(_gone, month: _october).toUri()}',
      const WorkLocation.overview(),
      WorkShellNotices.employmentGone,
    ),
    (
      '/work?employment=${fixtureEmployment.value}&mode=edit&add=agreement',
      const WorkLocation.employment(fixtureEmployment),
      null,
    ),
  ]) {
    testWidgets("a place file holding '$stored' opens a valid place", (
      tester,
    ) async {
      await start(tester, store: placeFile(stored), settle: false);
      // The place file is read with real IO, outside the test's clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settleSheet(tester);
      final shell = shellOf(tester);
      expect(shell.location, expected);
      expect(shell.notice, notice);
    });
  }

  testWidgets('closing while the shell still starts closes, releases the '
      'database and keeps the remembered place', (tester) async {
    final store = _HeldStore();
    final window = FakeWindowClose();
    var released = 0;
    await start(
      tester,
      store: store,
      window: window,
      release: () async => released++,
      settle: false,
    );
    await tester.pump();
    expect(shellOf(tester).started, isFalse);

    unawaited(window.pressClose());
    await tester.pump();
    await tester.pump();
    expect(window.destroyed, 1);
    expect(released, 1);
    expect(store.writes, isEmpty);

    store.answer.complete(null);
    await settleSheet(tester);
    expect(store.writes, isEmpty);
  });

  testWidgets('a place file that cannot be written still lets the window '
      'close and releases the database', (tester) async {
    final window = FakeWindowClose();
    var released = 0;
    await start(
      tester,
      store: _ReadOnlyStore(),
      window: window,
      release: () async => released++,
    );
    unawaited(window.pressClose());
    await settleSheet(tester);
    expect(window.destroyed, 1);
    expect(released, 1);
    expect(tester.takeException(), isA<FileSystemException>());
  });
}
