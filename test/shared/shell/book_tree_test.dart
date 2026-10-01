import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/shell/book_tree.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

Future<List<String>> _pumpTree(WidgetTester tester, {String? selected}) async {
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: LifeOSSkinScope(
        child: Scaffold(
          body: SizedBox(
            width: 228,
            child: BookTree(
              nodes: const [
                TreeSheet(label: 'Journal', route: '/journal', built: false),
                TreeArea(
                  area: LifeOSArea.work,
                  route: '/work',
                  built: true,
                  children: [
                    TreeSheet(
                      label: 'Synthetic depot',
                      route: '/work?employment=a',
                      liveValue: 'running',
                      liveValueIsActive: true,
                    ),
                  ],
                ),
                TreeArea(
                  area: LifeOSArea.finance,
                  route: '/finance',
                  built: false,
                ),
                TreeArea(
                  area: LifeOSArea.tracking,
                  route: '/tracking',
                  built: false,
                ),
                TreeArea(
                  area: LifeOSArea.knowledge,
                  route: '/knowledge',
                  built: false,
                ),
              ],
              footer: const [
                TreeSheet(label: 'Backup and export', route: '/system/files'),
              ],
              selectedRoute: selected,
              onOpen: opened.add,
            ),
          ),
        ),
      ),
    ),
  );
  return opened;
}

void main() {
  testWidgets('unbuilt areas say so and still open their sheet', (
    tester,
  ) async {
    final opened = await _pumpTree(tester);
    // Journal, Finance, Tracking and Knowledge.
    expect(find.text('Not built yet'), findsNWidgets(4));

    await tester.tap(find.text('Finance'));
    expect(opened, ['/finance']);
  });

  testWidgets('a running employment shows its live value', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpTree(tester);
    expect(find.text('running'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Synthetic depot')),
      matchesSemantics(
        label: 'Synthetic depot',
        value: 'running',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the selected node is marked selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpTree(tester, selected: '/work?employment=a');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Synthetic depot')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Journal')),
      isSemantics(isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('right-click lists Open, Open on new desk and Add to desk', (
    tester,
  ) async {
    final opened = await _pumpTree(tester);
    await tester.tap(find.text('Synthetic depot'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Open on new desk'), findsOneWidget);
    expect(find.text('Add to desk'), findsOneWidget);
    expect(find.text('Arrives with desks'), findsNWidgets(2));

    // Desk items are disabled until desks ship: the menu stays open.
    await tester.tap(find.text('Add to desk'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Open'), findsOneWidget);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(opened, ['/work?employment=a']);
  });
}
