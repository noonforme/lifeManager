import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';

/// The date the gallery treats as today: fixed, so goldens hold.
const galleryToday = LocalDate(2026, 10, 8);

/// The gallery's knobs: what the owner can vary on a demo.
@immutable
final class GalleryKnobs {
  const GalleryKnobs({
    this.enabled = true,
    this.error = false,
    this.longText = false,
    this.textScale = 1,
  });

  final bool enabled;
  final bool error;
  final bool longText;
  final double textScale;

  /// [long] while the Long text knob is on, otherwise [short].
  String text(String short, String long) => longText ? long : short;

  /// A validation message while the error knob is on.
  String? get errorText => error ? 'Enter a valid value.' : null;

  /// [action], or null so the key greys while the Enabled knob is off.
  VoidCallback? press(VoidCallback action) => enabled ? action : null;

  GalleryKnobs copyWith({
    bool? enabled,
    bool? error,
    bool? longText,
    double? textScale,
  }) => GalleryKnobs(
    enabled: enabled ?? this.enabled,
    error: error ?? this.error,
    longText: longText ?? this.longText,
    textScale: textScale ?? this.textScale,
  );
}

/// One library widget's demo (database shell spec 5.3). [id] is
/// `<folder>/<name>`; the folder is the widget's folder under `lib/ui/`.
@immutable
final class GalleryDemo {
  const GalleryDemo({
    required this.id,
    required this.widget,
    required this.summary,
    required this.build,
    this.size = const Size(480, 240),
  });

  final String id;

  /// The widget class the demo shows, as named in CATALOG.md.
  final String widget;
  final String summary;
  final Widget Function(BuildContext context, GalleryKnobs knobs) build;

  /// The canvas size of the demo's goldens.
  final Size size;

  String get folder => id.split('/').first;

  /// The golden's file name without extension: "controls_key_button".
  String get goldenName => id.replaceAll('/', '_');
}

/// Holds one demo value, so a demo's control can change it.
final class GalleryValue<T> extends StatefulWidget {
  const GalleryValue({required this.initial, required this.builder, super.key});

  final T initial;
  final Widget Function(BuildContext context, T value, ValueChanged<T> update)
  builder;

  @override
  State<GalleryValue<T>> createState() => _GalleryValueState<T>();
}

final class _GalleryValueState<T> extends State<GalleryValue<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _value,
    (value) => setState(() => _value = value),
  );
}
