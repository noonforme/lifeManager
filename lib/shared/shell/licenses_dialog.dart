import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Help › About › Licenses (XP-authentic shell spec 6.4): every package and
/// font with its licence, in a read-only white box.
final class LicensesDialog extends StatelessWidget {
  const LicensesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return EraDialog(
      title: 'Licenses',
      body: SizedBox(
        height: 360,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.paper,
            border: Border.all(color: MillenniumColors.fieldLine),
          ),
          child: FutureBuilder<List<LicenseEntry>>(
            future: LicenseRegistry.licenses.toList(),
            builder: (context, snapshot) {
              final entries = snapshot.data;
              if (entries == null) return const SizedBox.shrink();
              return ListView(
                padding: const EdgeInsets.all(6),
                children: [
                  for (final entry in entries) ...[
                    Text(
                      entry.packages.join(', '),
                      style: skin.typography.strong.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.paragraphs.map((p) => p.text).join('\n\n'),
                      style: skin.typography.small.copyWith(color: tokens.ink),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        KeyButton(
          label: 'OK',
          kind: KeyKind.primary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
