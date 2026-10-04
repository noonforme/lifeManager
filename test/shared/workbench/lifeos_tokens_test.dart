import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';
import 'package:lifeos/shared/workbench/millennium_style.dart';

void main() {
  const t = LifeOSTokens.millennium;

  test('contrast ratio matches the WCAG reference values', () {
    expect(
      contrastRatio(const Color(0xff000000), const Color(0xffffffff)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xff777777), const Color(0xffffffff)),
      closeTo(4.48, 0.01),
    );
  });

  // Selected rows draw every cell in selInk, so muted, run, negative and
  // positive text never sits on the saturated selWash.
  final text = <String, (Color, List<Color>)>{
    'ink': (
      t.ink,
      [
        t.paper,
        t.band,
        t.chrome,
        MillenniumColors.paneBody,
        MillenniumColors.page,
      ],
    ),
    'muted': (t.muted, [t.paper, t.band, t.chrome, MillenniumColors.paneBody]),
    'runInk': (t.runInk, [t.paper, t.band, t.chrome]),
    'negative': (t.negative, [t.paper, t.band, t.chrome]),
    'positive': (t.positive, [t.paper, t.band, t.chrome]),
    'selInk': (t.selInk, [t.selWash]),
    'headInk': (t.headInk, [t.head, MillenniumColors.captionBottom]),
    'head as text': (t.head, [t.paper, MillenniumColors.page]),
    'link': (MillenniumColors.link, [MillenniumColors.paneBody, t.paper]),
  };
  for (final MapEntry(key: name, value: (ink, surfaces)) in text.entries) {
    test('$name text meets 4.5:1', () {
      for (final surface in surfaces) {
        expect(
          contrastRatio(ink, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name on $surface',
        );
      }
    });
  }

  test('area key letters meet 4.5:1 on their keys', () {
    expect(t.areaKeys.keys, unorderedEquals(LifeOSArea.values));
    for (final key in t.areaKeys.values) {
      expect(contrastRatio(key.ink, key.fill), greaterThanOrEqualTo(4.5));
    }
  });

  test('indicators and outlines meet 3:1', () {
    for (final (name, color, surface) in [
      ('signal', t.signal, t.paper),
      ('signal on face', t.signal, t.chrome),
      ('focus', t.focus, t.paper),
      ('focus on face', t.focus, t.chrome),
      ('key outline', MillenniumColors.keyLine, t.chrome),
      ('key outline on white', MillenniumColors.keyLine, t.paper),
      ('progress', MillenniumColors.progress, t.ink),
    ]) {
      expect(
        contrastRatio(color, surface),
        greaterThanOrEqualTo(3),
        reason: name,
      );
    }
  });

  test('caption titles read on their caption, active and inactive', () {
    expect(contrastRatio(t.headInk, t.head), greaterThanOrEqualTo(4.5));
    expect(
      contrastRatio(t.headInk, MillenniumColors.inactiveCaption),
      greaterThanOrEqualTo(4.5),
    );
  });
}
