import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

/// ActionPanel under the shared editor contract (database shell spec 4.4,
/// 4.6, 9): registered fields in order, Enter/Tab never submit, the
/// primary key flushes first, busy locks fields, picks and keys, and
/// completed results stay as they were.

const _today = LocalDate(2026, 10, 8);
const _record = 'action:correct-shift';

const _choices = [
  EraComboItem<Object?>('shift', 'Shift'),
  EraComboItem<Object?>('leave', 'Leave'),
];

Map<String, Object?> _initial() => {
  'note': 'Late',
  'hours': 8,
  'total': '100.00',
  'day': _today,
  'start': const LocalTime(7, 0),
  'kind': 'shift',
  'paid': false,
};

/// The order the panel shows its fields in; `total` is derived.
const _order = ['note', 'hours', 'total', 'day', 'start', 'kind', 'paid'];

const _days = ['Mon', 'Tue', 'Wed'];

/// A synthetic owner: the pending input, a pick list it gates while busy,
/// and the panel.
final class _Owner extends StatefulWidget {
  const _Owner({
    required this.controller,
    this.extraFields = 0,
    this.extraResults = 0,
    this.mounted = true,
  });

  final EditorSessionController controller;
  final int extraFields;
  final int extraResults;
  final bool mounted;

  @override
  State<_Owner> createState() => _OwnerState();
}

final class _OwnerState extends State<_Owner> {
  final values = _initial();
  final changes = <(String, Object?)>[];
  final log = <String>[];
  final picks = <String>{'Mon', 'Tue'};
  var results = <ActionResult>[];
  String? error;
  var busy = false;
  var primaries = 0;
  var cancels = 0;

  /// Makes the primary action asynchronous: the owner goes busy.
  var goBusy = false;

  void update(VoidCallback change) => setState(change);

  String? _validate(String name, Object? draft) => switch (name) {
    'note' when draft == '' => 'Enter a note.',
    'hours' when int.tryParse('$draft') == null => 'Enter whole hours.',
    'day' when (draft! as LocalDate).compareTo(_today) < 0 =>
      'Pick today or later.',
    _ => null,
  };

  ActionField _field(String name) => ActionField(
    id: name,
    label: name,
    kind: switch (name) {
      'note' => ValueKind.text,
      'hours' => ValueKind.number,
      'total' => ValueKind.money,
      'day' => ValueKind.date,
      'start' => ValueKind.time,
      'kind' => ValueKind.choice,
      'paid' => ValueKind.check,
      _ => ValueKind.text,
    },
    value: values[name],
    enabled: name != 'total',
    choices: name == 'kind' ? _choices : const [],
    validate: (draft) => _validate(name, draft),
    fieldKey: ValueKey('box-$name'),
  );

  @override
  Widget build(BuildContext context) {
    final panel = ActionPanel(
      title: 'Correct shift',
      record: _record,
      controller: widget.controller,
      today: _today,
      groups: () => [
        ActionGroup(
          legend: 'Shift',
          fields: [_field('note'), _field('hours'), _field('total')],
        ),
        ActionGroup(legend: 'When', fields: [_field('day'), _field('start')]),
        ActionGroup(
          legend: 'Kind',
          fields: [
            _field('kind'),
            _field('paid'),
            for (var i = 0; i < widget.extraFields; i++)
              ActionField(
                id: 'extra$i',
                label: 'Extra $i',
                kind: ValueKind.text,
                value: values['extra$i'] ?? 'x',
                fieldKey: ValueKey('box-extra$i'),
              ),
          ],
          children: [Text('${picks.length} days picked')],
        ),
      ],
      onChanged: (field, value) {
        changes.add((field, value));
        log.add('change $field');
        setState(
          () => values[field] = field == 'hours' ? int.parse('$value') : value,
        );
      },
      primaryLabel: 'Correct',
      onPrimary: () {
        primaries++;
        log.add('primary');
        if (goBusy) setState(() => busy = true);
      },
      onCancel: () {
        cancels++;
        log.add('cancel ${widget.controller.session?.id.field}');
      },
      results: [
        ...results,
        for (var i = 0; i < widget.extraResults; i++)
          ActionResult.done('Synthetic day $i'),
      ],
      error: error,
      busy: busy,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The grid's pick column stand-in: the owner gates it while busy.
        SizedBox(
          width: 120,
          child: Column(
            children: [
              for (final day in _days)
                EraCheckBox(
                  key: ValueKey('pick-$day'),
                  label: day,
                  value: picks.contains(day),
                  onChanged: busy
                      ? null
                      : (on) => setState(
                          () => on ? picks.add(day) : picks.remove(day),
                        ),
                ),
            ],
          ),
        ),
        Expanded(child: widget.mounted ? panel : const SizedBox()),
      ],
    );
  }
}

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<EditorSessionController> _pump(
  WidgetTester tester, {
  EditorSessionController? controller,
  Size size = const Size(800, 600),
  double scale = 1,
  int extraFields = 0,
  int extraResults = 0,
  bool mounted = true,
}) async {
  _window(tester, size);
  final session = controller ?? EditorSessionController();
  if (controller == null) addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: LifeOSSkinScope(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                // The property column's width beside a pick list.
                width: 120 + 306,
                height: size.height,
                child: _Owner(
                  controller: session,
                  extraFields: extraFields,
                  extraResults: extraResults,
                  mounted: mounted,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

_OwnerState _owner(WidgetTester tester) => tester.state(find.byType(_Owner));

Finder _box(String name) => find.byKey(ValueKey('box-$name'));

Finder _editor(String name) =>
    find.ancestor(of: _box(name), matching: find.byType(CellEditor));

/// The registered field whose editor holds the keyboard.
String? get _focused {
  final context = FocusManager.instance.primaryFocus?.context;
  final editor = context?.findAncestorWidgetOfExactType<CellEditor>();
  return editor?.field.id.field;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _click(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

/// Opens [name]'s editor with a mouse click, as the owner does.
Future<void> _open(WidgetTester tester, String name) async {
  final target = switch (name) {
    'start' => find.descendant(
      of: _box(name),
      matching: find.byKey(const ValueKey('era-time-hour')),
    ),
    'paid' => find.descendant(
      of: _editor(name),
      matching: find.byKey(const ValueKey('era-check-box')),
    ),
    _ => _box(name),
  };
  await _click(tester, target.first);
}

Future<void> _type(WidgetTester tester, String name, String text) async {
  await tester.enterText(_box(name), text);
  await tester.pump();
}

Finder get _primary => find.widgetWithText(KeyButton, 'Correct');
Finder get _cancel => find.widgetWithText(KeyButton, 'Cancel');

void main() {
  group('fields', () {
    testWidgets('every kind is a labelled CellEditor of the shared '
        'controller, in registration order', (tester) async {
      final controller = await _pump(tester);
      final editors = tester
          .widgetList<CellEditor>(find.byType(CellEditor))
          .toList();
      expect(editors.map((e) => e.field.id.field), _order);
      expect(editors.map((e) => e.bare), everyElement(isFalse));
      expect(editors.map((e) => e.controller), everyElement(controller));
      expect(editors.map((e) => e.field.id.record), everyElement(_record));
      expect(
        editors.singleWhere((e) => e.field.id.field == 'total').enabled,
        isFalse,
      );
      expect(find.text('note:'), findsOneWidget);
      expect(find.text('Correct shift'), findsOneWidget);
    });

    testWidgets('text, date, time, choice and check edit through the '
        'controller and reach the owner only when accepted', (tester) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);

      await _open(tester, 'note');
      await _type(tester, 'note', 'Early');
      expect(owner.values['note'], 'Late', reason: 'a draft only');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.values['note'], 'Early');
      expect(controller.active?.field, 'hours');

      // Date: a mouse pick from the calendar, then Tab.
      await _click(
        tester,
        find.descendant(
          of: _box('day'),
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
      );
      await _click(
        tester,
        find.byKey(ValueKey('era-day-${_today.addDays(2)}')).last,
      );
      expect(owner.values['day'], _today);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(owner.values['day'], _today.addDays(2));
      expect(controller.active?.field, 'start');

      // Time: step the hour part up.
      await _open(tester, 'start');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.values['start'], const LocalTime(8, 0));
      expect(controller.active?.field, 'kind');

      // Choice: a mouse pick from the list.
      await _click(tester, _box('kind'));
      await _click(tester, find.text('Leave').last);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.values['kind'], 'leave');
      expect(controller.active?.field, 'paid');

      // Check: a mouse tick.
      await _open(tester, 'paid');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.values['paid'], isTrue);
      expect(controller.session, isNull);
      expect(owner.primaries, 0);
    });
  });

  group('keyboard', () {
    testWidgets('Enter and Tab walk the eligible fields, skipping the '
        'derived one, and close the last without submitting', (tester) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'note');
      final visited = <String?>[_focused];
      for (var i = 0; i < 5; i++) {
        await _press(
          tester,
          i.isEven ? LogicalKeyboardKey.enter : LogicalKeyboardKey.tab,
        );
        visited.add(_focused);
        expect(controller.active?.field, _focused);
      }
      expect(visited, ['note', 'hours', 'day', 'start', 'kind', 'paid']);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.session, isNull);
      // The keyboard stays in the panel; nothing traverses or submits.
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.numpadEnter,
      ]) {
        await _press(tester, key);
      }
      expect(controller.session, isNull);
      expect(owner.primaries, 0);
      expect(owner.cancels, 0);
      final focus = FocusManager.instance.primaryFocus;
      expect(
        focus?.context?.findAncestorWidgetOfExactType<ActionPanel>(),
        isNotNull,
        reason: 'the panel keeps the keyboard',
      );
      expect(
        focus?.context?.findAncestorWidgetOfExactType<KeyButton>(),
        isNull,
      );
    });

    testWidgets('the next field, its eligibility and its value come from '
        'the input the commit just changed', (tester) async {
      _window(tester, const Size(800, 600));
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      // b is enabled only while a is "on"; c's value follows a.
      final values = <String, Object?>{'a': 'off', 'b': 'b', 'c': 'old'};
      await tester.pumpWidget(
        MaterialApp(
          home: LifeOSSkinScope(
            child: Scaffold(
              body: SizedBox(
                width: 306,
                height: 500,
                child: StatefulBuilder(
                  builder: (context, setState) => ActionPanel(
                    title: 'Dependent',
                    record: 'dependent',
                    controller: controller,
                    groups: () => [
                      ActionGroup(
                        legend: 'G',
                        fields: [
                          for (final id in [
                            if (values['a'] != 'gone') 'a',
                            'b',
                            'c',
                          ])
                            ActionField(
                              id: id,
                              label: id,
                              kind: ValueKind.text,
                              value: values[id],
                              enabled: id != 'b' || values['a'] == 'on',
                              fieldKey: ValueKey('box-$id'),
                            ),
                        ],
                      ),
                    ],
                    onChanged: (id, value) => setState(() {
                      values[id] = value;
                      if (id == 'a') values['c'] = 'after $value';
                    }),
                    primaryLabel: 'Go',
                    onPrimary: () {},
                    onCancel: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // a "on" enables b: Enter opens b, not c.
      await _click(tester, _box('a'));
      await _type(tester, 'a', 'on');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'b');
      expect(_focused, 'b');
      expect(tester.takeException(), isNull);
      // Back to "off": b is skipped, and c opens with the value the commit
      // gave it, not its old one.
      await _click(tester, _box('a'));
      await _type(tester, 'a', 'off');
      await _press(tester, LogicalKeyboardKey.tab);
      expect(controller.active?.field, 'c');
      expect(controller.session?.original, 'after off');
      expect(controller.session?.draft, 'after off');
      expect(tester.widget<TextField>(_box('c')).controller!.text, 'after off');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(values['c'], 'after off', reason: 'unchanged: no commit');
      expect(controller.session, isNull);
      // Removing the accepted field does not wrap to the first remaining
      // registration when there is no longer an anchor for traversal.
      await _click(tester, _box('a'));
      await _type(tester, 'a', 'gone');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.session, isNull);
      expect(values['c'], 'after gone');
    });

    testWidgets(
      'the window going inactive and back leaves the open editor with the '
      'keyboard',
      (tester) async {
        final controller = await _pump(tester);
        addTearDown(() {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        await _open(tester, 'note');
        final editor = FocusManager.instance.primaryFocus;
        expect(_focused, 'note');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus,
          FocusManager.instance.rootScope,
          reason: 'the panel does not grab the parked keyboard',
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, editor);
        // Typing reaches the still-open field.
        tester.testTextInput.enterText('Typed after resume');
        await tester.pump();
        expect(controller.active?.field, 'note');
        expect(controller.session?.draft, 'Typed after resume');
        await _press(tester, LogicalKeyboardKey.enter);
        expect(_owner(tester).values['note'], 'Typed after resume');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets('an enclosing scope taking focus does not reclaim a live '
        'editor', (tester) async {
      final controller = await _pump(tester);
      await _open(tester, 'note');
      await _type(tester, 'note', 'Pending');
      final editor = FocusManager.instance.primaryFocus!;
      final scope = editor.enclosingScope!;
      editor.unfocus();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, scope);
      expect(controller.session?.draft, 'Pending');
      expect(_owner(tester).changes, isEmpty);
      editor.requestFocus();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, editor);
    });

    testWidgets('a removed editor falling to rootScope is not reclaimed', (
      tester,
    ) async {
      _window(tester, const Size(800, 600));
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      var showField = true;
      late StateSetter rebuild;
      // No route scope: the root scope is the only fallback. It belongs to
      // the application, so the panel must never take it over.
      await tester.pumpWidget(
        Focus(
          parentNode: FocusManager.instance.rootScope,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(800, 600)),
              child: LifeOSSkinScope(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return ActionPanel(
                      title: 'Root fallback',
                      record: 'root-fallback',
                      controller: controller,
                      groups: () => [
                        ActionGroup(
                          legend: 'Options',
                          fields: [
                            if (showField)
                              const ActionField(
                                id: 'checked',
                                label: 'Checked',
                                kind: ValueKind.check,
                                value: false,
                                fieldKey: ValueKey('root-check'),
                              ),
                          ],
                        ),
                      ],
                      onChanged: (_, _) {},
                      primaryLabel: 'Go',
                      onPrimary: () {},
                      onCancel: () {},
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await _click(tester, find.byKey(const ValueKey('era-check-box')));
      expect(_focused, 'checked');
      expect(
        FocusManager.instance.primaryFocus!.enclosingScope,
        FocusManager.instance.rootScope,
      );
      expect(controller.session?.draft, isTrue);
      rebuild(() => showField = false);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus,
        FocusManager.instance.rootScope,
      );
      expect(controller.session?.draft, isTrue);
      expect(controller.flush().isAccepted, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('traversal from outside never lands on the keys', (
      tester,
    ) async {
      _window(tester, const Size(800, 600));
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      var presses = 0;
      // No fields to hold Tab: only the keys could take it.
      await tester.pumpWidget(
        MaterialApp(
          home: LifeOSSkinScope(
            child: Scaffold(
              body: ActionPanel(
                title: 'Confirm days',
                record: 'confirm',
                controller: controller,
                groups: () => const [
                  ActionGroup(legend: 'Days', children: [Text('2 picked')]),
                ],
                onChanged: (_, _) {},
                primaryLabel: 'Confirm',
                onPrimary: () => presses++,
                onCancel: () => presses++,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await _press(tester, LogicalKeyboardKey.tab);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<KeyButton>(),
          isNull,
        );
        await _press(tester, LogicalKeyboardKey.space);
        await _press(tester, LogicalKeyboardKey.enter);
      }
      expect(presses, 0);
    });

    testWidgets('Esc rolls back only the open field', (tester) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'note');
      await _type(tester, 'note', 'Early');
      await _press(tester, LogicalKeyboardKey.enter);
      await _type(tester, 'hours', '11');
      await _press(tester, LogicalKeyboardKey.escape);
      expect(controller.session, isNull);
      expect(owner.values['note'], 'Early');
      expect(owner.values['hours'], 8);
      expect(tester.widget<TextField>(_box('hours')).controller!.text, '8');
      expect(owner.changes, [('note', 'Early')]);
    });

    testWidgets('a field closed by the panel losing it keeps the keyboard in '
        'the panel', (tester) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'note');
      owner.update(() => owner.busy = true);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<ActionPanel>(),
        isNotNull,
      );
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(owner.primaries, 0);
      expect(controller.active?.field, 'note', reason: 'locked, not closed');
    });

    testWidgets('a focused editor going away leaves the keyboard on the '
        'panel, so Tab cannot traverse', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller, extraFields: 1);
      await _open(tester, 'extra0');
      await _press(tester, LogicalKeyboardKey.escape);
      expect(_focused, 'extra0');
      // The owner drops the field: its focused editor is disposed.
      await _pump(tester, controller: controller);
      final focus = FocusManager.instance.primaryFocus;
      expect(focus?.debugLabel, 'ActionPanel');
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, focus);
      expect(controller.session, isNull);
    });
  });

  group('primary', () {
    testWidgets('flushes the open field before the callback', (tester) async {
      await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'hours');
      await _type(tester, 'hours', '10');
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.log, ['change hours', 'primary']);
      expect(owner.values['hours'], 10);
    });

    testWidgets('an invalid draft blocks it and keeps the red editor', (
      tester,
    ) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'hours');
      await _type(tester, 'hours', '9x');
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.primaries, 0);
      expect(find.text('Enter whole hours.'), findsOneWidget);
      expect(controller.active?.field, 'hours');
      expect(controller.session?.draft, '9x');
      expect(_focused, 'hours');
      await _type(tester, 'hours', '9');
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.primaries, 1);
      expect(owner.values['hours'], 9);
    });

    testWidgets('a double click submits once', (tester) async {
      await _pump(tester);
      final owner = _owner(tester)..goBusy = true;
      final center = tester.getCenter(_primary);
      for (var i = 0; i < 2; i++) {
        final gesture = await tester.startGesture(
          center,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.up();
      }
      await tester.pumpAndSettle();
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.primaries, 1);
    });

    testWidgets('a synchronous action may run again after a frame', (
      tester,
    ) async {
      await _pump(tester);
      final owner = _owner(tester);
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.primaries, 2);
    });
  });

  group('cancel', () {
    testWidgets('cancels the open field before telling the owner', (
      tester,
    ) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'note');
      await _type(tester, 'note', '');
      await tester.tap(_cancel, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.log, ['cancel null'], reason: 'no commit, field closed');
      expect(controller.session, isNull);
      expect(owner.values['note'], 'Late');
    });

    testWidgets("leaves another region's open field alone", (tester) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      controller.begin(
        EditField(
          id: const EditIdentity(record: 'shift:7', field: 'end'),
          kind: ValueKind.text,
          value: 'a',
          commit: (_, _) => const EditResult.accepted(),
        ),
        host: 'grid',
      );
      controller.update(
        const EditIdentity(record: 'shift:7', field: 'end'),
        'b',
      );
      await tester.tap(_cancel, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.cancels, 1);
      expect(controller.session?.draft, 'b');
    });
  });

  group('busy', () {
    testWidgets('locks every field, the pick list and both keys', (
      tester,
    ) async {
      final controller = await _pump(tester);
      final owner = _owner(tester)..goBusy = true;
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(owner.busy, isTrue);
      final before = Map.of(owner.values);

      for (final key in [_primary, _cancel]) {
        expect(tester.widget<KeyButton>(key).onPressed, isNull);
      }
      for (final name in _order) {
        expect(
          tester.widget<CellEditor>(_editor(name)).enabled,
          isFalse,
          reason: name,
        );
      }

      // No field takes the pointer: no click can open, tick or drop down.
      for (final name in _order) {
        expect(_box(name).hitTestable(), findsNothing, reason: name);
      }
      expect(
        find
            .descendant(
              of: _box('day'),
              matching: find.byKey(const ValueKey('era-date-drop')),
            )
            .hitTestable(),
        findsNothing,
      );
      // Typing, a tick on the pick list and the greyed keys do nothing.
      expect(find.byType(EraMonthCalendar), findsNothing);
      expect(find.text('Leave'), findsNothing, reason: 'no list');
      await tester.enterText(_box('note'), 'Typed');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-Wed')));
      await tester.pumpAndSettle();
      await tester.tap(_primary, kind: PointerDeviceKind.mouse);
      await tester.tap(_cancel, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(controller.session, isNull);
      expect(owner.values, before);
      expect(owner.changes, isEmpty);
      expect(owner.picks, {'Mon', 'Tue'});
      expect(owner.primaries, 1);
      expect(owner.cancels, 0);

      owner.update(() => owner.busy = false);
      await tester.pumpAndSettle();
      expect(tester.widget<KeyButton>(_primary).onPressed, isNotNull);
      expect(tester.widget<CellEditor>(_editor('note')).enabled, isTrue);
    });

    testWidgets('a draft opened before busy cannot be committed while busy', (
      tester,
    ) async {
      final controller = await _pump(tester);
      final owner = _owner(tester);
      await _open(tester, 'note');
      await _type(tester, 'note', 'Early');
      owner.update(() => owner.busy = true);
      await tester.pumpAndSettle();
      expect(controller.flush().isAccepted, isFalse);
      expect(owner.values['note'], 'Late');
      owner.update(() => owner.busy = false);
      await tester.pumpAndSettle();
      expect(controller.flush().isAccepted, isTrue);
      expect(owner.values['note'], 'Early');
    });

    testWidgets('Enabled off greys the keys and locks the fields', (
      tester,
    ) async {
      _window(tester, const Size(800, 600));
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      var primaries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LifeOSSkinScope(
            child: Scaffold(
              body: EraFormScope(
                enabled: false,
                child: ActionPanel(
                  title: 'Off',
                  record: 'off',
                  controller: controller,
                  groups: () => const [
                    ActionGroup(
                      legend: 'G',
                      fields: [
                        ActionField(id: 'a', label: 'A', kind: ValueKind.text),
                      ],
                    ),
                  ],
                  onChanged: (_, _) {},
                  primaryLabel: 'Go',
                  onPrimary: () => primaries++,
                  onCancel: () {},
                ),
              ),
            ),
          ),
        ),
      );
      for (final key in tester.widgetList<KeyButton>(find.byType(KeyButton))) {
        expect(key.onPressed, isNull);
      }
      await tester.tap(find.text('Go'), kind: PointerDeviceKind.mouse);
      expect(primaries, 0);
    });
  });

  group('results', () {
    testWidgets('completed results stay as they were on a later failure', (
      tester,
    ) async {
      await _pump(tester);
      final owner = _owner(tester);
      owner.update(
        () => owner.results = [
          const ActionResult.done('Mon 2026-10-05', detail: 'Confirmed'),
          const ActionResult.done('Tue 2026-10-06', detail: 'Confirmed'),
        ],
      );
      await tester.pumpAndSettle();
      Rect rectOf(String text) => tester.getRect(find.text(text));
      final mon = rectOf('Mon 2026-10-05');
      owner.update(() {
        owner.results = [
          ...owner.results,
          const ActionResult.failed(
            'Wed 2026-10-07',
            'The synthetic store is busy.',
          ),
          const ActionResult.uncertain(
            'Thu 2026-10-08',
            detail: 'The save may have succeeded.',
          ),
        ];
        owner.error = 'One day failed; one is uncertain.';
      });
      await tester.pumpAndSettle();
      expect(find.text('Mon 2026-10-05'), findsOneWidget);
      expect(find.text('Tue 2026-10-06'), findsOneWidget);
      expect(find.text('Confirmed'), findsNWidgets(2));
      expect(find.text('The synthetic store is busy.'), findsOneWidget);
      expect(find.text('The save may have succeeded.'), findsOneWidget);
      expect(find.text('One day failed; one is uncertain.'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Done: Mon 2026-10-05')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Failed: Wed 2026-10-07')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Uncertain: Thu 2026-10-08')),
        findsOneWidget,
      );
      expect(rectOf('Mon 2026-10-05').size, mon.size);
    });
  });

  group('layout', () {
    for (final (size, scale) in [
      (const Size(800, 600), 2.0),
      (const Size(800, 600), 1.0),
    ]) {
      testWidgets('a tall form and result list scroll; the footer stays '
          'reachable at ${size.width.toInt()}x${size.height.toInt()} '
          '${(scale * 100).toInt()} %', (tester) async {
        final controller = await _pump(
          tester,
          size: size,
          scale: scale,
          extraFields: 12,
          extraResults: 30,
        );
        expect(tester.takeException(), isNull);
        final owner = _owner(tester);
        // The footer is on screen and takes the pointer without scrolling.
        for (final key in [_primary, _cancel]) {
          final rect = tester.getRect(key);
          expect((Offset.zero & size).contains(rect.center), isTrue);
          expect(key.hitTestable(), findsOneWidget);
        }
        await tester.tap(_primary, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(owner.primaries, 1);
        // Every field can be scrolled to and opened; Enter brings the next
        // one into view.
        await _open(tester, 'extra10');
        await _press(tester, LogicalKeyboardKey.enter);
        expect(controller.active?.field, 'extra11');
        expect(_box('extra11').hitTestable(), findsOneWidget);
        // The last result can be scrolled into view.
        await tester.ensureVisible(find.text('Synthetic day 29'));
        await tester.pumpAndSettle();
        expect(find.text('Synthetic day 29').hitTestable(), findsOneWidget);
        expect(tester.getRect(_cancel).bottom, lessThanOrEqualTo(size.height));
      });
    }
  });

  group('lifecycle', () {
    testWidgets('a remounted panel keeps the draft and takes its commit', (
      tester,
    ) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      await _open(tester, 'note');
      await _type(tester, 'note', 'Moved');
      // A new owner tree: the panel's State is replaced (AppFrame docking).
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, controller: controller);
      expect(controller.session?.draft, 'Moved');
      expect(tester.widget<TextField>(_box('note')).controller!.text, 'Moved');
      expect(controller.flush().isAccepted, isTrue);
      await tester.pumpAndSettle();
      expect(_owner(tester).values['note'], 'Moved');
    });

    testWidgets('a removed panel leaves an identifiable orphan, not a call '
        'into disposed state', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      final owner = _owner(tester);
      await _open(tester, 'note');
      await _type(tester, 'note', 'Gone');
      await _pump(tester, controller: controller, mounted: false);
      final result = controller.flush();
      expect(result.isAccepted, isFalse);
      expect(controller.session?.id.record, _record);
      expect(controller.session?.draft, 'Gone');
      expect(owner.changes, isEmpty);
      expect(tester.takeException(), isNull);
      controller.cancel();
    });
  });
}
