import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/ui.dart';

/// Value kinds, their text, and the era editor each one reuses; plus the
/// opt-in shared-control additions an editor host needs (focus nodes,
/// focus on a hosted click, a disabled-aware custom face, a filled combo).

const _today = LocalDate(2026, 10, 8);
const _box = ValueKey('box');
const _choices = [
  EraComboItem<Object?>('shift', 'Shift'),
  EraComboItem<Object?>('leave', 'Leave'),
];

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildLifeOSTheme(),
    home: LifeOSSkinScope(
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: child),
        ),
      ),
    ),
  ),
);

/// Holds one value for a controlled editor and lets the test replace it.
final class _Holder extends StatefulWidget {
  const _Holder({required this.initial, required this.builder, super.key});

  final Object? initial;
  final Widget Function(Object? value, ValueChanged<Object?> set) builder;

  @override
  State<_Holder> createState() => _HolderState();
}

final class _HolderState extends State<_Holder> {
  late Object? value = widget.initial;

  void set(Object? next) => setState(() => value = next);

  @override
  Widget build(BuildContext context) => widget.builder(value, set);
}

_HolderState _holder(WidgetTester tester) =>
    tester.state<_HolderState>(find.byType(_Holder));

void main() {
  group('ValueKind', () {
    test('numeric kinds align right in figures; dates and times use '
        'figures; text aligns left', () {
      for (final kind in ValueKind.values) {
        final numeric = {
          ValueKind.number,
          ValueKind.money,
          ValueKind.duration,
        }.contains(kind);
        expect(kind.isNumeric, numeric, reason: '$kind');
        expect(
          kind.align,
          numeric ? TextAlign.right : TextAlign.left,
          reason: '$kind',
        );
        expect(
          kind.usesFigures,
          numeric || kind == ValueKind.date || kind == ValueKind.time,
          reason: '$kind',
        );
        expect(
          kind.typedAsText,
          numeric || kind == ValueKind.text,
          reason: '$kind',
        );
      }
    });
  });

  group('formatValue', () {
    test('null is empty for every kind', () {
      for (final kind in ValueKind.values) {
        expect(formatValue(kind, null), '', reason: '$kind');
      }
    });

    test('dates and times use the era helpers', () {
      expect(formatValue(ValueKind.date, _today), 'Thu 2026-10-08');
      expect(formatValue(ValueKind.time, const LocalTime(7, 5)), '07:05');
      expect(formatValue(ValueKind.time, const LocalTime(7, 5, 9)), '07:05:09');
    });

    test('checks are Yes or No and choices show their label', () {
      expect(formatValue(ValueKind.check, true), 'Yes');
      expect(formatValue(ValueKind.check, false), 'No');
      expect(
        formatValue(ValueKind.choice, 'leave', choices: _choices),
        'Leave',
      );
    });

    test('amounts and durations show the caller\'s text, never invented '
        'rules', () {
      expect(formatValue(ValueKind.money, '€ 12.50'), '€ 12.50');
      expect(
        formatValue(
          ValueKind.money,
          1250,
          display: (cents) => '${(cents as int) ~/ 100},${cents % 100} €',
        ),
        '12,50 €',
      );
      expect(
        formatValue(
          ValueKind.duration,
          const Duration(minutes: 450),
          display: (value) => '7 h 30 min',
        ),
        '7 h 30 min',
      );
      expect(formatValue(ValueKind.number, 3), '3');
      expect(formatValue(ValueKind.text, 'Late'), 'Late');
    });
  });

  group('valueEditor reuses the era controls', () {
    testWidgets('text kinds edit a caller-owned controller; numbers right '
        'in tabular figures', (tester) async {
      for (final kind in [
        ValueKind.text,
        ValueKind.number,
        ValueKind.money,
        ValueKind.duration,
      ]) {
        final text = TextEditingController(text: '12');
        addTearDown(text.dispose);
        await _pump(
          tester,
          valueEditor(kind: kind, label: 'Amount', controller: text),
        );
        expect(find.byType(EraField), findsOneWidget, reason: '$kind');
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.textAlign, kind.align, reason: '$kind');
        expect(
          field.style?.fontFeatures,
          kind.isNumeric
              ? contains(const FontFeature.tabularFigures())
              : isNull,
          reason: '$kind',
        );
      }
    });

    testWidgets('a text editor keeps typing and selection over unrelated '
        'rebuilds', (tester) async {
      final text = TextEditingController(text: 'Late');
      addTearDown(text.dispose);
      await _pump(
        tester,
        _Holder(
          initial: 0,
          builder: (value, set) => valueEditor(
            kind: ValueKind.text,
            label: 'Note $value',
            controller: text,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Later');
      text.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
      _holder(tester).set(1);
      await tester.pump();
      expect(text.text, 'Later');
      expect(
        text.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
    });

    testWidgets('date, time, choice and check repaint with the value they '
        'are given', (tester) async {
      Future<void> check(
        ValueKind kind,
        Object initial,
        Object next,
        Finder Function(Object value) shows,
      ) async {
        await _pump(
          tester,
          _Holder(
            key: ValueKey(kind),
            initial: initial,
            builder: (value, set) => valueEditor(
              kind: kind,
              label: 'Value',
              value: value,
              onChanged: set,
              today: _today,
              choices: _choices,
            ),
          ),
        );
        expect(shows(initial), findsOneWidget, reason: '$kind initial');
        _holder(tester).set(next);
        await tester.pump();
        expect(shows(next), findsOneWidget, reason: '$kind next');
        expect(shows(initial), findsNothing, reason: '$kind old');
      }

      Finder semantics(String text) => find.bySemanticsLabel(RegExp(text));
      final handle = tester.ensureSemantics();
      await check(
        ValueKind.date,
        _today,
        const LocalDate(2026, 11, 2),
        (value) => semantics(spokenDate(value as LocalDate)),
      );
      await check(
        ValueKind.time,
        const LocalTime(7, 0),
        const LocalTime(19, 45),
        (value) => semantics('Value, ${value.toString().substring(0, 5)}'),
      );
      await check(
        ValueKind.choice,
        'shift',
        'leave',
        (value) => find.text(value == 'shift' ? 'Shift' : 'Leave'),
      );
      await _pump(
        tester,
        _Holder(
          key: const ValueKey(ValueKind.check),
          initial: true,
          builder: (value, set) => valueEditor(
            kind: ValueKind.check,
            label: 'Paid',
            value: value,
            onChanged: set,
          ),
        ),
      );
      expect(tester.widget<EraCheckBox>(find.byType(EraCheckBox)).value, true);
      _holder(tester).set(false);
      await tester.pump();
      expect(tester.widget<EraCheckBox>(find.byType(EraCheckBox)).value, false);
      handle.dispose();
    });

    testWidgets('a mouse change reports the typed value', (tester) async {
      await _pump(
        tester,
        _Holder(
          initial: false,
          builder: (value, set) => valueEditor(
            kind: ValueKind.check,
            label: 'Paid',
            value: value,
            onChanged: set,
          ),
        ),
      );
      await tester.tap(find.text('Paid'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(_holder(tester).value, isTrue);
    });

    testWidgets('disabled greys and locks, keeping the form\'s label width', (
      tester,
    ) async {
      await _pump(
        tester,
        EraFormScope(
          labelWidth: 90,
          child: _Holder(
            initial: false,
            builder: (value, set) => Column(
              children: [
                valueEditor(
                  kind: ValueKind.check,
                  label: 'Paid',
                  value: value,
                  onChanged: set,
                  enabled: false,
                ),
                valueEditor(
                  kind: ValueKind.time,
                  label: 'Start',
                  value: const LocalTime(7, 0),
                  fieldKey: _box,
                  enabled: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Paid'), kind: PointerDeviceKind.mouse);
      await tester.pump();
      expect(_holder(tester).value, isFalse);
      final scope = tester.element(find.byKey(_box));
      expect(EraFormScope.enabledOf(scope), isFalse);
      expect(EraFormScope.labelWidthOf(scope), 90);
    });
  });

  group('shared controls, opt-in', () {
    testWidgets('date, time, text and combo boxes take a caller focus node', (
      tester,
    ) async {
      final nodes = [for (var i = 0; i < 4; i++) FocusNode()];
      addTearDown(() {
        for (final node in nodes) {
          node.dispose();
        }
      });
      final text = TextEditingController();
      addTearDown(text.dispose);
      await _pump(
        tester,
        Column(
          children: [
            EraDateField(
              label: 'Day',
              value: _today,
              today: _today,
              focusNode: nodes[0],
              onChanged: (_) {},
            ),
            EraTimeField(
              label: 'Start',
              value: const LocalTime(7, 0),
              focusNode: nodes[1],
              onChanged: (_) {},
            ),
            EraField(controller: text, label: 'Note', focusNode: nodes[2]),
            EraCombo<String>(
              items: const [EraComboItem('a', 'A')],
              value: 'a',
              semanticLabel: 'View',
              focusNode: nodes[3],
              onSelected: (_) {},
            ),
          ],
        ),
      );
      for (final node in nodes) {
        node.requestFocus();
        await tester.pump();
        expect(node.hasPrimaryFocus, isTrue);
      }
    });

    testWidgets('autofocus focuses a date or time box', (tester) async {
      await _pump(
        tester,
        EraTimeField(
          label: 'Start',
          value: const LocalTime(7, 0),
          autofocus: true,
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'EraTimeField');
      await _pump(
        tester,
        EraDateField(
          label: 'Day',
          value: _today,
          today: _today,
          autofocus: true,
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'EraDateField');
    });

    testWidgets('a hosted check box takes focus on a click; a legacy one '
        'does not', (tester) async {
      for (final hosted in [false, true]) {
        final node = FocusNode();
        addTearDown(node.dispose);
        final box = _Holder(
          key: ValueKey(hosted),
          initial: false,
          builder: (value, set) => EraCheckBox(
            value: value! as bool,
            label: 'Paid',
            focusNode: node,
            onChanged: set,
          ),
        );
        await _pump(tester, hosted ? EraEditorHostScope(child: box) : box);
        await tester.tap(find.text('Paid'), kind: PointerDeviceKind.mouse);
        await tester.pump();
        expect(_holder(tester).value, isTrue, reason: 'hosted $hosted');
        expect(node.hasPrimaryFocus, hosted, reason: 'hosted $hosted');
      }
    });

    testWidgets('a bare check box shows its box alone and keeps its name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        EraEditorHostScope(
          bare: true,
          child: EraCheckBox(value: true, label: 'Paid', onChanged: (_) {}),
        ),
      );
      expect(find.text('Paid'), findsNothing);
      expect(find.bySemanticsLabel('Paid'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a custom combo face can tell the combo is locked', (
      tester,
    ) async {
      final seen = <bool>[];
      Widget combo() => EraCombo<String>(
        items: const [EraComboItem('a', 'A')],
        value: 'a',
        semanticLabel: 'View',
        face: (context, focused) {
          seen.add(EraCombo.enabledOf(context));
          return const Text('face');
        },
        onSelected: (_) {},
      );
      await _pump(tester, combo());
      await _pump(
        tester,
        EraEditorHostScope(child: EraFormScope(enabled: false, child: combo())),
      );
      expect(seen.first, isTrue);
      expect(seen.last, isFalse);
    });

    testWidgets('a hosted combo in a wide cell has its arrow at the right '
        'edge; a legacy one keeps its arrow after its text', (tester) async {
      Future<(Rect, Rect)> measure({required bool hosted}) async {
        final combo = SizedBox(
          width: 300,
          child: EraCombo<String>(
            key: _box,
            items: const [EraComboItem('a', 'A')],
            value: 'a',
            semanticLabel: 'View',
            onSelected: (_) {},
          ),
        );
        await _pump(
          tester,
          Align(
            alignment: Alignment.topLeft,
            child: hosted
                ? EraEditorHostScope(bare: true, child: combo)
                : combo,
          ),
        );
        return (
          tester.getRect(find.byType(EraComboFace)),
          tester.getRect(find.byType(ComboArrow)),
        );
      }

      final (face, arrow) = await measure(hosted: true);
      expect(face.width, 300);
      expect(arrow.right, face.right - 1, reason: 'inside the 1 px border');
      final (legacyFace, legacyArrow) = await measure(hosted: false);
      expect(legacyFace.width, 300);
      expect(legacyArrow.right, lessThan(legacyFace.right - 1));
    });
  });
}
