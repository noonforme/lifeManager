import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/shared/shell/task_pane.dart';
import 'package:lifeos/shared/workbench/era_dates.dart';
import 'package:lifeos/shared/workbench/era_month_calendar.dart';

import '../support/scheduled_app.dart';
import '../support/work_sheets.dart';

/// The owner saw the date box's calendar "freeze / jump months" (bead
/// lifeManager-7qj). Each host below pages the open calendar with ▸ while
/// the app around it rebuilds, and checks it moves one month per click and
/// stays there.

final _next = find.byKey(const ValueKey('era-calendar-next'));

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('era-calendar-title'))).data!;

/// Confirms 5 October through the services, as another part of the app
/// would: the plan, the register and the schedules all emit again.
Future<void> _emit(WidgetTester tester, ScheduledApp app) async {
  await tester.runAsync(
    () => app.work.plans.confirm(
      EmploymentId(app.employment),
      const LocalDate(2026, 10, 5),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens the box keyed [key] and pages its calendar ▸ six times, the app
/// emitting after the third. Every click moves exactly one month, ▸ stays
/// under the pointer, and nothing rebuilds on a frame nobody asked for.
Future<void> _pageThrough(
  WidgetTester tester,
  ScheduledApp app,
  String key,
) async {
  final box = find.byKey(ValueKey(key));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.ancestor(of: box, matching: find.byType(Column)).first,
      matching: find.byKey(const ValueKey('era-date-drop')),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(EraMonthCalendar), findsOneWidget);
  var arrow = tester.getCenter(_next);
  final [name, year] = _title(tester).split(' ');
  var month = LocalDate(int.parse(year), eraMonthNames.indexOf(name) + 1, 1);

  for (var click = 0; click < 6; click++) {
    if (click == 3) {
      await _emit(tester, app);
      expect(_title(tester), eraMonthTitle(month), reason: 'after the emit');
      // The calendar follows its box, which a form may move as it updates
      // (an agreement coming into use gains a note above its dates).
      arrow = tester.getCenter(_next);
    }
    await tester.tapAt(arrow);
    await tester.pump();
    month = month.addMonths(1);
    expect(_title(tester), eraMonthTitle(month), reason: 'click $click');
    await tester.pumpAndSettle();
    expect(_title(tester), eraMonthTitle(month), reason: 'settled $click');
    expect(tester.getCenter(_next), arrow, reason: '▸ moved on $click');
  }

  // Open and idle: no frame is pending and a forced one rebuilds nothing.
  expect(tester.binding.hasScheduledFrame, isFalse);
  var rebuilt = 0;
  debugOnRebuildDirtyWidget = (_, _) => rebuilt++;
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  tester.binding.scheduleFrame();
  await tester.pump();
  debugOnRebuildDirtyWidget = null;
  expect(rebuilt, 0);
  expect(tester.binding.hasScheduledFrame, isFalse);
}

void main() {
  testWidgets('Work › Date range… pages its From calendar', (tester) async {
    final app = await pumpScheduledApp(
      tester,
      location: '/work?employment={employment}&sheet=shifts',
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^Period, ')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date range…'));
    await tester.pumpAndSettle();
    await _pageThrough(tester, app, 'range-from');
  });

  testWidgets('the manual shift form pages its start date', (tester) async {
    final app = await pumpScheduledApp(
      tester,
      location: '/work?employment={employment}&sheet=shifts',
    );
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual shift').last);
    await tester.pumpAndSettle();
    await _pageThrough(tester, app, 'shift-start-date');
  });

  testWidgets('a schedule\'s Properties page In use from', (tester) async {
    final app = await pumpScheduledApp(
      tester,
      location:
          '/work?employment={employment}&sheet=schedules'
          '&record=schedule:{schedule}&mode=properties',
    );
    await _pageThrough(tester, app, 'schedule-from');
  });

  testWidgets('a new schedule pages In use from', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.widgetWithText(TaskLink, 'New schedule…'));
    await tester.pumpAndSettle();
    await _pageThrough(tester, app, 'schedule-from');
  });

  testWidgets('an agreement\'s Properties page Starts on', (tester) async {
    final app = await pumpScheduledApp(tester);
    await chooseSheet(tester, 'Agreements');
    await tester.tap(find.text('v1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Properties').first);
    await tester.pumpAndSettle();
    await _pageThrough(tester, app, 'agreement-effective-start');
  });

  testWidgets('+ Add › Extra shift… pages its date', (tester) async {
    final app = await pumpScheduledApp(tester);
    await tester.tap(find.byKey(const ValueKey('quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra shift…').last);
    await tester.pumpAndSettle();
    await _pageThrough(tester, app, 'add-day-date');
  });
}
