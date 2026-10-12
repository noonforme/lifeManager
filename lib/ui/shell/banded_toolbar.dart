import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../controls/era_controls.dart';
import '../controls/keys.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';

/// One command in a [ToolbarBand]: a flat toolbar key, or an etched
/// separator ([ToolbarItem.separator]) between groups inside a band.
///
/// A null [onPressed] greys the key where it stands, so a band never shifts
/// (database shell spec section 3). Callbacks are plain: when a command
/// depends on an open draft, the owner's callback flushes the editor first.
@immutable
final class ToolbarItem {
  const ToolbarItem({
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.tooltip,
    this.iconOnly = false,
    this.dropArrow = false,
  }) : isSeparator = false;

  /// An etched vertical line between two groups of keys in a band.
  const ToolbarItem.separator()
    : label = '',
      onPressed = null,
      icon = null,
      leading = null,
      tooltip = null,
      iconOnly = false,
      dropArrow = false,
      isSeparator = true;

  /// Shown beside the icon, and announced. Announced even when [iconOnly].
  final String label;

  /// Null disables the key (greyed in place; no tap, no hover paint).
  final VoidCallback? onPressed;

  /// A painted icon; drawn in greys while the key is unavailable.
  final EraIconKind? icon;

  /// A custom leading mark such as an [Orb]; used instead of [icon].
  final Widget? leading;

  /// The era's pale yellow note on hover. An [iconOnly] key defaults to its
  /// [label].
  final String? tooltip;

  /// Shows only the icon; the [label] stays as the semantic label and tip.
  final bool iconOnly;

  /// Adds the painted drop arrow after the label (a menu or list opens).
  final bool dropArrow;

  /// True for [ToolbarItem.separator].
  final bool isSeparator;
}

/// A group of [ToolbarItem]s that starts with a painted gripper, as a band
/// of an era toolbar does.
@immutable
final class ToolbarBand {
  const ToolbarBand({required this.items});

  final List<ToolbarItem> items;
}

/// The banded toolbar (database shell spec 3, 5): bands that start with a
/// dotted gripper and are split by etched lines; flat keys that rise on
/// hover or press; unavailable keys greyed in place.
///
/// **Reflow.** The toolbar never overflows. Bands wrap onto further rows,
/// and a band wider than the toolbar wraps its own keys within it
/// (measured, not clipped), so Save and Undo stay reachable at 800 x 600
/// and 200 % text. Long labels ellipsise only when a single key is wider
/// than the toolbar.
///
/// **No keyboard.** Keys are mouse commands: they take no focus and Enter or
/// Space never activates one (spec section 4.6). A "Tree" key that
/// AppFrame shows while the tree column is folded is an ordinary
/// [ToolbarItem] the caller puts in a band; the toolbar knows nothing of
/// AppFrame.
///
/// **Trailing slot.** [trailing] holds one caller-supplied widget, normally
/// a Find editor such as an `EraField`. It is an explicit hosted editor and
/// stays focusable; it is given a bounded width of [trailingWidth], narrowed
/// to the toolbar's width when that is smaller, and wraps onto its own row
/// when it does not fit beside the bands.
final class BandedToolbar extends StatelessWidget {
  const BandedToolbar({
    required this.bands,
    this.trailing,
    this.trailingWidth = 200,
    super.key,
  });

  final List<ToolbarBand> bands;
  final Widget? trailing;

  /// The width given to [trailing], at most the toolbar's own width.
  final double trailingWidth;

  static const _padding = 4.0;
  static const _gripperWidth = 9.0;
  static const _separatorWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.max(0.0, constraints.maxWidth - 2 * _padding);
        final slot = trailing;
        return DecoratedBox(
          decoration: skin.painters.toolbar(skin.tokens),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _padding,
                vertical: 2,
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (index, band) in bands.indexed)
                    _Band(
                      band: band,
                      available: available,
                      last: index == bands.length - 1 && slot == null,
                    ),
                  if (slot != null)
                    SizedBox(
                      width: math.min(trailingWidth, available),
                      child: slot,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _Band extends StatelessWidget {
  const _Band({
    required this.band,
    required this.available,
    required this.last,
  });

  final ToolbarBand band;
  final double available;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final fixed =
        BandedToolbar._gripperWidth +
        (last ? 0 : BandedToolbar._separatorWidth);
    // The most one key may take: the band's room less gripper and divider.
    final itemMax = math.max(0.0, available - fixed);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: available),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Gripper(),
          Flexible(
            // A band wider than the toolbar wraps within itself.
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final item in band.items)
                  if (item.isSeparator)
                    const _Etch()
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: itemMax),
                      child: _ToolbarKey(item: item),
                    ),
              ],
            ),
          ),
          if (!last) const _Etch(),
        ],
      ),
    );
  }
}

/// A band's key. Mouse only: it takes no focus, so no key activates it.
final class _ToolbarKey extends StatelessWidget {
  const _ToolbarKey({required this.item});

  final ToolbarItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final enabled = item.onPressed != null;
    final icon = item.icon;
    return ExcludeFocus(
      child: KeyButton(
        label: item.iconOnly ? '' : item.label,
        semanticLabel: item.label,
        kind: KeyKind.toolbar,
        tooltip: item.tooltip ?? (item.iconOnly ? item.label : null),
        leading:
            item.leading ??
            (icon == null ? null : EraIcon(icon, disabled: !enabled)),
        trailing: item.dropArrow
            ? EraGlyph(
                EraGlyphKind.dropDown,
                color: enabled ? tokens.ink : tokens.muted,
              )
            : null,
        onPressed: item.onPressed,
      ),
    );
  }
}

/// The painted dotted gripper that starts a band.
final class _Gripper extends StatelessWidget {
  const _Gripper();

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return ExcludeSemantics(
      child: SizedBox(
        width: BandedToolbar._gripperWidth,
        height: 24,
        child: CustomPaint(
          painter: _GripperPainter(tokens.muted, tokens.paper),
        ),
      ),
    );
  }
}

final class _GripperPainter extends CustomPainter {
  const _GripperPainter(this.dot, this.light);

  final Color dot;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = dot;
    final white = Paint()..color = light;
    for (var y = 2.0; y < size.height - 2; y += 3) {
      canvas
        ..drawRect(Rect.fromLTWH(3, y + 1, 2, 2), white)
        ..drawRect(Rect.fromLTWH(2, y, 2, 2), dark);
    }
  }

  @override
  bool shouldRepaint(_GripperPainter oldDelegate) =>
      oldDelegate.dot != dot || oldDelegate.light != light;
}

/// A vertical etched separator: a grey line beside a white one.
final class _Etch extends StatelessWidget {
  const _Etch();

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SizedBox(
          width: 2,
          height: 24,
          child: Row(
            children: [
              Container(width: 1, color: tokens.chromeLine),
              Container(width: 1, color: tokens.paper),
            ],
          ),
        ),
      ),
    );
  }
}
