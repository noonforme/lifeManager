import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/domain/schedule.dart';
import 'package:lifeos/features/work/presentation/shift_types_dialog.dart';
import 'package:lifeos/shared/workbench/era_dialog.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../../../support/era_pickers.dart';
import '../../../support/schedule_fixture.dart';

List<ShiftType>? _result;

Future<void> _open(
  WidgetTester tester, {
  List<ShiftType>? types,
  Set<ShiftTypeId> used = const {},
}) async {
  _result = null;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: Builder(
            builder: (context) => KeyButton(
              label: 'Open',
              onPressed: () async => _result = await editShiftTypes(
                context,
                types: types ?? depotDraft().shiftTypes,
                used: used,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Finder _key(String label) => find.descendant(
  of: find.byType(EraDialog).last,
  matching: find.widgetWithText(KeyButton, label),
);

void main() {
  test('names and summaries read as the era list did', () {
    final night = depotDraft().shiftTypes.last;
    expect(typeTimes(night), '19:00–07:00 +1');
    expect(breakSummary(night), '30 min');
    expect(
      nextShiftTypeId(depotDraft().shiftTypes),
      const ShiftTypeId('type-1'),
    );
  });

  testWidgets('lists the types with their times and paid time', (tester) async {
    await _open(tester);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('07:00–19:00'), findsOneWidget);
    expect(find.text('Night'), findsOneWidget);
    expect(find.text('19:00–07:00 +1'), findsOneWidget);
    // Both are 12 hours with a 30-minute break.
    expect(find.text('11:30'), findsNWidgets(2));
  });

  testWidgets('a type the cycle uses cannot be removed', (tester) async {
    await _open(tester, used: {const ShiftTypeId('day')});
    await tester.tap(find.byKey(const ValueKey('shift-type-row-0')));
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(_key('Remove')).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('shift-type-row-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<KeyButton>(_key('Remove')).onPressed, isNotNull);
  });

  testWidgets('Add… makes a new type; OK returns the list', (tester) async {
    await _open(tester);
    await tester.tap(_key('Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('type-name')), 'Late');
    await setTime(tester, 'type-start', const LocalTime(14, 0));
    await setTime(tester, 'type-end', const LocalTime(22, 0));
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsOneWidget);
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(_result!.map((type) => type.name), ['Day', 'Night', 'Late']);
    expect(_result!.last.id, const ShiftTypeId('type-1'));
  });

  testWidgets('a break outside the shift keeps the type dialog open', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('shift-type-row-0')));
    await tester.tap(_key('Edit…'));
    await tester.pumpAndSettle();
    await setTime(tester, 'type-break-0-start', const LocalTime(20, 0));
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Breaks must lie inside the shift, not overlap, and last 1 to 240 '
        'minutes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a name another type has is refused', (tester) async {
    await _open(tester);
    await tester.tap(_key('Add…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('type-name')), 'Day');
    await tester.tap(_key('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Another shift type has this name.'), findsOneWidget);
  });

  testWidgets('Cancel returns nothing', (tester) async {
    await _open(tester);
    await tester.tap(_key('Cancel'));
    await tester.pumpAndSettle();
    expect(_result, isNull);
  });
}
