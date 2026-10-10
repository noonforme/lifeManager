import 'package:flutter/material.dart';

import '../../ui/ui.dart';
import 'book_tree.dart';

@immutable
final class AddressCrumb {
  const AddressCrumb(this.label, [this.route]);

  final String label;
  final String? route;

  @override
  bool operator ==(Object other) =>
      other is AddressCrumb && other.label == label && other.route == route;

  @override
  int get hashCode => Object.hash(label, route);
}

/// One entry in the Address drop-down's location tree.
@immutable
final class AddressLocation {
  const AddressLocation(
    this.label,
    this.route, {
    this.depth = 0,
    this.icon,
    this.unbuilt = false,
  });

  final String label;
  final String route;
  final int depth;
  final EraIconKind? icon;

  /// An area not built yet, greyed as Books shows it.
  final bool unbuilt;

  @override
  bool operator ==(Object other) =>
      other is AddressLocation &&
      other.label == label &&
      other.route == route &&
      other.depth == depth &&
      other.icon == icon &&
      other.unbuilt == unbuilt;

  @override
  int get hashCode => Object.hash(label, route, depth, icon, unbuilt);
}

/// The Address drop-down's tree, from the same nodes as Books.
List<AddressLocation> addressTreeFrom(List<TreeNode> nodes) => [
  for (final node in nodes)
    ...switch (node) {
      TreeSheet(:final label, :final route) => [AddressLocation(label, route)],
      TreeGroup(:final children) => [
        for (final sheet in children) AddressLocation(sheet.label, sheet.route),
      ],
      TreeArea(:final area, :final route, :final built, :final children) => [
        AddressLocation(
          built ? area.label : '${area.label} (not built yet)',
          route,
          icon: areaIcon(area),
          unbuilt: !built,
        ),
        for (final sheet in children)
          AddressLocation(sheet.label, sheet.route, depth: 1),
      ],
    },
];

/// The Address bar (XP-authentic shell spec 6.3): the location as a path in
/// a combo box whose drop-down lists every location, and **Go**.
final class AddressBar extends StatelessWidget {
  const AddressBar({
    required this.crumbs,
    required this.tree,
    required this.onNavigate,
    required this.onGo,
    this.icon,
    this.comboKey,
    super.key,
  });

  /// Reaches the location combo, for F4 and Alt+D.
  final GlobalKey<EraComboState<int>>? comboKey;

  final List<AddressCrumb> crumbs;
  final List<AddressLocation> tree;
  final ValueChanged<String> onNavigate;
  final VoidCallback onGo;

  /// The current area's icon, shown before the path.
  final EraIconKind? icon;

  /// The tree with the current place in it, and that place's index. A
  /// sheet the tree does not list (Shifts) sits one step under its parent
  /// crumb, as the era's Address list opened down to where you are.
  (List<AddressLocation>, int) get _locations {
    final here = crumbs.lastOrNull;
    if (here == null) return (tree, -1);
    final exact = tree.indexWhere(
      (entry) => entry.label == here.label && entry.route == here.route,
    );
    if (exact >= 0) return (tree, exact);
    final parentCrumb = crumbs.length < 2 ? null : crumbs[crumbs.length - 2];
    final parent = parentCrumb == null
        ? -1
        : tree.indexWhere((entry) => entry.label == parentCrumb.label);
    if (parent >= 0 && here.route != null) {
      return (
        [
          ...tree.take(parent + 1),
          AddressLocation(
            here.label,
            here.route!,
            depth: tree[parent].depth + 1,
          ),
          ...tree.skip(parent + 1),
        ],
        parent + 1,
      );
    }
    return (tree, tree.indexWhere((entry) => entry.route == here.route));
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final body = skin.typography.body.copyWith(color: tokens.ink);
    final path = crumbs.map((crumb) => crumb.label).join(r'\');
    final (locations, current) = _locations;
    return Semantics(
      container: true,
      label: 'Address',
      explicitChildNodes: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: tokens.chrome,
          border: Border(bottom: BorderSide(color: tokens.chromeLine)),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Text('Address', style: body.copyWith(color: tokens.muted)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: EraCombo<int>(
                key: comboKey,
                semanticLabel: 'Address',
                semanticValue: crumbs.map((c) => c.label).join(', '),
                value: current,
                items: [
                  for (final (index, entry) in locations.indexed)
                    EraComboItem(
                      index,
                      entry.label,
                      icon: entry.icon,
                      depth: entry.depth,
                      muted: entry.unbuilt,
                    ),
                ],
                onSelected: (index) => onNavigate(locations[index].route),
                face: (context, focused) => Container(
                  constraints: const BoxConstraints(minHeight: 22),
                  padding: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: tokens.paper,
                    border: Border.all(color: MillenniumColors.fieldLine),
                  ),
                  child: Row(
                    children: [
                      if (icon case final icon?) ...[
                        EraIcon(icon),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: eraComboText(skin, focused: focused),
                          ),
                        ),
                      ),
                      const ComboArrow(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            KeyButton(
              label: 'Go',
              kind: KeyKind.small,
              tooltip: 'Open the place in the Address box again',
              leading: const Orb(
                glyph: OrbGlyph.forward,
                tone: OrbTone.green,
                size: 14,
              ),
              onPressed: onGo,
            ),
          ],
        ),
      ),
    );
  }
}
