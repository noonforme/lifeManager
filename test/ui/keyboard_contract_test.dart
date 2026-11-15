import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

import '../support/shell_editor_fixture.dart';

const _closedKeys = [
  LogicalKeyboardKey.tab,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.escape,
  LogicalKeyboardKey.space,
  LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.home,
  LogicalKeyboardKey.end,
  LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.pageDown,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f4,
];

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

Future<ShellEditorFixtureState> _pump(
  WidgetTester tester, {
  bool enabled = true,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = EditorSessionController();
  addTearDown(controller.dispose);
  final key = GlobalKey<ShellEditorFixtureState>();
  await tester.pumpWidget(
    GalleryHost(
      home: ShellEditorFixture(
        key: key,
        controller: controller,
        enabled: enabled,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Finder _grid(String field) => find.byKey(ValueKey('grid-cell:row:0:$field'));
Finder _property(String field) => find.byKey(ValueKey('property-value:$field'));

Map<String, Object?> _snapshot(
  WidgetTester tester,
  ShellEditorFixtureState host,
) => {
  'records': {
    for (final entry in host.records.entries) entry.key: {...entry.value},
  },
  'action': {...host.actionValues},
  'events': [...host.events],
  'selected': host.selected,
  'picked': {...host.picked},
  'tree': host.treeSelection,
  'area': host.area,
  'tab': host.tab,
  'sort': host.sortColumn,
  'scroll': [
    for (final state in tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    ))
      state.position.pixels,
  ],
  'text': [
    for (final text in tester.widgetList<Text>(find.byType(Text))) text.data,
  ],
};

void main() {
  testWidgets(
    'closed and cancelled hosts ignore keyboard commands and traversal',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _grid('note'));
      await _key(tester, LogicalKeyboardKey.escape);
      expect(host.controller.session, isNull);
      final before = _snapshot(tester, host);
      final focus = FocusManager.instance.primaryFocus;
      expect(host.selected, 'row:0');
      expect(focus?.debugLabel, 'DataGrid');
      expect(
        focus?.ancestors.where((node) => node.debugLabel == 'CellEditor'),
        isEmpty,
      );
      for (final key in _closedKeys) {
        await _key(tester, key);
        expect(_snapshot(tester, host), before, reason: key.debugName);
        expect(host.controller.session, isNull, reason: key.debugName);
        expect(FocusManager.instance.primaryFocus, same(focus));
      }
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        for (final key in [
          LogicalKeyboardKey.tab,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.keyS,
        ]) {
          await _chord(tester, modifier, key);
          expect(_snapshot(tester, host), before);
          expect(FocusManager.instance.primaryFocus, same(focus));
        }
      }
    },
  );

  testWidgets('held Enter commits once and leaves the next editor open', (
    tester,
  ) async {
    final host = await _pump(tester);
    await _tap(tester, _grid('note'));
    tester.testTextInput.enterText('One commit');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(host.events, ['commit:row:0:note']);
    expect(
      host.controller.active,
      const EditIdentity(record: 'row:0', field: 'hours'),
    );
    final focus = FocusManager.instance.primaryFocus;
    final draft = host.controller.session!.draft;
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(host.events, ['commit:row:0:note']);
    expect(
      host.controller.active,
      const EditIdentity(record: 'row:0', field: 'hours'),
    );
    expect(host.controller.session!.draft, draft);
    expect(FocusManager.instance.primaryFocus, same(focus));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  });

  testWidgets(
    'active editor holds forbidden commands, commits once, then cancels one field',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _grid('note'));
      tester.testTextInput.enterText('Pending note');
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus;
      for (final key in [
        LogicalKeyboardKey.f2,
        LogicalKeyboardKey.f4,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await _key(tester, key);
        expect(host.controller.session!.draft, 'Pending note');
        expect(host.events, isEmpty);
        expect(FocusManager.instance.primaryFocus, same(focus));
      }
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await _chord(tester, modifier, LogicalKeyboardKey.tab);
        await _chord(tester, modifier, LogicalKeyboardKey.enter);
        expect(host.events, isEmpty);
        expect(host.controller.active!.field, 'note');
      }
      await _key(tester, LogicalKeyboardKey.enter);
      expect(host.values['note'], 'Pending note');
      expect(host.events, ['commit:row:0:note']);
      expect(host.controller.active!.field, 'hours');
      final hours = tester.widget<EditableText>(
        find.descendant(
          of: _grid('hours'),
          matching: find.byType(EditableText),
        ),
      );
      expect(hours.focusNode.hasPrimaryFocus, isTrue);
      tester.testTextInput.enterText('invalid hours');
      await tester.pump();
      expect(
        host.controller.active,
        const EditIdentity(record: 'row:0', field: 'hours'),
      );
      expect(host.controller.session!.draft, 'invalid hours');
      await _key(tester, LogicalKeyboardKey.escape);
      expect(host.values['hours'], '8');
      expect(host.values['note'], 'Pending note');
      expect(host.controller.session, isNull);
      expect(host.events, ['commit:row:0:note']);
    },
  );

  testWidgets(
    'mouse-opened calendar and choice overlays cannot pick by keyboard',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _property('day'));
      await _tap(
        tester,
        find.descendant(
          of: _property('day'),
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
      );
      expect(find.byType(EraMonthCalendar), findsOneWidget);
      final focus = FocusManager.instance.primaryFocus;
      final draft = host.controller.session!.draft;
      for (final key in [
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.f2,
        LogicalKeyboardKey.f4,
      ]) {
        await _key(tester, key);
        expect(host.controller.session!.draft, draft);
        expect(host.events, isEmpty);
        expect(find.byType(EraMonthCalendar), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, same(focus));
      }
      await _key(tester, LogicalKeyboardKey.tab);
      expect(host.controller.active!.field, 'kind');
      expect(find.byType(EraMonthCalendar), findsNothing);
      await _tap(
        tester,
        find.descendant(
          of: _property('kind'),
          matching: find.byType(EraCombo<Object?>),
        ),
      );
      expect(find.text('Leave'), findsOneWidget);
      final comboFocus = FocusManager.instance.primaryFocus;
      for (final key in [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
      ]) {
        await _key(tester, key);
        expect(host.controller.session!.draft, 'shift');
        expect(host.events, isEmpty);
        expect(find.text('Leave'), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, same(comboFocus));
      }
      await _key(tester, LogicalKeyboardKey.escape);
      expect(host.values['kind'], 'shift');
      expect(host.controller.session, isNull);
      expect(find.text('Leave'), findsNothing);
    },
  );

  for (final enter in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  ]) {
    testWidgets('choice ${enter.debugName} ignores the mouse highlight', (
      tester,
    ) async {
      final host = await _pump(tester);
      await _tap(tester, _property('kind'));
      await _tap(
        tester,
        find.descendant(
          of: _property('kind'),
          matching: find.byType(EraCombo<Object?>),
        ),
      );
      final combo = tester.widget<EraCombo<Object?>>(
        find.descendant(
          of: _property('kind'),
          matching: find.byType(EraCombo<Object?>),
        ),
      );
      expect(combo.focusNode!.hasPrimaryFocus, isTrue);
      final mouse = TestGesture(
        dispatcher: tester.sendEventToBinding,
        pointer: 42,
        kind: PointerDeviceKind.mouse,
        device: 42,
      );
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('Leave')));
      await tester.pumpAndSettle();
      expect(combo.focusNode!.hasPrimaryFocus, isTrue);
      await _key(tester, enter);
      expect(find.text('Leave'), findsNothing);
      expect(host.values['kind'], 'shift');
      expect(host.events, isEmpty);
      expect(
        host.controller.active,
        const EditIdentity(record: 'row:0', field: 'paid'),
      );
      final check = tester.widget<EraCheckBox>(
        find.descendant(
          of: _property('paid'),
          matching: find.byType(EraCheckBox),
        ),
      );
      expect(check.focusNode!.hasPrimaryFocus, isTrue);
      await mouse.removePointer();
    });
  }

  testWidgets(
    'confirmation consumes keys without changing the underlying draft',
    (tester) async {
      final host = await _pump(tester);
      await _tap(tester, _property('note'));
      tester.testTextInput.enterText('Retained draft');
      await tester.pump();
      final confirmation = host.confirm();
      await tester.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus;
      for (final key in _closedKeys) {
        await _key(tester, key);
        expect(host.controller.session!.draft, 'Retained draft');
        expect(host.events, isEmpty);
        expect(find.byType(ConfirmWindow<bool>), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, same(focus));
      }
      await _tap(tester, find.text('Keep editing'));
      await confirmation;
      expect(host.events, ['confirm:false']);
      expect(host.controller.session!.draft, 'Retained draft');
    },
  );

  testWidgets('disabled real hosts emit no command or edit callbacks', (
    tester,
  ) async {
    final host = await _pump(tester, enabled: false);
    final targets = [
      find.text('Save'),
      find.text('Undo'),
      find.text('People'),
      find.text('Pay periods'),
      find.text('History'),
      find.text('Correct'),
      find.text('Cancel'),
      _grid('note'),
      _property('note'),
    ];
    for (final target in targets) {
      await _tap(tester, target);
      expect(host.events, isEmpty, reason: target.toString());
      expect(host.controller.session, isNull);
    }
    expect(host.selected, 'row:0');
    expect(host.area, 'work');
    expect(host.treeSelection, 'shifts');
    expect(host.tab, 'children');
  });
}
