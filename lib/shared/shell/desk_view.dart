import 'package:flutter/material.dart';

import '../../core/desks/desks.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/lifeos_tokens.dart';
import '../workbench/office_controls.dart';

/// What a tile shows: its heading, area (none for a sheet spanning areas)
/// and content, and where Open full size goes.
typedef DeskTileContent = ({
  String title,
  LifeOSArea? area,
  Widget body,
  String? fullSizeRoute,
});

/// Desk tabs with + Desk over the selected desk's tiles (shell spec 6.4).
final class DeskView extends StatelessWidget {
  const DeskView({
    required this.desks,
    required this.selected,
    required this.sheetNames,
    required this.tile,
    required this.onSelectDesk,
    required this.onNewDesk,
    required this.onRemoveTile,
    required this.onReplaceTile,
    required this.onAddSheet,
    required this.onLayout,
    required this.onRename,
    required this.onReset,
    required this.onDelete,
    required this.onOpen,
    this.views = const {},
    this.onAddView,
    super.key,
  });

  final List<Desk> desks;
  final Desk selected;

  /// Every sheet a tile can show, by key, with its display name.
  final Map<String, String> sheetNames;
  final DeskTileContent Function(DeskTile tile) tile;
  final ValueChanged<Desk> onSelectDesk;
  final VoidCallback onNewDesk;
  final void Function(DeskTile tile) onRemoveTile;
  final void Function(DeskTile tile, String sheetRef) onReplaceTile;
  final ValueChanged<String> onAddSheet;
  final ValueChanged<DeskLayout> onLayout;
  final VoidCallback onRename;
  final VoidCallback? onReset;
  final VoidCallback? onDelete;
  final ValueChanged<String> onOpen;

  /// Saved views that can be placed on the desk, by id, with their names.
  final Map<String, String> views;
  final ValueChanged<String>? onAddView;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return ColoredBox(
      color: tokens.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: 'Desk tabs',
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: tokens.chrome,
                border: Border(bottom: BorderSide(color: tokens.chromeLine)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedTabs(
                      labels: [for (final desk in desks) desk.name],
                      selectedIndex: desks.indexWhere(
                        (desk) => desk.id == selected.id,
                      ),
                      onSelected: (index) => onSelectDesk(desks[index]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  KeyButton(label: '+ Desk', onPressed: onNewDesk),
                  const SizedBox(width: 6),
                  _DeskMenu(
                    desk: selected,
                    sheetNames: sheetNames,
                    views: onAddView == null ? const {} : views,
                    skin: skin,
                    onAddSheet: onAddSheet,
                    onAddView: onAddView,
                    onLayout: onLayout,
                    onRename: onRename,
                    onReset: onReset,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: selected.tiles.isEmpty
                  ? Center(
                      child: Text(
                        'This desk is empty. Add a sheet from the desk menu.',
                        style: skin.typography.body.copyWith(
                          color: tokens.muted,
                        ),
                      ),
                    )
                  : _layout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layout(BuildContext context) {
    final tiles = selected.tiles.take(selected.layout.capacity).toList();
    Widget card(DeskTile tile) => _TileCard(
      key: ValueKey(tile.id),
      tile: tile,
      content: this.tile(tile),
      sheetNames: sheetNames,
      onRemove: () => onRemoveTile(tile),
      onReplace: (sheet) => onReplaceTile(tile, sheet),
      onOpen: onOpen,
    );
    const gap = SizedBox(width: 10, height: 10);
    return switch (selected.layout) {
      DeskLayout.single => card(tiles.first),
      DeskLayout.twoColumns => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, tile) in tiles.indexed) ...[
            if (index > 0) gap,
            Expanded(child: card(tile)),
          ],
        ],
      ),
      DeskLayout.mainAndSide => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: card(tiles.first)),
          if (tiles.length > 1) ...[
            gap,
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, tile) in tiles.skip(1).indexed) ...[
                    if (index > 0) gap,
                    Expanded(child: card(tile)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    };
  }
}

final class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.tile,
    required this.content,
    required this.sheetNames,
    required this.onRemove,
    required this.onReplace,
    required this.onOpen,
    super.key,
  });

  final DeskTile tile;
  final DeskTileContent content;
  final Map<String, String> sheetNames;
  final VoidCallback onRemove;
  final ValueChanged<String> onReplace;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final fullSize = content.fullSizeRoute;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${content.title} tile',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border.all(color: tokens.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: tokens.head,
              child: Row(
                children: [
                  if (content.area case final area?) ...[
                    AreaKey(area: area),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: skin.typography.label.copyWith(
                        color: tokens.headInk,
                      ),
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: PopupMenuButton<String>(
                      tooltip: 'Tile menu',
                      icon: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: tokens.headInk,
                      ),
                      onSelected: (choice) => switch (choice) {
                        'remove' => onRemove(),
                        'open' => fullSize == null ? null : onOpen(fullSize),
                        final sheet => onReplace(sheet),
                      },
                      itemBuilder: (context) => [
                        for (final MapEntry(key: sheet, value: name)
                            in sheetNames.entries)
                          if (tile.viewId != null || sheet != tile.sheetRef)
                            PopupMenuItem(
                              value: sheet,
                              child: Text('Replace with $name'),
                            ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'open',
                          enabled: fullSize != null,
                          child: const Text('Open full size'),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close ${content.title}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: tokens.headInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: content.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The desk's own menu: add a sheet, layout, rename, reset and delete.
final class _DeskMenu extends StatelessWidget {
  const _DeskMenu({
    required this.desk,
    required this.sheetNames,
    required this.views,
    required this.skin,
    required this.onAddSheet,
    required this.onAddView,
    required this.onLayout,
    required this.onRename,
    required this.onReset,
    required this.onDelete,
  });

  final Desk desk;
  final Map<String, String> sheetNames;
  final Map<String, String> views;
  final LifeOSSkinData skin;
  final ValueChanged<String> onAddSheet;
  final ValueChanged<String>? onAddView;
  final ValueChanged<DeskLayout> onLayout;
  final VoidCallback onRename;
  final VoidCallback? onReset;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    const layouts = {
      DeskLayout.single: 'Single',
      DeskLayout.twoColumns: 'Two columns',
      DeskLayout.mainAndSide: 'Main and side',
    };
    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<Object>(
        tooltip: 'Desk menu',
        onSelected: (choice) => switch (choice) {
          final DeskLayout layout => onLayout(layout),
          'rename' => onRename(),
          'reset' => onReset?.call(),
          'delete' => onDelete?.call(),
          _AddView(:final id) => onAddView?.call(id),
          final String sheet => onAddSheet(sheet),
          _ => null,
        },
        itemBuilder: (context) => [
          for (final MapEntry(key: sheet, value: name) in sheetNames.entries)
            PopupMenuItem(value: sheet, child: Text('Add $name')),
          for (final MapEntry(key: id, value: name) in views.entries)
            PopupMenuItem(value: _AddView(id), child: Text('Add view: $name')),
          const PopupMenuDivider(),
          for (final MapEntry(key: layout, value: name) in layouts.entries)
            CheckedPopupMenuItem(
              value: layout,
              checked: desk.layout == layout,
              child: Text('Layout: $name'),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'rename', child: Text('Rename desk…')),
          PopupMenuItem(
            value: 'reset',
            enabled: onReset != null,
            child: const Text('Reset starter desk'),
          ),
          PopupMenuItem(
            value: 'delete',
            enabled: onDelete != null,
            child: const Text('Delete desk'),
          ),
        ],
        child: IgnorePointer(
          child: KeyButton(label: 'Desk', onPressed: () {}),
        ),
      ),
    );
  }
}

/// The desk menu's choice to place a saved view.
final class _AddView {
  const _AddView(this.id);

  final String id;
}
