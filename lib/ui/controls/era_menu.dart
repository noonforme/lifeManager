import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';
import 'era_controls.dart';
import 'keys.dart';

/// The era menu panel: white, a 1 px grey edge and a 2 px inset, sized to
/// its items. Depth is bevels only, so it has no shadow.
MenuStyle eraMenuStyle(LifeOSSkinData skin) => MenuStyle(
  backgroundColor: WidgetStatePropertyAll(skin.tokens.paper),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  elevation: const WidgetStatePropertyAll(0),
  side: const WidgetStatePropertyAll(
    BorderSide(color: MillenniumColors.menuEdge),
  ),
  shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
  padding: const WidgetStatePropertyAll(EdgeInsets.all(2)),
  visualDensity: VisualDensity.standard,
);

/// A menu row: a 16 px gutter for its icon or check, then its text;
/// selection blue with white text while hovered or keyboard-lit, grey when
/// disabled, bold for the default command. [padding] widens it for
/// menu-bar titles, which have no gutter.
ButtonStyle eraMenuItemStyle(
  LifeOSSkinData skin, {
  bool bold = false,
  EdgeInsetsGeometry padding = const EdgeInsetsDirectional.only(
    start: 2,
    end: 20,
  ),
}) {
  final t = skin.tokens;
  bool lit(Set<WidgetState> states) =>
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused);
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(
      bold
          ? skin.typography.body.copyWith(fontWeight: FontWeight.w700)
          : skin.typography.body,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? t.muted
          : lit(states)
          ? t.selInk
          : t.ink,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => !states.contains(WidgetState.disabled) && lit(states)
          ? t.selWash
          : Colors.transparent,
    ),
    // The theme's grey hover wash would sit over the selection blue.
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
    // The selection band moves with the pointer at once; motion is
    // immediate.
    animationDuration: Duration.zero,
    minimumSize: const WidgetStatePropertyAll(Size(0, menuRowHeight)),
    // Era menus are dense: no padding up to a touch target. Standard
    // density, or compact would take 8 px off the 24 px row.
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    padding: WidgetStatePropertyAll(padding),
    shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
  );
}

/// One row of an era menu, or a separator.
final class EraMenuItem {
  const EraMenuItem(
    this.label,
    this.onSelected, {
    this.isDefault = false,
    this.icon,
    this.checked = false,
  }) : separator = false;

  /// The era's etched line between groups of rows.
  const EraMenuItem.separator()
    : label = '',
      onSelected = null,
      isDefault = false,
      icon = null,
      checked = false,
      separator = true;

  final String label;

  /// Null shows the row grey and inert.
  final VoidCallback? onSelected;

  /// Bold: the command a double-click or Enter runs.
  final bool isDefault;

  /// Painted in the gutter before the text.
  final EraIconKind? icon;

  /// A check in the gutter, for a setting that is on.
  final bool checked;
  final bool separator;
}

/// The row's gutter (icon or check) and text, for a [MenuItemButton].
final class EraMenuLabel extends StatelessWidget {
  const EraMenuLabel(this.item, {super.key});

  final EraMenuItem item;

  @override
  Widget build(BuildContext context) {
    final ink = DefaultTextStyle.of(context).style.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          child: switch (item) {
            EraMenuItem(checked: true) => Center(
              child: EraGlyph(EraGlyphKind.tick, color: ink ?? Colors.black),
            ),
            EraMenuItem(:final icon?) => EraIcon(
              icon,
              disabled: item.onSelected == null,
            ),
            _ => null,
          },
        ),
        const SizedBox(width: 6),
        Text(item.label),
      ],
    );
  }
}

/// The rows of an era menu panel; [focusNodes] lines up with [items].
List<Widget> eraMenuRows(
  LifeOSSkinData skin,
  List<EraMenuItem> items, {
  List<FocusNode>? focusNodes,
}) => [
  for (final (index, item) in items.indexed)
    if (item.separator)
      const _EraMenuSeparator()
    else
      MenuItemButton(
        focusNode: focusNodes?[index],
        style: eraMenuItemStyle(skin, bold: item.isDefault),
        onPressed: item.onSelected,
        child: EraMenuLabel(item),
      ),
];

/// The era's etched line: a grey rule over a white one, inset from the
/// panel's sides.
final class _EraMenuSeparator extends StatelessWidget {
  const _EraMenuSeparator();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 1, vertical: 3),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MillenniumColors.menuEdge),
          bottom: BorderSide(color: Color(0xffffffff)),
        ),
      ),
      child: SizedBox(height: 0, width: double.infinity),
    ),
  );
}

/// A key that drops an era menu, as the toolbar's **Add** and a desk's
/// **Desk** key do. [builder] draws the key and calls its toggle.
final class EraMenuButton extends StatefulWidget {
  const EraMenuButton({
    required this.items,
    required this.builder,
    this.tooltip,
    super.key,
  });

  final List<EraMenuItem> items;
  final Widget Function(BuildContext context, VoidCallback toggle) builder;
  final String? tooltip;

  @override
  State<EraMenuButton> createState() => _EraMenuButtonState();
}

final class _EraMenuButtonState extends State<EraMenuButton> {
  final _controller = MenuController();

  void _toggle() =>
      _controller.isOpen ? _controller.close() : _controller.open();

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return MenuAnchor(
      controller: _controller,
      style: eraMenuStyle(skin),
      consumeOutsideTap: true,
      menuChildren: eraMenuRows(skin, widget.items),
      builder: (context, controller, child) {
        final key = widget.builder(context, _toggle);
        final tooltip = widget.tooltip;
        return tooltip == null ? key : Tooltip(message: tooltip, child: key);
      },
    );
  }
}

/// Hosts the era right-click menu over [child]: [EraContextMenuState.show]
/// opens it at once with its corner at the pointer, as in the era. Down
/// lights the first row; Esc or a click outside closes it, and focus goes
/// back to where it was in [child].
final class EraContextMenu extends StatefulWidget {
  const EraContextMenu({required this.child, super.key});

  final Widget child;

  @override
  State<EraContextMenu> createState() => EraContextMenuState();
}

final class EraContextMenuState extends State<EraContextMenu> {
  final _controller = MenuController();

  /// Holds focus while no row is lit, so the keyboard reaches the menu.
  final _panel = FocusNode(debugLabel: 'EraContextMenu');
  List<EraMenuItem> _items = const [];
  List<FocusNode> _rows = const [];

  @override
  void dispose() {
    _panel.dispose();
    _disposeRows();
    super.dispose();
  }

  void _disposeRows() {
    for (final row in _rows) {
      row.dispose();
    }
  }

  /// Down lights the first row and Up the last, as in the era; once a row
  /// is lit, the menu moves between rows itself.
  KeyEventResult _onPanelKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final enabled = [
      for (final (index, item) in _items.indexed)
        if (!item.separator && item.onSelected != null) _rows[index],
    ];
    if (enabled.isEmpty) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      enabled.first.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      enabled.last.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Opens [items] with the menu's top-left corner at [globalPosition].
  void show(Offset globalPosition, List<EraMenuItem> items) {
    if (items.isEmpty) return;
    final box = context.findRenderObject()! as RenderBox;
    // The old rows are gone from the tree once this rebuild lands.
    final old = _rows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in old) {
        row.dispose();
      }
    });
    setState(() {
      _items = items;
      _rows = [for (final item in items) FocusNode(debugLabel: item.label)];
    });
    _controller.open(position: box.globalToLocal(globalPosition));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isOpen) _panel.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    // The menu hangs from a point at the area's corner, not from [child]:
    // an anchor's child counts as inside the menu, so a click on [child]
    // would not close it.
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          child: MenuAnchor(
            controller: _controller,
            style: eraMenuStyle(skin),
            // A click outside only closes the menu, as in the era.
            consumeOutsideTap: true,
            menuChildren: [
              Focus(
                focusNode: _panel,
                skipTraversal: true,
                onKeyEvent: _onPanelKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...eraMenuRows(skin, _items, focusNodes: _rows)],
                ),
              ),
            ],
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
