import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

/// Area tabs (24/27 px) and subform tabs (20/22 px), selected by id.
final tabStripDemo = GalleryDemo(
  id: 'shell/tab_strip',
  widget: 'TabStrip',
  summary:
      'Tabs selected by id: area tabs (24/27 px) and subform tabs (20/22 '
      'px), with an icon, a count, a disabled tab that explains why in its '
      'tooltip and a trailing caption. A tap only requests the tab; this '
      'demo grants it. Long text wraps a tab label and moves the caption '
      'onto its own line. Mouse only. The Enabled knob disables every tab.',
  size: const Size(520, 480),
  build: (context, knobs) => GalleryValue<String>(
    initial: 'agreements',
    builder: (context, selected, update) {
      final tabs = [
        TabItem(
          id: 'details',
          label: knobs.text('Details', 'Details of the pay agreement period'),
          icon: EraIconKind.properties,
          enabled: knobs.enabled,
          disabledReason: 'Switched off in this demo.',
        ),
        TabItem(
          id: 'agreements',
          label: 'Agreements',
          icon: EraIconKind.agreement,
          count: 3,
          countLabel: 'to confirm',
          enabled: knobs.enabled,
          disabledReason: 'Switched off in this demo.',
        ),
        const TabItem(
          id: 'history',
          label: 'History',
          enabled: false,
          disabledReason: 'No history until the record is saved.',
        ),
      ];
      final caption = Text(
        knobs.text('3 to confirm', '3 agreements to confirm before payday'),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 480,
            child: TabStrip(
              tabs: tabs,
              selectedId: selected,
              onSelect: update,
              trailing: caption,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 480,
            child: TabStrip(
              size: TabStripSize.subform,
              tabs: tabs,
              selectedId: selected,
              onSelect: update,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 200,
            child: TabStrip(
              size: TabStripSize.subform,
              tabs: tabs,
              selectedId: selected,
              onSelect: update,
              trailing: caption,
            ),
          ),
        ],
      );
    },
  ),
);
