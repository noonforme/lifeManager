import 'package:flutter/material.dart';

import '../workbench/era_controls.dart';
import '../workbench/era_icons.dart';
import '../workbench/era_menu.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/lifeos_tokens.dart';
import '../workbench/office_controls.dart';

/// One way to add a record from anywhere (shell spec 6.7).
final class QuickAddEntry {
  const QuickAddEntry({
    required this.area,
    required this.label,
    required this.open,
    this.icon,
  });

  final LifeOSArea area;
  final String label;

  /// The record kind's icon; the area's when null.
  final EraIconKind? icon;

  EraIconKind get shownIcon => icon ?? areaIcon(area);

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
    return EraMenuButton(
      tooltip: 'Add a record',
      items: [
        for (final entry in entries)
          EraMenuItem(entry.label, entry.open, icon: entry.shownIcon),
      ],
      builder: (context, toggle) => KeyButton(
        key: const ValueKey('quick-add'),
        label: 'Add',
        kind: KeyKind.toolbar,
        leading: const Orb(glyph: OrbGlyph.add, tone: OrbTone.orange),
        trailing: EraGlyph(EraGlyphKind.dropDown, color: skin.tokens.ink),
        onPressed: toggle,
      ),
    );
  }
}
