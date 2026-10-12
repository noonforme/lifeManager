import 'dart:math' as math;

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/keys.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// The two tab-row sizes (database shell spec 5, 6). The heights are
/// minima at 100 % text: a larger text scale or an icon and count grow the
/// tab. The active tab is taller than the rest, so it stands proud of the
/// line the page continues.
enum TabStripSize {
  /// Area tabs of the application frame: 24 px inactive, 27 px active.
  area(inactive: 24, active: 27),

  /// Tabs over a subform: 20 px inactive, 22 px active.
  subform(inactive: 20, active: 22);

  const TabStripSize({required this.inactive, required this.active});

  /// Minimum height of an inactive tab.
  final double inactive;

  /// Minimum height of the active tab.
  final double active;
}

/// One tab of a [TabStrip]. [id] is the tab's stable identity: selection,
/// reordering and removal all go by id, never by list position.
@immutable
final class TabItem {
  const TabItem({
    required this.id,
    required this.label,
    this.icon,
    this.enabled = true,
    this.disabledReason,
    this.tooltip,
    this.count,
    this.countLabel = 'waiting',
  });

  /// Unique within one strip.
  final String id;
  final String label;
  final EraIconKind? icon;

  /// A disabled tab keeps its place, paints greyed and requests nothing. It
  /// can still be the selected tab (the owner decides).
  final bool enabled;

  /// Why the tab is unavailable. Shown as the tooltip and announced to
  /// assistive technology. Ignored while [enabled].
  final String? disabledReason;

  /// Hover text of an enabled tab.
  final String? tooltip;

  /// An orange count after the label (rows to confirm, pending items). Null
  /// shows none; zero is shown.
  final int? count;

  /// What [count] counts, announced as "count countLabel".
  final String countLabel;
}

/// A row of tabs (database shell spec 5.5, 6), for area tabs of the frame
/// ([TabStripSize.area]) and the tabs over a subform
/// ([TabStripSize.subform]).
///
/// **Controlled by id.** [selectedId] is supplied by the owner. A tap on an
/// enabled, unselected tab only *requests* it with [onSelect]; the strip
/// never changes its own selection, so an owner that must first flush an
/// editor, ask a leave guard or refuse the change simply does not pass the
/// new id. Tabs are matched by [TabItem.id], so reordering, inserting or
/// removing tabs cannot move the selection to a neighbour.
///
/// **Validation.** Duplicate ids throw a [FlutterError] on build. An empty
/// list paints an empty strip (the line, and any [trailing]). A
/// [selectedId] that matches no tab (the selected tab was removed, or null)
/// paints no tab as active and never indexes into the list; the owner
/// reconciles with [resolveSelection] and supplies the result.
///
/// **Mouse only.** Tabs take no keyboard focus and the arrow keys, Enter
/// and Space do nothing (spec 4.6); mouse and assistive-technology
/// activation work. The active tab has an amber top edge, a hovered
/// enabled tab shows the same edge, and a disabled tab paints a greyed icon
/// and label.
///
/// **Reflow.** Tabs and [trailing] each get a bounded width. A tab whose
/// label is wider than the strip wraps onto further lines (the full label
/// stays in its semantics); tabs that do not fit wrap onto further rows.
/// The [trailing] caption (a muted note such as "3 of 5 saved") sits at the
/// right edge of the tab row when both fit on one line, and otherwise moves
/// onto its own line above the tabs and wraps within the width. It is
/// passive: focus is removed from it.
final class TabStrip extends StatelessWidget {
  const TabStrip({
    required this.tabs,
    required this.selectedId,
    required this.onSelect,
    this.size = TabStripSize.area,
    this.trailing,
    super.key,
  });

  final List<TabItem> tabs;

  /// The id of the active tab; null or an id not in [tabs] selects none.
  final String? selectedId;

  /// A request to select the tab with this id. Called only for an enabled
  /// tab that is not already selected.
  final ValueChanged<String> onSelect;
  final TabStripSize size;

  /// Passive caption beside or above the tabs; keyboard focus is removed.
  final Widget? trailing;

  /// The id the owner should select after the tabs changed: [selectedId]
  /// when a tab with that id still exists; otherwise the first enabled tab,
  /// or null when no tab is enabled (nothing to select). Never throws on an
  /// empty list.
  static String? resolveSelection(List<TabItem> tabs, String? selectedId) {
    for (final tab in tabs) {
      if (tab.id == selectedId) {
        return selectedId;
      }
    }
    for (final tab in tabs) {
      if (tab.enabled) {
        return tab.id;
      }
    }
    return null;
  }

  static void _validate(List<TabItem> tabs) {
    final seen = <String>{};
    for (final tab in tabs) {
      if (!seen.add(tab.id)) {
        throw FlutterError(
          'TabStrip: duplicate tab id "${tab.id}". Tab ids must be unique.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _validate(tabs);
    final skin = LifeOSSkinScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final slot = trailing;
        final row = Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (final tab in tabs)
              ConstrainedBox(
                // Every tab, however long its label, is bounded by the
                // strip; its text wraps.
                constraints: BoxConstraints(maxWidth: width),
                child: _Tab(
                  key: ValueKey(tab.id),
                  item: tab,
                  size: size,
                  selected: tab.id == selectedId,
                  onSelect: onSelect,
                ),
              ),
          ],
        );
        return DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MillenniumColors.tabLine)),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.inactive),
            child: _RowAndCaption(
              row: row,
              caption: slot == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: DefaultTextStyle.merge(
                        style: skin.typography.small.copyWith(
                          color: skin.tokens.muted,
                        ),
                        child: ExcludeFocus(child: slot),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

final class _Tab extends StatefulWidget {
  const _Tab({
    required this.item,
    required this.size,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final TabItem item;
  final TabStripSize size;
  final bool selected;
  final ValueChanged<String> onSelect;

  @override
  State<_Tab> createState() => _TabState();
}

final class _TabState extends State<_Tab> {
  bool _hovered = false;

  void _tap() {
    if (widget.item.enabled && !widget.selected) {
      widget.onSelect(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final item = widget.item;
    final selected = widget.selected;
    final enabled = item.enabled;
    final reason = enabled ? null : item.disabledReason;
    final edge = selected || (_hovered && enabled);
    final count = item.count;
    final spoken = StringBuffer(item.label);
    if (count != null) {
      spoken.write(', $count ${item.countLabel}');
    }
    final hint = enabled ? item.tooltip : reason;
    final box = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Container(
          constraints: BoxConstraints(
            minHeight: selected ? widget.size.active : widget.size.inactive,
          ),
          margin: const EdgeInsets.only(right: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? MillenniumColors.page : null,
            gradient: selected
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [tokens.paper, tokens.chrome],
                  ),
            border: Border(
              top: BorderSide(
                color: edge
                    ? MillenniumColors.tabAccent
                    : MillenniumColors.tabLine,
                width: edge ? 2 : 1,
              ),
              left: const BorderSide(color: MillenniumColors.tabLine),
              right: const BorderSide(color: MillenniumColors.tabLine),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (item.icon case final icon?)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: EraIcon(icon, disabled: !enabled),
                ),
              Flexible(
                child: Text(
                  item.label,
                  style: skin.typography.body.copyWith(
                    color: enabled ? tokens.ink : tokens.muted,
                  ),
                ),
              ),
              if (count != null)
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: CountBadge(
                    count: count,
                    semanticLabel: item.countLabel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: spoken.toString(),
      hint: hint,
      excludeSemantics: true,
      onTap: enabled && !selected ? _tap : null,
      // Mouse only: nothing in a tab takes keyboard focus.
      child: ExcludeFocus(
        child: hint == null
            ? box
            : Tooltip(message: hint, excludeFromSemantics: true, child: box),
      ),
    );
  }
}

/// Lays out the tab [row] and the optional [caption]. When the row's
/// natural width and the caption's natural width fit together, the caption
/// sits at the right edge, bottom-aligned with the tabs. Otherwise the
/// caption takes its own line above the tabs, bounded to the full width so
/// it wraps. The row is always bounded by the width, never the caption.
final class _RowAndCaption extends MultiChildRenderObjectWidget {
  _RowAndCaption({required Widget row, required Widget? caption})
    : super(children: [row, ?caption]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRowAndCaption();
}

final class _ParentData extends ContainerBoxParentData<RenderBox> {}

final class _RenderRowAndCaption extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ParentData> {
  static const _gap = 8.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ParentData) {
      child.parentData = _ParentData();
    }
  }

  RenderBox get _row => firstChild!;
  RenderBox? get _caption => childAfter(_row);

  /// Sizes and offsets for [constraints]; [layoutChild] lays out or
  /// measures a child.
  ({Size size, Offset rowAt, Offset? captionAt}) _plan(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) layoutChild,
  ) {
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: width);
    final row = layoutChild(_row, loose);
    final caption = _caption;
    if (caption == null) {
      return (
        size: constraints.constrain(row),
        rowAt: Offset.zero,
        captionAt: null,
      );
    }
    final note = layoutChild(caption, loose);
    if (!width.isFinite || row.width + _gap + note.width <= width) {
      final height = math.max(row.height, note.height);
      final size = constraints.constrain(
        Size(width.isFinite ? width : row.width + _gap + note.width, height),
      );
      return (
        size: size,
        rowAt: Offset(0, height - row.height),
        captionAt: Offset(size.width - note.width, height - note.height),
      );
    }
    final size = constraints.constrain(
      Size(math.max(row.width, note.width), note.height + row.height),
    );
    return (size: size, rowAt: Offset(0, note.height), captionAt: Offset.zero);
  }

  @override
  void performLayout() {
    final plan = _plan(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    size = plan.size;
    (_row.parentData! as _ParentData).offset = plan.rowAt;
    if (_caption case final caption? when plan.captionAt != null) {
      (caption.parentData! as _ParentData).offset = plan.captionAt!;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _plan(constraints, (child, c) => child.getDryLayout(c)).size;

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => null;

  @override
  double computeMinIntrinsicWidth(double height) =>
      _row.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _row.getMaxIntrinsicWidth(height) +
      (_caption?.getMaxIntrinsicWidth(height) ?? 0);

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
