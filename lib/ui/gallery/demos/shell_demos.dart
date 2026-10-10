import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

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
  GalleryDemo(
    id: 'shell/inspector_pane',
    widget: 'InspectorPane',
    summary: 'A scrolling Properties page on the inspector inset.',
    size: const Size(480, 280),
    build: (context, knobs) => SizedBox(
      width: 340,
      height: 240,
      child: InspectorPane(
        children: [
          const InspectorTitle(
            'Synthetic depot',
            meta: 'Employment',
            icon: EraIconKind.employment,
          ),
          const InspectorFacts([
            Fact('Hourly rate', 'EUR 18.40'),
            Fact('Night premium', '+50 %'),
          ], legend: 'Pay'),
          InspectorNote(
            knobs.text(
              'Defaults follow the agreement.',
              'Defaults follow the pay agreement; change it from Agreements.',
            ),
          ),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/dialog_form',
    widget: 'DialogForm',
    summary: 'Form fields that scroll above keys pinned bottom-right.',
    size: const Size(480, 280),
    build: (context, knobs) => SizedBox(
      width: 380,
      height: 220,
      child: DialogForm(
        fields: const [
          EraLabelled(label: 'Hourly rate (€)', field: Text('18.40')),
          EraLabelled(label: 'Basis', field: Text('Gross')),
        ],
        keys: [
          KeyButton(
            label: 'Save agreement',
            kind: KeyKind.primary,
            onPressed: knobs.press(() {}),
          ),
          KeyButton(label: 'Cancel', onPressed: knobs.press(() {})),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_title',
    widget: 'InspectorTitle',
    summary: "A record's name, kind and icon atop a Properties page.",
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorTitle(
        knobs.text(
          'Shift 2026-10-07',
          'Shift on Wednesday 2026-10-07, Synthetic depot',
        ),
        meta: 'To confirm',
        icon: EraIconKind.shift,
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_facts',
    widget: 'InspectorFacts',
    summary: 'A block of "Label:" facts closed by an etched line.',
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorFacts([
        const Fact('Paid time', '12:15'),
        const Fact('Est. pay', 'EUR 225.40'),
        Fact(
          'Difference',
          '+0:45',
          tone: knobs.error ? FactTone.negative : FactTone.positive,
        ),
      ], legend: 'Pay'),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_fact_row',
    widget: 'InspectorFactRow',
    summary: 'One "Label:" fact row.',
    build: (context, knobs) => const SizedBox(
      width: 340,
      child: InspectorFactRow(fact: Fact('Hourly rate', 'EUR 18.40')),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_note',
    widget: 'InspectorNote',
    summary: 'A secondary line under the facts; red when negative.',
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorNote(
        knobs.text(
          'Finalized. Use Correct… to change it.',
          'Finalized on 2026-10-06. Use Correct… to void it and record a '
              'replacement.',
        ),
        tone: knobs.error ? FactTone.negative : null,
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_text',
    widget: 'InspectorText',
    summary: 'Body text that is the content itself.',
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorText(
        knobs.text(
          'Defaults follow the Lithuanian Labour Code minimums.',
          'Defaults follow the Lithuanian Labour Code minimums. They are '
              'defaults, not legal advice.',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/inspector_actions',
    widget: 'InspectorActions',
    summary: "A record's keys at the foot of a page, right-aligned.",
    build: (context, knobs) => SizedBox(
      width: 340,
      child: InspectorActions(
        children: [
          KeyButton(label: 'Correct…', onPressed: knobs.press(() {})),
          KeyButton(label: 'History', onPressed: knobs.press(() {})),
        ],
      ),
    ),
  ),
  GalleryDemo(
    id: 'shell/property_sheet_scope',
    widget: 'PropertySheetScope',
    summary:
        "Gives a Properties sheet's OK, Cancel and Apply keys their edit "
        'state.',
    build: (context, knobs) => const _PropertySheetDemo(),
  ),
];

final class _PropertySheetDemo extends StatefulWidget {
  const _PropertySheetDemo();

  @override
  State<_PropertySheetDemo> createState() => _PropertySheetDemoState();
}

final class _PropertySheetDemoState extends State<_PropertySheetDemo> {
  final _sheet = PropertySheetController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PropertySheetScope(
    controller: _sheet,
    child: ListenableBuilder(
      listenable: _sheet,
      builder: (context, _) => Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EraCheckBox(
            value: _sheet.dirty,
            onChanged: _sheet.markDirty,
            label: 'A field has changed',
          ),
          KeyButton(label: 'Apply', onPressed: _sheet.dirty ? () {} : null),
        ],
      ),
    ),
  );
}
