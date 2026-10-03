import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/shared/workbench/era_date_field.dart';
import 'package:lifeos/shared/workbench/era_dates.dart';
import 'package:lifeos/shared/workbench/era_time_field.dart';

/// Drive the era date and time boxes the way the owner does. Dates and
/// times are never typed (era pickers spec 5).

Finder _dateField(String key) => find.ancestor(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EraDateField),
);

Finder _timeField(String key) => find.ancestor(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(EraTimeField),
);

/// The date in the box keyed [key]; null when an optional box is clear.
LocalDate? dateIn(WidgetTester tester, String key) =>
    tester.widget<EraDateField>(_dateField(key)).value;

/// The time in the box keyed [key]; null when it shows "--:--".
LocalTime? timeIn(WidgetTester tester, String key) =>
    tester.widget<EraTimeField>(_timeField(key)).value;

/// Ticks an optional box when clear, opens its calendar, pages to [date]'s
/// month with ◂ or ▸, and clicks the day.
Future<void> pickDate(WidgetTester tester, String key, LocalDate date) async {
  final box = find.byKey(ValueKey(key));
  await tester.ensureVisible(box);
  await tester.pumpAndSettle();
  if (dateIn(tester, key) == null) {
    await tester.tap(
      find.descendant(
        of: _dateField(key),
        matching: find.byKey(const ValueKey('era-date-check')),
      ),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(box);
  await tester.pumpAndSettle();
  final title = tester
      .widget<Text>(find.byKey(const ValueKey('era-calendar-title')))
      .data!;
  final [monthName, yearText] = title.split(' ');
  final months =
      (date.year - int.parse(yearText)) * 12 +
      date.month -
      (eraMonthNames.indexOf(monthName) + 1);
  final page = find.byKey(
    ValueKey(months < 0 ? 'era-calendar-previous' : 'era-calendar-next'),
  );
  for (var index = 0; index < months.abs(); index++) {
    await tester.tap(page);
    await tester.pump();
  }
  await tester.tap(find.byKey(ValueKey('era-day-$date')));
  await tester.pumpAndSettle();
}

/// Selects each part of the box keyed [key] and steps it up to [time]'s
/// value: PageUp for tens, Up for ones. An empty box takes its first step
/// before counting.
Future<void> setTime(WidgetTester tester, String key, LocalTime time) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  Future<void> select(String part) async {
    await tester.tap(
      find.descendant(
        of: _timeField(key),
        matching: find.byKey(ValueKey('era-time-$part')),
      ),
    );
    await tester.pump();
  }

  Future<void> press(LogicalKeyboardKey pressed, int times) async {
    for (var index = 0; index < times; index++) {
      await tester.sendKeyEvent(pressed);
      await tester.pump();
    }
  }

  Future<void> move(String part, int from, int to, int modulo) async {
    await select(part);
    final ahead = (to - from) % modulo;
    await press(LogicalKeyboardKey.pageUp, ahead ~/ 10);
    await press(LogicalKeyboardKey.arrowUp, ahead % 10);
  }

  await select('hour');
  if (timeIn(tester, key) == null) {
    await press(LogicalKeyboardKey.arrowUp, 1);
  }
  final now = timeIn(tester, key)!;
  await move('hour', now.hour, time.hour, 24);
  await move('minute', now.minute, time.minute, 60);
  if (time.second != 0 || now.second != 0) {
    expect(
      find.descendant(
        of: _timeField(key),
        matching: find.byKey(const ValueKey('era-time-second')),
      ),
      findsOneWidget,
      reason: 'the box keyed $key shows no seconds',
    );
    await move('second', now.second, time.second, 60);
  }
  await tester.pumpAndSettle();
}
