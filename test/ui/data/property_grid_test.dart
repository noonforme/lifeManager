import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

/// PropertyGrid (database shell spec 3, 4.1, 4.2, 4.6, 6) under the shared
/// editor contract: categorized and A–Z views, kind-specific editors on one
/// caller-owned controller, flush before every command, the next eligible
/// field from the caller's refreshed data, measured layout at 260 and
/// 306 px and 100/200 % text, and no keyboard outside an open editor.

const _today = LocalDate(2026, 10, 8);

const _types = [
  EraComboItem<Object?>('day', 'Day'),
  EraComboItem<Object?>('night', 'Night'),
  EraComboItem<Object?>('extra', 'Extra'),
];

Map<String, Object?> _shift({String note = 'Late'}) => {
  'date': _today,
  'type': 'day',
  'start': const LocalTime(7, 0),
  'end': const LocalTime(19, 0),
  'note': note,
  'paid': true,
  'bonus': '0.00',
  'break': '30',
  'overtime': '0:00',
};

const _longError =
    'Enter a note. The note is kept with the day and printed on the '
    'monthly summary, so it must say something about the day; an empty '
    'note is not accepted. Write a few words about what happened, who '
    'asked for the change and why the times differ from the plan. '
    'This last sentence closes the long error.';

/// A synthetic pending aggregate of two shifts with the same property keys.
/// Commits apply to `id.record`.
final class _Host extends StatefulWidget {
  const _Host({
    required this.controller,
    required this.record,
    required this.width,
    required this.height,
    this.enabled = true,
    this.formEnabled = true,
    this.longError = false,
    this.gridKey,
  });

  final EditorSessionController controller;
  final String record;
  final double width;
  final double height;
  final bool enabled;
  final bool formEnabled;
  final bool longError;
  final Key? gridKey;

  @override
  State<_Host> createState() => _HostState();
}

final class _HostState extends State<_Host> {
  final records = {'shift:7': _shift(), 'shift:8': _shift(note: 'Early')};
  final saved = {'shift:7': _shift(), 'shift:8': _shift(note: 'Early')};
  final commits = <(EditIdentity, Object?)>[];
  final follows = <String>[];
  final orders = <PropertyGridOrder>[];
  var saves = 0;

  EditResult commit(EditIdentity id, Object? draft) {
    commits.add((id, draft));
    final values = records[id.record];
    if (values == null) return const EditResult.rejected('Shift removed.');
    switch (id.field) {
      case 'break' when int.tryParse('$draft') == null:
        return const EditResult.rejected('Enter whole minutes.');
      case 'bonus' when !RegExp(r'^\d+\.\d\d$').hasMatch('$draft'):
        return const EditResult.rejected('Enter an amount like 12.50.');
      case 'overtime' when !RegExp(r'^\d+:\d\d$').hasMatch('$draft'):
        return const EditResult.rejected('Enter a time like 1:30.');
      case 'note' when draft == '':
        return EditResult.rejected(
          widget.longError ? _longError : 'Enter a note.',
        );
      case 'start' when (draft! as LocalTime).hour < 6:
        return const EditResult.rejected('Start at 06:00 or later.');
    }
    setState(() {
      values[id.field] = draft;
      // An unpaid shift has no break to deduct.
      if (id.field == 'paid' && draft == false) values['break'] = '0';
    });
    return const EditResult.accepted();
  }

  List<PropertyItem> items() {
    final v = records[widget.record]!;
    final s = saved[widget.record]!;
    String? was(String key, ValueKind kind) =>
        v[key] == s[key] ? null : formatValue(kind, s[key], choices: _types);
    final paid = v['paid'] == true;
    return [
      PropertyItem(
        key: 'date',
        label: 'Date',
        category: 'Shift',
        kind: ValueKind.date,
        value: v['date'],
        description: 'The day the shift starts on.',
      ),
      PropertyItem(
        key: 'type',
        label: 'Type',
        category: 'Shift',
        kind: ValueKind.choice,
        value: v['type'],
        choices: _types,
      ),
      PropertyItem(
        key: 'start',
        label: 'Start',
        category: 'Shift',
        kind: ValueKind.time,
        value: v['start'],
      ),
      PropertyItem(
        key: 'end',
        label: 'End',
        category: 'Shift',
        kind: ValueKind.time,
        value: v['end'],
        was: was('end', ValueKind.time),
      ),
      PropertyItem(
        key: 'note',
        label: 'Note',
        category: 'Shift',
        value: v['note'],
        description: 'Your own words about this day.',
      ),
      PropertyItem(
        key: 'paid',
        label: 'Paid',
        category: 'Shift',
        kind: ValueKind.check,
        value: v['paid'],
      ),
      PropertyItem(
        key: 'bonus',
        label: 'Bonus',
        category: 'Pay',
        kind: ValueKind.money,
        value: v['bonus'],
        display: 'EUR ${v['bonus']}',
        readOnlyReason: paid ? null : 'An unpaid shift has no bonus.',
      ),
      PropertyItem(
        key: 'break',
        label: 'Break',
        category: 'Pay',
        kind: ValueKind.number,
        value: v['break'],
      ),
      const PropertyItem(
        key: 'rate',
        label: 'Hourly rate',
        category: 'Pay',
        kind: ValueKind.money,
        value: '18.40',
        display: 'EUR 18.40',
        readOnlyReason: 'Set by the agreement.',
        description: 'The gross rate per hour.',
      ),
      PropertyItem(
        key: 'overtime',
        label: 'Overtime',
        category: 'Pay',
        kind: ValueKind.duration,
        value: v['overtime'],
      ),
      const PropertyItem(
        key: 'payslip',
        label: 'Payslip',
        category: 'Pay',
        value: '(not yet)',
        enabled: false,
      ),
      PropertyItem(
        key: 'employment',
        label: 'Employment',
        category: 'Belongs to',
        value: 'Synthetic depot',
        onFollow: () => follows.add('employment'),
      ),
      PropertyItem(
        key: 'agreement',
        label: 'Agreement',
        category: 'Belongs to',
        value: 'From 2026-10-01',
        onFollow: () => follows.add('agreement'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          KeyButton(
            label: 'Save',
            kind: KeyKind.toolbar,
            onPressed: () {
              if (widget.controller.flush().isAccepted) saves++;
            },
          ),
          KeyButton(
            label: 'Undo',
            kind: KeyKind.toolbar,
            onPressed: widget.controller.cancel,
          ),
        ],
      ),
      SizedBox(
        width: widget.width,
        height: widget.height,
        child: EraFormScope(
          enabled: widget.formEnabled,
          child: PropertyGrid(
            key: widget.gridKey,
            record: widget.record,
            controller: widget.controller,
            items: items(),
            onCommit: commit,
            today: _today,
            enabled: widget.enabled,
            onOrderChanged: orders.add,
          ),
        ),
      ),
    ],
  );
}

Future<EditorSessionController> _pump(
  WidgetTester tester, {
  EditorSessionController? controller,
  String record = 'shift:7',
  double width = 306,
  double height = 560,
  double scale = 1,
  bool enabled = true,
  bool formEnabled = true,
  bool longError = false,
  Key? gridKey,
}) async {
  final session = controller ?? EditorSessionController();
  if (controller == null) addTearDown(session.dispose);
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLifeOSTheme(),
      home: LifeOSSkinScope(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _Host(
                    controller: session,
                    record: record,
                    width: width,
                    height: height,
                    enabled: enabled,
                    formEnabled: formEnabled,
                    longError: longError,
                    gridKey: gridKey,
                  ),
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

_HostState _host(WidgetTester tester) => tester.state(find.byType(_Host));

Finder _value(String key) => find.byKey(ValueKey('property-value:$key'));
Finder _name(String key) => find.byKey(ValueKey('property-name:$key'));
Finder _row(String key) => find.byKey(ValueKey('property-row:$key'));
Finder _shows(String text) => find.text(text, findRichText: true);
Finder _editor(String key) => find.byKey(ValueKey('property-editor:$key'));
Finder _category(String name) =>
    find.byKey(ValueKey('property-category:$name'));
final _alphabetical = find.byKey(const ValueKey('property-order-alphabetical'));
final _categorized = find.byKey(const ValueKey('property-order-categorized'));
final _description = find.byKey(const ValueKey('property-description'));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(_editor(key), text);
  await tester.pump();
}

/// The text the description pane shows, in reading order.
List<String> _describes(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: _description, matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan!.toPlainText(),
];

/// The property whose editor holds the keyboard, or null.
String? get _focusedEditor {
  final context = FocusManager.instance.primaryFocus?.context;
  final editor = context?.findAncestorWidgetOfExactType<CellEditor>();
  return editor?.field.id.field;
}

/// Whether the keyboard is on the property grid itself (not an editor).
bool get _regionFocused {
  final node = FocusManager.instance.primaryFocus;
  final context = node?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<CellEditor>() == null &&
      (context.widget is PropertyGrid ||
          context.findAncestorWidgetOfExactType<PropertyGrid>() != null);
}

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  group('views', () {
    testWidgets('categorized: category headers over their properties; a '
        'click collapses and expands a category', (tester) async {
      await _pump(tester);
      expect(_category('Shift'), findsOneWidget);
      expect(_category('Pay'), findsOneWidget);
      expect(_category('Belongs to'), findsOneWidget);
      expect(
        _top(tester, _category('Shift')),
        lessThan(_top(tester, _name('date'))),
      );
      expect(
        _top(tester, _name('paid')),
        lessThan(_top(tester, _category('Pay'))),
      );
      await _tap(tester, _category('Pay'));
      expect(_name('bonus'), findsNothing);
      expect(_name('overtime'), findsNothing);
      expect(_name('employment'), findsOneWidget);
      await _tap(tester, _category('Pay'));
      expect(_name('bonus'), findsOneWidget);
    });

    testWidgets('A–Z sorts by label without categories; Categorized '
        'restores them; only the display order changes', (tester) async {
      await _pump(tester);
      await _tap(tester, _alphabetical);
      expect(_host(tester).orders, [PropertyGridOrder.alphabetical]);
      expect(_describes(tester).first, 'Date', reason: 'selection kept');
      expect(_category('Shift'), findsNothing);
      final labels = [
        'agreement',
        'bonus',
        'break',
        'date',
        'employment',
        'end',
        'rate',
        'note',
        'overtime',
        'paid',
        'payslip',
        'start',
        'type',
      ];
      final tops = [for (final key in labels) _top(tester, _name(key))];
      expect(tops, orderedEquals([...tops]..sort()));
      // Enter follows the display order: Bonus, then Break, then Date.
      final controller = _host(tester).widget.controller;
      await _tap(tester, _value('bonus'));
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'break');
      expect(controller.active?.record, 'shift:7');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'date');
      await _press(tester, LogicalKeyboardKey.escape);
      await _tap(tester, _categorized);
      expect(_category('Shift'), findsOneWidget);
      expect(_host(tester).orders, [
        PropertyGridOrder.alphabetical,
        PropertyGridOrder.categorized,
      ]);
    });

    testWidgets('the first selectable property is selected and described; '
        'a click selects another', (tester) async {
      await _pump(tester);
      expect(_describes(tester), ['Date', 'The day the shift starts on.']);
      await _tap(tester, _name('note'));
      expect(_describes(tester), ['Note', 'Your own words about this day.']);
      expect(_host(tester).widget.controller.active, isNull);
    });

    testWidgets('read-only values are muted and explain why; a disabled '
        'property neither selects nor opens', (tester) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('rate'));
      expect(controller.active, isNull);
      expect(_describes(tester), [
        'Hourly rate',
        'Set by the agreement.',
        'The gross rate per hour.',
      ]);
      final rate = tester.widget<RichText>(
        find.descendant(of: _value('rate'), matching: find.byType(RichText)),
      );
      expect(
        rate.text.toPlainText(),
        'EUR 18.40',
        reason: 'the caller supplies the display text',
      );
      final style = (rate.text as TextSpan).children!.first.style!;
      expect(style.color, LifeOSTokens.millennium.muted);
      await _tap(tester, _value('payslip'));
      expect(_describes(tester).first, 'Hourly rate');
      expect(controller.active, isNull);
    });

    testWidgets('a changed value is bold with "(was …)" after it', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, _value('end'));
      await tester.tap(
        find.descendant(
          of: _editor('end'),
          matching: find.byKey(const ValueKey('era-time-up')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.enter);
      final end = tester.widget<RichText>(
        find.descendant(of: _value('end'), matching: find.byType(RichText)),
      );
      expect(end.text.toPlainText(), '20:00 (was 19:00)');
      final spans = (end.text as TextSpan).children!;
      expect(spans.first.style!.fontWeight, FontWeight.w700);
      expect(spans.last.style!.fontWeight, FontWeight.w400);
    });

    testWidgets('duplicate property keys are rejected', (tester) async {
      final controller = EditorSessionController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 300,
            child: PropertyGrid(
              record: 'r',
              controller: controller,
              onCommit: (_, _) => const EditResult.accepted(),
              items: const [
                PropertyItem(key: 'a', label: 'A', category: 'C'),
                PropertyItem(key: 'a', label: 'B', category: 'C'),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isArgumentError);
    });
  });

  group('editors', () {
    for (final (key, type) in [
      ('note', EraField),
      ('break', EraField),
      ('bonus', EraField),
      ('overtime', EraField),
      ('date', EraDateField),
      ('start', EraTimeField),
      ('type', EraCombo<Object?>),
      ('paid', EraCheckBox),
    ]) {
      testWidgets('a click on $key opens its kind\'s editor in the row', (
        tester,
      ) async {
        final controller = await _pump(tester);
        await _tap(tester, _value(key));
        expect(controller.active, EditIdentity(record: 'shift:7', field: key));
        expect(
          find.descendant(
            of: find.byKey(ValueKey('property-row:$key')),
            matching: find.byType(type),
          ),
          findsOneWidget,
        );
        expect(_focusedEditor, key);
      });
    }

    testWidgets('text kinds commit their raw text', (tester) async {
      final controller = await _pump(tester);
      for (final (key, text) in [
        ('note', 'Swapped with Ana'),
        ('bonus', '12.50'),
        ('break', '45'),
        ('overtime', '1:30'),
      ]) {
        await _tap(tester, _value(key));
        await _type(tester, key, text);
        await tester.tap(find.text('Save'), kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(_host(tester).records['shift:7']![key], text);
      }
      expect(controller.active, isNull);
      expect(_host(tester).saves, 4);
    });

    testWidgets('reject, correct, retry: the error is in the editor and '
        'first in the description; the next field opens after the fix', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('break'));
      await _type(tester, 'break', '4x');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'break');
      expect(controller.session!.draft, '4x');
      expect(_focusedEditor, 'break');
      expect(
        find.descendant(
          of: _row('break'),
          matching: find.text('Enter whole minutes.'),
        ),
        findsOneWidget,
        reason: 'in the editor',
      );
      expect(_describes(tester), ['Break', 'Enter whole minutes.']);
      await _press(tester, LogicalKeyboardKey.tab);
      expect(controller.session!.error, 'Enter whole minutes.');
      await _type(tester, 'break', '45');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).records['shift:7']!['break'], '45');
      expect(controller.active?.field, 'overtime', reason: 'rate is read-only');
      expect(_focusedEditor, 'overtime');
      expect(_describes(tester).first, 'Overtime');
    });

    testWidgets('next skips read-only, disabled and link rows but stops at '
        'the check; eligibility comes from the refreshed caller data', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('note'));
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'paid', reason: 'the check counts');
      // Untick: bonus becomes read-only in the caller's new items.
      await tester.tap(
        find.descendant(
          of: _editor('paid'),
          matching: find.byKey(const ValueKey('era-check-box')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(controller.session!.draft, isFalse);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).records['shift:7']!['paid'], isFalse);
      expect(controller.active?.field, 'break', reason: 'bonus is read-only');
      // Break opens with the value the same commit gave it, not the old 30.
      expect(controller.session!.draft, '0');
      expect(
        find.descendant(of: _row('break'), matching: find.text('0')),
        findsOneWidget,
      );
      await _press(tester, LogicalKeyboardKey.tab);
      expect(controller.active?.field, 'overtime');
    });

    testWidgets('at the last field Enter closes the editor without '
        'wrapping; the selection stays and the grid keeps the keyboard', (
      tester,
    ) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('overtime'));
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active, isNull);
      expect(_describes(tester).first, 'Overtime');
      expect(_regionFocused, isTrue);
      final before = FocusManager.instance.primaryFocus;
      await _press(tester, LogicalKeyboardKey.tab);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active, isNull);
      expect(FocusManager.instance.primaryFocus, same(before));
      expect(_host(tester).commits, isEmpty, reason: 'unchanged');
    });

    testWidgets('Esc throws away the active field only; earlier accepted '
        'fields stay pending', (tester) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('note'));
      await _type(tester, 'note', 'Kept');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.active?.field, 'paid');
      await tester.tap(
        find.descendant(
          of: _editor('paid'),
          matching: find.byKey(const ValueKey('era-check-box')),
        ),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.escape);
      expect(controller.active, isNull);
      final values = _host(tester).records['shift:7']!;
      expect(values['note'], 'Kept');
      expect(values['paid'], isTrue);
      expect(_regionFocused, isTrue);
    });

    testWidgets('the app going inactive and back leaves the open editor '
        'with the keyboard; typing reaches it', (tester) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('note'));
      await _type(tester, 'note', 'Before');
      expect(_focusedEditor, 'note');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_focusedEditor, 'note');
      // Through the live text input connection, without refocusing.
      tester.testTextInput.enterText('After resume');
      await tester.pump();
      expect(controller.session!.draft, 'After resume');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).records['shift:7']!['note'], 'After resume');
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('external flush and cancel: Save commits the draft, Undo '
        'drops it', (tester) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('note'));
      await _type(tester, 'note', 'Saved');
      await tester.tap(find.text('Save'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_host(tester).records['shift:7']!['note'], 'Saved');
      expect(controller.active, isNull);
      await _tap(tester, _value('note'));
      await _type(tester, 'note', 'Dropped');
      await tester.tap(find.text('Undo'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.active, isNull);
      expect(_host(tester).records['shift:7']!['note'], 'Saved');
      expect(
        find.descendant(of: _value('note'), matching: _shows('Saved')),
        findsOneWidget,
      );
    });

    testWidgets('a field opened by another region shows the same draft '
        'here, and the keyboard stays with that region', (tester) async {
      final controller = await _pump(tester);
      final host = _host(tester);
      controller.begin(
        EditField(
          id: const EditIdentity(record: 'shift:7', field: 'note'),
          kind: ValueKind.text,
          value: 'Late',
          commit: host.commit,
        ),
        host: 'grid',
      );
      controller.update(
        const EditIdentity(record: 'shift:7', field: 'note'),
        'From the grid',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _editor('note'),
          matching: find.text('From the grid'),
        ),
        findsOneWidget,
      );
      expect(_focusedEditor, isNull);
      expect(_describes(tester).first, 'Note');
    });
  });

  group('flush before commands', () {
    Future<EditorSessionController> rejected(WidgetTester tester) async {
      final controller = await _pump(tester);
      await _tap(tester, _value('break'));
      await _type(tester, 'break', 'x');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.session!.error, 'Enter whole minutes.');
      _host(tester).commits.clear();
      return controller;
    }

    testWidgets('a refused flush keeps the field, its category, the order '
        'and the selection', (tester) async {
      final controller = await rejected(tester);
      await _tap(tester, _name('date'));
      await _tap(tester, _value('note'));
      await _tap(tester, _category('Pay'));
      await _tap(tester, _alphabetical);
      await _tap(tester, _value('employment'));
      expect(controller.active?.field, 'break');
      expect(controller.session!.draft, 'x');
      expect(_editor('break'), findsOneWidget);
      expect(_category('Pay'), findsOneWidget);
      expect(_name('bonus'), findsOneWidget, reason: 'Pay stays expanded');
      expect(_host(tester).orders, isEmpty);
      expect(_host(tester).follows, isEmpty);
      expect(_describes(tester).take(2), ['Break', 'Enter whole minutes.']);
      expect(_focusedEditor, 'break');
      // Each command tried the draft once; none was taken.
      expect(_host(tester).commits, hasLength(5));
    });

    testWidgets('an accepted flush runs first: another property, a '
        'collapse, the order and a link each commit the draft', (tester) async {
      final controller = await _pump(tester);
      Future<void> draft(String text) async {
        await _tap(tester, _value('note'));
        await _type(tester, 'note', text);
      }

      await draft('one');
      await _tap(tester, _name('date'));
      expect(_host(tester).records['shift:7']!['note'], 'one');
      expect(_describes(tester).first, 'Date');

      await draft('two');
      await _tap(tester, _category('Belongs to'));
      expect(_host(tester).records['shift:7']!['note'], 'two');
      expect(_name('employment'), findsNothing);
      await _tap(tester, _category('Belongs to'));

      await draft('three');
      await _tap(tester, _alphabetical);
      expect(_host(tester).records['shift:7']!['note'], 'three');
      expect(_host(tester).orders, [PropertyGridOrder.alphabetical]);

      await draft('four');
      await _tap(tester, _value('agreement'));
      expect(_host(tester).records['shift:7']!['note'], 'four');
      expect(_host(tester).follows, ['agreement']);
      expect(controller.active, isNull);
    });
  });

  group('records', () {
    testWidgets('record A to B with the same keys: no draft, text, error '
        'or collapse carries over; the orphan stays for A', (tester) async {
      final controller = await _pump(tester);
      await _tap(tester, _category('Pay'));
      await _tap(tester, _value('note'));
      await _type(tester, 'note', '');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.session!.error, 'Enter a note.');
      await _type(tester, 'note', 'Draft for A');
      await _pump(tester, controller: controller, record: 'shift:8');
      expect(_editor('note'), findsNothing);
      expect(
        find.descendant(of: _value('note'), matching: _shows('Early')),
        findsOneWidget,
      );
      expect(_name('bonus'), findsOneWidget, reason: 'expanded again');
      expect(
        controller.session!.id,
        const EditIdentity(record: 'shift:7', field: 'note'),
      );
      expect(controller.session!.draft, 'Draft for A');
      // B selects its own first property; A's error is not B's.
      expect(_describes(tester), ['Date', 'The day the shift starts on.']);
      expect(_host(tester).records['shift:8']!['note'], 'Early');
      // Back on A the draft and its error are there; Save commits to A.
      await _pump(tester, controller: controller);
      expect(_describes(tester).take(2), ['Note', 'Enter a note.']);
      expect(
        find.descendant(
          of: _editor('note'),
          matching: find.text('Draft for A'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Save'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(_host(tester).records['shift:7']!['note'], 'Draft for A');
      expect(_host(tester).records['shift:8']!['note'], 'Early');
    });

    testWidgets('a new widget key with a new record starts clean and the '
        'old state takes no callbacks', (tester) async {
      final controller = await _pump(tester, gridKey: const ValueKey(1));
      await _tap(tester, _category('Pay'));
      await _tap(tester, _value('note'));
      await _type(tester, 'note', 'Draft for A');
      await _pump(
        tester,
        controller: controller,
        record: 'shift:8',
        gridKey: const ValueKey(2),
      );
      expect(_editor('note'), findsNothing);
      expect(_name('bonus'), findsOneWidget);
      expect(controller.session!.id.record, 'shift:7');
      controller.cancel();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tap(tester, _value('note'));
      await _type(tester, 'note', 'For B');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(_host(tester).records['shift:8']!['note'], 'For B');
      expect(_host(tester).records['shift:7']!['note'], 'Late');
    });
  });

  group('keyboard and disabled', () {
    testWidgets('outside an editor no key selects, opens, collapses, sorts, '
        'scrolls or moves focus', (tester) async {
      final controller = await _pump(tester, height: 200);
      await _tap(tester, _name('start'));
      expect(_regionFocused, isTrue);
      final focus = FocusManager.instance.primaryFocus;
      final scroll = tester
          .stateList<ScrollableState>(
            find.descendant(
              of: find.byType(PropertyGrid),
              matching: find.byType(Scrollable),
            ),
          )
          .map((state) => state.position.pixels)
          .toList();
      for (final key in [
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.f2,
        LogicalKeyboardKey.keyA,
      ]) {
        await _press(tester, key);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await _press(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      expect(controller.active, isNull);
      expect(_describes(tester).first, 'Start');
      expect(_category('Shift'), findsOneWidget);
      expect(_name('date'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(
        tester
            .stateList<ScrollableState>(
              find.descendant(
                of: find.byType(PropertyGrid),
                matching: find.byType(Scrollable),
              ),
            )
            .map((state) => state.position.pixels),
        scroll,
      );
      expect(_host(tester).commits, isEmpty);
    });

    for (final (name, enabled, formEnabled) in [
      ('a disabled form scope', true, false),
      ('enabled: false', false, true),
    ]) {
      testWidgets('$name: nothing opens, selects, collapses, sorts or '
          'follows', (tester) async {
        final controller = await _pump(
          tester,
          enabled: enabled,
          formEnabled: formEnabled,
        );
        await _tap(tester, _value('note'));
        await _tap(tester, _name('start'));
        await _tap(tester, _category('Pay'));
        await _tap(tester, _alphabetical);
        await _tap(tester, _value('employment'));
        expect(controller.active, isNull);
        expect(_describes(tester).first, 'Date');
        expect(_name('bonus'), findsOneWidget);
        expect(_category('Shift'), findsOneWidget);
        expect(_host(tester).orders, isEmpty);
        expect(_host(tester).follows, isEmpty);
        final note = tester.widget<RichText>(
          find.descendant(of: _value('note'), matching: find.byType(RichText)),
        );
        expect(
          (note.text as TextSpan).children!.first.style!.color,
          LifeOSTokens.millennium.muted,
        );
      });
    }
  });

  group('layout', () {
    testWidgets('a long error scrolls inside a bounded description; the '
        'field list keeps its room', (tester) async {
      final controller = await _pump(tester, height: 400, longError: true);
      await _tap(tester, _value('note'));
      await _type(tester, 'note', '');
      await _press(tester, LogicalKeyboardKey.enter);
      expect(controller.session!.error, _longError);
      final grid = tester.getRect(find.byType(PropertyGrid));
      final pane = tester.getRect(_description);
      expect(pane.height, lessThanOrEqualTo(grid.height * 0.4));
      expect(pane.bottom, lessThanOrEqualTo(grid.bottom));
      final list = tester.getRect(find.byKey(const ValueKey('property-list')));
      expect(list.height, greaterThanOrEqualTo(grid.height * 0.5));
      expect(
        tester.getRect(_editor('note')).top,
        greaterThanOrEqualTo(list.top),
      );
      final scroll = find.descendant(
        of: _description,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scroll).position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(scroll, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);
      expect(_focusedEditor, 'note');
    });

    for (final width in [260.0, 306.0]) {
      for (final scale in [1.0, 2.0]) {
        final at = '${width.round()} px, ${(scale * 100).round()} %';
        testWidgets('$at: labels are clamped or stacked, never overflowed', (
          tester,
        ) async {
          await _pump(tester, width: width, scale: scale);
          expect(tester.takeException(), isNull);
          for (final key in ['note', 'date', 'start', 'type', 'break']) {
            final label = tester.getRect(_name(key));
            final value = tester.getRect(_value(key));
            final stacked = value.top >= label.bottom;
            expect(
              stacked || value.left >= label.right,
              isTrue,
              reason: '$key: beside or under its label',
            );
            if (!stacked) {
              expect(
                label.width,
                lessThanOrEqualTo(128 * scale),
                reason: '$key: the label column is clamped',
              );
            }
            expect(
              value.width,
              greaterThanOrEqualTo(
                switch (key) {
                          'note' || 'type' => 96,
                          'date' => 120,
                          'start' => 72,
                          _ => 64,
                        } *
                        scale -
                    1,
              ),
              reason: '$key keeps its editor minimum',
            );
          }
          if (scale == 1 && width == 306) {
            expect(
              tester.getRect(_name('break')).width,
              128,
              reason: 'the baseline label column',
            );
          }
        });

        testWidgets('$at: real date, time and choice editing by mouse', (
          tester,
        ) async {
          final controller = await _pump(tester, width: width, scale: scale);
          final grid = tester.getRect(find.byType(PropertyGrid));

          await _tap(tester, _value('date'));
          final drop = find.descendant(
            of: _editor('date'),
            matching: find.byKey(const ValueKey('era-date-drop')),
          );
          expect(grid.contains(tester.getCenter(drop)), isTrue);
          await _tap(tester, drop);
          final day = find.byKey(ValueKey('era-day-${_today.addDays(2)}'));
          expect(day, findsOneWidget);
          await _tap(tester, day);
          expect(controller.session!.draft, _today.addDays(2));
          await _press(tester, LogicalKeyboardKey.enter);
          expect(_host(tester).records['shift:7']!['date'], _today.addDays(2));
          expect(controller.active?.field, 'type');

          final face = _editor('type');
          expect(grid.contains(tester.getCenter(face)), isTrue);
          await _tap(tester, face);
          await _tap(tester, find.text('Night').last);
          expect(controller.session!.draft, 'night');
          await _press(tester, LogicalKeyboardKey.enter);
          expect(_host(tester).records['shift:7']!['type'], 'night');
          expect(controller.active?.field, 'start');

          final up = find.descendant(
            of: _editor('start'),
            matching: find.byKey(const ValueKey('era-time-up')),
          );
          expect(grid.contains(tester.getCenter(up)), isTrue);
          await _tap(tester, up);
          await _press(tester, LogicalKeyboardKey.enter);
          expect(
            _host(tester).records['shift:7']!['start'],
            const LocalTime(8, 0),
          );
          expect(controller.active?.field, 'end');
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('260 px at 200 %: an editor wider than the column scrolls '
        'sideways with its error reachable', (tester) async {
      final controller = await _pump(tester, width: 260, scale: 2);
      await _tap(tester, _value('date'));
      final list = tester.getRect(find.byKey(const ValueKey('property-list')));
      final box = tester.getRect(_editor('date'));
      expect(box.left, greaterThanOrEqualTo(list.left - 0.5));
      expect(box.right, lessThanOrEqualTo(list.right + 0.5));
      expect(controller.active?.field, 'date');
      await _tap(tester, _value('note'));
      await _type(tester, 'note', '');
      await _press(tester, LogicalKeyboardKey.enter);
      final error = find.descendant(
        of: _row('note'),
        matching: find.text('Enter a note.'),
      );
      expect(error, findsOneWidget);
      expect(list.contains(tester.getCenter(error)), isTrue);
    });
  });
}
