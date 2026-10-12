import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show MenuItemButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/app_frame_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

/// The layout matrix of spec section 3 ("Narrow windows", "Text scaling").
const appFrameSizes = [
  Size(1280, 800),
  Size(1024, 768),
  Size(960, 700),
  Size(860, 650),
  Size(800, 600),
];

/// Pumps the gallery's whole frame composition on a client area of [size]
/// at text [scale], the way the app hosts it: theme, skin, era scrolling.
Future<AppFrameShowcaseState> pumpAppFrame(
  WidgetTester tester,
  Size size, {
  double scale = 1,
  GalleryKnobs knobs = const GalleryKnobs(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GalleryHost(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: EraFormScope(
            enabled: knobs.enabled,
            child: AppFrameShowcase(knobs: knobs),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return showcaseOf(tester);
}

AppFrameShowcaseState showcaseOf(WidgetTester tester) =>
    tester.state<AppFrameShowcaseState>(find.byType(AppFrameShowcase));

AppFrameState frameOf(WidgetTester tester) =>
    tester.state<AppFrameState>(find.byType(AppFrame));

/// Changes the window to [size] and lets the frame settle.
Future<void> resizeTo(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// The middle column's data grid (the subform tabs hold none).
final dataGrid = find.byWidgetPredicate((widget) => widget is DataGrid);
final treeColumn = find.byKey(const ValueKey('app-frame-tree-column'));
final propertyColumn = find.byKey(const ValueKey('app-frame-property-column'));
final treeOverlay = find.byKey(const ValueKey('app-frame-tree-overlay'));
final treeKey = find.byWidgetPredicate(
  (widget) => widget is KeyButton && widget.semanticLabel == 'Tree',
);
Finder splitter(String id) => find.byKey(ValueKey('app-frame-splitter:$id'));
Finder propertyValue(String key) => find.byKey(ValueKey('property-value:$key'));
Finder propertyEditor(String key) =>
    find.byKey(ValueKey('property-editor:$key'));
Finder toolbarKey(String label) => find.byWidgetPredicate(
  (widget) => widget is KeyButton && widget.semanticLabel == label,
);
Finder pushKey(String label) => find.byWidgetPredicate(
  (widget) => widget is KeyButton && widget.label == label,
);

/// A row of an open choice list (an era combo's drop-down).
Finder comboChoice(String label) => find.descendant(
  of: find.byType(MenuItemButton),
  matching: find.text(label),
);

/// The docked Properties tab's face (among the subform tabs).
Finder dockTab([String label = 'Properties']) =>
    find.descendant(of: find.byType(Subform), matching: find.text(label));

/// Asserts that a mouse press at [alignment] in [finder] (its centre by
/// default) reaches it: inside the window and not covered by anything else.
/// A long wrapped message is checked at its first line ([Alignment.topLeft]
/// moved 4 px in), which a reader scrolls on from.
void expectHittable(
  WidgetTester tester,
  Finder finder, {
  String? reason,
  Alignment alignment = Alignment.center,
}) {
  final box = tester.renderObject<RenderBox>(finder);
  final inset = alignment == Alignment.center
      ? box.size.center(Offset.zero)
      : alignment.alongSize(box.size) + const Offset(4, 4);
  final center = box.localToGlobal(inset);
  final window = Offset.zero & tester.view.physicalSize;
  expect(window.contains(center), isTrue, reason: '$reason: off-window');
  final result = tester.hitTestOnBinding(center);
  expect(
    result.path.any((entry) => entry.target == box),
    isTrue,
    reason: '${reason ?? finder}: covered at $center',
  );
}

/// Scrolls [finder] into view, asserts it can be hit, then clicks it.
Future<void> click(WidgetTester tester, Finder finder, {String? reason}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expectHittable(tester, finder, reason: reason);
  await tester.tap(finder, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Drags [finder] by [offset] with the mouse, from its centre.
Future<void> drag(WidgetTester tester, Finder finder, Offset offset) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
  );
  await gesture.moveBy(offset);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Shows the property pane: the docked tab when docked.
Future<void> showProperties(
  WidgetTester tester, {
  String label = 'Properties',
}) async {
  if (frameOf(tester).layout!.propertiesDocked) {
    await click(tester, dockTab(label), reason: 'dock tab $label');
  }
}

/// Whether the primary focus is inside [finder].
bool focusedIn(WidgetTester tester, Finder finder) {
  final focus = FocusManager.instance.primaryFocus?.context;
  if (focus == null) return false;
  final target = finder.evaluate().single;
  var inside = focus == target;
  focus.visitAncestorElements((element) {
    if (element == target) inside = true;
    return !inside;
  });
  return inside;
}

/// The data grid's cell of [row] and [column], scrolled into view (its rows
/// are built lazily). Use a column near the left: columns are not scrolled.
Future<Finder> gridCell(WidgetTester tester, String row, String column) async {
  final cell = find.byKey(ValueKey('grid-cell:$row:$column'));
  if (cell.evaluate().isEmpty) {
    final body = find.descendant(
      of: dataGrid,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    final position = tester
        .stateList<ScrollableState>(body)
        .map((state) => state.position)
        .firstWhere((position) => position.maxScrollExtent > 0);
    // Scrolled by the program, not dragged: the grid's centre may itself
    // be scrolled out of a short page.
    position.jumpTo(0);
    await tester.pump();
    while (cell.evaluate().isEmpty &&
        position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        (position.pixels + 40).clamp(0.0, position.maxScrollExtent),
      );
      await tester.pump();
    }
  }
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  return cell;
}
