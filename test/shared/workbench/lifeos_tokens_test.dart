import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/shared/workbench/lifeos_tokens.dart';

void main() {
  const palettes = {
    'day': LifeOSTokens.day,
    'night': LifeOSTokens.night,
    'high contrast': LifeOSTokens.highContrast,
  };

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

  for (final MapEntry(key: name, value: t) in palettes.entries) {
    group('$name palette', () {
      // Every text token is checked on each surface it can sit on.
      final textOnSurfaces = <String, (Color, List<Color>)>{
        'ink': (t.ink, [t.paper, t.band, t.chrome]),
        'muted': (t.muted, [t.paper, t.band, t.chrome, t.selWash]),
        'runInk': (t.runInk, [t.paper, t.band, t.selWash]),
        'negative': (t.negative, [t.paper, t.band, t.chrome, t.selWash]),
        'positive': (t.positive, [t.paper, t.band, t.chrome, t.selWash]),
        'selInk': (t.selInk, [t.selWash]),
        'actionInk': (t.actionInk, [t.actionFill]),
        'headInk': (t.headInk, [t.head]),
      };

      for (final MapEntry(key: token, value: (ink, surfaces))
          in textOnSurfaces.entries) {
        test('$token text meets 4.5:1', () {
          for (final surface in surfaces) {
            expect(
              contrastRatio(ink, surface),
              greaterThanOrEqualTo(4.5),
              reason: '$token on ${_hex(surface)}',
            );
          }
        });
      }

      test('area key letters meet 4.5:1 on their keys', () {
        expect(t.areaKeys.keys, unorderedEquals(LifeOSArea.values));
        for (final MapEntry(key: area, value: key) in t.areaKeys.entries) {
          expect(
            contrastRatio(key.ink, key.fill),
            greaterThanOrEqualTo(4.5),
            reason: area.label,
          );
        }
      });

      // chromeLine only divides panes; control outlines use muted, so they
      // are held to the 3:1 non-text minimum here.
      test('indicators and control outlines meet 3:1', () {
        // signal sits on paper (selection, bars) and on the status line.
        for (final MapEntry(key: token, value: (color, surfaces)) in {
          'signal': (t.signal, [t.paper, t.head]),
          'focus': (t.focus, [t.paper, t.chrome]),
          'muted outline': (t.muted, [t.paper, t.chrome]),
        }.entries) {
          for (final surface in surfaces) {
            expect(
              contrastRatio(color, surface),
              greaterThanOrEqualTo(3),
              reason: '$token on ${_hex(surface)}',
            );
          }
        }
      });
    });
  }
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
