import 'dart:math' as math;

import 'package:flutter/material.dart' show TextButton;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/editor_session_controller.dart';
import '../controls/era_menu.dart';
import '../controls/era_scrollbar.dart';
import '../controls/keys.dart';
import '../data/subform.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';
import 'banded_toolbar.dart';
import 'pane_caption.dart';
import 'splitter.dart';
import 'tab_strip.dart';

/// One title of the [AppFrame]'s menu bar and the rows it drops.
@immutable
final class AppMenu {
  const AppMenu(this.label, this.items);

  final String label;
  final List<EraMenuItem> items;
}

/// The owner's remembered pane sizes of one area (database shell spec 3),
/// in **baseline logical pixels at 100 % text**: the tree column, the
/// property column and the subform (or docked properties) height.
///
/// The frame multiplies them by the text scale exactly once to lay out, and
/// divides a dragged size by it before reporting, so a size dragged at
/// 200 % restores the same layout at 200 % and its half at 100 %. The frame
/// never stores or rewrites them: a size that does not fit is clamped to the
/// space actually there for as long as it does not fit, and the owner's
/// value comes back when the window grows again.
@immutable
final class AppFramePanes {
  const AppFramePanes({this.left = 196, this.right = 306, this.dock = 168});

  /// The spec's 1280 x 800 layout: 196, 306 and 168.
  static const baseline = AppFramePanes();

  /// The tree column's width.
  final double left;

  /// The property column's width.
  final double right;

  /// The height of the region under the grid: subform tabs, and the
  /// Properties tab while the property column is docked.
  final double dock;

  AppFramePanes copyWith({double? left, double? right, double? dock}) =>
      AppFramePanes(
        left: left ?? this.left,
        right: right ?? this.right,
        dock: dock ?? this.dock,
      );

  @override
  bool operator ==(Object other) =>
      other is AppFramePanes &&
      other.left == left &&
      other.right == right &&
      other.dock == dock;

  @override
  int get hashCode => Object.hash(left, right, dock);

  @override
  String toString() => 'AppFramePanes(left: $left, right: $right, dock: $dock)';
}

/// How an [AppFrame] of a given client width lays out its columns (spec 3,
/// "Narrow windows"). Pure: [AppFrameLayout.resolve] is what the frame
/// itself uses.
@immutable
final class AppFrameLayout {
  const AppFrameLayout._({
    required this.scale,
    required this.treeFolded,
    required this.propertiesDocked,
    required this.left,
    required this.leftMax,
    required this.right,
    required this.rightMax,
    required this.flyoutWidth,
  });

  /// Decides folding and docking for a frame [width] pixels wide (the
  /// client width, before the page's own padding) at text [scale], and
  /// clamps the owner's [panes] (baseline sizes) to the room left.
  ///
  /// The tree folds below [AppFrame.foldWidth], and also whenever the scaled
  /// minimum widths of three columns do not fit; the property column then
  /// narrows to at most [AppFrame.narrowRight] (scaled). The properties dock
  /// below [AppFrame.dockWidth], or whenever the scaled minima of grid and
  /// property column do not fit side by side.
  factory AppFrameLayout.resolve({
    required double width,
    required double scale,
    AppFramePanes panes = AppFramePanes.baseline,
  }) {
    const split = Splitter.thickness;
    final s = scale;
    // The page's own vertical scrollbar, shown when a short window scrolls
    // it, comes out of this width: minima and clamps leave room for it.
    final inner = math.max(
      0.0,
      width - 2 * AppFrame.pagePadding - EraScrollbar.thickness,
    );
    final minLeft = AppFrame.minLeft * s;
    final minMiddle = AppFrame.minMiddle * s;
    final minRight = AppFrame.minRight * s;
    final folded =
        width < AppFrame.foldWidth ||
        minLeft + minMiddle + minRight + 2 * split > inner;
    final docked =
        width < AppFrame.dockWidth || minMiddle + minRight + split > inner;
    var right = 0.0;
    var rightMax = 0.0;
    if (!docked) {
      final others = minMiddle + split + (folded ? 0 : minLeft + split);
      rightMax = math.max(minRight, inner - others);
      if (folded) rightMax = math.min(rightMax, AppFrame.narrowRight * s);
      rightMax = math.max(minRight, rightMax);
      right = _size(
        panes.right,
        AppFramePanes.baseline.right,
        s,
      ).clamp(minRight, rightMax).toDouble();
    }
    var left = 0.0;
    var leftMax = 0.0;
    if (!folded) {
      leftMax = math.max(minLeft, inner - minMiddle - 2 * split - right);
      left = _size(
        panes.left,
        AppFramePanes.baseline.left,
        s,
      ).clamp(minLeft, leftMax).toDouble();
    }
    final flyoutWidth = math.min(
      _size(
        panes.left,
        AppFramePanes.baseline.left,
        s,
      ).clamp(minLeft, math.max(minLeft, inner)).toDouble(),
      inner,
    );
    return AppFrameLayout._(
      scale: s,
      treeFolded: folded,
      propertiesDocked: docked,
      left: left,
      leftMax: leftMax,
      right: right,
      rightMax: rightMax,
      flyoutWidth: flyoutWidth,
    );
  }

  /// The text scale the sizes were multiplied by.
  final double scale;

  /// The tree column is folded into the toolbar's Tree key.
  final bool treeFolded;

  /// The property column is a tab beside the subform tabs.
  final bool propertiesDocked;

  /// The tree column's laid-out width in pixels; 0 while folded.
  final double left;

  /// The most the tree column may be dragged to; 0 while folded.
  final double leftMax;

  /// The property column's laid-out width in pixels; 0 while docked.
  final double right;

  /// The most the property column may be dragged to; 0 while docked.
  final double rightMax;

  /// The width of the folded tree's overlay.
  final double flyoutWidth;

  /// The least height in which the page's panes stay usable; below it the
  /// page scrolls rather than squeezing them. [strip] is the measured
  /// height of the subform's tab strip (long labels wrap onto rows).
  double pageMinHeight({required bool lower, double strip = 0}) {
    final s = scale;
    var middle = AppFrame.minGrid * s;
    if (lower || propertiesDocked) {
      middle += Splitter.thickness + _lowerLeast(strip);
    }
    return math.max(
          middle,
          math.max(
            treeFolded ? 0.0 : AppFrame.minPaneHeight * s,
            propertiesDocked ? 0.0 : AppFrame.minPropertiesHeight * s,
          ),
        ) +
        2 * AppFrame.pagePadding;
  }

  /// The lower region's height in a middle column [height] pixels high,
  /// with its least and most values for the splitter: at least its tab
  /// [strip] and a few rows under it, at most what leaves the grid its
  /// minimum.
  (double, double, double) lowerHeight(
    double height,
    AppFramePanes panes, {
    double strip = 0,
  }) {
    final least = _lowerLeast(strip);
    final most = math.max(
      least,
      height - Splitter.thickness - AppFrame.minGrid * scale,
    );
    final value = _size(
      panes.dock,
      AppFramePanes.baseline.dock,
      scale,
    ).clamp(least, most).toDouble();
    return (value, least, most);
  }

  double _lowerLeast(double strip) =>
      strip + (propertiesDocked ? AppFrame.minDock : AppFrame.minLower) * scale;

  /// A baseline size in pixels at [scale]; a missing (NaN) size is the
  /// baseline's. Infinite and negative sizes are left to the clamp.
  static double _size(double value, double fallback, double scale) =>
      (value.isNaN ? fallback : value) * scale;

  @override
  bool operator ==(Object other) =>
      other is AppFrameLayout &&
      other.scale == scale &&
      other.treeFolded == treeFolded &&
      other.propertiesDocked == propertiesDocked &&
      other.left == left &&
      other.leftMax == leftMax &&
      other.right == right &&
      other.rightMax == rightMax &&
      other.flyoutWidth == flyoutWidth;

  @override
  int get hashCode => Object.hash(
    scale,
    treeFolded,
    propertiesDocked,
    left,
    leftMax,
    right,
    rightMax,
    flyoutWidth,
  );
}

/// The database shell's window (spec 3): menu bar, banded toolbar, area
/// tabs, a three-column page (tree and Details, the grid over its subform,
/// the property column) split by 5 px splitters, and the status bar.
///
/// **One instance of each pane.** The frame moves, never copies, the
/// owner's panes. Below [foldWidth] (or when the scaled minima of three
/// columns do not fit) the tree column folds into a **Tree** key that
/// [toolbarBuilder] receives and places in a band; the key opens the same
/// tree and Details in a bounded overlay hanging from it, closed by its
/// Close key or a click outside. Below [dockWidth] (or when grid and
/// property column do not fit side by side) [properties] becomes a tab
/// beside [subformTabs], sharing the resizable lower region. The tree pane,
/// [middle], the lower region and [properties] each keep one element under
/// a frame-owned global key, so their state (scroll positions, a mounted
/// editor and its focus, an action panel's input) moves with them. While
/// folded and closed, or docked and never shown, a pane is parked
/// off-stage: kept, not painted, not hit and not focusable. Moving a pane
/// never flushes or cancels the editor.
///
/// **Sizes are the owner's.** [panes] are baseline sizes of the current
/// area; the frame scales them once, clamps them to the room actually left
/// after chrome, splitters and the panes' minima, and reports each drag in
/// baseline pixels to [onPanesChanged] (and [onPanesChangeEnd] on release)
/// without keeping a local copy. Supplying another area's [panes] restores
/// that area's layout.
///
/// **Reveal.** When the window narrows while the property column is the
/// active region (last clicked, or holding focus), the frame shows the
/// Properties tab at once and asks the owner, through [onSubformSelect], to
/// select it; when it widens again with that tab selected, it asks for the
/// child tab shown before. These requests do not flush the editor. The
/// owner's later [subformSelectedId] always wins.
///
/// **Chrome never takes the page.** The menu bar, toolbar and area tabs
/// scroll within a bounded top region and the page scrolls below its
/// minimum height, so at 800 x 600 and 200 % text every command, editor,
/// error and footer stays reachable; nothing is shrunk or clipped.
///
/// **Mouse only.** Menus, area tabs, the Tree key and splitters take no
/// focus. A menu row or an area tab first flushes [controller]; a refused
/// draft keeps the editor and the request is dropped. Subform tabs flush
/// it too ([Subform]). Toolbar callbacks are the owner's, who flushes first.
final class AppFrame extends StatefulWidget {
  const AppFrame({
    required this.toolbarBuilder,
    required this.areas,
    required this.areaId,
    required this.onAreaSelect,
    required this.tree,
    required this.details,
    required this.middle,
    required this.properties,
    required this.panes,
    required this.onPanesChanged,
    this.menus = const [],
    this.treeTitle = 'Objects',
    this.treeIcon = EraIconKind.work,
    this.subformTabs = const [],
    this.subformSelectedId,
    this.onSubformSelect,
    this.subformTrailing,
    this.subformLabel,
    this.propertiesLabel = 'Properties',
    this.status,
    this.onPanesChangeEnd,
    this.controller,
    this.enabled = true,
    super.key,
  });

  /// The client width below which the tree column folds into the toolbar.
  static const foldWidth = 1024.0;

  /// The client width below which the property column docks as a tab.
  static const dockWidth = 860.0;

  /// The property column's widest size while the tree is folded (baseline).
  static const narrowRight = 260.0;

  /// Baseline minima of the panes, multiplied by the text scale. The grid's
  /// height leaves its header, group, footer, navigator and horizontal
  /// scrollbar two rows at any scale (the 17 px scrollbar does not scale).
  static const minLeft = 140.0;
  static const minMiddle = 320.0;
  static const minRight = 220.0;
  static const minGrid = 140.0;

  /// Under the subform's measured tab strip: a few child rows, or the
  /// docked property grid's toolbar, rows and description (an action
  /// panel's title, fields and pinned keys), which scroll inside.
  static const minLower = 66.0;
  static const minDock = 130.0;
  static const minPaneHeight = 160.0;
  static const minPropertiesHeight = 200.0;

  /// The page's inset inside the client area.
  static const pagePadding = 2.0;

  /// The id of the docked Properties tab among the subform tabs.
  static const propertiesTabId = 'app-frame:properties';

  /// The menu bar's titles; rows flush [controller] before they run.
  final List<AppMenu> menus;

  /// Builds the banded toolbar. `treeAction` is the Tree key while the tree
  /// is folded, and null otherwise: put it in a band, as the first key.
  final Widget Function(BuildContext context, ToolbarItem? treeAction)
  toolbarBuilder;

  /// The area tabs, selected by [areaId]; a request flushes first.
  final List<TabItem> areas;
  final String? areaId;
  final ValueChanged<String> onAreaSelect;

  /// The tree pane's caption, and the Tree key's icon.
  final String treeTitle;
  final EraIconKind treeIcon;

  /// The object tree (`TreeView`): its height is capped, so the [details]
  /// under it stay in view.
  final Widget tree;

  /// The Details box (`DetailsBox`) under the tree.
  final Widget details;

  /// The middle column's content over the subform: the data grid, or the
  /// calendar sheet. Needs no size of its own.
  final Widget middle;

  /// The selected record's children tabs. The frame appends the Properties
  /// tab ([propertiesTabId]) while docked.
  final List<SubformTab> subformTabs;
  final String? subformSelectedId;

  /// A subform tab request: after the shared [controller] accepted its
  /// flush for a click, and without a flush for the frame's reveal requests.
  final ValueChanged<String>? onSubformSelect;
  final Widget? subformTrailing;
  final String? subformLabel;

  /// The property column: the property grid, or an action panel in its
  /// place. One instance, shown in the column or in the docked tab.
  final Widget properties;

  /// The docked Properties tab's label (an action's name while it runs).
  final String propertiesLabel;

  /// The status bar (`StatusBar`); it caps its own height.
  final Widget? status;

  /// The current area's remembered sizes, in baseline pixels.
  final AppFramePanes panes;

  /// A drag's new sizes, in baseline pixels, on every move.
  final ValueChanged<AppFramePanes> onPanesChanged;

  /// The sizes when a drag ends, to persist.
  final ValueChanged<AppFramePanes>? onPanesChangeEnd;

  /// The editor session shared by the panes, flushed before area, menu and
  /// subform tab requests.
  final EditorSessionController? controller;

  /// False greys the Tree key, menus and area tabs and stops the splitters.
  final bool enabled;

  @override
  State<AppFrame> createState() => AppFrameState();
}

enum _Region { tree, middle, lower, properties }

enum _Slot { strip, top, page, status, overlay, parkTree, parkProperties }

/// Where the one property pane is mounted this frame.
enum _Place { column, dock, parked }

/// The frame's state: open or close the folded tree from outside with a
/// `GlobalKey<AppFrameState>`.
final class AppFrameState extends State<AppFrame> {
  final _treeKey = GlobalKey(debugLabel: 'AppFrame tree pane');
  final _middleKey = GlobalKey(debugLabel: 'AppFrame middle');
  final _lowerKey = GlobalKey(debugLabel: 'AppFrame lower region');
  final _propertiesKey = GlobalKey(debugLabel: 'AppFrame properties');
  final _treeAnchor = GlobalKey(debugLabel: 'AppFrame Tree key');
  final _layoutKey = GlobalKey(debugLabel: 'AppFrame layout');
  final _propertiesFocus = FocusNode(
    debugLabel: 'AppFrame properties region',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final _topScroll = ScrollController();
  final _pageScroll = ScrollController();
  final _geometry = _Geometry();

  bool _treeOpen = false;
  _Region? _active;
  AppFrameLayout? _layout;
  Size? _size;

  /// Whether the docked Properties tab has been shown since docking, so
  /// the [Subform] keeps its content: mirrors the subform's own record.
  bool _dockShown = false;

  /// The last child tab the owner selected, to return to on undocking.
  String? _lastChildTab;

  /// A selection the frame shows while its request to the owner is
  /// outstanding: valid while the owner still selects [_pendingFor].
  String? _pendingShow;
  String? _pendingFor;

  // Sizes when a drag started.
  double _dragStart = 0;

  /// Whether the folded tree's overlay is open.
  bool get treeOpen => _treeOpen && (_layout?.treeFolded ?? false);

  /// The layout of the last build.
  AppFrameLayout? get layout => _layout;

  /// Opens the folded tree's overlay; nothing while the tree is a column.
  void openTree() {
    if (!(_layout?.treeFolded ?? false) || _treeOpen) return;
    setState(() => _treeOpen = true);
  }

  /// Closes the folded tree's overlay.
  void closeTree() {
    if (!_treeOpen) return;
    setState(() => _treeOpen = false);
  }

  @override
  void initState() {
    super.initState();
    final selected = widget.subformSelectedId;
    if (selected != AppFrame.propertiesTabId) _lastChildTab = selected;
  }

  @override
  void didUpdateWidget(AppFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.subformSelectedId;
    if (_pendingShow != null && selected != _pendingFor) _clearPending();
    if (selected != null && selected != AppFrame.propertiesTabId) {
      _lastChildTab = selected;
    }
    if (!widget.enabled) _treeOpen = false;
  }

  @override
  void dispose() {
    _propertiesFocus.dispose();
    _topScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  void _clearPending() {
    _pendingShow = null;
    _pendingFor = null;
  }

  bool _flush() => widget.controller?.flush().isAccepted ?? true;

  bool get _propertiesActive =>
      _active == _Region.properties || _propertiesFocus.hasFocus;

  /// Shows [id] now and asks the owner to select it after this frame.
  void _request(String id) {
    _pendingShow = id;
    _pendingFor = widget.subformSelectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingShow != id) return;
      widget.onSubformSelect?.call(id);
    });
  }

  void _onSubformSelect(String id) {
    _clearPending();
    widget.onSubformSelect?.call(id);
  }

  /// Follows a change of size and layout: reveal the docked properties
  /// when they were the active region, or return to a child tab on
  /// undocking; then scroll the focused editor, wherever its pane went or
  /// however its region shrank, back into view.
  void _follow(AppFrameLayout layout, Size size) {
    final before = _layout;
    final resized = size != _size;
    _layout = layout;
    _size = size;
    if (!layout.treeFolded) _treeOpen = false;
    if (before == null) return;
    if (resized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealFocus());
    }
    final selected = widget.subformSelectedId;
    if (!before.propertiesDocked && layout.propertiesDocked) {
      if (_propertiesActive && selected != AppFrame.propertiesTabId) {
        _request(AppFrame.propertiesTabId);
      }
    } else if (before.propertiesDocked && !layout.propertiesDocked) {
      if (_pendingShow == AppFrame.propertiesTabId) _clearPending();
      if (selected == AppFrame.propertiesTabId) {
        final tabs = [for (final tab in widget.subformTabs) tab._item];
        final back = TabStrip.resolveSelection(tabs, _lastChildTab);
        if (back != null) _request(back);
      }
    }
  }

  /// Brings the focused editor into view after its pane moved or its
  /// region shrank, with the least scrolling. Again a frame later: a
  /// scrollbar that the new size shows takes its room only then.
  void _revealFocus({bool again = true}) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (!mounted || focused == null || !focused.mounted) return;
    final frame = context;
    var inside = false;
    focused.visitAncestorElements((element) {
      inside = element == frame;
      return !inside;
    });
    if (!inside) return;
    for (final policy in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(focused, alignmentPolicy: policy);
    }
    if (again) {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _revealFocus(again: false))
        ..ensureVisualUpdate();
    }
  }

  String? get _shownTab {
    final selected = widget.subformSelectedId;
    if (_pendingShow != null && selected == _pendingFor) return _pendingShow;
    return selected;
  }

  void _activate(_Region region) => _active = region;

  Widget _region(_Region region, Widget child) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => _activate(region),
    child: child,
  );

  // ---- the panes, each under its one global key ----

  Widget _treePane({VoidCallback? onClose}) => KeyedSubtree(
    key: _treeKey,
    child: _region(
      _Region.tree,
      _ObjectPane(
        title: widget.treeTitle,
        icon: widget.treeIcon,
        tree: widget.tree,
        details: widget.details,
        scale: _layout?.scale ?? 1,
        onClose: onClose,
      ),
    ),
  );

  Widget _propertiesPane() => KeyedSubtree(
    key: _propertiesKey,
    child: Focus(
      focusNode: _propertiesFocus,
      canRequestFocus: false,
      skipTraversal: true,
      child: _region(_Region.properties, widget.properties),
    ),
  );

  static Widget _park(Widget child) => Offstage(
    child: ExcludeFocus(child: TickerMode(enabled: false, child: child)),
  );

  // ---- drags ----

  void _report(AppFramePanes panes) => widget.onPanesChanged(panes);

  void _end() => widget.onPanesChangeEnd?.call(widget.panes);

  Widget _splitter({
    required String id,
    required Axis axis,
    required String label,
    required double start,
    required void Function(double offset) onDrag,
  }) => Splitter(
    key: ValueKey('app-frame-splitter:$id'),
    axis: axis,
    semanticLabel: label,
    onDragStart: widget.enabled ? () => _dragStart = start : null,
    onDrag: widget.enabled ? onDrag : (_) {},
    onDragEnd: widget.enabled ? _end : null,
  );

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = AppFrameLayout.resolve(
          width: width,
          scale: scale,
          panes: widget.panes,
        );
        _follow(layout, constraints.biggest);
        final docked = layout.propertiesDocked;
        final shownTab = _shownTab;
        if (!docked) {
          _dockShown = false;
        } else if (shownTab == AppFrame.propertiesTabId) {
          _dockShown = true;
        }
        final place = !docked
            ? _Place.column
            : _dockShown
            ? _Place.dock
            : _Place.parked;
        final lower = docked || widget.subformTabs.isNotEmpty;
        final open = treeOpen;

        final top = SingleChildScrollView(
          controller: _topScroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuBar(
                menus: widget.menus,
                enabled: widget.enabled,
                guard: _flush,
              ),
              KeyedSubtree(
                child: widget.toolbarBuilder(
                  context,
                  layout.treeFolded ? _treeAction() : null,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: skin.tokens.chrome),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, top: 1),
                  child: TabStrip(
                    tabs: [
                      for (final area in widget.areas)
                        widget.enabled ? area : _disabled(area),
                    ],
                    selectedId: widget.areaId,
                    onSelect: (id) {
                      if (_flush()) widget.onAreaSelect(id);
                    },
                  ),
                ),
              ),
            ],
          ),
        );

        final page = LayoutBuilder(
          builder: (context, page) {
            // Measured by the frame's layout just before this builder runs.
            final height = math.max(page.maxHeight, _geometry.pageMin);
            final inner = height - 2 * AppFrame.pagePadding;
            final (lowerHeight, lowerLeast, lowerMost) = layout.lowerHeight(
              inner,
              widget.panes,
              strip: _geometry.strip,
            );
            final middle = KeyedSubtree(
              key: _middleKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _region(_Region.middle, widget.middle)),
                  if (lower) ...[
                    _splitter(
                      id: 'lower',
                      axis: Axis.vertical,
                      label: 'Resize the subform',
                      start: lowerHeight,
                      onDrag: (offset) => _report(
                        widget.panes.copyWith(
                          dock:
                              (_dragStart - offset).clamp(
                                lowerLeast,
                                lowerMost,
                              ) /
                              layout.scale,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: lowerHeight,
                      child: KeyedSubtree(
                        key: _lowerKey,
                        child: _lowerRegion(place, shownTab),
                      ),
                    ),
                  ],
                ],
              ),
            );
            return SingleChildScrollView(
              controller: _pageScroll,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(AppFrame.pagePadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!layout.treeFolded) ...[
                        SizedBox(
                          key: const ValueKey('app-frame-tree-column'),
                          width: layout.left,
                          child: _treePane(),
                        ),
                        _splitter(
                          id: 'left',
                          axis: Axis.horizontal,
                          label: 'Resize the tree column',
                          start: layout.left,
                          onDrag: (offset) => _report(
                            widget.panes.copyWith(
                              left:
                                  (_dragStart + offset).clamp(
                                    AppFrame.minLeft * layout.scale,
                                    layout.leftMax,
                                  ) /
                                  layout.scale,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        key: const ValueKey('app-frame-middle-column'),
                        child: middle,
                      ),
                      if (place == _Place.column) ...[
                        _splitter(
                          id: 'right',
                          axis: Axis.horizontal,
                          label: 'Resize the property column',
                          start: layout.right,
                          onDrag: (offset) => _report(
                            widget.panes.copyWith(
                              right:
                                  (_dragStart - offset).clamp(
                                    AppFrame.minRight * layout.scale,
                                    layout.rightMax,
                                  ) /
                                  layout.scale,
                            ),
                          ),
                        ),
                        SizedBox(
                          key: const ValueKey('app-frame-property-column'),
                          width: layout.right,
                          child: _propertiesPane(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );

        return ColoredBox(
          color: skin.tokens.chrome,
          child: CustomMultiChildLayout(
            key: _layoutKey,
            delegate: _FrameLayout(
              geometry: _geometry,
              layout: layout,
              lower: lower,
              parkedTree: Size(
                layout.flyoutWidth,
                AppFrame.minPaneHeight * scale,
              ),
              parkedProperties: Size(
                math.max(AppFrame.narrowRight * scale, layout.right),
                AppFrame.minPropertiesHeight * scale,
              ),
            ),
            children: [
              if (lower)
                LayoutId(id: _Slot.strip, child: _stripProbe(place, shownTab)),
              LayoutId(id: _Slot.top, child: top),
              LayoutId(id: _Slot.page, child: page),
              if (widget.status case final status?)
                LayoutId(id: _Slot.status, child: status),
              if (open)
                LayoutId(id: _Slot.overlay, child: _overlay(layout))
              else if (layout.treeFolded)
                LayoutId(id: _Slot.parkTree, child: _park(_treePane())),
              if (place == _Place.parked)
                LayoutId(
                  id: _Slot.parkProperties,
                  child: _park(_propertiesPane()),
                ),
            ],
          ),
        );
      },
    );
  }

  static TabItem _disabled(TabItem area) => TabItem(
    id: area.id,
    label: area.label,
    icon: area.icon,
    enabled: false,
    disabledReason: area.disabledReason,
    tooltip: area.tooltip,
    count: area.count,
    countLabel: area.countLabel,
  );

  ToolbarItem _treeAction() => ToolbarItem(
    label: 'Tree',
    tooltip: 'Shows the tree and Details',
    dropArrow: true,
    leading: KeyedSubtree(
      key: _treeAnchor,
      child: EraIcon(widget.treeIcon, disabled: !widget.enabled),
    ),
    onPressed: widget.enabled
        ? () => setState(() => _treeOpen = !_treeOpen)
        : null,
  );

  List<SubformTab> _lowerTabs(_Place place) => [
    for (final tab in widget.subformTabs)
      SubformTab(
        id: tab.id,
        label: tab.label,
        icon: tab.icon,
        enabled: tab.enabled,
        disabledReason: tab.disabledReason,
        tooltip: tab.tooltip,
        count: tab.count,
        countLabel: tab.countLabel,
        builder: (context) =>
            _region(_Region.lower, Builder(builder: tab.builder)),
      ),
    if (_layout?.propertiesDocked ?? false)
      SubformTab(
        id: AppFrame.propertiesTabId,
        label: widget.propertiesLabel,
        icon: EraIconKind.properties,
        // The pane is here only while the frame placed it here, so a
        // cached tab can never hold it beside the column or the park.
        builder: (context) =>
            place == _Place.dock ? _propertiesPane() : const SizedBox.shrink(),
      ),
  ];

  Widget _lowerRegion(_Place place, String? shownTab) => Subform(
    label: widget.subformLabel,
    controller: widget.controller,
    selectedId: shownTab,
    onSelect: _onSubformSelect,
    trailing: widget.subformTrailing,
    tabs: _lowerTabs(place),
  );

  /// An off-stage twin of the subform's tab strip, laid out at the middle
  /// column's width so the frame knows how tall the wrapped tabs are
  /// before it gives the lower region its height. Not painted, hit,
  /// announced, focused or found.
  Widget _stripProbe(_Place place, String? shownTab) => Offstage(
    child: ExcludeFocus(
      child: TickerMode(
        enabled: false,
        child: _SizeProbe(
          onSize: (size) => _geometry.strip = size.height,
          child: TabStrip(
            size: TabStripSize.subform,
            tabs: [for (final tab in _lowerTabs(place)) tab._item],
            selectedId: shownTab,
            onSelect: (_) {},
            trailing: widget.subformTrailing,
          ),
        ),
      ),
    ),
  );

  /// The folded tree's overlay: a barrier over chrome and page that closes
  /// it on any press, and the tree pane hanging from the Tree key.
  Widget _overlay(AppFrameLayout layout) => LayoutBuilder(
    builder: (context, constraints) {
      const pad = AppFrame.pagePadding;
      final size = constraints.biggest;
      var anchor = Rect.fromLTWH(pad, _geometry.topHeight, 0, 0);
      final root = _layoutKey.currentContext?.findRenderObject();
      final key = _treeKeyBox();
      if (root is RenderBox && key != null) {
        anchor = key.localToGlobal(Offset.zero, ancestor: root) & key.size;
      }
      final width = math.min(layout.flyoutWidth, size.width - 2 * pad);
      final left = anchor.left
          .clamp(pad, math.max(pad, size.width - pad - width))
          .toDouble();
      final top = anchor.bottom
          .clamp(0.0, math.max(0.0, size.height - pad))
          .toDouble();
      return Stack(
        children: [
          Positioned.fill(
            child: Listener(
              key: const ValueKey('app-frame-tree-barrier'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => closeTree(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: math.max(0, width),
            height: math.max(0, size.height - top - pad),
            child: _Flyout(child: _treePane(onClose: closeTree)),
          ),
        ],
      );
    },
  );

  /// The Tree key's render box, found from the anchor in its leading icon.
  RenderBox? _treeKeyBox() {
    final anchor = _treeAnchor.currentContext;
    if (anchor == null) return null;
    RenderObject? box;
    anchor.visitAncestorElements((element) {
      if (element.widget is! KeyButton) return true;
      box = element.findRenderObject();
      return false;
    });
    final found = box;
    return found is RenderBox && found.hasSize ? found : null;
  }
}

extension on SubformTab {
  TabItem get _item => TabItem(
    id: id,
    label: label,
    icon: icon,
    enabled: enabled,
    disabledReason: disabledReason,
    tooltip: tooltip,
    count: count,
    countLabel: countLabel,
  );
}

/// Shared between the frame's layout delegate and its overlay.
final class _Geometry {
  double topHeight = 0;

  /// The subform tab strip's measured height, and the page's least height
  /// with it.
  double strip = 0;
  double pageMin = 0;
}

/// Lays the frame out top to bottom: the status bar takes its own capped
/// height, the chrome at most what leaves the page its minimum (but never
/// less than 30 % of the height), and the page the rest. The page's
/// minimum includes the subform's tab strip, measured first on an
/// invisible twin at the middle column's width. The overlay covers chrome
/// and page; parked panes are laid out at a typical size.
final class _FrameLayout extends MultiChildLayoutDelegate {
  _FrameLayout({
    required this.geometry,
    required this.layout,
    required this.lower,
    required this.parkedTree,
    required this.parkedProperties,
  });

  final _Geometry geometry;
  final AppFrameLayout layout;
  final bool lower;
  final Size parkedTree;
  final Size parkedProperties;

  @override
  void performLayout(Size size) {
    final width = size.width;
    final height = size.height;
    var strip = 0.0;
    if (hasChild(_Slot.strip)) {
      const split = Splitter.thickness;
      final middle = math.max(
        0.0,
        width -
            2 * AppFrame.pagePadding -
            (layout.treeFolded ? 0 : layout.left + split) -
            (layout.propertiesDocked ? 0 : layout.right + split),
      );
      // Off-stage, so its own size is nil: the probe inside reports the
      // strip's height whenever it lays the strip out (and keeps the last
      // report while the strip is unchanged and skips layout).
      layoutChild(
        _Slot.strip,
        BoxConstraints(minWidth: middle, maxWidth: middle),
      );
      positionChild(_Slot.strip, Offset.zero);
      strip = geometry.strip;
    }
    final pageMin = layout.pageMinHeight(lower: lower, strip: strip);
    geometry
      ..strip = strip
      ..pageMin = pageMin;
    var status = 0.0;
    if (hasChild(_Slot.status)) {
      status = layoutChild(
        _Slot.status,
        BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height),
      ).height;
    }
    final room = math.max(0.0, height - status);
    final cap = math
        .max(height - status - pageMin, height * 0.3)
        .clamp(0.0, room)
        .toDouble();
    final top = layoutChild(
      _Slot.top,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: cap),
    ).height;
    positionChild(_Slot.top, Offset.zero);
    geometry.topHeight = top;
    final page = math.max(0.0, room - top);
    layoutChild(
      _Slot.page,
      BoxConstraints.tightFor(width: width, height: page),
    );
    positionChild(_Slot.page, Offset(0, top));
    if (hasChild(_Slot.status)) positionChild(_Slot.status, Offset(0, room));
    for (final (slot, parked) in [
      (_Slot.parkTree, parkedTree),
      (_Slot.parkProperties, parkedProperties),
    ]) {
      if (!hasChild(slot)) continue;
      layoutChild(slot, BoxConstraints.tight(parked));
      positionChild(slot, Offset.zero);
    }
    if (hasChild(_Slot.overlay)) {
      // After the chrome, so the Tree key it hangs from is laid out.
      layoutChild(_Slot.overlay, BoxConstraints.tight(Size(width, top + page)));
      positionChild(_Slot.overlay, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_FrameLayout oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.lower != lower ||
      oldDelegate.parkedTree != parkedTree ||
      oldDelegate.parkedProperties != parkedProperties;
}

/// The tree pane: its caption, the tree capped at 60 % of the pane, and
/// Details filling the rest. Below its minimum height it scrolls.
final class _ObjectPane extends StatelessWidget {
  const _ObjectPane({
    required this.title,
    required this.icon,
    required this.tree,
    required this.details,
    required this.scale,
    this.onClose,
  });

  final String title;
  final EraIconKind icon;
  final Widget tree;
  final Widget details;
  final double scale;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => _AtLeast(
    height: AppFrame.minPaneHeight * scale,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneCaption(
          title: title,
          icon: icon,
          onClose: onClose,
          closeLabel: 'Close the tree',
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, below) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: below.maxHeight * 0.6),
                  child: tree,
                ),
                const SizedBox(height: 2),
                Expanded(child: details),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Gives [child] the height it is offered, but at least [height]; below
/// that it scrolls, so a short region never squeezes or clips the pane.
/// The same widget in every case, so the pane's state is never rebuilt.
final class _AtLeast extends StatefulWidget {
  const _AtLeast({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  State<_AtLeast> createState() => _AtLeastState();
}

final class _AtLeastState extends State<_AtLeast> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      controller: _scroll,
      child: SizedBox(
        height: math.max(constraints.maxHeight, widget.height),
        child: widget.child,
      ),
    ),
  );
}

/// The folded tree's raised frame: dark outer edge, white inner light.
final class _Flyout extends StatelessWidget {
  const _Flyout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return DecoratedBox(
      key: const ValueKey('app-frame-tree-overlay'),
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border.all(color: MillenniumColors.sunkenEdge),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: tokens.paper),
            left: BorderSide(color: tokens.paper),
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(2), child: child),
      ),
    );
  }
}

/// The menu bar: flat titles that drop era menus. Mouse only: no title or
/// row takes focus, so no key opens or walks a menu. A row first runs
/// [guard] (the editor's flush) and does nothing when it is refused.
final class _MenuBar extends StatelessWidget {
  const _MenuBar({
    required this.menus,
    required this.enabled,
    required this.guard,
  });

  final List<AppMenu> menus;
  final bool enabled;
  final bool Function() guard;

  EraMenuItem _guarded(EraMenuItem item) {
    if (item.separator) return item;
    final run = item.onSelected;
    return EraMenuItem(
      item.label,
      run == null || !enabled
          ? null
          : () {
              if (guard()) run();
            },
      isDefault: item.isDefault,
      icon: item.icon,
      checked: item.checked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final style = eraMenuItemStyle(
      skin,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.paper, tokens.chrome],
        ),
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: menuRowHeight),
        child: ExcludeFocus(
          child: Wrap(
            children: [
              for (final menu in menus)
                EraMenuButton(
                  key: ValueKey('app-frame-menu:${menu.label}'),
                  items: [for (final item in menu.items) _guarded(item)],
                  builder: (context, toggle) => TextButton(
                    style: style,
                    onPressed: enabled && menu.items.isNotEmpty ? toggle : null,
                    child: Text(menu.label),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reports its child's size each time it lays the child out.
final class _SizeProbe extends SingleChildRenderObjectWidget {
  const _SizeProbe({required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeProbe(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeProbe renderObject) {
    renderObject.onSize = onSize;
  }
}

final class _RenderSizeProbe extends RenderProxyBox {
  _RenderSizeProbe(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
