import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

/// One pane's probe: a box that reports whether its region is active.
Widget _probe(String name, {FocusNode? focus}) => Builder(
  builder: (context) => SizedBox.expand(
    child: Focus(
      focusNode: focus,
      child: Text('$name ${ActiveRegion.of(context) ? 'active' : 'inactive'}'),
    ),
  ),
);

/// AppFrame shows one region's selection as active (DESIGN.md: blue in the
/// active region, face grey elsewhere), bead 9pk.4.45.
void main() {
  Future<void> pump(
    WidgetTester tester,
    Size size, {
    FocusNode? propertiesFocus,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLifeOSTheme(),
        home: LifeOSSkinScope(
          child: Material(
            child: AppFrame(
              toolbarBuilder: (context, tree) => BandedToolbar(
                bands: [
                  ToolbarBand(
                    items: [
                      ?tree,
                      ToolbarItem(label: 'Save', onPressed: () {}),
                    ],
                  ),
                ],
              ),
              areas: const [TabItem(id: 'work', label: 'Work')],
              areaId: 'work',
              onAreaSelect: (_) {},
              tree: _probe('Tree'),
              details: const Text('Details'),
              middle: _probe('Middle'),
              subformTabs: [
                SubformTab(
                  id: 'a',
                  label: 'A',
                  builder: (_) => _probe('Lower'),
                ),
              ],
              subformSelectedId: 'a',
              properties: _probe('Properties', focus: propertiesFocus),
              status: const StatusBar(notice: 'Ready.'),
              panes: AppFramePanes.baseline,
              onPanesChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectActive(String region) {
    for (final name in ['Tree', 'Middle', 'Lower', 'Properties']) {
      expect(
        find.text('$name ${name == region ? 'active' : 'inactive'}'),
        findsOneWidget,
        reason: name,
      );
    }
  }

  testWidgets('an editor focused without a press activates its region', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pump(tester, const Size(1280, 800), propertiesFocus: focus);
    expectActive('Middle');
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expectActive('Properties');
  });

  testWidgets('the middle is active first; a press makes its region active', (
    tester,
  ) async {
    await pump(tester, const Size(1280, 800));
    expectActive('Middle');
    for (final name in ['Properties', 'Tree', 'Lower', 'Middle']) {
      await tester.tap(
        find.textContaining('$name '),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expectActive(name);
    }
  });
}
