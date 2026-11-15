import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

/// The filter band over a sheet, with the Shifts sheet's controls: a
/// period between step keys, a status, Off days and Clear. Narrow, it
/// wraps; Clear stays at the right.
final filterStripDemo = GalleryDemo(
  id: 'shell/filter_strip',
  widget: 'FilterStrip',
  summary:
      'The filter band over a sheet: labelled controls left to right, Clear '
      'at the right. Narrower than its items, they wrap onto further rows. '
      'The Enabled knob greys Clear; Long text lengthens a status.',
  size: const Size(720, 320),
  build: (context, knobs) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _strip(knobs, width: 680),
      const SizedBox(height: 12),
      _strip(knobs, width: 320),
    ],
  ),
);

Widget _strip(GalleryKnobs knobs, {required double width}) => SizedBox(
  width: width * knobs.textScale,
  child: FilterStrip(
    enabled: knobs.enabled,
    onClear: () {},
    items: [
      FilterStripItem(
        label: 'Period',
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StepKey(
              forward: false,
              semanticLabel: 'Previous period',
              onPressed: knobs.enabled ? () {} : null,
            ),
            EraCombo<String>(
              items: const [
                EraComboItem('2026-10', 'October 2026'),
                EraComboItem('2026-11', 'November 2026'),
              ],
              value: '2026-10',
              onSelected: (_) {},
              semanticLabel: 'Period',
            ),
            StepKey(
              forward: true,
              semanticLabel: 'Next period',
              onPressed: knobs.enabled ? () {} : null,
            ),
          ],
        ),
      ),
      FilterStripItem(
        label: 'Status',
        child: EraCombo<String>(
          items: [
            const EraComboItem('all', 'All'),
            EraComboItem(
              'effective',
              knobs.text('Effective', 'Effective, without void shifts'),
            ),
          ],
          value: 'effective',
          onSelected: (_) {},
          semanticLabel: 'Status',
        ),
      ),
      FilterStripItem(
        child: EraCheckBox(value: true, onChanged: (_) {}, label: 'Off days'),
      ),
    ],
  ),
);
