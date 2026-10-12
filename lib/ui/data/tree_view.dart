import 'dart:math' as math;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/widgets.dart';

import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';

/// One node of a [TreeView]: immutable data, no widget state.
///
/// [id] is unique within the tree and stable across rebuilds; the view keys
/// its expansion state by it. [muted] only changes the paint (an ended
/// employment can be muted and still selectable); [enabled] decides whether
/// the node can be selected at all.
@immutable
final class TreeNodeData {
  const TreeNodeData({
    required this.id,
    required this.label,
    this.icon,
    this.count,
    this.children = const [],
    this.warning = false,
    this.muted = false,
    this.bold = false,
    this.expanded = false,
    this.enabled = true,
  });

  final String id;
  final String label;

  /// Drawn at 16 px before the label.
  final EraIconKind? icon;

  /// Shown as "(n)" after the label; it survives label truncation.
  final int? count;
  final List<TreeNodeData> children;

  /// Paints the node in run ink and announces "Needs attention".
  final bool warning;

  /// Paints the node in muted ink and a greyed icon; announces "Inactive".
  /// The node stays selectable.
  final bool muted;
  final bool bold;

  /// Whether the node starts expanded. Honoured once, when the view first
  /// sees this id (again if the id is removed and later reinserted).
  final bool expanded;

  /// A disabled node cannot be selected (it can still be expanded).
  final bool enabled;
}

/// The object tree (database shell spec 6): XP dotted connector lines, boxed
/// plus and minus expanders, 16 px icons, counts, warning and muted nodes.
/// Mouse only: no key selects, expands or scrolls it.
///
/// Selection is controlled. A click on a row calls [onSelect]; the view
/// shows [selectedId] and never changes it itself, so the owner can flush an
/// editor first and accept or refuse. Expansion is local view state, keyed
/// by node id; [onExpansionChanged] only reports the user's toggles.
///
/// Rows are laid out at one fixed height (20 px at 100 % text, growing with
/// the text scale) in a lazy list over the flattened visible nodes, so a
/// large tree builds only the rows on screen. Labels truncate with an
/// ellipsis; the full name, count and state are in each row's semantics.
/// Indentation is capped so a deep node always keeps room for its label.
///
/// The tree takes its content height, up to the incoming constraint and up
/// to [maxContentHeight]; beyond that it scrolls inside. AppFrame passes the
/// cap so the tree cannot consume the Details box's space.
final class TreeView extends StatefulWidget {
  const TreeView({
    required this.label,
    required this.nodes,
    required this.selectedId,
    required this.onSelect,
    this.active = true,
    this.enabled = true,
    this.onExpansionChanged,
    this.maxContentHeight,
    super.key,
  });

  /// The tree's accessible name.
  final String label;
  final List<TreeNodeData> nodes;

  /// The accepted selection; null or an id not shown selects nothing.
  final String? selectedId;

  /// A request to select [id]; the owner decides whether to accept it.
  final ValueChanged<String> onSelect;

  /// Only the selection paint: blue wash when active, grey when not.
  final bool active;

  /// A disabled tree is greyed and neither selects nor expands.
  final bool enabled;
  final void Function(String id, bool expanded)? onExpansionChanged;

  /// The tallest the tree may grow before it scrolls; null for no cap beyond
  /// the incoming constraint.
  final double? maxContentHeight;

  @override
  State<TreeView> createState() => _TreeViewState();
}

final class _TreeViewState extends State<TreeView> {
  final _scroll = ScrollController();

  /// Ids the user (or an initial flag) has expanded; only ids in the tree.
  final _open = <String>{};
  final _known = <String>{};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Validates ids, applies initial expansion to ids not seen before and
  /// prunes ids that left the tree.
  void _sync() {
    final seen = <String>{};
    void visit(TreeNodeData node) {
      if (!seen.add(node.id)) {
        throw ArgumentError.value(node.id, 'nodes', 'duplicate tree node id');
      }
      if (_known.add(node.id) && node.expanded) _open.add(node.id);
      node.children.forEach(visit);
    }

    widget.nodes.forEach(visit);
    _known.retainAll(seen);
    _open.retainAll(seen);
  }

  void _toggle(String id) {
    if (!widget.enabled) return;
    final open = !_open.contains(id);
    setState(() => open ? _open.add(id) : _open.remove(id));
    widget.onExpansionChanged?.call(id, open);
  }

  List<_Flat> _flatten() {
    final rows = <_Flat>[];
    void visit(List<TreeNodeData> nodes, List<bool> lines) {
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final last = i == nodes.length - 1;
        rows.add(
          _Flat(
            node,
            lines.length,
            isFirst: lines.isEmpty && i == 0,
            isLast: last,
            ancestorLines: lines,
          ),
        );
        if (node.children.isNotEmpty && _open.contains(node.id)) {
          visit(node.children, [...lines, !last]);
        }
      }
    }

    visit(widget.nodes, const []);
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final rows = _flatten();
    final bodyStyle = skin.typography.body;
    final extent = math.max(
      20.0,
      (MediaQuery.textScalerOf(
                context,
              ).scale((bodyStyle.fontSize ?? 11) * (bodyStyle.height ?? 1.3)) +
              6)
          .ceilToDouble(),
    );
    // Room kept for the widest count, so a deep node still shows its count.
    var widestCount = '';
    for (final row in rows) {
      final count = row.node.count;
      if (count != null && ' ($count)'.length > widestCount.length) {
        widestCount = ' ($count)';
      }
    }
    final countWidth = widestCount.isEmpty
        ? 0.0
        : (TextPainter(
            text: TextSpan(text: widestCount, style: skin.typography.figure),
            textDirection: TextDirection.ltr,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout()).width.ceilToDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        // How many indent columns fit while the label keeps [_minLabel].
        final cap = constraints.hasBoundedWidth
            ? math.max(
                0,
                ((constraints.maxWidth -
                            _column -
                            20 -
                            4 -
                            _minLabel -
                            countWidth) /
                        _column)
                    .floor(),
              )
            : 1 << 20;
        var height = rows.length * extent;
        if (widget.maxContentHeight != null) {
          height = math.min(height, widget.maxContentHeight!);
        }
        height = math.min(height, constraints.maxHeight);
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.label,
          child: ExcludeFocus(
            child: ColoredBox(
              color: skin.tokens.paper,
              child: SizedBox(
                height: height,
                width: constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : null,
                child: ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  itemExtent: extent,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final flat = rows[index];
                    return _TreeRow(
                      key: ValueKey('tree-row:${flat.node.id}'),
                      flat: flat,
                      cap: cap,
                      open: _open.contains(flat.node.id),
                      selected: flat.node.id == widget.selectedId,
                      active: widget.active,
                      enabled: widget.enabled,
                      onSelect: () => widget.onSelect(flat.node.id),
                      onToggle: () => _toggle(flat.node.id),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A visible node with the facts the connector painter needs.
final class _Flat {
  const _Flat(
    this.node,
    this.depth, {
    required this.isFirst,
    required this.isLast,
    required this.ancestorLines,
  });

  final TreeNodeData node;
  final int depth;
  final bool isFirst;
  final bool isLast;

  /// For each ancestor depth, whether that ancestor has a later sibling (so
  /// its line continues through this row).
  final List<bool> ancestorLines;
}

const _column = 16.0;
const _minLabel = 48.0;

final class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.flat,
    required this.cap,
    required this.open,
    required this.selected,
    required this.active,
    required this.enabled,
    required this.onSelect,
    required this.onToggle,
    super.key,
  });

  final _Flat flat;
  final int cap;
  final bool open;
  final bool selected;
  final bool active;
  final bool enabled;
  final VoidCallback onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final node = flat.node;
    final canSelect = enabled && node.enabled;
    final branch = node.children.isNotEmpty;
    final washed = selected;
    final background = !washed
        ? null
        : active && enabled
        ? tokens.selWash
        : tokens.chromeLine;
    final ink = washed && active && enabled
        ? tokens.selInk
        : !enabled || !node.enabled
        ? tokens.muted
        : node.warning
        ? tokens.runInk
        : node.muted
        ? tokens.muted
        : tokens.ink;
    final style = skin.typography.body.copyWith(
      color: ink,
      fontWeight: node.bold || node.warning ? FontWeight.w700 : FontWeight.w400,
    );
    final figure = skin.typography.figure.copyWith(color: ink);
    final hints = [
      if (node.warning) 'Needs attention',
      if (node.muted) 'Inactive',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        double columnX(int level) => math.min(level, cap) * _column;
        final labelX =
            columnX(flat.depth) + _column + (node.icon != null ? 16 + 4 : 4);
        final row = SizedBox(
          height: constraints.maxHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConnectorPainter(
                    flat: flat,
                    columnX: columnX,
                    iconStart: columnX(flat.depth) + _column,
                    color: tokens.muted,
                  ),
                ),
              ),
              Positioned(
                left: labelX - (node.icon != null ? 20 : 4),
                top: 0,
                bottom: 0,
                right: 0,
                child: ColoredBox(
                  color: background ?? const Color(0x00000000),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      children: [
                        if (node.icon != null) ...[
                          EraIcon(
                            node.icon!,
                            disabled: node.muted || !enabled || !node.enabled,
                          ),
                          const SizedBox(width: 4),
                        ] else
                          const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            node.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: style,
                          ),
                        ),
                        if (node.count != null)
                          // Never wider than the row, so even a count that
                          // cannot fit beside the label cannot overflow.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: math.max(
                                0,
                                constraints.maxWidth - labelX - 4,
                              ),
                            ),
                            child: Text(
                              ' (${node.count})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: figure,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (branch)
                Positioned(
                  left: columnX(flat.depth),
                  top: 0,
                  bottom: 0,
                  width: _column,
                  child: GestureDetector(
                    key: ValueKey('tree-box:${node.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? onToggle : null,
                    child: CustomPaint(
                      painter: _BoxPainter(
                        open: open,
                        line: tokens.muted,
                        fill: tokens.paper,
                        sign: enabled ? tokens.ink : tokens.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return Semantics(
          container: true,
          excludeSemantics: true,
          label: node.label,
          value: node.count?.toString(),
          hint: hints.isEmpty ? null : hints.join(', '),
          selected: selected,
          expanded: branch ? open : null,
          enabled: canSelect,
          onTap: canSelect ? onSelect : null,
          customSemanticsActions: branch && enabled
              ? {
                  CustomSemanticsAction(label: open ? 'Collapse' : 'Expand'):
                      onToggle,
                }
              : null,
          child: MouseRegion(
            cursor: canSelect ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: canSelect ? onSelect : null,
              child: row,
            ),
          ),
        );
      },
    );
  }
}

/// Draws dots on a 1 px line, every other pixel, as the era tree does.
void _dottedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
  final horizontal = from.dy == to.dy;
  final length = horizontal ? (to.dx - from.dx) : (to.dy - from.dy);
  for (var d = 0.0; d < length; d += 2) {
    final dot = horizontal
        ? Rect.fromLTWH(from.dx + d, from.dy, 1, 1)
        : Rect.fromLTWH(from.dx, from.dy + d, 1, 1);
    canvas.drawRect(dot, paint);
  }
}

final class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.flat,
    required this.columnX,
    required this.iconStart,
    required this.color,
  });

  final _Flat flat;
  final double Function(int level) columnX;
  final double iconStart;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final mid = (size.height / 2).floorToDouble();
    for (var level = 0; level < flat.ancestorLines.length; level++) {
      if (!flat.ancestorLines[level]) continue;
      final x = (columnX(level) + _column / 2).floorToDouble();
      _dottedLine(canvas, Offset(x, 0), Offset(x, size.height), paint);
    }
    final x = (columnX(flat.depth) + _column / 2).floorToDouble();
    if (!flat.isFirst) _dottedLine(canvas, Offset(x, 0), Offset(x, mid), paint);
    if (!flat.isLast) {
      _dottedLine(canvas, Offset(x, mid), Offset(x, size.height), paint);
    }
    _dottedLine(canvas, Offset(x, mid), Offset(iconStart, mid), paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.flat != flat || old.color != color || old.iconStart != iconStart;
}

final class _BoxPainter extends CustomPainter {
  const _BoxPainter({
    required this.open,
    required this.line,
    required this.fill,
    required this.sign,
  });

  final bool open;
  final Color line;
  final Color fill;
  final Color sign;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(
      (size.width / 2).floorToDouble(),
      (size.height / 2).floorToDouble(),
    );
    final box = Rect.fromCenter(
      center: centre + const Offset(0.5, 0.5),
      width: 9,
      height: 9,
    );
    canvas.drawRect(box, Paint()..color = fill);
    canvas.drawRect(
      box,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final ink = Paint()..color = sign;
    canvas.drawRect(
      Rect.fromCenter(center: box.center, width: 5, height: 1),
      ink,
    );
    if (!open) {
      canvas.drawRect(
        Rect.fromCenter(center: box.center, width: 1, height: 5),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.open != open ||
      old.line != line ||
      old.fill != fill ||
      old.sign != sign;
}
