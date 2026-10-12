import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/gallery/demos/cell_editor_demo.dart';
import 'package:lifeos/ui/ui.dart';

import '../../support/gallery.dart';

/// CellEditor under the shared editor contract (database shell spec 4.2,
/// 4.6): Enter/Tab commit and advance only after an accepted flush, Esc
/// cancels the field, a rejected draft keeps its editor and the keyboard,
/// and drafts live in the caller's controller.

const _today = LocalDate(2026, 10, 8);

/// The record's fields, in their order. `total` is derived (read-only).
const _order = [
  'note',
  'hours',
  'total',
  'paid',
  'start',
  'day',
  'pay',
  'kind',
];

const _kinds = {
  'note': ValueKind.text,
  'hours': ValueKind.number,
  'total': ValueKind.money,
  'paid': ValueKind.check,
  'start': ValueKind.time,
  'day': ValueKind.date,
  'pay': ValueKind.money,
  'kind': ValueKind.choice,
};

const _choices = [
  EraComboItem<Object?>('shift', 'Shift'),
  EraComboItem<Object?>('leave', 'Leave'),
];

Map<String, Object?> _initial() => {
  'note': 'Late',
  'hours': 8,
  'total': '100.00',
  'paid': true,
  'start': const LocalTime(7, 0),
  'day': _today,
  'pay': '12.50',
  'kind': 'shift',
};

/// A synthetic pending record with a labelled form, a grid row whose
/// open cell is a bare editor, and a toolbar Save key, sharing one
/// controller.
final class _Host extends StatefulWidget {
  const _Host({
    required this.controller,
    this.record = 'shift:7',
    this.form = true,
    this.grid = false,
    this.formHeight,
    this.hide = const {},
  });

  final EditorSessionController controller;
  final Object record;
  final bool form;
  final bool grid;

  /// Puts the form in a scroll view this tall.
  final double? formHeight;

  /// Fields whose form editor is not mounted.
  final Set<String> hide;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  /// Pending values per record: a commit applies to the record its
  /// identity names, never to the record shown now.
  final records = <Object, Map<String, Object?>>{};
  final committed = <EditIdentity>[];

  Map<String, Object?> get values =>
      records.putIfAbsent(widget.record, _initial);
  final commits = <(String, Object?)>[];
  final saves = <Map<String, Object?>>[];

  // The grid row shows the open cell's editor, as a grid listening to its
  // controller does.
  void _onSession() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSession);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSession);
    super.dispose();
  }

  EditResult commit(EditIdentity id, Object? draft) {
    commits.add((id.field, draft));
    committed.add(id);
    final record = records[id.record];
    if (record == null) {
      return const EditResult.rejected('This shift was removed.');
    }
    Object? parsed = draft;
    switch (id.field) {
      case 'hours':
        parsed = int.tryParse('$draft');
        if (parsed == null) {
          return const EditResult.rejected('Enter a whole number.');
        }
      case 'pay':
        if (!RegExp(r'^\d+\.\d\d$').hasMatch('$draft')) {
          return const EditResult.rejected('Enter an amount like 12.50.');
        }
      case 'note':
        if (draft == '') return const EditResult.rejected('Enter a note.');
      case 'day':
        if ((draft! as LocalDate).compareTo(_today) < 0) {
          return const EditResult.rejected('Pick today or later.');
        }
      case 'start':
        if ((draft! as LocalTime).hour < 6) {
          return const EditResult.rejected('Start at 06:00 or later.');
        }
    }
    setState(() => record[id.field] = parsed);
    return const EditResult.accepted();
  }

  EditIdentity id(String name) =>
      EditIdentity(record: widget.record, field: name);

  EditField field(String name) => EditField(
    id: id(name),
    kind: _kinds[name]!,
    value: values[name],
    commit: commit,
  );

  bool eligible(String name) => name != 'total';

  /// The next eligible field after [name] in the record, from the current
  /// pending values.
  EditField? next(String name) {
    for (final other in _order.skip(_order.indexOf(name) + 1)) {
      if (eligible(other)) return field(other);
    }
    return null;
  }

  Widget editor(String name, {required bool bare}) => CellEditor(
    key: ValueKey('${bare ? 'grid' : 'form'}-$name'),
    controller: widget.controller,
    field: field(name),
    label: name,
    bare: bare,
    host: bare ? 'grid' : 'form',
    enabled: eligible(name),
    choices: _choices,
    today: _today,
    fieldKey: ValueKey('${bare ? 'grid' : 'form'}-$name-box'),
    next: () => next(name),
  );

  @override
  Widget build(BuildContext context) {
    Widget form = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final name in _order)
          if (!widget.hide.contains(name)) editor(name, bare: false),
      ],
    );
    if (widget.formHeight case final height?) {
      form = SizedBox(
        height: height,
        child: SingleChildScrollView(child: form),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyButton(
          label: 'Save',
          kind: KeyKind.toolbar,
          onPressed: () {
            if (widget.controller.flush().isAccepted) {
              saves.add(Map.of(values));
            }
          },
        ),
        if (widget.grid)
          Wrap(
            children: [
              for (final name in _order)
                SizedBox(
                  key: ValueKey('cell-$name'),
                  width: 140,
                  child: widget.controller.isActive(id(name))
                      ? editor(name, bare: true)
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.controller.begin(
                            field(name),
                            host: 'grid',
                          ),
                          child: Text(
                            formatValue(
                              _kinds[name]!,
                              values[name],
                              choices: _choices,
                            ),
                          ),
                        ),
                ),
            ],
          ),
        if (widget.form) form,
      ],
    );
  }
}

Future<EditorSessionController> _pump(
  WidgetTester tester, {
  EditorSessionController? controller,
  Object record = 'shift:7',
  bool form = true,
  bool grid = false,
  double? formHeight,
  Set<String> hide = const {},
}) async {
  final session = controller ?? EditorSessionController();
  if (controller == null) addTearDown(session.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 760,
                child: _Host(
                  controller: session,
                  record: record,
                  form: form,
                  grid: grid,
                  formHeight: formHeight,
                  hide: hide,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return session;
}

_HostState _host(WidgetTester tester) => tester.state(find.byType(_Host));

/// The field whose editor holds the keyboard, as "form-note" or
/// "grid-note".
String? get _focused {
  final context = FocusManager.instance.primaryFocus?.context;
  final editor = context?.findAncestorWidgetOfExactType<CellEditor>();
  return (editor?.key as ValueKey<String>?)?.value;
}

Finder _box(String key) => find.byKey(ValueKey('$key-box'));

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Opens [name]'s form editor the way a click on it does.
Future<void> _click(
  WidgetTester tester,
  String name, {
  bool settle = true,
}) async {
  final target = switch (_kinds[name]!) {
    ValueKind.time => find.descendant(
      of: _box('form-$name'),
      matching: find.byKey(const ValueKey('era-time-hour')),
    ),
    ValueKind.check => find.descendant(
      of: find.byKey(ValueKey('form-$name')),
      matching: find.byKey(const ValueKey('era-check-box')),
    ),
    _ => _box('form-$name'),
  };
  await tester.tap(target.first, kind: PointerDeviceKind.mouse);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Opens [name] the way a host does (no click): the date box selects its
/// year.
Future<void> _open(WidgetTester tester, String name) async {
  final host = _host(tester);
  host.widget.controller.begin(host.field(name), host: 'form');
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String name, String text) async {
  await tester.enterText(_box('form-$name'), text);
  await tester.pump();
}

Finder get _calendar => find.byType(EraMonthCalendar);

void main() {
  group('Enter and Tab', () {
    testWidgets('commit the typed text and open the next field', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _type(tester, 'note', 'Early');
      expect(controller.active?.field, 'note');
      expect(_host(tester).values['note'], 'Late', reason: 'a draft only');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['note'], 'Early');
      expect(controller.active?.field, 'hours');
      expect(_focused, 'form-hours');
      await _type(tester, 'hours', '9');
      await _press(tester, LogicalKeyboardKey.tab);
      expect(_host(tester).values['hours'], 9);
      expect(_host(tester).commits, [('note', 'Early'), ('hours', '9')]);
    });

    testWidgets('an unchanged field advances without a commit', (tester) async {
      final controller = await _pump(tester);
      await _click(tester, 'note');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).commits, isEmpty);
      expect(controller.active?.field, 'hours');
    });

    testWidgets('skip the derived field but stop at the check, then at '
        'each later kind', (tester) async {
      final controller = await _pump(tester);
      await _click(tester, 'hours');
      final visited = <String?>[];
      for (var i = 0; i < 4; i++) {
        await _press(tester, LogicalKeyboardKey.enter);
        visited.add(_focused);
        expect(controller.active?.field, _focused?.substring(5));
      }
      expect(visited, ['form-paid', 'form-start', 'form-day', 'form-pay']);
      expect(_focused, 'form-pay');
    });

    testWidgets('at the last field close the editor without wrapping or '
        'traversing', (tester) async {
      final controller = await _pump(tester);
      await _click(tester, 'kind');
      expect(controller.active?.field, 'kind');
      await _press(tester, LogicalKeyboardKey.tab);
      expect(controller.session, isNull);
      expect(_focused, 'form-kind', reason: 'the keyboard stays put');
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_focused, 'form-kind');
      expect(controller.session, isNull);
    });

    testWidgets('modified Enter/Tab and Shift+Tab neither commit nor move', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _type(tester, 'note', 'Early');
      for (final modifier in [
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.tab]) {
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(key);
          await tester.sendKeyUpEvent(modifier);
          await tester.pumpAndSettle();
        }
      }
      for (final key in [
        LogicalKeyboardKey.f2,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.arrowDown,
      ]) {
        await _press(tester, key);
      }
      expect(_host(tester).commits, isEmpty);
      expect(controller.session?.draft, 'Early');
      expect(_focused, 'form-note');
    });
  });

  group('rejection', () {
    testWidgets('keeps the invalid text, the editor and the keyboard; a '
        'correction is accepted', (tester) async {
      final controller = await _pump(tester);
      await _click(tester, 'hours');
      await _type(tester, 'hours', '8.5x');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(find.text('Enter a whole number.'), findsOneWidget);
      expect(controller.active?.field, 'hours');
      expect(_focused, 'form-hours');
      expect(
        tester.widget<TextField>(_box('form-hours')).controller!.text,
        '8.5x',
      );
      expect(_host(tester).values['hours'], 8);
      // Retried as it stands: rejected again, nothing cached as done.
      await _press(tester, LogicalKeyboardKey.tab);
      expect(controller.active?.field, 'hours');
      await _type(tester, 'hours', '10');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['hours'], 10);
      expect(find.text('Enter a whole number.'), findsNothing);
      expect(controller.active?.field, 'paid');
    });

    for (final (bad, error, others) in [
      ('hours', 'Enter a whole number.', ['day', 'kind', 'paid', 'start']),
      ('start', 'Start at 06:00 or later.', ['day', 'kind', 'paid', 'hours']),
      ('day', 'Pick today or later.', ['start', 'kind', 'paid', 'hours']),
    ]) {
      testWidgets('a click on another field while $bad is rejected does '
          'nothing to it', (tester) async {
        final controller = await _pump(tester);
        if (bad == 'hours') {
          await _type(tester, 'hours', 'x');
        } else if (bad == 'start') {
          await _open(tester, 'start');
          await _press(tester, LogicalKeyboardKey.digit5);
        } else {
          await _open(tester, 'day');
          await _press(tester, LogicalKeyboardKey.arrowDown);
        }
        final draft = controller.session!.draft;
        for (final (index, name) in [...others, 'note'].indexed) {
          await _click(tester, name, settle: false);
          // Not even for a frame: the click never reaches the editor.
          expect(_calendar, findsNothing, reason: name);
          expect(find.byType(MenuItemButton), findsNothing, reason: name);
          await tester.pumpAndSettle();
          expect(controller.active?.field, bad, reason: name);
          expect(_focused, 'form-$bad', reason: name);
          // One attempt per click: focus the click brings does not retry.
          expect(_host(tester).commits, hasLength(index + 1), reason: name);
        }
        expect(_host(tester).values['paid'], isTrue);
        expect(controller.session!.draft, draft);
        expect(find.text(error), findsOneWidget);
      });
    }

    testWidgets('a mouse tick follows the same path: a locked check never '
        'changes, an eligible one opens first', (tester) async {
      final controller = await _pump(tester);
      await _click(tester, 'paid');
      expect(controller.active?.field, 'paid');
      expect(controller.session!.draft, isFalse);
      expect(_host(tester).values['paid'], isTrue, reason: 'a draft');
      expect(_focused, 'form-paid');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['paid'], isFalse);
      expect(controller.active?.field, 'start');
      // The derived field is locked.
      await tester.tap(_box('form-total'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.active?.field, 'start');
    });
  });

  group('Esc', () {
    testWidgets('throws away this field only', (tester) async {
      final controller = await _pump(tester);
      await _type(tester, 'note', 'Early');
      await _press(tester, LogicalKeyboardKey.enter);
      await _type(tester, 'hours', '99');
      await _press(tester, LogicalKeyboardKey.escape);
      expect(controller.session, isNull);
      expect(_host(tester).values['note'], 'Early');
      expect(_host(tester).values['hours'], 8);
      expect(
        tester.widget<TextField>(_box('form-hours')).controller!.text,
        '8',
      );
    });

    testWidgets('after a calendar pick restores the entry date', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _click(tester, 'start');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(controller.session!.draft, const LocalTime(8, 0));
      await _press(tester, LogicalKeyboardKey.escape);
      expect(_host(tester).values['start'], const LocalTime(7, 0));
      expect(find.bySemanticsLabel(RegExp(r'^start, 07:00')), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: _box('form-day'),
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(controller.active?.field, 'day');
      await tester.tap(
        find.descendant(
          of: _calendar,
          matching: find.byKey(ValueKey('era-day-${_today.addDays(3)}')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(controller.session!.draft, _today.addDays(3));
      expect(_focused, 'form-day', reason: 'the pick returns to the box');
      await _press(tester, LogicalKeyboardKey.escape);
      expect(controller.session, isNull);
      expect(_host(tester).values['day'], _today);
      expect(_host(tester).commits, isEmpty);
    });
  });

  group('controlled editors', () {
    testWidgets('a mouse calendar pick then Enter commits the picked day', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await tester.tap(
        find.descendant(
          of: _box('form-day'),
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: _calendar,
          matching: find.byKey(ValueKey('era-day-${_today.addDays(1)}')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_calendar, findsNothing);
      expect(_host(tester).commits, isEmpty, reason: 'no premature commit');
      expect(
        find.bySemanticsLabel(RegExp(spokenDate(_today.addDays(1)))),
        findsOneWidget,
      );
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['day'], _today.addDays(1));
      expect(controller.active?.field, 'pay');
    });

    testWidgets('Enter with the calendar open closes it without its cursor '
        'day and commits the draft', (tester) async {
      await _pump(tester);
      await _open(tester, 'day');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      await tester.tap(
        find.descendant(
          of: _box('form-day'),
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_calendar, findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_calendar, findsNothing);
      expect(_host(tester).values['day'], const LocalDate(2027, 10, 8));
    });

    testWidgets('time, choice and check repaint with their drafts', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _click(tester, 'start');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      await _press(tester, LogicalKeyboardKey.digit9);
      expect(controller.session!.draft, const LocalTime(9, 0));
      expect(find.bySemanticsLabel(RegExp(r'^start, 09:00')), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.enter);
      await _press(tester, LogicalKeyboardKey.enter); // day, unchanged
      await _press(tester, LogicalKeyboardKey.enter); // pay, unchanged
      expect(controller.active?.field, 'kind');
      await _click(tester, 'kind');
      await tester.tap(find.text('Leave').last, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.session!.draft, 'leave');
      expect(find.text('Leave'), findsOneWidget);
      expect(_host(tester).values['kind'], 'shift');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['kind'], 'leave');
      expect(_host(tester).values['start'], const LocalTime(9, 0));
    });
  });

  group('text input', () {
    testWidgets('accepting an input method candidate does not advance', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _click(tester, 'note');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Latek',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 4, end: 5),
        ),
      );
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'note');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Latte',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(controller.active?.field, 'note');
      expect(controller.session!.draft, 'Latte');
      expect(_host(tester).commits, isEmpty);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['note'], 'Latte');
    });

    testWidgets('a remounted editor resumes the draft and its selection', (
      tester,
    ) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      await _type(tester, 'note', 'Earlier');
      final text = tester.widget<TextField>(_box('form-note')).controller!;
      text.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
      await tester.pump();
      // Scrolled away: the editor goes, the draft stays.
      await _pump(tester, controller: controller, hide: {'note'});
      expect(controller.session!.draft, 'Earlier');
      await _pump(tester, controller: controller);
      await tester.pumpAndSettle();
      final again = tester.widget<TextField>(_box('form-note')).controller!;
      expect(again.text, 'Earlier');
      expect(
        again.selection,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      expect(_focused, isNot('form-note'), reason: 'a remount takes no focus');
    });
  });

  group('commands outside the editor', () {
    testWidgets('Save sees the newly typed text on the first click', (
      tester,
    ) async {
      await _pump(tester);
      await _type(tester, 'note', 'Typed');
      await tester.tap(find.text('Save'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_host(tester).saves, hasLength(1));
      expect(_host(tester).saves.single['note'], 'Typed');
    });

    testWidgets('a rejected draft stops Save and keeps the editor', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _click(tester, 'pay');
      await _type(tester, 'pay', '12,5');
      await tester.tap(find.text('Save'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_host(tester).saves, isEmpty);
      expect(find.text('Enter an amount like 12.50.'), findsOneWidget);
      expect(controller.session!.draft, '12,5');
      expect(_focused, 'form-pay');
    });
  });

  group('sharing and lifecycle', () {
    testWidgets('a grid cell and a property editor of one field hold one '
        'draft', (tester) async {
      final controller = await _pump(tester, grid: true);
      await tester.tap(find.byKey(const ValueKey('cell-note')));
      await tester.pumpAndSettle();
      expect(_focused, 'grid-note');
      await tester.enterText(_box('grid-note'), 'From grid');
      await tester.pump();
      expect(
        tester.widget<TextField>(_box('form-note')).controller!.text,
        'From grid',
      );
      await tester.enterText(_box('form-note'), 'From form');
      await tester.pump();
      expect(
        tester.widget<TextField>(_box('grid-note')).controller!.text,
        'From form',
      );
      expect(controller.session!.draft, 'From form');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).values['note'], 'From form');
      // The grid's next cell opens as the bare editor of the next field.
      expect(controller.active?.field, 'hours');
      expect(find.byKey(const ValueKey('grid-note')), findsNothing);
      expect(find.byKey(const ValueKey('grid-hours')), findsOneWidget);
    });

    testWidgets('a grid cell click while a draft is rejected opens nothing', (
      tester,
    ) async {
      final controller = await _pump(tester, grid: true);
      await _type(tester, 'hours', 'x');
      await tester.tap(find.byKey(const ValueKey('cell-day')));
      await tester.pumpAndSettle();
      expect(controller.active?.field, 'hours');
      expect(find.byKey(const ValueKey('grid-day')), findsNothing);
    });

    testWidgets('an old draft never lands on another record with the same '
        'field', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      await _type(tester, 'note', 'For shift 7');
      await _pump(tester, controller: controller, record: 'shift:8');
      expect(
        tester.widget<TextField>(_box('form-note')).controller!.text,
        'Late',
      );
      expect(controller.session!.id.record, 'shift:7');
      expect(controller.session!.draft, 'For shift 7');
      // Acting on shift 8's note flushes the orphan to shift 7 only.
      await _type(tester, 'note', 'For shift 8');
      expect(_host(tester).committed, [
        const EditIdentity(record: 'shift:7', field: 'note'),
      ]);
      expect(_host(tester).records['shift:7']!['note'], 'For shift 7');
      expect(_host(tester).records['shift:8']!['note'], 'Late');
      expect(controller.session!.id.record, 'shift:8');
      expect(controller.session!.draft, 'For shift 8');
    });

    testWidgets('an orphaned draft of a removed record stays until it is '
        'resolved', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      await _type(tester, 'note', 'For shift 7');
      await _pump(tester, controller: controller, record: 'shift:8');
      _host(tester).records.remove('shift:7');
      await _type(tester, 'note', 'For shift 8');
      // Rejected: shift 8 neither opens nor takes the orphan's text.
      expect(_host(tester).committed, [
        const EditIdentity(record: 'shift:7', field: 'note'),
      ]);
      expect(controller.session!.id.record, 'shift:7');
      expect(controller.session!.draft, 'For shift 7');
      expect(controller.session!.error, 'This shift was removed.');
      expect(_host(tester).records['shift:8']!['note'], 'Late');
      expect(
        tester.widget<TextField>(_box('form-note')).controller!.text,
        'Late',
      );
      // Resolved explicitly: shift 8 can be edited.
      controller.cancel();
      await _type(tester, 'note', 'For shift 8');
      expect(controller.session!.id.record, 'shift:8');
      expect(controller.session!.draft, 'For shift 8');
    });

    testWidgets('only a primary click opens a field: a secondary click '
        'neither opens nor flushes', (tester) async {
      final controller = await _pump(tester);
      await _type(tester, 'note', 'Early');
      for (final name in ['hours', 'day', 'kind', 'paid']) {
        await tester.tap(
          name == 'paid'
              ? find.descendant(
                  of: find.byKey(const ValueKey('form-paid')),
                  matching: find.byKey(const ValueKey('era-check-box')),
                )
              : _box('form-$name'),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();
        expect(controller.active?.field, 'note', reason: name);
      }
      expect(_host(tester).commits, isEmpty);
      expect(controller.session!.draft, 'Early');
      expect(_host(tester).values['paid'], isTrue);
    });

    testWidgets('focus arriving by itself neither opens a field nor flushes '
        'the open one', (tester) async {
      final controller = await _pump(tester);
      await _type(tester, 'note', 'Early');
      for (final name in ['hours', 'start', 'day']) {
        final editor = find.byKey(ValueKey('form-$name'));
        final node = tester
            .widget<Focus>(
              find
                  .descendant(
                    of: editor,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Focus &&
                          widget.focusNode?.debugLabel == 'CellEditor',
                    ),
                  )
                  .first,
            )
            .focusNode!;
        node.requestFocus();
        await tester.pumpAndSettle();
        expect(_focused, 'form-$name', reason: 'focus moved');
        expect(controller.active?.field, 'note', reason: name);
      }
      expect(_host(tester).commits, isEmpty);
      expect(controller.session!.draft, 'Early');
    });

    testWidgets('a next field with no editor in the same host is reported '
        'in a debug build', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLifeOSTheme(),
          home: LifeOSSkinScope(
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: CellEditor(
                  controller: controller,
                  host: 'panel',
                  field: EditField(
                    id: const EditIdentity(record: 'r', field: 'a'),
                    kind: ValueKind.text,
                    value: 'x',
                    commit: (id, draft) => const EditResult.accepted(),
                  ),
                  label: 'A',
                  next: () => EditField(
                    id: const EditIdentity(record: 'r', field: 'missing'),
                    kind: ValueKind.text,
                    value: '',
                    commit: (id, draft) => const EditResult.accepted(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        '${tester.takeException()}',
        contains('no CellEditor of that field in host panel'),
      );
    });

    testWidgets('disposing an editor with its calendar open leaves the '
        'draft and no callbacks', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      await _open(tester, 'day');
      await _press(tester, LogicalKeyboardKey.arrowUp);
      await tester.tap(
        find.descendant(
          of: _box('form-day'),
          matching: find.byKey(const ValueKey('era-date-drop')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(_calendar, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_calendar, findsNothing);
      expect(controller.session!.draft, const LocalDate(2027, 10, 8));
      // The controller's notices reach no disposed editor.
      controller
        ..update(controller.active!, _today)
        ..requestFocus()
        ..cancel();
      expect(tester.takeException(), isNull);
    });

    testWidgets("an editor going away never resets another field's draft", (
      tester,
    ) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);
      await _type(tester, 'note', 'Kept');
      await _pump(tester, controller: controller, hide: {'hours', 'paid'});
      await _pump(tester, controller: controller);
      expect(controller.session!.draft, 'Kept');
      expect(controller.active?.field, 'note');
    });

    testWidgets('the next field is scrolled into view before it takes the '
        'keyboard', (tester) async {
      final controller = await _pump(tester, formHeight: 60);
      await _type(tester, 'note', 'Early');
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      // The check, time and date boxes do not scroll themselves into view
      // as a text field does.
      for (final name in ['hours', 'paid', 'start', 'day']) {
        await _press(tester, LogicalKeyboardKey.enter);
        expect(controller.active?.field, name);
        expect(_focused, 'form-$name');
        final box = tester.getRect(find.byKey(ValueKey('form-$name')).first);
        expect(
          viewport.top <= box.top + 0.5 && box.bottom - 0.5 <= viewport.bottom,
          isTrue,
          reason: '$name at $box in $viewport',
        );
      }
    });
  });

  group('gallery demo', () {
    /// The focused editor's field and host.
    (String, Object?)? focusedIn() {
      final context = FocusManager.instance.primaryFocus?.context;
      final editor = context?.findAncestorWidgetOfExactType<CellEditor>();
      return editor == null ? null : (editor.field.id.field, editor.host);
    }

    Finder editorOf(String field, String host) => find.byWidgetPredicate(
      (widget) =>
          widget is CellEditor &&
          widget.field.id.field == field &&
          widget.host == host,
    );

    for (final (host, order) in [
      ('panel', ['note', 'hours', 'start', 'kind', 'paid']),
      ('grid', ['hours', 'pay', 'start', 'day', 'kind', 'paid']),
    ]) {
      testWidgets('Enter walks the $host region and keeps the keyboard in it', (
        tester,
      ) async {
        await pumpGalleryDemo(tester, cellEditorDemo);
        await tester.tap(
          find.descendant(
            of: editorOf(order.first, host),
            matching: find.byType(TextField),
          ),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(focusedIn(), (order.first, host));
        for (final field in order.skip(1)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(focusedIn(), (field, host), reason: 'after Enter');
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Open field: none'), findsOneWidget);
        expect(focusedIn(), (order.last, host), reason: 'closed, no traversal');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
