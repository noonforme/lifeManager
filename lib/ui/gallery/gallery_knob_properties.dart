import '../ui.dart';
import 'gallery_demo.dart';

/// The record the gallery's property grid edits: the knobs.
const galleryKnobRecord = 'gallery:knobs';

/// The text sizes the Text size knob offers.
const galleryTextSizes = [
  EraComboItem<Object?>(1.0, '100 %'),
  EraComboItem<Object?>(2.0, '200 %'),
];

/// The knobs as property rows (database shell spec 5.3), in the order
/// Enter and Tab walk them.
List<PropertyItem> galleryKnobItems(GalleryKnobs knobs) => [
  PropertyItem(
    key: 'enabled',
    label: 'Enabled',
    category: 'State',
    kind: ValueKind.check,
    value: knobs.enabled,
    description:
        'No greys and locks the demo, as a read-only sheet shows its '
        'values; its keys do nothing.',
  ),
  PropertyItem(
    key: 'error',
    label: 'Show an error',
    category: 'State',
    kind: ValueKind.check,
    value: knobs.error,
    description: "Shows the demo's validation message.",
  ),
  PropertyItem(
    key: 'longText',
    label: 'Long text',
    category: 'Sample data',
    kind: ValueKind.check,
    value: knobs.longText,
    description: 'Swaps labels and values for long ones, to see wrapping.',
  ),
  PropertyItem(
    key: 'textScale',
    label: 'Text size',
    category: 'Sizes',
    kind: ValueKind.choice,
    value: knobs.textScale,
    choices: galleryTextSizes,
    description:
        'Scales the text of the gallery and the demo, as the system text '
        'size does.',
  ),
];

/// [knobs] with knob [key] set to [value], as the property grid commits it.
GalleryKnobs applyGalleryKnob(GalleryKnobs knobs, String key, Object? value) =>
    switch ((key, value)) {
      ('enabled', final bool on) => knobs.copyWith(enabled: on),
      ('error', final bool on) => knobs.copyWith(error: on),
      ('longText', final bool on) => knobs.copyWith(longText: on),
      ('textScale', final double scale) => knobs.copyWith(textScale: scale),
      _ => throw ArgumentError.value(value, key, 'Not a gallery knob value'),
    };

/// The knobs the demo shows: [knobs] with the open knob's draft applied, so
/// a tick or a pick shows at once; Enter keeps it and Esc drops it.
GalleryKnobs previewGalleryKnobs(GalleryKnobs knobs, EditSession? session) {
  if (session == null ||
      session.id.record != galleryKnobRecord ||
      !session.changed) {
    return knobs;
  }
  return applyGalleryKnob(knobs, session.id.field, session.draft);
}
