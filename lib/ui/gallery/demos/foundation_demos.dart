import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final foundationDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'foundation/lifeos_skin_scope',
    widget: 'LifeOSSkinScope',
    summary:
        'Provides tokens, type and key painting to every LifeOS widget '
        'below it.',
    build: (context, knobs) => LifeOSSkinScope(
      child: Builder(
        builder: (context) {
          final t = LifeOSSkinScope.of(context).tokens;
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (name, colour) in [
                ('ground', t.ground),
                ('paper', t.paper),
                ('ink', t.ink),
                ('muted', t.muted),
                ('chrome', t.chrome),
                ('head', t.head),
                ('signal', t.signal),
                ('selWash', t.selWash),
                ('negative', t.negative),
                ('positive', t.positive),
              ])
                _Swatch(name: name, colour: colour),
            ],
          );
        },
      ),
    ),
  ),
  GalleryDemo(
    id: 'foundation/era_icon',
    widget: 'EraIcon',
    summary: 'The painted 16 and 32 px icon set; greyed when disabled.',
    build: (context, knobs) => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final kind in EraIconKind.values) ...[
          EraIcon(kind, disabled: !knobs.enabled),
          EraIcon(kind, size: 32, disabled: !knobs.enabled),
        ],
      ],
    ),
  ),
];

final class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.colour});

  final String name;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return SizedBox(
      width: 76,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: colour,
              border: Border.all(color: skin.tokens.chromeLine),
            ),
          ),
          Text(name, style: skin.typography.small),
        ],
      ),
    );
  }
}
