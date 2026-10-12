import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

const _tree = [
  TreeNodeData(
    id: 'emp:1',
    label: 'Night shifts',
    icon: EraIconKind.employment,
    expanded: true,
    children: [
      TreeNodeData(id: 'emp:1:cal', label: 'Calendar'),
      TreeNodeData(id: 'emp:1:shifts', label: 'Shifts', count: 12),
      TreeNodeData(
        id: 'emp:1:confirm',
        label: 'To confirm',
        count: 3,
        warning: true,
      ),
    ],
  ),
  TreeNodeData(
    id: 'ended',
    label: 'Ended employments',
    muted: true,
    count: 1,
    children: [TreeNodeData(id: 'emp:0', label: 'Old job', muted: true)],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<TreeNodeData> nodes = _tree,
  String? selectedId,
  ValueChanged<String>? onSelect,
  bool active = true,
  bool enabled = true,
  void Function(String, bool)? onExpansionChanged,
  double? maxContentHeight,
  double width = 196,
  double height = 400,
  double scale = 1,
  Key? key,
  Widget? sibling,
}) => tester.pumpWidget(
  MaterialApp(
    scrollBehavior: const EraScrollBehavior(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: LifeOSSkinScope(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: height),
            child: sibling == null
                ? TreeView(
                    key: key,
                    label: 'Object tree',
                    nodes: nodes,
                    selectedId: selectedId,
                    onSelect: onSelect ?? (_) {},
                    active: active,
                    enabled: enabled,
                    onExpansionChanged: onExpansionChanged,
                    maxContentHeight: maxContentHeight,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      sibling,
                      Flexible(
                        child: TreeView(
                          key: key,
                          label: 'Object tree',
                          nodes: nodes,
                          selectedId: selectedId,
                          onSelect: onSelect ?? (_) {},
                          active: active,
                          enabled: enabled,
                          onExpansionChanged: onExpansionChanged,
                          maxContentHeight: maxContentHeight,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a click requests selection and does not accept it itself', (
    tester,
  ) async {
    final requests = <String>[];
    await _pump(tester, selectedId: 'emp:1', onSelect: requests.add);
    await tester.tap(find.text('Calendar'));
    await tester.pump();
    expect(requests, ['emp:1:cal']);
    final node = tester.getSemantics(find.bySemanticsLabel('Calendar'));
    expect(node.flagsCollection.isSelected, Tristate.isFalse);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Night shifts')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });

  testWidgets('expansion is separate from selection and is reported', (
    tester,
  ) async {
    final requests = <String>[];
    final toggles = <(String, bool)>[];
    await _pump(
      tester,
      onSelect: requests.add,
      onExpansionChanged: (id, open) => toggles.add((id, open)),
    );
    expect(find.text('Old job'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tree-box:ended')));
    await tester.pump();
    expect(find.text('Old job'), findsOneWidget);
    expect(toggles, [('ended', true)]);
    expect(requests, isEmpty);
    await tester.tap(find.byKey(const ValueKey('tree-box:emp:1')));
    await tester.pump();
    expect(find.text('Calendar'), findsNothing);
    expect(toggles.last, ('emp:1', false));
    expect(requests, isEmpty);
  });

  testWidgets('initial expansion applies once per newly seen id', (
    tester,
  ) async {
    TreeNodeData node(String id, {bool expanded = false}) => TreeNodeData(
      id: id,
      label: id,
      expanded: expanded,
      children: [TreeNodeData(id: '$id/child', label: '$id child')],
    );
    await _pump(tester, nodes: [node('a', expanded: true), node('b')]);
    expect(find.text('a child'), findsOneWidget);
    // The user collapses a; a rebuild with the same ids keeps it collapsed.
    await tester.tap(find.byKey(const ValueKey('tree-box:a')));
    await tester.pump();
    await _pump(tester, nodes: [node('a', expanded: true), node('b')]);
    expect(find.text('a child'), findsNothing);
    // A new id honours its initial expansion.
    await _pump(
      tester,
      nodes: [node('a', expanded: true), node('b'), node('c', expanded: true)],
    );
    expect(find.text('c child'), findsOneWidget);
    // Removed then reinserted counts as new: stale state is pruned.
    await _pump(tester, nodes: [node('b')]);
    await _pump(tester, nodes: [node('a', expanded: true), node('b')]);
    expect(find.text('a child'), findsOneWidget);
  });

  testWidgets('duplicate ids are rejected', (tester) async {
    await _pump(
      tester,
      nodes: const [
        TreeNodeData(id: 'x', label: 'One'),
        TreeNodeData(id: 'x', label: 'Two'),
      ],
    );
    expect(tester.takeException(), isA<ArgumentError>());
  });

  testWidgets('a muted node stays selectable; a disabled one does not', (
    tester,
  ) async {
    final requests = <String>[];
    await _pump(
      tester,
      onSelect: requests.add,
      nodes: const [
        TreeNodeData(id: 'm', label: 'Muted one', muted: true),
        TreeNodeData(id: 'd', label: 'Disabled one', enabled: false),
        TreeNodeData(id: 'w', label: 'Warned one', warning: true),
      ],
    );
    await tester.tap(find.text('Muted one'));
    await tester.tap(find.text('Disabled one'));
    await tester.tap(find.text('Warned one'));
    expect(requests, ['m', 'w']);
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Muted one')),
      isSemantics(isEnabled: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Disabled one')),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );
    expect(find.bySemanticsLabel('Warned one'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Warned one')).hint,
      'Needs attention',
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Muted one')).hint,
      'Inactive',
    );
    handle.dispose();
  });

  testWidgets('a disabled tree neither selects nor expands', (tester) async {
    final requests = <String>[];
    final toggles = <String>[];
    await _pump(
      tester,
      enabled: false,
      onSelect: requests.add,
      onExpansionChanged: (id, _) => toggles.add(id),
    );
    await tester.tap(find.text('Calendar'));
    await tester.tap(find.byKey(const ValueKey('tree-box:ended')));
    await tester.pump();
    expect(requests, isEmpty);
    expect(toggles, isEmpty);
    expect(find.text('Old job'), findsNothing);
  });

  testWidgets('deep, long labels and counts hold at 200 % in 196 px', (
    tester,
  ) async {
    TreeNodeData deep(int level) => TreeNodeData(
      id: 'n$level',
      label: 'A very long employment sheet name number $level',
      count: 12345,
      expanded: true,
      children: level < 12 ? [deep(level + 1)] : const [],
    );
    for (final scale in [1.0, 2.0]) {
      await _pump(tester, nodes: [deep(0)], scale: scale, width: 196);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('(12345)'), findsWidgets);
    }
    final handle = tester.ensureSemantics();
    final node = tester.getSemantics(
      find.bySemanticsLabel('A very long employment sheet name number 0'),
    );
    expect(node.value, '12345');
    handle.dispose();
  });

  testWidgets('no key selects, expands, scrolls or takes focus', (
    tester,
  ) async {
    final requests = <String>[];
    final toggles = <String>[];
    final outside = FocusNode();
    addTearDown(outside.dispose);
    await _pump(
      tester,
      nodes: [
        for (var i = 0; i < 100; i++)
          TreeNodeData(
            id: 'n$i',
            label: 'Node $i',
            children: [TreeNodeData(id: 'c$i', label: 'Child $i')],
          ),
      ],
      selectedId: 'n0',
      onSelect: requests.add,
      onExpansionChanged: (id, _) => toggles.add(id),
      height: 200,
      sibling: Focus(focusNode: outside, child: const SizedBox(height: 10)),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    bool focusInTree() {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      var inside = false;
      context.visitAncestorElements((e) {
        if (e.widget is TreeView) inside = true;
        return !inside;
      });
      return inside;
    }

    // Click a row and an expander first: a click must not leave focus
    // (and so key handling) in the tree.
    await tester.tap(find.text('Node 1'));
    await tester.tap(find.byKey(const ValueKey('tree-box:n2')));
    await tester.pump();
    final baseRequests = requests.length;
    final baseToggles = toggles.length;
    expect(baseRequests, 1);
    expect(baseToggles, 1);
    expect(focusInTree(), isFalse);
    outside.requestFocus();
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.pageUp,
      LogicalKeyboardKey.pageDown,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(focusInTree(), isFalse, reason: '$key');
    }
    expect(outside.hasPrimaryFocus, isTrue);
    expect(requests, hasLength(baseRequests));
    expect(toggles, hasLength(baseToggles));
    expect(scrollable.position.pixels, 0);
    expect(find.text('Child 0'), findsNothing);
  });

  testWidgets('a large tree builds only the visible rows', (tester) async {
    await _pump(
      tester,
      nodes: [
        for (var i = 0; i < 5000; i++)
          TreeNodeData(id: 'n$i', label: 'Node $i'),
      ],
      height: 200,
    );
    final built = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('tree-row:'),
    );
    expect(built.evaluate().length, lessThan(30));
    expect(built, findsWidgets);
    expect(find.text('Node 4999'), findsNothing);
  });

  testWidgets('a bounded tree is capped and scrolls; a short one shrinks', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 50; i++) TreeNodeData(id: 'n$i', label: 'Node $i'),
    ];
    await _pump(tester, nodes: many, maxContentHeight: 100, height: 600);
    expect(tester.getSize(find.byType(TreeView)).height, 100);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.drag(find.byType(Scrollable), const Offset(0, -60));
    expect(scrollable.position.pixels, greaterThan(0));

    await _pump(tester, nodes: many.take(3).toList(), maxContentHeight: 100);
    expect(tester.getSize(find.byType(TreeView)).height, 60);
  });

  testWidgets('an inactive tree paints its selection without the blue wash', (
    tester,
  ) async {
    Color? washOf() {
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('tree-row:emp:1')),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      return box.color;
    }

    await _pump(tester, selectedId: 'emp:1');
    expect(washOf(), LifeOSTokens.millennium.selWash);
    await _pump(tester, selectedId: 'emp:1', active: false);
    expect(washOf(), isNot(LifeOSTokens.millennium.selWash));
  });

  testWidgets('secondary clicks and double taps add nothing', (tester) async {
    final requests = <String>[];
    final toggles = <String>[];
    await _pump(
      tester,
      onSelect: requests.add,
      onExpansionChanged: (id, _) => toggles.add(id),
    );
    await tester.tap(find.text('Calendar'), buttons: kSecondaryButton);
    await tester.tap(
      find.byKey(const ValueKey('tree-box:ended')),
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(requests, isEmpty);
    expect(toggles, isEmpty);
    expect(find.text('Old job'), findsNothing);

    // A double tap on a row is two selection requests, never an expansion.
    await tester.tap(find.text('Ended employments'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.text('Ended employments'));
    await tester.pump();
    expect(requests, ['ended', 'ended']);
    expect(toggles, isEmpty);
    expect(find.text('Old job'), findsNothing);

    // A double tap on an expander toggles twice and selects nothing.
    final box = find.byKey(const ValueKey('tree-box:ended'));
    await tester.tap(box);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(box);
    await tester.pump();
    expect(toggles, ['ended', 'ended']);
    expect(requests, ['ended', 'ended']);
  });
}
