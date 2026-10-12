import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/app_frame_harness.dart' show expectHittable, focusedIn;

/// AppFrame's contract with its owner, on plain synthetic panes: the Tree
/// key handed to the toolbar only while folded, controlled reveal and
/// return requests that never flush, owner-held sizes, and an owner that
/// refuses a request.
void main() {
  testWidgets('the toolbar gets the Tree key only while folded', (
    tester,
  ) async {
    final owner = await _pump(tester, const Size(1280, 800));
    expect(owner.treeActions.last, isNull);
    await _resize(tester, const Size(1000, 800));
    final tree = owner.treeActions.last!;
    expect(tree.label, 'Tree');
    expect(tree.onPressed, isNotNull);
    expect(tree.dropArrow, isTrue);
  });

  testWidgets('docking while the properties are active shows their tab at '
      'once and asks the owner, without a flush', (tester) async {
    final owner = await _pump(tester, const Size(1280, 800));
    await tester.tap(_box, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(focusedIn(tester, _box), isTrue);
    owner.controller.begin(owner.editField, host: owner);
    owner.controller.update(owner.editField.id, 'draft');
    await _resize(tester, const Size(800, 600));
    expect(owner.requests, [AppFrame.propertiesTabId]);
    expect(owner.commits, 0, reason: 'a reveal never flushes');
    expect(owner.controller.session?.draft, 'draft');
    expect(find.byKey(_field), findsOneWidget);
    expect(focusedIn(tester, _box), isTrue);
    expectHittable(tester, _box);
  });

  testWidgets('an owner that refuses the reveal keeps the tab it chose', (
    tester,
  ) async {
    final owner = await _pump(tester, const Size(1280, 800), refuse: true);
    await tester.tap(_box, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await _resize(tester, const Size(800, 600));
    expect(owner.requests, [AppFrame.propertiesTabId]);
    expect(owner.selected, 'a');
    // Shown while the request is outstanding.
    expect(find.byKey(_field), findsOneWidget);
    // The owner's own later choice wins.
    owner.select('b');
    await tester.pumpAndSettle();
    expect(find.text('Child B'), findsOneWidget);
    expect(find.byKey(_field), findsNothing);
    expect(find.byKey(_field, skipOffstage: false), findsOneWidget);
  });

  testWidgets('docking while another region is active asks nothing', (
    tester,
  ) async {
    final owner = await _pump(tester, const Size(1280, 800));
    await tester.tap(find.text('Middle'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await _resize(tester, const Size(800, 600));
    expect(owner.requests, isEmpty);
    expect(find.byKey(_field), findsNothing);
  });

  testWidgets('undocking with the Properties tab selected asks for the '
      'child tab shown before', (tester) async {
    final owner = await _pump(tester, const Size(800, 600));
    owner.select('b');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Properties'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(owner.selected, AppFrame.propertiesTabId);
    await _resize(tester, const Size(1280, 800));
    expect(owner.requests.last, 'b');
    expect(owner.selected, 'b');
    expect(find.text('Child B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supplied sizes always win: no local copy masks them', (
    tester,
  ) async {
    final owner = await _pump(tester, const Size(1280, 800));
    final column = find.byKey(const ValueKey('app-frame-tree-column'));
    expect(tester.getSize(column).width, 196);
    owner.setPanes(const AppFramePanes(left: 240));
    await tester.pumpAndSettle();
    expect(tester.getSize(column).width, 240);
    // A drag the owner does not take changes nothing.
    owner.takeDrags = false;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('app-frame-splitter:left'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(owner.reported.last.left, 290);
    expect(tester.getSize(column).width, 240);
    owner.setPanes(AppFramePanes.baseline);
    await tester.pumpAndSettle();
    expect(tester.getSize(column).width, 196);
  });
}

const _field = ValueKey('owner-field');
final _box = find.descendant(
  of: find.byKey(_field),
  matching: find.byType(EditableText),
);

Future<_OwnerState> _pump(
  WidgetTester tester,
  Size size, {
  bool refuse = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Material(child: _Owner(refuse: refuse)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_OwnerState>(find.byType(_Owner));
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

final class _Owner extends StatefulWidget {
  const _Owner({required this.refuse});

  final bool refuse;

  @override
  State<_Owner> createState() => _OwnerState();
}

final class _OwnerState extends State<_Owner> {
  final controller = EditorSessionController();
  final text = TextEditingController();
  final requests = <String>[];
  final reported = <AppFramePanes>[];
  final treeActions = <ToolbarItem?>[];
  int commits = 0;
  String? selected = 'a';
  bool takeDrags = true;
  AppFramePanes panes = AppFramePanes.baseline;

  late final editField = EditField(
    id: const EditIdentity(record: 'r', field: 'f'),
    kind: ValueKind.text,
    value: 'v',
    commit: (id, draft) {
      commits++;
      return const EditResult.accepted();
    },
  );

  void select(String id) => setState(() => selected = id);

  void setPanes(AppFramePanes value) => setState(() => panes = value);

  @override
  void dispose() {
    controller.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppFrame(
    controller: controller,
    toolbarBuilder: (context, tree) {
      treeActions.add(tree);
      return BandedToolbar(
        bands: [
          ToolbarBand(
            items: [
              ?tree,
              ToolbarItem(label: 'Save', onPressed: () {}),
            ],
          ),
        ],
      );
    },
    areas: const [TabItem(id: 'work', label: 'Work')],
    areaId: 'work',
    onAreaSelect: (_) {},
    tree: const Text('Tree'),
    details: const Text('Details'),
    middle: const Center(child: Text('Middle')),
    subformTabs: [
      SubformTab(id: 'a', label: 'A', builder: (_) => const Text('Child A')),
      SubformTab(id: 'b', label: 'B', builder: (_) => const Text('Child B')),
    ],
    subformSelectedId: selected,
    onSubformSelect: (id) {
      requests.add(id);
      if (!widget.refuse) select(id);
    },
    properties: Padding(
      padding: const EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 160,
          child: EraField(key: _field, controller: text, label: 'Note'),
        ),
      ),
    ),
    status: const StatusBar(notice: 'Ready.'),
    panes: panes,
    onPanesChanged: (value) {
      reported.add(value);
      if (takeDrags) setPanes(value);
    },
  );
}
