import 'package:flutter/widgets.dart';

import '../controls/keys.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/lifeos_tokens.dart';

/// One labelled control of a [FilterStrip]: "Label:" then [child]. Without
/// a label (a check box that carries its own), the control alone.
@immutable
final class FilterStripItem {
  const FilterStripItem({required this.child, this.label, this.editor = false});

  final String? label;
  final Widget child;

  /// A data-entry control (a date box) that keeps keyboard focus (spec
  /// 4.6). Every other item is mouse only: it never takes focus, so no
  /// key changes a filter.
  final bool editor;
}

/// The filter band over a sheet (database shell spec 3): a face-coloured
/// strip, at least [LifeOSMetrics.paneHeader] tall (scaled with the text),
/// so the grid under it starts level with the boxes of the other columns,
/// with its items left to right
/// and a Clear key at the right. Items wrap onto further rows when the
/// width runs out; Clear stays at the right of the first row. Mouse only
/// (spec 4.6): Clear and every item take no keyboard focus, except items
/// marked [FilterStripItem.editor] (a date box), which keep their own
/// keyboard rules.
final class FilterStrip extends StatelessWidget {
  const FilterStrip({
    required this.items,
    this.onClear,
    this.clearLabel = 'Clear',
    this.enabled = true,
    super.key,
  });

  final List<FilterStripItem> items;

  /// Resets every filter; null greys Clear (nothing is set).
  final VoidCallback? onClear;
  final String clearLabel;

  /// False greys Clear.
  final bool enabled;

  static const _gap = 8.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 6, vertical: 2);

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: LifeOSMetrics.paneHeader * scale,
        ),
        child: Padding(
          padding: _padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: _gap,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Too narrow for both, an item's label goes above
                    // its control.
                    for (final item in items)
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.label case final label?) Text('$label:'),
                          ExcludeFocus(
                            excluding: !item.editor,
                            child: item.child,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: _gap),
              ExcludeFocus(
                child: KeyButton(
                  label: clearLabel,
                  onPressed: enabled ? onClear : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
