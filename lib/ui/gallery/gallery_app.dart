import 'package:flutter/widgets.dart';

import '../ui.dart';
import 'gallery_demo.dart';
import 'gallery_demos.dart';
import 'gallery_host.dart';

/// The widget gallery (database shell spec 5.3): every library widget on
/// synthetic data, picked from a list, with knobs. This phase 1 host is made
/// of moved controls and the existing list; phase 2 rebuilds it on AppFrame.
final class GalleryApp extends StatelessWidget {
  const GalleryApp({
    this.demos,
    this.initialKnobs = const GalleryKnobs(),
    super.key,
  });

  /// The demos to list; every library demo when null.
  final List<GalleryDemo>? demos;
  final GalleryKnobs initialKnobs;

  @override
  Widget build(BuildContext context) => GalleryHost(
    home: GalleryHome(demos: demos ?? galleryDemos, initialKnobs: initialKnobs),
  );
}

final class GalleryHome extends StatefulWidget {
  const GalleryHome({
    required this.demos,
    required this.initialKnobs,
    super.key,
  });

  final List<GalleryDemo> demos;
  final GalleryKnobs initialKnobs;

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

final class _GalleryHomeState extends State<GalleryHome> {
  static const _folders = {
    'foundation': 'Foundation',
    'controls': 'Controls',
    'data': 'Data',
    'shell': 'Shell',
  };

  late GalleryDemo _demo = widget.demos.first;
  late GalleryKnobs _knobs = widget.initialKnobs;

  void _knob(GalleryKnobs knobs) => setState(() => _knobs = knobs);

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return ColoredBox(
      color: skin.tokens.ground,
      child: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_knobs.textScale)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DataRegister<GalleryDemo>(
                  label: 'Widgets',
                  lines: [
                    for (final MapEntry(key: folder, value: title)
                        in _folders.entries)
                      if (widget.demos.where((d) => d.folder == folder)
                          case final demos when demos.isNotEmpty) ...[
                        GroupLine<GalleryDemo>(
                          label: '$title (${demos.length})',
                        ),
                        for (final demo in demos) RowLine<GalleryDemo>(demo),
                      ],
                  ],
                  columns: [
                    RegisterColumn<GalleryDemo>(
                      key: 'widget',
                      label: 'Widget',
                      kind: ColumnKind.text,
                      width: 180,
                      value: (demo) => demo.widget,
                    ),
                    RegisterColumn<GalleryDemo>(
                      key: 'folder',
                      label: 'Folder',
                      kind: ColumnKind.text,
                      width: 80,
                      value: (demo) => demo.folder,
                    ),
                  ],
                  rowId: (demo) => demo.id,
                  rowLabel: (demo) => demo.widget,
                  selectedId: _demo.id,
                  onOpen: (demo) => setState(() => _demo = demo),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                    child: Text(_demo.widget, style: skin.typography.caption),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(_demo.summary, style: skin.typography.body),
                  ),
                  Expanded(
                    child: GalleryCanvas(
                      key: ValueKey(_demo.id),
                      demo: _demo,
                      knobs: _knobs,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 220,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: GroupBox(
                  legend: 'Knobs',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EraCheckBox(
                        value: _knobs.enabled,
                        onChanged: (on) => _knob(_knobs.copyWith(enabled: on)),
                        label: 'Enabled',
                      ),
                      EraCheckBox(
                        value: _knobs.error,
                        onChanged: (on) => _knob(_knobs.copyWith(error: on)),
                        label: 'Show an error',
                      ),
                      EraCheckBox(
                        value: _knobs.longText,
                        onChanged: (on) => _knob(_knobs.copyWith(longText: on)),
                        label: 'Long text',
                      ),
                      EraCheckBox(
                        value: _knobs.textScale == 2,
                        onChanged: (on) =>
                            _knob(_knobs.copyWith(textScale: on ? 2 : 1)),
                        label: '200 % text',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
