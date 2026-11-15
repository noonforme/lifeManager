import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

import 'era_pickers.dart';

final class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

final class _FormState extends State<_Form> {
  LocalDate? start = const LocalDate(2026, 10, 5);
  LocalDate? end;
  LocalTime? at;
  LocalTime? precise = const LocalTime(8, 0, 13);

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      EraDateField(
        label: 'Start',
        fieldKey: const ValueKey('start'),
        value: start,
        today: const LocalDate(2026, 10, 5),
        onChanged: (value) => setState(() => start = value),
      ),
      EraDateField(
        label: 'End',
        optional: true,
        fieldKey: const ValueKey('end'),
        value: end,
        today: const LocalDate(2026, 10, 5),
        onChanged: (value) => setState(() => end = value),
      ),
      EraTimeField(
        label: 'At',
        fieldKey: const ValueKey('at'),
        value: at,
        emptyStart: const LocalTime(9, 0),
        onChanged: (value) => setState(() => at = value),
      ),
      EraTimeField(
        label: 'Precise',
        fieldKey: const ValueKey('precise'),
        value: precise,
        onChanged: (value) => setState(() => precise = value),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    theme: buildLifeOSTheme(),
    home: const LifeOSSkinScope(
      child: Scaffold(body: SizedBox(width: 320, child: _Form())),
    ),
  ),
);

void main() {
  testWidgets('pickDate pages back across a year and picks the day', (
    tester,
  ) async {
    await _pump(tester);
    await pickDate(tester, 'start', const LocalDate(2025, 11, 30));
    expect(dateIn(tester, 'start'), const LocalDate(2025, 11, 30));
  });

  testWidgets('pickDate ticks an optional box first', (tester) async {
    await _pump(tester);
    expect(dateIn(tester, 'end'), isNull);
    await pickDate(tester, 'end', const LocalDate(2027, 2, 28));
    expect(dateIn(tester, 'end'), const LocalDate(2027, 2, 28));
  });

  testWidgets('setTime fills an empty box and wraps backwards', (tester) async {
    await _pump(tester);
    await setTime(tester, 'at', const LocalTime(6, 45));
    expect(timeIn(tester, 'at'), const LocalTime(6, 45));
    await setTime(tester, 'at', const LocalTime(22, 5));
    expect(timeIn(tester, 'at'), const LocalTime(22, 5));
  });

  testWidgets('setTime steps the seconds of a box that shows them', (
    tester,
  ) async {
    await _pump(tester);
    await setTime(tester, 'precise', const LocalTime(8, 30, 0));
    expect(timeIn(tester, 'precise'), const LocalTime(8, 30, 0));
  });
}
