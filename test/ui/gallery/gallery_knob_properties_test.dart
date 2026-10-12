import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/ui/gallery/gallery_demo.dart';
import 'package:lifeos/ui/gallery/gallery_knob_properties.dart';
import 'package:lifeos/ui/ui.dart';

void main() {
  test('every knob is a property row, in traversal order', () {
    const knobs = GalleryKnobs(enabled: false, longText: true, textScale: 2);
    final items = galleryKnobItems(knobs);
    expect(items.map((item) => item.key), [
      'enabled',
      'error',
      'longText',
      'textScale',
    ]);
    expect(items.map((item) => item.category), [
      'State',
      'State',
      'Sample data',
      'Sizes',
    ]);
    expect(items.map((item) => item.value), [false, false, true, 2.0]);
    expect(items.last.kind, ValueKind.choice);
    expect(items.last.choices.map((choice) => choice.label), [
      '100 %',
      '200 %',
    ]);
    expect(items.every((item) => item.editable), isTrue);
    expect(items.every((item) => item.description != null), isTrue);
  });

  test('a committed value changes only its own knob', () {
    const knobs = GalleryKnobs();
    expect(applyGalleryKnob(knobs, 'enabled', false).enabled, isFalse);
    expect(applyGalleryKnob(knobs, 'error', true).error, isTrue);
    expect(applyGalleryKnob(knobs, 'longText', true).longText, isTrue);
    final scaled = applyGalleryKnob(knobs, 'textScale', 2.0);
    expect(scaled.textScale, 2);
    expect(
      (scaled.enabled, scaled.error, scaled.longText),
      (true, false, false),
    );
  });

  test('an unknown knob or a wrong value type is a programming error', () {
    expect(
      () => applyGalleryKnob(const GalleryKnobs(), 'colour', true),
      throwsArgumentError,
    );
    expect(
      () => applyGalleryKnob(const GalleryKnobs(), 'enabled', 'yes'),
      throwsArgumentError,
    );
  });

  test("the open knob's draft is previewed; other records are not", () {
    final controller = EditorSessionController();
    addTearDown(controller.dispose);
    const knobs = GalleryKnobs();
    expect(previewGalleryKnobs(knobs, controller.session), same(knobs));

    const id = EditIdentity(record: galleryKnobRecord, field: 'error');
    controller.begin(
      EditField(
        id: id,
        kind: ValueKind.check,
        value: false,
        commit: (_, _) => const EditResult.accepted(),
      ),
    );
    controller.update(id, true);
    expect(previewGalleryKnobs(knobs, controller.session).error, isTrue);
    controller.cancel();
    expect(previewGalleryKnobs(knobs, controller.session).error, isFalse);

    const other = EditIdentity(record: 'shift:7', field: 'error');
    controller.begin(
      EditField(
        id: other,
        kind: ValueKind.check,
        value: false,
        commit: (_, _) => const EditResult.accepted(),
      ),
    );
    controller.update(other, true);
    expect(previewGalleryKnobs(knobs, controller.session), same(knobs));
  });
}
