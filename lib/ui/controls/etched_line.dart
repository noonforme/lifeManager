import 'package:flutter/widgets.dart';

import '../foundation/lifeos_skin.dart';

/// A 2 px etched separator: a grey line over a white one.
final class EtchedLine extends StatelessWidget {
  const EtchedLine({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: tokens.chromeLine),
          Container(height: 1, color: tokens.paper),
        ],
      ),
    );
  }
}
