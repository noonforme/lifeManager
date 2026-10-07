import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/presentation/work_calendar.dart';
import 'package:lifeos/features/work/presentation/work_plan_view.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

import '../../../support/schedule_views.dart';

Future<void> _pump(
  WidgetTester tester, {
  Map<LocalDate, DayView>? days,
  LocalDate month = const LocalDate(2026, 10, 1),
  ValueChanged<LocalDate>? onOpen,
  ValueChanged<LocalDate>? onMonth,
  ValueChanged<LocalDate>? onCursor,
  bool readOnly = false,
}) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: WorkCalendar(
              month: month,
              today: const LocalDate(2026, 10, 7),
              days: days ?? octoberViews(octoberPlan()),
              onOpen: onOpen,
              onMonth: onMonth,
              onCursor: onCursor,
              readOnly: readOnly,
              autofocus: true,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every entry is written in words', (tester) async {
    await _pump(tester);
    expect(find.text('Day 07:00–19:00'), findsNWidgets(9));
    expect(find.text('Night 19:00–07:00'), findsNWidgets(6));
  });

  testWidgets('weeks start on Monday', (tester) async {
    await _pump(tester);
    final monday = tester.getTopLeft(find.text('Mon'));
    final sunday = tester.getTopLeft(find.text('Sun'));
    expect(monday.dx, lessThan(sunday.dx));
    // 1 October 2026 is a Thursday: the first row starts on 28 September.
    expect(
      find.byKey(const ValueKey('work-calendar-day-2026-09-28')),
      findsOneWidget,
    );
  });

  testWidgets('today has the amber outline', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('work-calendar-day-2026-10-07')),
        matching: find.byKey(const ValueKey('work-calendar-today')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a third entry folds into "+1 more"', (tester) async {
    const date = LocalDate(2026, 10, 5);
    final days = octoberViews(octoberPlan());
    final day = days[date]!;
    days[date] = DayView(
      date: date,
      planned: day.planned,
      entries: [
        ...day.entries,
        const DayEntry(DayEntryKind.extra, 'Extra 20:00–22:00'),
        const DayEntry(DayEntryKind.leave, 'Vacation'),
      ],
    );
    await _pump(tester, days: days);
    expect(find.text('Extra 20:00–22:00'), findsOneWidget);
    expect(find.text('Vacation'), findsNothing);
    expect(find.text('+1 more'), findsOneWidget);
  });

  testWidgets('arrow keys move the day and Enter opens it', (tester) async {
    LocalDate? opened;
    await _pump(tester, onOpen: (day) => opened = day);
    // The cursor starts on today.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, const LocalDate(2026, 10, 15));
  });

  testWidgets('Page Down asks for the next month', (tester) async {
    LocalDate? month;
    await _pump(tester, onMonth: (value) => month = value);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    expect(month, const LocalDate(2026, 11, 1));
  });

  testWidgets('a double-click opens a day', (tester) async {
    LocalDate? opened;
    await _pump(tester, onOpen: (day) => opened = day);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-12'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(opened, const LocalDate(2026, 10, 12));
  });

  testWidgets(
    'a single click selects at once, not after the double-click wait',
    (tester) async {
      LocalDate? cursor;
      await _pump(tester, onCursor: (day) => cursor = day);
      final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-12'));
      final gesture = await tester.startGesture(tester.getCenter(cell));
      await tester.pump();
      expect(cursor, const LocalDate(2026, 10, 12));
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a cell is announced with its date and entries', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Monday 5 October 2026: Day 07:00–19:00'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a preview takes no keys and opens nothing', (tester) async {
    LocalDate? opened;
    await _pump(tester, readOnly: true, onOpen: (day) => opened = day);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    final cell = find.byKey(const ValueKey('work-calendar-day-2026-10-12'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(opened, isNull);
  });
}
