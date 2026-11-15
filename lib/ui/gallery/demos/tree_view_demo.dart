import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final treeViewDemo = GalleryDemo(
  id: 'data/tree_view',
  widget: 'TreeView',
  summary:
      'The object tree: dotted lines, boxed expanders, icons, live counts, '
      'a warning node and a muted folder of ended employments. Click selects '
      'or expands; no key does.',
  size: const Size(260, 320),
  build: (context, knobs) => GalleryValue<String?>(
    initial: 'night:shifts',
    builder: (context, selected, select) => SizedBox(
      width: 196 * knobs.textScale,
      height: 300 * knobs.textScale,
      child: TreeView(
        label: 'Object tree',
        selectedId: selected,
        onSelect: select,
        enabled: knobs.enabled,
        maxContentHeight: 300 * knobs.textScale,
        nodes: [
          TreeNodeData(
            id: 'night',
            label: knobs.text(
              'Night shifts',
              'Night shifts at the harbour logistics depot',
            ),
            icon: EraIconKind.employment,
            bold: true,
            expanded: true,
            children: [
              const TreeNodeData(
                id: 'night:calendar',
                label: 'Calendar',
                icon: EraIconKind.shift,
              ),
              const TreeNodeData(
                id: 'night:shifts',
                label: 'Shifts',
                icon: EraIconKind.shift,
                count: 12,
              ),
              const TreeNodeData(
                id: 'night:periods',
                label: 'Pay periods',
                icon: EraIconKind.payPeriod,
                count: 3,
              ),
              TreeNodeData(
                id: 'night:confirm',
                label: 'To confirm',
                icon: EraIconKind.warning,
                count: knobs.error ? 3 : null,
                warning: knobs.error,
              ),
              const TreeNodeData(
                id: 'night:off',
                label: 'Agreements (unavailable)',
                icon: EraIconKind.agreement,
                enabled: false,
              ),
            ],
          ),
          const TreeNodeData(
            id: 'ended',
            label: 'Ended employments',
            icon: EraIconKind.employment,
            count: 1,
            muted: true,
            children: [
              TreeNodeData(
                id: 'ended:old',
                label: 'Weekend cafe',
                icon: EraIconKind.employment,
                muted: true,
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
