import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  test('everything is EraSans at 11 px, falling back to Noto Sans', () {
    const type = lifeOSTypography;
    for (final style in [
      type.body,
      type.strong,
      type.label,
      type.small,
      type.figure,
    ]) {
      expect(style.fontFamily, 'EraSans');
      expect(style.fontSize, 11);
      expect(style.fontFamilyFallback, ['NotoSans']);
    }
    expect(type.caption.fontSize, 13);
    expect(type.caption.fontWeight, FontWeight.w700);
    expect(type.strong.fontWeight, FontWeight.w700);
    expect(type.counter.fontSize, 18);
  });

  test('no style joins letters into ligatures, as Tahoma never did', () {
    const type = lifeOSTypography;
    for (final style in [
      type.caption,
      type.strong,
      type.label,
      type.body,
      type.small,
      type.figure,
      type.counter,
    ]) {
      expect(style.fontFeatures, contains(const FontFeature.disable('liga')));
    }
  });
}
