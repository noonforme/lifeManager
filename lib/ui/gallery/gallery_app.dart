import 'package:flutter/widgets.dart';

import '../ui.dart';
import 'gallery_demo.dart';
import 'gallery_demos.dart';
import 'gallery_host.dart';
import 'gallery_knob_properties.dart';

/// The widget gallery (database shell spec 5.3): every library widget on
/// synthetic data in the library's own shell. The tree lists the widgets by
/// folder, the middle shows the live demo over its summary, and the
/// property grid edits the demo's knobs.
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
  static const _area = 'widgets';
  static const _summaryTab = 'summary';

  final _controller = EditorSessionController();
  final _frame = GlobalKey<AppFrameState>();

  late GalleryDemo _demo = widget.demos.first;
  late GalleryKnobs _knobs = widget.initialKnobs;
  AppFramePanes _panes = AppFramePanes.baseline;
  String? _lowerTab = _summaryTab;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the demo [id] names; a folder node names none. An open knob
  /// draft is kept first, as any command that leaves the field does.
  void _open(String id) {
    final demo = widget.demos.where((demo) => demo.id == id).firstOrNull;
    if (demo == null) return;
    if (!_controller.flush().isAccepted) return;
    _frame.currentState?.closeTree();
    if (demo.id != _demo.id) setState(() => _demo = demo);
  }

  EditResult _commit(EditIdentity id, Object? draft) {
    setState(() => _knobs = applyGalleryKnob(_knobs, id.field, draft));
    return const EditResult.accepted();
  }

  void _reset() {
    _controller.cancel();
    setState(() => _knobs = widget.initialKnobs);
  }

  List<TreeNodeData> _nodes() => [
    for (final MapEntry(key: folder, value: title) in _folders.entries)
      if (widget.demos.where((demo) => demo.folder == folder).toList()
          case final demos when demos.isNotEmpty)
        TreeNodeData(
          id: 'folder:$folder',
          label: title,
          count: demos.length,
          bold: true,
          expanded: true,
          children: [
            for (final demo in demos)
              TreeNodeData(id: demo.id, label: demo.widget),
          ],
        ),
  ];

  Widget _details() => DetailsBox(
    caption: 'Details',
    sections: [
      DetailsSection(
        facts: [
          DetailsFact('Widget', _demo.widget, figure: false),
          DetailsFact('Folder', _demo.folder, figure: false),
          DetailsFact('Gallery id', _demo.id, figure: false),
          DetailsFact(
            'Golden',
            'test/ui/goldens/${_demo.goldenName}.png',
            figure: false,
          ),
          DetailsFact(
            'Canvas',
            '${_demo.size.width.round()} x ${_demo.size.height.round()} px',
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final shown = previewGalleryKnobs(_knobs, _controller.session);
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(shown.textScale)),
        child: AppFrame(
          key: _frame,
          controller: _controller,
          toolbarBuilder: (context, tree) => BandedToolbar(
            bands: [
              if (tree != null) ToolbarBand(items: [tree]),
              ToolbarBand(
                items: [ToolbarItem(label: 'Reset knobs', onPressed: _reset)],
              ),
            ],
          ),
          areas: const [
            TabItem(id: _area, label: 'Widgets', icon: EraIconKind.app),
          ],
          areaId: _area,
          onAreaSelect: (_) {},
          treeTitle: 'Widgets',
          treeIcon: EraIconKind.app,
          tree: TreeView(
            label: 'Widgets by folder',
            nodes: _nodes(),
            selectedId: _demo.id,
            onSelect: _open,
          ),
          details: _details(),
          middle: GalleryCanvas(
            key: ValueKey(_demo.id),
            demo: _demo,
            knobs: shown,
          ),
          subformTabs: [
            SubformTab(
              id: _summaryTab,
              label: 'Summary',
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: Text(_demo.summary),
              ),
            ),
          ],
          subformSelectedId: _lowerTab,
          onSubformSelect: (id) => setState(() => _lowerTab = id),
          subformLabel: _demo.widget,
          properties: PropertyGrid(
            record: galleryKnobRecord,
            controller: _controller,
            items: galleryKnobItems(_knobs),
            onCommit: _commit,
            today: galleryToday,
            label: 'Knobs',
          ),
          propertiesLabel: 'Knobs',
          status: StatusBar(
            notice: 'Synthetic data only; no database is open.',
            panels: [
              StatusPanel('${widget.demos.length} widgets'),
              StatusPanel(_demo.id),
              StatusPanel('Text ${(shown.textScale * 100).round()} %'),
            ],
          ),
          panes: _panes,
          onPanesChanged: (panes) => setState(() => _panes = panes),
        ),
      );
    },
  );
}
