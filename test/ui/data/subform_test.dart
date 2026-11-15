import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/demos/subform_demo.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

Widget _host(
  Widget child, {
  double width = 480,
  double height = 300,
  double textScale = 1,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: MaterialApp(
    home: LifeOSSkinScope(
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    ),
  ),
);

/// Content with State of its own, to prove identity.
final class _Counter extends StatefulWidget {
  const _Counter(this.name);

  final String name;

  @override
  State<_Counter> createState() => _CounterState();
}

final class _CounterState extends State<_Counter> {
  int taps = 0;
  int disposed = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => taps++),
    child: Text('${widget.name} taps $taps'),
  );
}

SubformTab _counter(String id, {bool enabled = true, String? reason}) =>
    SubformTab(
      id: id,
      label: id.toUpperCase(),
      enabled: enabled,
      disabledReason: reason,
      builder: (_) => _Counter(id),
    );

/// A subform owner with a pending record: hours (a whole number) on the
/// "rows" tab and a note on the "props" tab, one shared controller.
final class _Owner extends StatefulWidget {
  const _Owner({this.useController = true});

  final bool useController;

  @override
  State<_Owner> createState() => _OwnerState();
}

final class _OwnerState extends State<_Owner> {
  final controller = EditorSessionController();
  final values = <String, Object?>{'hours': 8, 'note': 'Late'};
  final requests = <String>[];
  String selected = 'rows';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  EditResult _commit(EditIdentity id, Object? draft) {
    Object? value = draft;
    if (id.field == 'hours') {
      value = int.tryParse('$draft');
      if (value == null) return const EditResult.rejected('Whole hours.');
    }
    setState(() => values[id.field] = value);
    return const EditResult.accepted();
  }

  Widget _editor(String name, ValueKind kind) => CellEditor(
    controller: controller,
    field: EditField(
      id: EditIdentity(record: 'shift:1', field: name),
      kind: kind,
      value: values[name],
      commit: _commit,
    ),
    label: name,
    bare: false,
  );

  @override
  Widget build(BuildContext context) {
    final byId = {
      'rows': SubformTab(
        id: 'rows',
        label: 'Rows',
        builder: (_) => Column(
          children: [
            _editor('hours', ValueKind.number),
            const _Counter('rows'),
          ],
        ),
      ),
      'history': _counter('history', enabled: false, reason: 'No history yet.'),
      'props': SubformTab(
        id: 'props',
        label: 'Properties',
        builder: (_) => _editor('note', ValueKind.text),
      ),
    };
    return Subform(
      controller: widget.useController ? controller : null,
      selectedId: selected,
      onSelect: (id) => setState(() {
        requests.add(id);
        selected = id;
      }),
      tabs: [
        for (final id in const ['rows', 'history', 'props']) byId[id]!,
      ],
    );
  }
}

Finder _tab(String label) => find.bySemanticsLabel(RegExp('^$label'));

Finder _editable(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  testWidgets('shows the selected content and requests another tab', (
    tester,
  ) async {
    final requests = <String>[];
    var selected = 'a';
    late StateSetter set;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return Subform(
              tabs: [_counter('a'), _counter('b')],
              selectedId: selected,
              onSelect: requests.add,
            );
          },
        ),
      ),
    );
    expect(find.text('a taps 0'), findsOneWidget);
    expect(find.text('b taps 0'), findsNothing, reason: 'never shown: unbuilt');
    await tester.tap(find.text('B'));
    expect(requests, ['b']);
    // Controlled: the owner has not moved the selection.
    expect(find.text('a taps 0'), findsOneWidget);
    set(() => selected = 'b');
    await tester.pump();
    expect(find.text('b taps 0'), findsOneWidget);
    expect(find.text('a taps 0'), findsNothing, reason: 'hidden');
  });

  testWidgets('tabs are the subform size, 20 and 22 px', (tester) async {
    await tester.pumpWidget(
      _host(
        Subform(
          tabs: [_counter('a'), _counter('b')],
          selectedId: 'a',
          onSelect: (_) {},
        ),
      ),
    );
    expect(tester.getSize(_tab('A')).height, greaterThanOrEqualTo(22));
    expect(tester.getSize(_tab('B')).height, greaterThanOrEqualTo(20));
    expect(
      tester.getSize(_tab('A')).height,
      greaterThan(tester.getSize(_tab('B')).height),
    );
  });

  testWidgets('no tabs shows the empty text; a removed selection nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Subform(
          tabs: const [],
          selectedId: 'gone',
          onSelect: (_) {},
          emptyText: 'No children.',
        ),
      ),
    );
    expect(find.text('No children.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The selected tab vanishes: no content, no invalid index, no throw.
    final tabs = [_counter('a'), _counter('b')];
    await tester.pumpWidget(
      _host(Subform(tabs: tabs, selectedId: 'b', onSelect: (_) {})),
    );
    expect(find.text('b taps 0'), findsOneWidget);
    await tester.pumpWidget(
      _host(Subform(tabs: [tabs.first], selectedId: 'b', onSelect: (_) {})),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('taps'), findsNothing);
    expect(
      TabStrip.resolveSelection([const TabItem(id: 'a', label: 'A')], 'b'),
      'a',
    );
  });

  testWidgets('duplicate ids throw', (tester) async {
    await tester.pumpWidget(
      _host(
        Subform(
          tabs: [_counter('a'), _counter('a')],
          selectedId: 'a',
          onSelect: (_) {},
        ),
      ),
    );
    expect(tester.takeException(), isA<FlutterError>());
  });

  testWidgets('content state follows the tab id through reordering', (
    tester,
  ) async {
    var order = ['rows', 'history', 'props'];
    var selected = 'rows';
    late StateSetter set;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return Subform(
              tabs: [
                for (final id in order)
                  _counter(id, enabled: id != 'history', reason: 'None.'),
              ],
              selectedId: selected,
              onSelect: (_) {},
            );
          },
        ),
      ),
    );
    Future<void> show(String id) async {
      set(() => selected = id);
      await tester.pump();
    }

    // Visit both tabs and give each its own count.
    await tester.tap(find.text('rows taps 0'));
    await tester.pump();
    await show('props');
    await tester.tap(find.text('props taps 0'));
    await tester.pump();
    await tester.tap(find.text('props taps 1'));
    await tester.pump();
    expect(find.text('props taps 2'), findsOneWidget);
    // Reorder: each pane keeps its own state, not its position's.
    set(() => order = ['props', 'history', 'rows']);
    await tester.pump();
    expect(find.text('props taps 2'), findsOneWidget);
    await show('rows');
    expect(find.text('rows taps 1'), findsOneWidget);
    await show('props');
    expect(find.text('props taps 2'), findsOneWidget);
    await show('rows');
    expect(find.text('rows taps 1'), findsOneWidget);
  });

  testWidgets('a disabled tab keeps its place, explains and requests nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const _Owner()));
    final state = tester.state<_OwnerState>(find.byType(_Owner));
    expect(
      tester.getTopLeft(_tab('HISTORY')).dx,
      greaterThan(tester.getTopLeft(_tab('Rows')).dx),
    );
    expect(
      tester.getTopLeft(_tab('HISTORY')).dx,
      lessThan(tester.getTopLeft(_tab('Properties')).dx),
    );
    await tester.tap(find.text('HISTORY'));
    await tester.pump();
    expect(state.requests, isEmpty);
    expect(
      tester.getSemantics(_tab('HISTORY')).hint,
      contains('No history yet.'),
    );
  });

  testWidgets('a count shows on the tab', (tester) async {
    await tester.pumpWidget(
      _host(
        Subform(
          tabs: [
            SubformTab(
              id: 'a',
              label: 'Rows',
              count: 3,
              countLabel: 'to confirm',
              builder: (_) => const SizedBox(),
            ),
          ],
          selectedId: 'a',
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(tester.getSemantics(_tab('Rows')).label, 'Rows, 3 to confirm');
  });

  testWidgets(
    'hidden content takes no focus, hits or keys; keys change nothing',
    (tester) async {
      await tester.pumpWidget(_host(const _Owner()));
      final state = tester.state<_OwnerState>(find.byType(_Owner));
      // Move to Properties through the owner; Rows content stays mounted.
      await tester.tap(find.text('Properties'));
      await tester.pump();
      expect(state.selected, 'props');
      expect(find.byType(_Counter), findsNothing, reason: 'hidden is offstage');
      expect(
        find.byType(_Counter, skipOffstage: false),
        findsOneWidget,
        reason: 'but still in the tree',
      );
      // Tab traversal reaches only the visible editor.
      var focusedVisible = false;
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        if (focus?.context == null) continue;
        focusedVisible = true;
        expect(
          find.descendant(
            of: find.byType(_Counter, skipOffstage: false),
            matching: find.byWidget(focus!.context!.widget),
            skipOffstage: false,
          ),
          findsNothing,
        );
        expect(
          focus.context!.findAncestorWidgetOfExactType<Offstage>()?.offstage ??
              false,
          isFalse,
        );
      }
      expect(focusedVisible, isTrue, reason: 'Tab reached a visible editor');
      final before = state.selected;
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      expect(state.selected, before);
      expect(state.requests, ['props']);
    },
  );

  testWidgets('accepted flush: edit, change tab, return', (tester) async {
    await tester.pumpWidget(_host(const _Owner()));
    final state = tester.state<_OwnerState>(find.byType(_Owner));
    await tester.enterText(_editable('8'), '9');
    await tester.pump();
    expect(state.controller.session?.draft, '9');
    await tester.tap(find.text('Properties'));
    await tester.pump();
    // Flushed first: the draft became the pending value, then the tab moved.
    expect(state.values['hours'], 9);
    expect(state.controller.session, isNull);
    expect(state.selected, 'props');
    await tester.tap(find.text('Rows'));
    await tester.pump();
    expect(_editable('9'), findsOneWidget);
    expect(state.requests, ['props', 'rows']);
  });

  testWidgets('rejected flush: the tab and the owner stay put', (tester) async {
    await tester.pumpWidget(_host(const _Owner()));
    final state = tester.state<_OwnerState>(find.byType(_Owner));
    await tester.enterText(_editable('8'), '8x');
    await tester.pump();
    await tester.tap(find.text('Properties'));
    await tester.pump();
    expect(state.requests, isEmpty, reason: 'the owner is not asked');
    expect(state.selected, 'rows');
    expect(state.controller.session?.draft, '8x');
    expect(state.controller.session?.error, 'Whole hours.');
    expect(_editable('8x'), findsOneWidget);
    // Correct it and the request goes through.
    await tester.enterText(_editable('8x'), '7');
    await tester.pump();
    await tester.tap(find.text('Properties'));
    await tester.pump();
    expect(state.requests, ['props']);
    expect(state.values['hours'], 7);
  });

  testWidgets('without a controller an open draft survives a round trip', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const _Owner(useController: false)));
    final state = tester.state<_OwnerState>(find.byType(_Owner));
    await tester.enterText(_editable('8'), '8x');
    await tester.pump();
    await tester.tap(find.text('Properties'));
    await tester.pump();
    expect(state.selected, 'props');
    // No controller on the Subform: nothing flushed the invalid draft, so it
    // is still open in the controller while its tab is hidden.
    expect(_editable('8x'), findsNothing, reason: 'hidden');
    await tester.tap(find.text('Rows'));
    await tester.pump();
    expect(_editable('8x'), findsOneWidget);
    expect(state.controller.session?.draft, '8x');
    expect(state.values['hours'], 8, reason: 'nothing was committed');
  });

  testWidgets('long caption and long tabs at 200% stay visible and hittable', (
    tester,
  ) async {
    final requests = <String>[];
    await tester.pumpWidget(
      _host(
        width: 200,
        height: 700,
        textScale: 2,
        Subform(
          trailing: const Text('42 rows, 3 waiting to be confirmed today'),
          tabs: [
            for (final id in ['shifts of this pay agreement period', 'two'])
              SubformTab(id: id, label: id, builder: (_) => Text('c $id')),
          ],
          selectedId: 'two',
          onSelect: requests.add,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final caption = find.textContaining('42 rows');
    final long = find.text('shifts of this pay agreement period');
    for (final finder in [caption, long, find.text('two')]) {
      final box = tester.getRect(finder);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(200));
    }
    await tester.tap(long);
    expect(requests, ['shifts of this pay agreement period']);
    expect(find.text('c two'), findsOneWidget);
  });

  testWidgets(
    'demo: a rejected draft keeps the tab; Enabled off greys History',
    (tester) async {
      await pumpGalleryDemo(tester, subformDemo);
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(find.text('No history yet.'), findsOneWidget);
      await tester.tap(find.text('Shifts'));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      await tester.tap(find.text('Properties'));
      await tester.pump();
      expect(find.text('Enter whole hours.'), findsWidgets);
      expect(find.text('No history yet.'), findsNothing);

      await pumpGalleryDemo(
        tester,
        subformDemo,
        knobs: const GalleryKnobs(enabled: false),
      );
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(find.text('No history yet.'), findsNothing);
    },
  );
}
