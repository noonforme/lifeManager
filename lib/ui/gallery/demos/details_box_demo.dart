import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final detailsBoxDemo = GalleryDemo(
  id: 'shell/details_box',
  widget: 'DetailsBox',
  summary:
      'The Details box: facts, follow links and warnings that scroll on their '
      'own. Links are mouse-only; Enabled off makes them plain text. Error '
      'adds a warning.',
  size: const Size(300, 320),
  build: (context, knobs) => SizedBox(
    width: 240,
    height: 280,
    child: DetailsBox(
      caption: 'Details',
      sections: [
        DetailsSection(
          facts: [
            DetailsFact(
              'Agreement',
              knobs.text(
                'Pay from 2026-10-01',
                'Synthetic depot pay '
                    'agreement from 2026-10-01 (night premium included)',
              ),
              figure: false,
              onFollow: knobs.press(() {}),
            ),
            DetailsFact('Hourly rate', 'EUR 18.40'),
            const DetailsFact('Night premium', '+50 %'),
            DetailsFact(
              'Schedule',
              'Four on, three off',
              figure: false,
              onFollow: knobs.press(() {}),
            ),
          ],
        ),
        DetailsSection(
          title: 'October 2026',
          facts: const [
            DetailsFact('Finalized', '12'),
            DetailsFact('To confirm', '3'),
            DetailsFact('Next shift', 'Wed 2026-10-14 06:00'),
          ],
          warnings: [
            if (knobs.error)
              DetailsWarning('3 days to confirm', onFollow: knobs.press(() {})),
          ],
        ),
      ],
    ),
  ),
);
