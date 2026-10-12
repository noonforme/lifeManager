import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

/// The banded toolbar with the spec's bands and a Find box in its trailing
/// slot. The width is narrow enough that the bands wrap.
final bandedToolbarDemo = GalleryDemo(
  id: 'shell/banded_toolbar',
  widget: 'BandedToolbar',
  summary:
      'Bands with painted grippers and etched lines; flat keys raised on '
      'hover or press; unavailable keys greyed in place. Wraps between and '
      'within bands; Find is an explicit editor in the trailing slot. The '
      'Enabled knob greys every key and the Find box; keys take no focus.',
  size: const Size(520, 200),
  build: (context, knobs) => _BandedToolbarDemo(knobs: knobs),
);

final class _BandedToolbarDemo extends StatefulWidget {
  const _BandedToolbarDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_BandedToolbarDemo> createState() => _BandedToolbarDemoState();
}

final class _BandedToolbarDemoState extends State<_BandedToolbarDemo> {
  final _find = TextEditingController();

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    void nothing() {}
    return SizedBox(
      width: 480,
      child: EraFormScope(
        labelWidth: 40,
        enabled: knobs.enabled,
        child: BandedToolbar(
          bands: [
            ToolbarBand(
              items: [
                ToolbarItem(
                  label: 'Back',
                  iconOnly: true,
                  leading: Orb(
                    glyph: OrbGlyph.back,
                    tone: knobs.enabled ? OrbTone.green : OrbTone.grey,
                  ),
                  onPressed: knobs.press(nothing),
                ),
                ToolbarItem(
                  label: 'Forward',
                  iconOnly: true,
                  leading: const Orb(
                    glyph: OrbGlyph.forward,
                    tone: OrbTone.grey,
                  ),
                  onPressed: null,
                ),
              ],
            ),
            ToolbarBand(
              items: [
                ToolbarItem(
                  label: 'Add',
                  leading: Orb(
                    glyph: OrbGlyph.add,
                    tone: knobs.enabled ? OrbTone.orange : OrbTone.grey,
                  ),
                  dropArrow: true,
                  onPressed: knobs.press(nothing),
                ),
              ],
            ),
            ToolbarBand(
              items: [
                ToolbarItem(
                  label: 'Save',
                  icon: EraIconKind.saveView,
                  tooltip: 'Save the pending changes',
                  onPressed: knobs.press(nothing),
                ),
                ToolbarItem(label: 'Undo', onPressed: knobs.press(nothing)),
                ToolbarItem(
                  label: 'Delete',
                  icon: EraIconKind.delete,
                  onPressed: knobs.press(nothing),
                ),
              ],
            ),
            ToolbarBand(
              items: [
                ToolbarItem(
                  label: knobs.text(
                    'Confirm worked days…',
                    'Confirm all worked days of the selected pay period…',
                  ),
                  onPressed: knobs.press(nothing),
                ),
                const ToolbarItem.separator(),
                ToolbarItem(
                  label: 'Mark as leave…',
                  onPressed: knobs.press(nothing),
                ),
                ToolbarItem(label: 'Correct…', onPressed: null),
              ],
            ),
            ToolbarBand(
              items: [
                ToolbarItem(
                  label: 'Filter',
                  iconOnly: true,
                  icon: EraIconKind.properties,
                  onPressed: knobs.press(nothing),
                ),
                ToolbarItem(
                  label: 'Sort',
                  dropArrow: true,
                  onPressed: knobs.press(nothing),
                ),
              ],
            ),
          ],
          trailingWidth: 260,
          trailing: EraField(
            controller: _find,
            label: 'Find',
            hint: 'Search',
            semanticLabel: 'Find',
          ),
        ),
      ),
    );
  }
}
