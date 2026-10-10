import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  testWidgets('orbs are decorative and sized as asked', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Orb(glyph: OrbGlyph.back, tone: OrbTone.green, size: 20),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Orb)), const Size(20, 20));
    final semantics = tester.getSemantics(find.byType(Orb));
    expect(semantics.label, isEmpty);
  });
  testWidgets('step glyphs paint at their size and stay silent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: EraGlyph(EraGlyphKind.stepBack, color: Color(0xff000000)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(EraGlyph)), const Size(9, 9));
    expect(tester.getSemantics(find.byType(EraGlyph)).label, isEmpty);
  });
  testWidgets('a group box announces its legend and shows its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scoped(const GroupBox(legend: 'Shift', child: Text('Date'))),
    );
    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.bySemanticsLabel('Shift'), findsOneWidget);
  });

  testWidgets('a combo face shows its value and a drop arrow', (tester) async {
    await tester.pumpWidget(_scoped(const EraComboFace(value: 'Shifts')));
    expect(find.text('Shifts'), findsOneWidget);
    expect(
      tester.getSize(find.byType(EraComboFace)).height,
      greaterThanOrEqualTo(24),
    );
  });

  testWidgets('a form footer keeps its keys at the right edge', (tester) async {
    await tester.pumpWidget(
      _scoped(
        SizedBox(
          width: 300,
          child: FormFooter(
            children: [KeyButton(label: 'Save', onPressed: () {})],
          ),
        ),
      ),
    );
    expect(
      tester.getTopRight(find.byKey(const ValueKey('key-face'))).dx,
      closeTo(300, 1),
    );
  });

  testWidgets('era glyphs are painted, never font characters', (tester) async {
    await tester.pumpWidget(
      _scoped(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in EraGlyphKind.values)
              EraGlyph(kind, color: const Color(0xff000000)),
          ],
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(EraGlyph), findsNWidgets(EraGlyphKind.values.length));
  });

  test('lib uses no character the bundled Noto Sans lacks', () {
    // Noto Sans has no ▴ ▾ ︽ ︾ ✓; they render as empty boxes.
    const missing = ['\u25B4', '\u25BE', '\uFE3D', '\uFE3E', '\u2713'];
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (index, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') && missing.any(line.contains))
              '${file.path}:${index + 1}',
    ];
    expect(offenders, isEmpty);
  });

  testWidgets('a caption close key is a focusable button', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      _scoped(
        SizedBox(
          width: 300,
          child: CaptionBar(title: 'Needs you', onClose: () => closed++),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Close Needs you')),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Close Needs you'));
    expect(closed, 1);
  });
}

Widget _scoped(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: LifeOSSkinScope(
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);
