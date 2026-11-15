import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/app_frame_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import 'app_frame_harness.dart';

/// The frame demo's states its default golden (three columns at
/// 1280 x 800) cannot show, shared by the synthetic and real-font variant
/// goldens: the folded tree open, the docked properties with an editor
/// open, the docked action panel, and Enabled off with errors.

Future<void> _asIs(WidgetTester tester) async {}

/// 960 x 700: the tree folded into the toolbar and opened over the page.
Future<void> _openTree(WidgetTester tester) => click(tester, treeKey);

/// 800 x 600: Properties docked beside the subform tabs, End being edited.
Future<void> _editDocked(WidgetTester tester) async {
  await showProperties(tester);
  await click(tester, propertyValue('end'));
}

/// 800 x 600: the action panel in the docked tab, its footer in view.
Future<void> _actionDocked(WidgetTester tester) =>
    click(tester, toolbarKey('Confirm worked days…'));

final appFrameVariants =
    <(String, GalleryDemo, GalleryKnobs, Future<void> Function(WidgetTester))>[
      (
        'shell_app_frame_tree_open',
        appFrameDemoAt(const Size(960, 700)),
        const GalleryKnobs(),
        _openTree,
      ),
      (
        'shell_app_frame_docked',
        appFrameDemoAt(const Size(800, 600)),
        const GalleryKnobs(),
        _editDocked,
      ),
      (
        'shell_app_frame_action_docked',
        appFrameDemoAt(const Size(800, 600)),
        const GalleryKnobs(),
        _actionDocked,
      ),
      (
        'shell_app_frame_disabled_error',
        appFrameDemo,
        const GalleryKnobs(enabled: false, error: true),
        _asIs,
      ),
    ];

/// Guards the variants' premises, so a golden never silently shows another
/// state than its name says.
void expectVariantState(WidgetTester tester, String name) {
  final layout = frameOf(tester).layout!;
  switch (name) {
    case 'shell_app_frame_tree_open':
      expect(layout.treeFolded, isTrue);
      expect(treeOverlay, findsOneWidget);
    case 'shell_app_frame_docked':
      expect(layout.propertiesDocked, isTrue);
      expect(propertyEditor('end'), findsOneWidget);
    case 'shell_app_frame_action_docked':
      expect(layout.propertiesDocked, isTrue);
      expect(find.byType(ActionPanel), findsOneWidget);
    case 'shell_app_frame_disabled_error':
      expect(layout.treeFolded, isFalse);
      expect(layout.propertiesDocked, isFalse);
  }
}
