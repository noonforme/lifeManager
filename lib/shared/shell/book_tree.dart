import 'package:flutter/material.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/lifeos_tokens.dart';
import '../workbench/office_controls.dart';

/// One row of the book tree.
sealed class TreeNode {
  const TreeNode();
}

/// An area heading such as Work or Finance. An unbuilt area opens its
/// honest unavailable sheet and says "Not built yet".
final class TreeArea extends TreeNode {
  const TreeArea({
    required this.area,
    required this.route,
    required this.built,
    this.children = const [],
  });

  final LifeOSArea area;
  final String route;
  final bool built;
  final List<TreeSheet> children;
}

/// Something a node's right-click menu offers besides Open.
final class TreeAction {
  const TreeAction(this.label, this.onSelected);

  final String label;
  final VoidCallback onSelected;
}

/// A heading over related sheets, such as Views, with a count.
final class TreeGroup extends TreeNode {
  const TreeGroup({required this.label, required this.children});

  final String label;
  final List<TreeSheet> children;
}

/// A sheet the owner can open. [liveValue] is read from a projection, never
/// stored; [needsYou] counts what waits on the owner.
final class TreeSheet extends TreeNode {
  const TreeSheet({
    required this.label,
    required this.route,
    this.liveValue,
    this.liveValueIsActive = false,
    this.needsYou = 0,
    this.built = true,
    this.actions = const [],
  });

  final String label;
  final String route;
  final String? liveValue;

  /// Marks a running state, such as a shift in progress.
  final bool liveValueIsActive;
  final int needsYou;
  final bool built;

  /// Offered after Open when the row is right-clicked.
  final List<TreeAction> actions;
}

/// The left pane: every area and sheet with its live value (spec 6.1).
final class BookTree extends StatelessWidget {
  const BookTree({
    required this.nodes,
    required this.footer,
    required this.selectedRoute,
    required this.onOpen,
    super.key,
  });

  final List<TreeNode> nodes;

  /// Rows pinned to the bottom, such as Backup and export.
  final List<TreeSheet> footer;
  final String? selectedRoute;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return ColoredBox(
      color: tokens.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: tokens.chrome,
              border: Border(bottom: BorderSide(color: tokens.chromeLine)),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(child: _label(skin, 'BOOKS')),
                  _label(skin, 'NOW'),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final node in nodes)
                  ...switch (node) {
                    TreeArea() => [
                      _AreaRow(
                        node: node,
                        selected: node.route == selectedRoute,
                        onOpen: onOpen,
                      ),
                      for (final child in node.children)
                        _SheetRow(
                          node: child,
                          indent: true,
                          selected: child.route == selectedRoute,
                          onOpen: onOpen,
                        ),
                    ],
                    TreeGroup() => [
                      _GroupRow(node: node),
                      for (final child in node.children)
                        _SheetRow(
                          node: child,
                          indent: true,
                          selected: child.route == selectedRoute,
                          onOpen: onOpen,
                        ),
                    ],
                    TreeSheet() => [
                      _SheetRow(
                        node: node,
                        indent: false,
                        selected: node.route == selectedRoute,
                        onOpen: onOpen,
                      ),
                    ],
                  },
              ],
            ),
          ),
          for (final node in footer)
            _SheetRow(
              node: node,
              indent: false,
              selected: node.route == selectedRoute,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }

  static Widget _label(LifeOSSkinData skin, String text) => Text(
    text,
    style: skin.typography.label.copyWith(color: skin.tokens.muted),
  );
}

final class _AreaRow extends StatelessWidget {
  const _AreaRow({
    required this.node,
    required this.selected,
    required this.onOpen,
  });

  final TreeArea node;
  final bool selected;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return _TreeRow(
      route: node.route,
      label: node.area.label,
      semanticValue: node.built ? null : 'Not built yet',
      selected: selected,
      onOpen: onOpen,
      background: tokens.band,
      child: Row(
        children: [
          AreaKey(area: node.area),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              node.area.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.body.copyWith(
                color: node.built ? tokens.ink : tokens.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!node.built)
            Text(
              'Not built yet',
              style: skin.typography.small.copyWith(color: tokens.muted),
            ),
        ],
      ),
    );
  }
}

/// A group heading; it opens nothing itself.
final class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.node});

  final TreeGroup node;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Semantics(
      header: true,
      label: node.label,
      value: '${node.children.length}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 25),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.rule)),
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                node.label,
                style: skin.typography.body.copyWith(color: tokens.ink),
              ),
            ),
            Text(
              '${node.children.length}',
              style: skin.typography.figure.copyWith(color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.node,
    required this.indent,
    required this.selected,
    required this.onOpen,
  });

  final TreeSheet node;
  final bool indent;
  final bool selected;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final value = node.built ? node.liveValue : 'Not built yet';
    return _TreeRow(
      route: node.route,
      label: node.label,
      semanticValue: value,
      selected: selected,
      onOpen: onOpen,
      actions: node.actions,
      child: Row(
        children: [
          if (indent) const SizedBox(width: 26),
          Expanded(
            child: Text(
              node.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.body.copyWith(
                color: node.built ? tokens.ink : tokens.muted,
              ),
            ),
          ),
          if (value != null)
            // The value keeps to the right edge; long values ellipsize.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style:
                    (node.built
                            ? skin.typography.figure
                            : skin.typography.small)
                        .copyWith(
                          color: node.liveValueIsActive
                              ? tokens.runInk
                              : tokens.muted,
                          fontWeight: node.liveValueIsActive
                              ? FontWeight.w700
                              : null,
                        ),
              ),
            ),
          if (node.needsYou > 0) ...[
            const SizedBox(width: 6),
            CountBadge(count: node.needsYou, semanticLabel: 'waiting'),
          ],
        ],
      ),
    );
  }
}

/// A selectable tree row: click opens, right-click lists what the node can
/// do. Selection is a filled row; focus is a ring.
final class _TreeRow extends StatefulWidget {
  const _TreeRow({
    required this.route,
    required this.label,
    required this.semanticValue,
    required this.selected,
    required this.onOpen,
    required this.child,
    this.background,
    this.actions = const [],
  });

  final String route;
  final String label;
  final String? semanticValue;
  final bool selected;
  final ValueChanged<String> onOpen;
  final Widget child;
  final Color? background;
  final List<TreeAction> actions;

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

final class _TreeRowState extends State<_TreeRow> {
  bool _focused = false;
  bool _hovered = false;

  Future<void> _showMenu(Offset position) async {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final choice = await showMenu<int>(
      context: context,
      color: tokens.paper,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(value: -1, child: Text('Open')),
        for (final (index, action) in widget.actions.indexed)
          PopupMenuItem(value: index, child: Text(action.label)),
      ],
    );
    switch (choice) {
      case -1:
        widget.onOpen(widget.route);
      case final int index:
        widget.actions[index].onSelected();
      case null:
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final fill = widget.selected
        ? tokens.selWash
        : _hovered
        ? Color.lerp(widget.background ?? tokens.paper, tokens.ink, 0.04)
        : widget.background;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        value: widget.semanticValue,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onOpen(widget.route);
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onOpen(widget.route),
            onSecondaryTapUp: (details) => _showMenu(details.globalPosition),
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 25),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: fill,
                  border: Border(bottom: BorderSide(color: tokens.rule)),
                ),
                foregroundDecoration: _focused
                    ? BoxDecoration(
                        border: Border.all(color: tokens.focus, width: 2),
                      )
                    : null,
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: widget.selected ? tokens.selInk : tokens.ink,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
