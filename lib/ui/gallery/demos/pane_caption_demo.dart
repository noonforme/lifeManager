import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

/// Pane captions: plain, with passive trailing content and actions, and a
/// long title that wraps while Close stays visible.
final paneCaptionDemo = GalleryDemo(
  id: 'shell/pane_caption',
  widget: 'PaneCaption',
  summary:
      'The caption over a pane: icon, title, passive trailing content, '
      'icon-only mouse actions and Close. The title wraps; Close stays '
      'visible. Nothing in it takes keyboard focus. The Enabled knob greys '
      'the actions and removes Close.',
  size: const Size(520, 300),
  build: (context, knobs) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 240,
        child: PaneCaption(
          icon: EraIconKind.work,
          title: 'Work',
          onClose: knobs.enabled ? () {} : null,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 240,
        child: PaneCaption(
          icon: EraIconKind.employment,
          title: 'Details',
          trailing: const CountBadge(count: 3, semanticLabel: 'to confirm'),
          actions: [
            PaneCaptionAction(
              icon: EraIconKind.properties,
              semanticLabel: 'Properties',
              onPressed: knobs.press(() {}),
            ),
          ],
          onClose: knobs.enabled ? () {} : null,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 160,
        child: PaneCaption(
          icon: EraIconKind.agreement,
          title: knobs.text(
            'Agreement',
            'Pay agreement from 2026-10-01 for Synthetic depot',
          ),
          actions: [
            PaneCaptionAction(
              icon: EraIconKind.add,
              semanticLabel: 'Add agreement',
              onPressed: knobs.press(() {}),
            ),
          ],
          onClose: knobs.enabled ? () {} : null,
        ),
      ),
    ],
  ),
);
