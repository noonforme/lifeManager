import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

/// Two splitters, one per axis, in a parent that clamps and applies them.
final splitterDemo = GalleryDemo(
  id: 'shell/splitter',
  widget: 'Splitter',
  summary:
      'The 5 px draggable divider, one per axis. The parent applies and '
      'clamps the reported offset; dragging past a clamp and back is '
      'reversible. Mouse only. It has no disabled state, so the Enabled '
      'knob does not apply.',
  build: (context, knobs) => const _SplitterDemo(),
);

final class _SplitterDemo extends StatefulWidget {
  const _SplitterDemo();

  @override
  State<_SplitterDemo> createState() => _SplitterDemoState();
}

final class _SplitterDemoState extends State<_SplitterDemo> {
  static const _width = 440.0;
  static const _height = 200.0;
  double _left = 150;
  double _top = 80;
  double _leftAtPress = 150;
  double _topAtPress = 80;

  double _clamp(double value, double total) =>
      math.max(40.0, math.min(total - 40.0 - Splitter.thickness, value));

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    Widget pane(String text) => ColoredBox(
      color: tokens.paper,
      child: Center(child: Text(text)),
    );
    return SizedBox(
      width: _width,
      height: _height,
      child: Row(
        children: [
          SizedBox(width: _left, child: pane('Left ${_left.round()} px')),
          Splitter(
            axis: Axis.horizontal,
            semanticLabel: 'Resize left pane',
            onDragStart: () => _leftAtPress = _left,
            onDrag: (offset) =>
                setState(() => _left = _clamp(_leftAtPress + offset, _width)),
          ),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: _top,
                  child: Center(child: Text('Top ${_top.round()} px')),
                ),
                Splitter(
                  axis: Axis.vertical,
                  semanticLabel: 'Resize top pane',
                  onDragStart: () => _topAtPress = _top,
                  onDrag: (offset) => setState(
                    () => _top = _clamp(_topAtPress + offset, _height),
                  ),
                ),
                Expanded(child: pane('Bottom')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
