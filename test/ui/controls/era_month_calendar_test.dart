import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/ui.dart';

const _today = LocalDate(2026, 10, 5);

Future<List<LocalDate>> _pump(
  WidgetTester tester, {
  LocalDate? selected = _today,
  VoidCallback? onCancel,
  double textScale = 1,
}) async {
  final picked = <LocalDate>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Center(
              child: EraMonthCalendar(
                selected: selected,
                today: _today,
                onPicked: picked.add,
                onCancel: onCancel,
                autofocus: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return picked;
}

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('era-calendar-title'))).data!;

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Finder _day(String iso) => find.byKey(ValueKey('era-day-$iso'));

void main() {
  testWidgets('weeks start on Monday under their initials', (tester) async {
    await _pump(tester);
    expect(_title(tester), 'October 2026');
    expect(_day('2026-09-28'), findsOneWidget);
    expect(_day('2026-09-27'), findsNothing);
    expect(
      tester.getCenter(_day('2026-09-28')).dx,
      closeTo(tester.getCenter(find.text('Mo')).dx, 0.5),
    );
  });

  testWidgets('today is circled and outside days are muted', (tester) async {
    await _pump(tester, selected: null);
    expect(find.byKey(const ValueKey('era-today-ring')), findsOneWidget);
    expect(
      find.descendant(
        of: _day('2026-10-05'),
        matching: find.byKey(const ValueKey('era-today-ring')),
      ),
      findsOneWidget,
    );
    Color? ink(String iso) => tester
        .widget<Text>(
          find.descendant(of: _day(iso), matching: find.byType(Text)),
        )
        .style!
        .color;
    expect(ink('2026-09-30'), LifeOSTokens.millennium.muted);
    expect(ink('2026-10-14'), LifeOSTokens.millennium.ink);
  });

  testWidgets('arrows move a day or a week and Enter picks', (tester) async {
    final picked = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.space);
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    await _press(tester, LogicalKeyboardKey.arrowUp);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked, const [
      LocalDate(2026, 10, 6),
      LocalDate(2026, 10, 13),
      LocalDate(2026, 10, 5),
    ]);
  });

  testWidgets('pages move a month, with Shift a year', (tester) async {
    final picked = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(_title(tester), 'November 2026');
    await _press(tester, LogicalKeyboardKey.pageUp);
    await _press(tester, LogicalKeyboardKey.pageUp, shift: true);
    expect(_title(tester), 'October 2025');
    await _press(tester, LogicalKeyboardKey.pageDown, shift: true);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked.single, _today);
  });

  testWidgets('Home and End go to the ends of the month', (tester) async {
    final picked = await _pump(tester);
    await _press(tester, LogicalKeyboardKey.home);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.end);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked, const [LocalDate(2026, 10, 1), LocalDate(2026, 10, 31)]);
  });

  testWidgets('moving past the month pages across a year end', (tester) async {
    final picked = await _pump(tester, selected: const LocalDate(2026, 12, 28));
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_title(tester), 'January 2027');
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked.single, const LocalDate(2027, 1, 4));
  });

  testWidgets('31 January pages to the last day of February', (tester) async {
    final picked = await _pump(tester, selected: const LocalDate(2028, 1, 31));
    await _press(tester, LogicalKeyboardKey.pageDown);
    expect(_day('2028-02-29'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.pageDown, shift: true);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(picked, const [LocalDate(2028, 2, 29), LocalDate(2029, 2, 28)]);
  });

  testWidgets('the header keys page and a click picks', (tester) async {
    final picked = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('era-calendar-next')));
    await tester.pump();
    expect(_title(tester), 'November 2026');
    await tester.tap(find.byKey(const ValueKey('era-calendar-previous')));
    await tester.tap(find.byKey(const ValueKey('era-calendar-previous')));
    await tester.pump();
    expect(_title(tester), 'September 2026');
    await tester.tap(_day('2026-09-17'));
    expect(picked.single, const LocalDate(2026, 9, 17));
  });

  testWidgets('a year of clicks on ▸ never moves the calendar or its key', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, textScale: scale);
      final next = find.byKey(const ValueKey('era-calendar-next'));
      final size = tester.getSize(find.byType(EraMonthCalendar));
      final key = tester.getCenter(next);
      for (var month = 0; month < 12; month++) {
        await tester.tapAt(key);
        await tester.pump();
        // The weeks decide the width, never the month's name.
        expect(tester.getSize(find.byType(EraMonthCalendar)), size);
        expect(tester.getCenter(next), key);
      }
      expect(_title(tester), 'October 2027');
    }
  });

  testWidgets('the Today link picks today', (tester) async {
    final picked = await _pump(tester, selected: const LocalDate(2026, 3, 1));
    expect(find.text('Today: 2026-10-05'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('era-calendar-today')));
    expect(picked.single, _today);
  });

  testWidgets('as a drop-down, Esc cancels and Tab stays inside', (
    tester,
  ) async {
    var cancelled = 0;
    await _pump(tester, onCancel: () => cancelled++);
    final focus = tester.binding.focusManager.primaryFocus;
    await _press(tester, LogicalKeyboardKey.tab);
    expect(tester.binding.focusManager.primaryFocus, same(focus));
    await _press(tester, LogicalKeyboardKey.escape);
    expect(cancelled, 1);
  });

  testWidgets('days are labelled and the chosen day is selected', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getSemantics(_day('2026-10-05')),
      isSemantics(
        label: 'Monday 5 October 2026',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_day('2026-10-06')),
      isSemantics(label: 'Tuesday 6 October 2026', isSelected: false),
    );
  });

  testWidgets('day cells are at least 24 px and hold at 200 % text', (
    tester,
  ) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    final cell = tester.getSize(_day('2026-10-05'));
    expect(cell.width, greaterThanOrEqualTo(24));
    expect(cell.height, greaterThanOrEqualTo(24));
    final calendar = tester.getRect(find.byType(EraMonthCalendar));
    expect(calendar.left, greaterThanOrEqualTo(0));
    expect(calendar.top, greaterThanOrEqualTo(0));
    expect(calendar.right, lessThanOrEqualTo(800));
    expect(calendar.bottom, lessThanOrEqualTo(600));
  });
}
