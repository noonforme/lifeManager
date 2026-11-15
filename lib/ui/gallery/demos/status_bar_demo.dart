import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final statusBarDemo = GalleryDemo(
  id: 'shell/status_bar',
  widget: 'StatusBar',
  summary:
      'The status bar: a notice, sunken panels, run-ink warning text and a '
      'decorative size grip. Reflows by measured text; has no commands, so '
      'Enabled changes nothing. Error adds the warning.',
  size: const Size(640, 140),
  build: (context, knobs) => SizedBox(
    width: 600,
    child: StatusBar(
      notice: knobs.text(
        'Saved shift 2026-10-07.',
        'Unsaved plan change: 2026-10-07, End 19:00 → 19:45. Save, or leave '
            'the day, to keep it. Confirmation is separate.',
      ),
      panels: const [
        StatusPanel('15 shifts'),
        StatusPanel('Paid 112:30'),
        StatusPanel('Est. pay EUR 2,070.00'),
        StatusPanel('Local database'),
      ],
      warning: knobs.error ? '3 days to confirm' : null,
    ),
  ),
);
