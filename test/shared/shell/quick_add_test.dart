import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/quick_add.dart';
import 'package:lifeos/shared/shell/shell_frame.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    bool hasEmployment = true,
    bool hasLastShift = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final opened = <String>[];
    QuickAddEntry entry(String label, {bool needsEmployment = true}) =>
        QuickAddEntry(
          area: LifeOSArea.work,
          label: label,
          open: needsEmployment && !hasEmployment
              ? null
              : () => opened.add(label),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: LifeOSSkinScope(
          child: ShellChrome(
            menuBar: const SizedBox.shrink(),
            tree: (_) => const SizedBox.shrink(),
            status: const SizedBox.shrink(),
            title: 'Work',
            onNavigate: (_) {},
            quickAdd: [
              entry('Start shift'),
              entry('Manual shift'),
              entry('Pay period'),
              entry('Payslip'),
              entry('Employment', needsEmployment: false),
              entry('Agreement'),
            ],
            fromLastTime: [
              if (hasLastShift) entry('Manual shift from last time'),
            ],
            child: const ShellFrame(
              desk: SizedBox.shrink(),
              inspector: SizedBox.shrink(),
              inspectorOpen: false,
              onBackToDesk: _noop,
            ),
          ),
        ),
      ),
    );
    return opened;
  }

  testWidgets('+ Add lists the six Work record types', (tester) async {
    final opened = await pump(tester);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    for (final label in [
      'Start shift',
      'Manual shift',
      'Pay period',
      'Payslip',
      'Employment',
      'Agreement',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.tap(find.text('Payslip'));
    await tester.pumpAndSettle();
    expect(opened, ['Payslip']);
  });

  testWidgets('without an employment only Employment can be added', (
    tester,
  ) async {
    final opened = await pump(tester, hasEmployment: false);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start shift'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Employment'));
    await tester.pumpAndSettle();
    expect(opened, ['Employment']);
  });

  testWidgets('"from last time" sits beside + Add only when it exists', (
    tester,
  ) async {
    final opened = await pump(tester);
    await tester.tap(find.text('Manual shift from last time'));
    expect(opened, ['Manual shift from last time']);

    await pump(tester, hasLastShift: false);
    expect(find.text('Manual shift from last time'), findsNothing);
  });
}

void _noop() {}
