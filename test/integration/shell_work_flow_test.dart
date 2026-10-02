import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/app/production_work_providers.dart';
import 'package:lifeos/core/database/app_database.dart' show AppDatabase;
import 'package:lifeos/core/time/app_clock.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/uuid_v7_work_id_factory.dart';

/// The shell spec's section 10 flow on the production composition: a
/// fresh install from Today to a finalized shift, then the formula bar,
/// History and the Journal. Synthetic facts only.
void main() {
  testWidgets('fresh install: Today to a finalized, explained shift', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    // 09:00 in Vilnius on 2026-10-01.
    final clock = _Clock()..now = DateTime.utc(2026, 10, 1, 6);
    final ids = UuidV7WorkIdFactory();
    final work = buildWorkProviders(
      database: database,
      clock: clock,
      timezones: IanaTimezoneService(),
      currentTimezoneId: () => 'Europe/Vilnius',
      workIds: ids,
      shiftIds: ids,
      evidenceIds: ids,
    );
    final router = createAppRouter(initialLocation: '/today');
    addTearDown(router.dispose);
    await tester.pumpWidget(work.scope(LifeOsApp(router: router)));
    await tester.pumpAndSettle();

    // Today, empty: Needs you offers the first step.
    expect(
      find.text('Nothing waiting. Work is ready when you add an employment.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Add employment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('employment-name')),
      'Synthetic depot',
    );
    await tester.tap(find.text('Save employment'));
    await tester.pumpAndSettle();

    // The agreement takes its defaults; only the rate is entered.
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '18.40',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('save-agreement'));
    await tester.scrollUntilVisible(
      save,
      240,
      scrollable: find
          .descendant(
            of: find.bySemanticsLabel('Create agreement'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Start at 09:00, end at 17:00, finalize.
    await tester.tap(_inInspector(find.text('Start shift')));
    await tester.pumpAndSettle();
    clock.now = DateTime.utc(2026, 10, 1, 14);
    await tester.tap(find.text('End shift'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finalize shift'));
    await tester.pumpAndSettle();
    expect(find.text('Shift finalized'), findsOneWidget);

    // The formula bar explains the expected pay cell.
    await tester.tap(
      find.descendant(
        of: find.bySemanticsLabel('Work register'),
        matching: find.text('EUR 147.20'),
      ),
    );
    await tester.pumpAndSettle();
    final bar = find.bySemanticsLabel('Formula bar');
    expect(
      find.descendant(of: bar, matching: find.textContaining('18.40')),
      findsWidgets,
    );
    expect(
      find.descendant(of: bar, matching: find.textContaining('147.20')),
      findsWidgets,
    );

    // History lists one event per command: start, end and finalize. (Spec
    // section 10 says four, which its one-event-per-command rule rules out.)
    await tester.tap(_inInspector(find.text('History')));
    await tester.pumpAndSettle();
    const kinds = {'Created', 'Changed', 'Finalized'};
    final headings = find
        .descendant(
          of: find.bySemanticsLabel('Record history'),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .where(kinds.contains)
        .toList();
    expect(headings, ['Finalized', 'Changed', 'Created']);

    // The Journal on Today shows the shift.
    router.go('/today');
    await tester.pumpAndSettle();
    expect(find.textContaining('Shift on 2026-10-01'), findsWidgets);
    expect(find.text('Nothing waiting.'), findsOneWidget);
  });
}

Finder _inInspector(Finder finder) => find.descendant(
  of: find.bySemanticsLabel('Record inspector'),
  matching: finder,
);

final class _Clock implements AppClock {
  DateTime now = DateTime.utc(2026, 10, 1);

  @override
  DateTime nowUtc() => now;
}
