import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

const _october = LocalDate(2026, 10, 1);
const _today = LocalDate(2026, 10, 20);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryHost(home: SizedBox(width: 840, height: 540, child: child)),
  );
  await tester.pumpAndSettle();
}

Finder _day(LocalDate date) => find.byKey(ValueKey('day-calendar-$date'));

void main() {
  testWidgets('October 2026 starts on Thursday under Mon–Sun', (tester) async {
    await _pump(
      tester,
      DayCalendar(
        label: 'Calendar',
        month: _october,
        today: _today,
        days: {
          LocalDate(2026, 9, 28): DayCalendarDay(
            lines: [DayCalendarLine('Not shown')],
          ),
        },
      ),
    );
    for (final head in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(head), findsOneWidget);
    }
    final monday = tester.getTopLeft(_day(const LocalDate(2026, 9, 28)));
    final first = tester.getTopLeft(_day(const LocalDate(2026, 10, 1)));
    final thursday = tester.getTopLeft(find.text('Thu'));
    expect(first.dy, monday.dy, reason: 'the first week row');
    expect(first.dx, lessThanOrEqualTo(thursday.dx));
    expect(
      tester.getTopLeft(_day(const LocalDate(2026, 10, 2))).dx,
      greaterThan(thursday.dx),
    );
    expect(find.text('Not shown'), findsNothing);
  });

  testWidgets('a click selects an in-month day and nothing else', (
    tester,
  ) async {
    final picked = <LocalDate>[];
    await _pump(
      tester,
      DayCalendar(
        label: 'Calendar',
        month: _october,
        today: _today,
        days: const {},
        onSelect: picked.add,
      ),
    );
    final before = FocusManager.instance.primaryFocus;
    await tester.tap(_day(const LocalDate(2026, 10, 6)));
    await tester.pump();
    await tester.tap(_day(const LocalDate(2026, 9, 28)));
    await tester.pump();
    expect(picked, [const LocalDate(2026, 10, 6)]);
    expect(FocusManager.instance.primaryFocus, before);
  });

  testWidgets('the words are its semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      DayCalendar(
        label: 'Calendar',
        month: _october,
        today: _today,
        selected: LocalDate(2026, 10, 6),
        days: {
          LocalDate(2026, 10, 6): DayCalendarDay(
            lines: [
              DayCalendarLine('Day 07:00–19:00', tone: DayTone.first),
              DayCalendarLine(
                'To confirm',
                mark: DayCalendarMark.warning,
                ink: DayCalendarInk.run,
              ),
            ],
          ),
          LocalDate(2026, 10, 22): DayCalendarDay(
            lines: [
              DayCalendarLine('', struck: 'Night 19:00–07:00'),
              DayCalendarLine('Cancelled · Swapped', ink: DayCalendarInk.muted),
            ],
          ),
        },
      ),
    );
    expect(
      tester.getSemantics(_day(const LocalDate(2026, 10, 6))),
      matchesSemantics(
        label:
            '${spokenDate(const LocalDate(2026, 10, 6))}: '
            'Day 07:00–19:00, To confirm',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
      ),
    );
    expect(
      tester.getSemantics(_day(const LocalDate(2026, 10, 22))).label,
      '${spokenDate(const LocalDate(2026, 10, 22))}: '
      'Night 19:00–07:00, Cancelled · Swapped',
    );
    semantics.dispose();
  });

  testWidgets('keys do nothing', (tester) async {
    final picked = <LocalDate>[];
    await _pump(
      tester,
      DayCalendar(
        label: 'Calendar',
        month: _october,
        today: _today,
        days: const {},
        selected: const LocalDate(2026, 10, 6),
        onSelect: picked.add,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(picked, isEmpty);
  });

  testWidgets('a disabled calendar selects nothing', (tester) async {
    final picked = <LocalDate>[];
    await _pump(
      tester,
      DayCalendar(
        label: 'Calendar',
        month: _october,
        today: _today,
        days: const {},
        enabled: false,
        onSelect: picked.add,
      ),
    );
    await tester.tap(_day(const LocalDate(2026, 10, 6)));
    await tester.pump();
    expect(picked, isEmpty);
  });

  testWidgets('the key names each tone', (tester) async {
    await _pump(
      tester,
      const DayCalendarKey([
        (DayTone.first, 'Day'),
        (DayTone.second, 'Night'),
        (DayTone.third, 'Extra'),
        (DayTone.fourth, 'Leave'),
      ]),
    );
    for (final word in ['Day', 'Night', 'Extra', 'Leave']) {
      expect(find.text(word), findsOneWidget);
    }
  });

  testWidgets('lines that do not fit fold into "+N more"; none is cut', (
    tester,
  ) async {
    const day = LocalDate(2026, 10, 7);
    await _pump(
      tester,
      DayCalendar(
        label: 'Calendar',
        month: _october,
        today: _today,
        days: {
          day: DayCalendarDay(
            lines: [for (var n = 1; n <= 8; n++) DayCalendarLine('Line $n')],
          ),
          const LocalDate(2026, 10, 8): const DayCalendarDay(
            lines: [DayCalendarLine('Day 07:00–19:00')],
          ),
        },
      ),
    );
    final cell = tester.getRect(_day(day));
    var shown = 0;
    for (var n = 1; n <= 8; n++) {
      final line = tester.getRect(find.text('Line $n'));
      final inside = line.top < cell.bottom && line.bottom > cell.top;
      if (!inside) continue;
      expect(line.bottom, lessThanOrEqualTo(cell.bottom), reason: 'Line $n');
      expect(n, shown + 1, reason: 'the lines shown come first, in order');
      shown++;
    }
    expect(shown, inInclusiveRange(1, 7));
    final more = find.text('+${8 - shown} more').hitTestable();
    expect(more, findsOneWidget);
    expect(tester.getRect(more).bottom, lessThanOrEqualTo(cell.bottom));
    // The other counts lie beyond the clip.
    expect(find.textContaining('more').hitTestable(), findsOneWidget);
  });
}
