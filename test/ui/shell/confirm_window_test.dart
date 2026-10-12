import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

enum _Answer { save, discard, keep }

const _choices = [
  ConfirmChoice(value: _Answer.save, label: 'Save'),
  ConfirmChoice(value: _Answer.discard, label: "Don't save"),
  ConfirmChoice(value: _Answer.keep, label: 'Keep editing'),
];

void main() {
  void window(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget inline(
    Widget child, {
    Size size = const Size(800, 600),
    double scale = 1,
  }) => MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: LifeOSSkinScope(
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );

  ConfirmWindow<_Answer> confirm({
    List<ConfirmChoice<_Answer>> choices = _choices,
    ValueChanged<_Answer>? onChoose,
    bool enabled = true,
    String message = 'Save your changes to this shift?',
  }) => ConfirmWindow<_Answer>(
    title: 'Leave shift',
    message: message,
    choices: choices,
    cancelValue: _Answer.keep,
    onChoose: onChoose ?? (_) {},
    enabled: enabled,
  );

  group('inline window', () {
    testWidgets('choices keep their order; the first is the primary key', (
      tester,
    ) async {
      final chosen = <_Answer>[];
      await tester.pumpWidget(inline(confirm(onChoose: chosen.add)));
      final xs = [
        for (final label in ['Save', "Don't save", 'Keep editing'])
          tester.getTopLeft(find.text(label)).dx,
      ];
      expect(xs, [...xs]..sort());
      await tester.tap(find.text("Don't save"));
      await tester.tap(find.text('Save'));
      expect(chosen, [_Answer.discard, _Answer.save]);
    });

    testWidgets('the close key chooses the explicit cancel value', (
      tester,
    ) async {
      final chosen = <_Answer>[];
      await tester.pumpWidget(inline(confirm(onChoose: chosen.add)));
      await tester.tap(find.bySemanticsLabel('Close Leave shift'));
      expect(chosen, [_Answer.keep]);
    });

    test('rejects one or four choices', () {
      expect(
        () => ConfirmWindow<int>(
          title: 't',
          message: 'm',
          choices: const [ConfirmChoice(value: 1, label: 'a')],
          cancelValue: 1,
          onChoose: (_) {},
        ),
        throwsAssertionError,
      );
      expect(
        () => ConfirmWindow<int>(
          title: 't',
          message: 'm',
          choices: [
            for (var i = 0; i < 4; i++) ConfirmChoice(value: i, label: '$i'),
          ],
          cancelValue: 1,
          onChoose: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('disabled: choices and close do nothing and paint greyed', (
      tester,
    ) async {
      final chosen = <_Answer>[];
      await tester.pumpWidget(
        inline(confirm(onChoose: chosen.add, enabled: false)),
      );
      await tester.tapAt(tester.getCenter(find.text('Save')));
      await tester.tapAt(
        tester.getCenter(find.bySemanticsLabel('Close Leave shift')),
      );
      expect(chosen, isEmpty);
      expect(
        tester
            .widgetList<KeyButton>(find.byType(KeyButton))
            .every((key) => key.onPressed == null),
        isTrue,
      );
      // The close key stays, greyed.
      expect(find.byType(Opacity), findsWidgets);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Close Leave shift')),
        isSemantics(
          label: 'Close Leave shift',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
    });

    testWidgets('Enter and Space activate nothing', (tester) async {
      final chosen = <_Answer>[];
      await tester.pumpWidget(inline(confirm(onChoose: chosen.add)));
      for (final key in [
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.tab,
      ]) {
        await tester.sendKeyEvent(key);
      }
      expect(chosen, isEmpty);
      expect(FocusManager.instance.primaryFocus?.context, isNull);
    });

    for (final (size, scale) in [
      (const Size(800, 600), 2.0),
      (const Size(320, 240), 2.0),
    ]) {
      for (final count in [2, 3]) {
        testWidgets('$count long choices stay inside ${size.width.toInt()}x'
            '${size.height.toInt()} at ${(scale * 100).toInt()} %', (
          tester,
        ) async {
          window(tester, size);
          await tester.pumpWidget(
            inline(
              size: size,
              scale: scale,
              confirm(
                choices: [
                  const ConfirmChoice(
                    value: _Answer.save,
                    label: 'Save every change to this synthetic shift',
                  ),
                  const ConfirmChoice(
                    value: _Answer.discard,
                    label: 'Discard every change and leave the day',
                  ),
                  const ConfirmChoice(
                    value: _Answer.keep,
                    label: 'Keep editing this shift',
                  ),
                ].take(count).toList(),
                message: List.filled(
                  12,
                  'The synthetic shift has unsaved changes to its times.',
                ).join(' '),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          final screen = Offset.zero & size;
          expect(
            screen.contains(
              tester.getRect(find.byType(Material).first).topLeft,
            ),
            isTrue,
          );
          final win = tester.getRect(find.byType(Material).first);
          expect(win.width, lessThanOrEqualTo(size.width));
          expect(win.height, lessThanOrEqualTo(size.height));
          // Keys that need more room than the window has scroll in their
          // own footer; each is brought into view and checked there.
          for (final key in find.byType(KeyButton).evaluate()) {
            await tester.ensureVisible(find.byWidget(key.widget));
            await tester.pump();
            final rect = tester.getRect(find.byWidget(key.widget));
            expect(win.inflate(0.5).contains(rect.topLeft), isTrue);
            // A key taller than a 240 px window's footer scrolls inside it.
            if (size.height >= 480) {
              expect(win.inflate(0.5).contains(rect.bottomRight), isTrue);
            }
          }
          // Labels wrap: the whole text sits inside its key, never ellipsized.
          var wrapped = false;
          for (final key in tester.widgetList<KeyButton>(
            find.byType(KeyButton),
          )) {
            final text = find.descendant(
              of: find.byWidget(key),
              matching: find.text(key.label),
            );
            final widget = tester.widget<Text>(text);
            expect(widget.maxLines, isNull);
            expect(widget.overflow, isNot(TextOverflow.ellipsis));
            final paragraph = tester.renderObject<RenderParagraph>(text);
            expect(paragraph.didExceedMaxLines, isFalse);
            final keyRect = tester.getRect(find.byWidget(key));
            final textRect = tester.getRect(text);
            expect(keyRect.inflate(0.5).contains(textRect.topLeft), isTrue);
            expect(keyRect.inflate(0.5).contains(textRect.bottomRight), isTrue);
            final line = TextPainter(
              text: TextSpan(text: key.label, style: widget.style),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout();
            if (line.width > textRect.width + 1) {
              wrapped = true;
              expect(textRect.height, greaterThan(line.height * 1.5));
            }
          }
          if (size.width < 400) {
            final tops = {
              for (final key in find.byType(KeyButton).evaluate())
                tester.getTopLeft(find.byWidget(key.widget)).dy.round(),
            };
            expect(wrapped, isTrue, reason: 'a narrow window wraps labels');
            expect(tops.length, greaterThan(1), reason: 'keys wrap to rows');
          }
          // The choices stay pointer-reachable.
          await tester.ensureVisible(find.byType(KeyButton).last);
          await tester.tap(find.byType(KeyButton).last);
        });
      }
    }
  });

  group('showConfirmWindow', () {
    final underText = TextEditingController();
    final shown = <_Answer?>[];
    var barrierTaps = 0;
    var shortcuts = 0;

    Future<void> open(WidgetTester tester, {double scale = 1}) async {
      shown.clear();
      barrierTaps = 0;
      shortcuts = 0;
      underText.text = 'draft';
      window(tester, const Size(800, 600));
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            textScaler: TextScaler.linear(scale),
          ),
          child: CallbackShortcuts(
            // An application-level shortcut must not see a key either.
            bindings: {
              for (final key in [
                LogicalKeyboardKey.enter,
                LogicalKeyboardKey.escape,
                LogicalKeyboardKey.tab,
                LogicalKeyboardKey.f5,
              ])
                SingleActivator(key): () => shortcuts++,
            },
            child: MaterialApp(
              home: LifeOSSkinScope(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        SizedBox(
                          width: 300,
                          child: EraField(
                            controller: underText,
                            label: 'Under',
                            fieldKey: const ValueKey('under'),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => barrierTaps++,
                          child: const SizedBox(
                            key: ValueKey('page'),
                            width: 400,
                            height: 100,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            shown.add(
                              await showConfirmWindow<_Answer>(
                                context,
                                title: 'Leave shift',
                                message: 'Save your changes?',
                                choices: _choices,
                                cancelValue: _Answer.keep,
                              ),
                            );
                          },
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('under')));
      await tester.pump();
      await tester.tap(find.text('Open'));
      await tester.pump();
    }

    testWidgets('a choice completes the future with its value', (tester) async {
      await open(tester);
      expect(find.text('Leave shift'), findsOneWidget);
      await tester.tap(find.text("Don't save"));
      await tester.pump();
      expect(shown, [_Answer.discard]);
      expect(find.text('Leave shift'), findsNothing);
    });

    testWidgets('the close key completes with the cancel value', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Close Leave shift'));
      await tester.pump();
      expect(shown, [_Answer.keep]);
    });

    testWidgets('the barrier absorbs taps and does not dismiss', (
      tester,
    ) async {
      await open(tester);
      await tester.tapAt(const Offset(780, 580));
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('page'))));
      await tester.pump();
      expect(find.text('Leave shift'), findsOneWidget);
      expect(barrierTaps, 0);
      expect(shown, isEmpty);
    });

    testWidgets('no key reaches the editor under the route or a choice', (
      tester,
    ) async {
      await open(tester);
      final keys = <LogicalKeyboardKey>[
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.tab,
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.backspace,
        LogicalKeyboardKey.delete,
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.pageUp,
        LogicalKeyboardKey.pageDown,
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.f2,
        LogicalKeyboardKey.f5,
      ];
      for (final key in keys) {
        await tester.sendKeyEvent(key);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      for (final chord in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await tester.sendKeyDownEvent(chord);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(chord);
      }
      await tester.pump();
      expect(underText.text, 'draft');
      expect(shortcuts, 0, reason: 'no application shortcut saw a key');
      expect(shown, isEmpty, reason: 'no key chose anything');
      expect(find.text('Leave shift'), findsOneWidget);
      // The editor lost focus to the route, so text cannot be typed into it.
      final focus = FocusManager.instance.primaryFocus!;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('under')),
          matching: find.byWidgetPredicate(
            (w) => w is Focus && w.focusNode == focus,
          ),
        ),
        findsNothing,
      );
      expect(
        focus.context!.findAncestorWidgetOfExactType<ConfirmWindow<_Answer>>(),
        isNull,
        reason: 'the route holds the focus, not a choice',
      );
    });

    testWidgets('carries the skin, theme and a Material context', (
      tester,
    ) async {
      await open(tester);
      final route = find.byType(ConfirmWindow<_Answer>);
      final context = tester.element(route);
      expect(LifeOSSkinScope.of(context), LifeOSSkinData.standard);
      expect(Material.maybeOf(context), isNotNull);
      expect(DefaultTextStyle.of(context).style.fontSize, isNotNull);
      // No shadow: the window's Material has no elevation.
      final material = tester.widget<Material>(
        find.descendant(of: route, matching: find.byType(Material)).first,
      );
      expect(material.elevation, 0);
    });

    testWidgets('a window at 200 % text stays on the screen', (tester) async {
      await open(tester, scale: 2);
      final win = tester.getRect(
        find
            .descendant(
              of: find.byType(ConfirmWindow<_Answer>),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        (Offset.zero & const Size(800, 600)).contains(win.topLeft),
        isTrue,
      );
      expect(win.right, lessThanOrEqualTo(800));
      expect(win.bottom, lessThanOrEqualTo(600));
    });
  });
}
