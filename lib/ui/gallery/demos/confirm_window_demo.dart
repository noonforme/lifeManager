import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

enum _Answer { save, discard, keep }

/// The confirmation window shown inline at a bounded size: no route, no
/// barrier. The close key reports "Keep editing", the explicit cancel value.
final confirmWindowDemo = GalleryDemo(
  id: 'shell/confirm_window',
  widget: 'ConfirmWindow',
  summary:
      'The confirmation window: caption with a close key, a sign and message, '
      'and two or three keys that wrap; the first is the affirmative one and '
      'the close key chooses the explicit cancel value. Mouse only. Enabled '
      'off greys the keys and the close key; Error adds a failed-save line; '
      'Long text gives a message that scrolls and keys that wrap.',
  size: const Size(520, 300),
  build: (context, knobs) => SizedBox(
    width: 480,
    height: 260,
    child: GalleryValue<_Answer?>(
      initial: null,
      builder: (context, answer, update) => ConfirmWindow<_Answer>(
        title: 'Leave shift',
        message: [
          knobs.text(
            'Save your changes to shift 2026-10-07 before leaving the day?',
            'Save your changes to shift 2026-10-07 before leaving the day? '
                    'The synthetic plan changed End 19:00 to 19:45 and Break 0:30 '
                    'to 1:15; the day then needs confirming again. Discarding '
                    'keeps the saved shift as it was. ' *
                4,
          ),
          if (knobs.error) 'The last save failed: the synthetic store is busy.',
          if (answer != null) 'Chosen: ${answer.name}.',
        ].join('\n\n'),
        sign: knobs.error ? ConfirmSign.warning : ConfirmSign.info,
        choices: [
          ConfirmChoice(
            value: _Answer.save,
            label: knobs.text('Save', 'Save every change to this shift'),
          ),
          ConfirmChoice(
            value: _Answer.discard,
            label: knobs.text("Don't save", 'Discard every change and leave'),
          ),
          ConfirmChoice(value: _Answer.keep, label: 'Keep editing'),
        ],
        cancelValue: _Answer.keep,
        enabled: knobs.enabled,
        onChoose: update,
      ),
    ),
  ),
);
