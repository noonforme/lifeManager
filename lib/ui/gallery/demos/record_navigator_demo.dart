import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final recordNavigatorDemo = GalleryDemo(
  id: 'data/record_navigator',
  widget: 'RecordNavigator',
  summary:
      'First, previous, "3 of 12", next, last and new, with a wrapped '
      'filter note.',
  size: const Size(480, 200),
  build: (context, knobs) => _RecordNavigatorDemo(knobs: knobs),
);

final class _RecordNavigatorDemo extends StatefulWidget {
  const _RecordNavigatorDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_RecordNavigatorDemo> createState() => _RecordNavigatorDemoState();
}

final class _RecordNavigatorDemoState extends State<_RecordNavigatorDemo> {
  int _position = 3;
  int _count = 12;

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RecordNavigator(
          label: 'Shifts',
          position: _position,
          count: _count,
          onGo: knobs.enabled
              ? (target) => setState(() => _position = target)
              : null,
          // New appends a record and selects it.
          onNew: knobs.press(() => setState(() => _position = ++_count)),
          note: knobs.text(
            'Filtered: open shifts',
            'Filtered: open shifts in October 2026 for the night team, '
                'excluding planned and cancelled days',
          ),
        ),
        const SizedBox(height: 12),
        const RecordNavigator(label: 'Expenses', position: 0, count: 0),
        const SizedBox(height: 12),
        RecordNavigator(
          label: 'Tasks',
          position: 0,
          count: 5,
          onGo: knobs.enabled ? (_) {} : null,
        ),
      ],
    );
  }
}
