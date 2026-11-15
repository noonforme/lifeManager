import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1000, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryHost(
      home: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

const _day = DayMark(text: 'D', tone: DayTone.first, semantics: 'Day 1, Day');

void main() {
  testWidgets('a strip numbers its days and rings today', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const DayStrip(
        label: 'Cycle, 3 days:',
        marks: [
          _day,
          DayMark(
            text: 'D',
            tone: DayTone.first,
            ring: true,
            semantics: 'Day 2, Day, today',
          ),
          DayMark(semantics: 'Day 3, Off'),
        ],
        trailing: 'Today is cycle day 2',
      ),
    );
    expect(find.text('Cycle, 3 days:'), findsOneWidget);
    for (final number in ['1', '2', '3']) {
      expect(find.text(number), findsOneWidget);
    }
    expect(find.text('D'), findsNWidgets(2));
    expect(find.text('Today is cycle day 2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('today')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an empty strip says so', (tester) async {
    await _pump(tester, const DayStrip(label: 'Cycle, 0 days:', marks: []));
    expect(find.text('No days yet'), findsOneWidget);
  });

  testWidgets('a month row ends its days and shows totals', (tester) async {
    await _pump(
      tester,
      SizedBox(
        width: 900,
        height: 120,
        child: MonthStrip(
          label: 'Preview',
          totalHeads: const ['Shifts', 'Paid', 'Planned pay'],
          rows: [
            MonthStripRow(
              label: 'Nov 2026',
              days: [
                for (var day = 1; day <= 30; day++)
                  DayMark(semantics: 'Nov $day'),
              ],
              totals: const ['13', '149:30', 'EUR 3 164.80'],
            ),
          ],
        ),
      ),
    );
    expect(find.byKey(const ValueKey('month-day:0:30')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-day:0:31')), findsNothing);
    for (final text in ['31', 'Shifts', '149:30', 'EUR 3 164.80']) {
      expect(find.text(text), findsOneWidget);
    }
    // Day 13's heading and the month's shifts.
    expect(find.text('13'), findsNWidgets(2));
  });

  testWidgets('a note replaces the totals', (tester) async {
    await _pump(
      tester,
      const SizedBox(
        width: 900,
        height: 120,
        child: MonthStrip(
          label: 'Preview',
          totalHeads: ['Shifts', 'Paid', 'Planned pay'],
          rows: [
            MonthStripRow(
              label: 'Jan 2027',
              days: [],
              totals: ['0', '0:00', 'EUR 0.00'],
              note: 'Winter rotation',
            ),
          ],
        ),
      ),
    );
    expect(find.text('Winter rotation'), findsOneWidget);
    expect(find.text('EUR 0.00'), findsNothing);
  });

  testWidgets('hatched days hide their text but keep their words', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const DayStrip(
        label: 'Cycle, 1 day:',
        marks: [
          DayMark(
            text: 'D',
            hatched: true,
            semantics: 'Fri 2027-01-01, Winter rotation',
          ),
        ],
      ),
    );
    expect(find.text('D'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Winter rotation')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a short month strip scrolls down instead of overflowing', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: 600,
        height: 70,
        child: MonthStrip(
          label: 'Preview',
          totalHeads: const ['Shifts'],
          rows: [
            for (final month in ['Oct', 'Nov', 'Dec', 'Jan'])
              MonthStripRow(
                label: month,
                days: [for (var d = 1; d <= 30; d++) DayMark(semantics: '$d')],
                totals: const ['13'],
              ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Jan', skipOffstage: false), findsOneWidget);
  });
}
