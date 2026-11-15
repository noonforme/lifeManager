import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';
import 'banded_toolbar_demo.dart';
import 'filter_strip_demo.dart';
import 'pane_caption_demo.dart';
import 'splitter_demo.dart';
import 'tab_strip_demo.dart';

final shellDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'shell/era_dialog',
    widget: 'EraDialog',
    summary:
        'An era window: blue caption, red close key, keys bottom-right. The '
        'base of the coming confirmation window. Its close key always works, '
        'as in the era.',
    size: const Size(600, 380),
    build: (context, knobs) => SizedBox(
      width: 560,
      height: 340,
      child: EraDialog(
        title: knobs.text(
          'Delete record?',
          'Delete this unused synthetic record?',
        ),
        body: const Text('This unused synthetic record will be deleted.'),
        actions: [
          KeyButton(
            label: 'Delete',
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
          KeyButton(label: 'Cancel', onPressed: knobs.press(() {})),
        ],
        onClose: () {},
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/era_movable_dialog',
    widget: 'EraMovableDialog',
    summary:
        'Lets a dialog be dragged by its caption, kept inside its space.'
        ' Its close key always works, as in the era.',
    size: const Size(600, 380),
    build: (context, knobs) => SizedBox(
      width: 560,
      height: 340,
      // EraDialog supplies the EraMovableDialog under test. Do not nest a
      // second movable shell around a dialog that expands to its bounds.
      child: EraDialog(
        title: 'Drag the caption',
        body: const Text('The window stays inside this area.'),
        actions: [
          KeyButton(
            label: 'OK',
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/caption_bar',
    widget: 'CaptionBar',
    summary: 'The blue gradient caption with a title and a red close key.',
    build: (context, knobs) => SizedBox(
      width: 320,
      child: CaptionBar(
        title: knobs.text(
          'Pay agreement',
          'Pay agreement from 2026-10-01 for Synthetic depot',
        ),
        onClose: knobs.press(() {}),
      ),
    ),
  ),
  bandedToolbarDemo,
  filterStripDemo,
  paneCaptionDemo,
  splitterDemo,
  tabStripDemo,
];
