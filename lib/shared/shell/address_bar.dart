import 'package:flutter/material.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_icons.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';
import '../workbench/office_controls.dart';
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
  const AddressLocation(this.label, this.route, {this.depth = 0, this.icon});

  final String label;
  final String route;
  final int depth;
  final EraIconKind? icon;

  @override
  bool operator ==(Object other) =>
      other is AddressLocation &&
      other.label == label &&
      other.route == route &&
      other.depth == depth &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(label, route, depth, icon);
}

/// The Address drop-down's tree, from the same nodes as Books.
List<AddressLocation> addressTreeFrom(List<TreeNode> nodes) => [
  for (final node in nodes)
    ...switch (node) {
      TreeSheet(:final label, :final route) => [AddressLocation(label, route)],
      TreeGroup(:final children) => [
        for (final sheet in children) AddressLocation(sheet.label, sheet.route),
      ],
      TreeArea(:final area, :final route, :final children) => [
        AddressLocation(area.label, route, icon: areaIcon(area)),
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
    super.key,
  });

  final List<AddressCrumb> crumbs;
  final List<AddressLocation> tree;
  final ValueChanged<String> onNavigate;
  final VoidCallback onGo;

  /// The current area's icon, shown before the path.
  final EraIconKind? icon;

  Future<void> _openTree(BuildContext fieldContext) async {
    final box = fieldContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset(0, box.size.height));
    final here = crumbs.lastOrNull?.route;
    final chosen = await showMenu<String>(
      context: fieldContext,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        origin.dx + box.size.width,
        origin.dy,
      ),
      constraints: BoxConstraints.tightFor(width: box.size.width),
      items: [
        for (final entry in tree)
          PopupMenuItem<String>(
            height: menuRowHeight,
            value: entry.route,
            child: Padding(
              padding: EdgeInsets.only(left: entry.depth * 16.0),
              child: Row(
                children: [
                  if (entry.icon case final icon?) ...[
                    EraIcon(icon),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    entry.label,
                    style: entry.route == here
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (chosen != null) onNavigate(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final body = skin.typography.body.copyWith(color: tokens.ink);
    final path = crumbs.map((crumb) => crumb.label).join(r'\');
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
              child: Builder(
                builder: (fieldContext) => EraPressable(
                  label: 'Address, ${crumbs.map((c) => c.label).join(', ')}',
                  onPressed: () => _openTree(fieldContext),
                  child: Container(
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
                          child: Text(
                            path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body,
                          ),
                        ),
                        const ComboArrow(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            KeyButton(
              label: 'Go',
              kind: KeyKind.small,
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
