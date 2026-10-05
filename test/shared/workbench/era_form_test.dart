import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/era_field.dart';
import 'package:lifeos/shared/workbench/era_form.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';

Widget _host(Widget child) => MaterialApp(
  home: LifeOSSkinScope(
    child: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 420, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('a field sits after its "Label:" at its kind width', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        EraField(
          controller: controller,
          label: 'Hourly rate (€)',
          fieldKey: const ValueKey('rate'),
          width: EraFieldWidth.money,
        ),
      ),
    );
    expect(find.text('Hourly rate (€):'), findsOneWidget);
    final label = tester.getRect(find.text('Hourly rate (€):'));
    final field = tester.getRect(find.byKey(const ValueKey('rate')));
    expect(field.left, greaterThan(label.right));
    expect(field.width, EraFieldWidth.money);
    expect((field.top - label.top).abs(), lessThan(8), reason: 'same row');
  });

  testWidgets('a check box is 13 px, beside its label, toggled by the row', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => EraCheckBox(
            key: const ValueKey('night'),
            value: value,
            label: 'Night pay',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('era-check-box'))),
      const Size(13, 13),
    );
    final box = tester.getRect(find.byKey(const ValueKey('era-check-box')));
    final label = tester.getRect(find.text('Night pay'));
    expect(label.left - box.right, lessThanOrEqualTo(6));
    await tester.tap(find.text('Night pay'));
    await tester.pump();
    expect(value, isTrue);
    expect(
      tester.getSize(find.byKey(const ValueKey('night'))).height,
      greaterThanOrEqualTo(24),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('night'))),
      isSemantics(
        label: 'Night pay',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('radios choose one value', (tester) async {
    var basis = 'gross';
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              for (final option in ['gross', 'net'])
                EraRadio<String>(
                  value: option,
                  groupValue: basis,
                  label: option == 'gross' ? 'Gross' : 'Net',
                  onChanged: (next) => setState(() => basis = next),
                ),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('era-radio')).first),
      const Size(13, 13),
    );
    await tester.tap(find.text('Net'));
    await tester.pump();
    expect(basis, 'net');
  });
}
