import 'package:flutter/material.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/lifeos_tokens.dart';
import '../workbench/office_controls.dart';

/// One way to add a record from anywhere (shell spec 6.7).
final class QuickAddEntry {
  const QuickAddEntry({
    required this.area,
    required this.label,
    required this.open,
  });

  final LifeOSArea area;
  final String label;

  /// Null while the entry cannot be used, for example before an
  /// employment exists.
  final VoidCallback? open;
}

/// The toolbar's **+ Add** menu: every record type the shipped areas
/// support, with its area key.
final class QuickAddMenu extends StatelessWidget {
  const QuickAddMenu({required this.entries, super.key});

  final List<QuickAddEntry> entries;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    // The toolbar sits outside any Scaffold; the menu button needs its own
    // Material to anchor ink and the popup route.
    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<int>(
        tooltip: 'Add a record',
        onSelected: (index) => entries[index].open?.call(),
        itemBuilder: (context) => [
          for (final (index, entry) in entries.indexed)
            PopupMenuItem(
              value: index,
              enabled: entry.open != null,
              child: Row(
                children: [
                  AreaKey(area: entry.area, skin: skin),
                  const SizedBox(width: 8),
                  Text(entry.label),
                ],
              ),
            ),
        ],
        child: IgnorePointer(
          child: KeyButton(
            label: '+ Add',
            kind: KeyKind.primary,
            leading: Icon(Icons.add, size: 16, color: skin.tokens.paper),
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}
