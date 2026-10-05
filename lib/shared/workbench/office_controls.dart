import 'package:flutter/widgets.dart';

import 'era_controls.dart';
import 'era_icons.dart';
import 'lifeos_skin.dart';
import 'lifeos_tokens.dart';
import 'millennium_style.dart';

/// The height of a popup menu row: the register's density, not a touch
/// target, and still above the 24-pixel minimum.
const menuRowHeight = 24.0;

/// A labelled key with a pressable bottom edge. Every action in LifeOS is a
/// visible key; the label is always shown.
final class KeyButton extends StatefulWidget {
  const KeyButton({
    required this.label,
    required this.onPressed,
    this.kind = KeyKind.secondary,
    this.leading,
    this.trailing,
    this.semanticLabel,
    super.key,
  });

  final String label;

  /// Announced instead of [label], for example "Back, unavailable".
  final String? semanticLabel;

  /// Null disables the key.
  final VoidCallback? onPressed;
  final KeyKind kind;
  final Widget? leading;

  /// Shown after the label, for example a drop arrow.
  final Widget? trailing;

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

final class _KeyButtonState extends State<KeyButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final kind = widget.kind;
    final surface = skin.painters.key(
      skin.tokens,
      kind,
      KeyState(
        enabled: _enabled,
        pressed: _pressed,
        hovered: _hovered,
        focused: _focused,
      ),
    );
    final rings = surface.rings;
    final face = Container(
      key: const ValueKey('key-face'),
      constraints: BoxConstraints(
        minHeight: kind == KeyKind.toolbar ? 30 : 24,
        // Dialog push buttons are at least 75 px wide, as the era's were
        // (XP-authentic shell spec 8.1); small and toolbar keys fit their
        // label.
        minWidth: kind == KeyKind.primary || kind == KeyKind.secondary
            ? 75
            : 24,
      ),
      padding: EdgeInsets.symmetric(horizontal: kind == KeyKind.small ? 7 : 10),
      decoration: surface.decoration,
      foregroundDecoration: rings == null
          ? null
          : InsetRings(rings.$1, rings.$2),
      // Centred in the 75 px minimum, and as wide as the label otherwise.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leading case final leading?) ...[
              leading,
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (kind == KeyKind.small
                            ? skin.typography.small
                            : skin.typography.body)
                        .copyWith(color: surface.ink),
              ),
            ),
            if (widget.trailing case final trailing?) ...[
              const SizedBox(width: 4),
              trailing,
            ],
          ],
        ),
      ),
    );
    // One merged node per key: label, button, enabled, focus and tap.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.semanticLabel ?? widget.label,
        child: FocusableActionDetector(
          enabled: _enabled,
          mouseCursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTapDown: _enabled ? (_) => _setPressed(true) : null,
            onTapUp: _enabled ? (_) => _setPressed(false) : null,
            onTapCancel: _enabled ? () => _setPressed(false) : null,
            onTap: widget.onPressed,
            child: ExcludeSemantics(
              child: _FocusRing(visible: _focused, child: face),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the skin's focus ring 2 pixels outside [child] without changing
/// its layout, so focus never shifts neighbouring controls.
final class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    final skin = LifeOSSkinScope.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('focus-ring'),
              decoration: skin.painters.focusRing(skin.tokens),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small key with a painted step arrow (◂ or ▸), for stepping through
/// periods or days. Announced by [semanticLabel].
final class StepKey extends StatelessWidget {
  const StepKey({
    required this.forward,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final bool forward;
  final String semanticLabel;

  /// Null greys the key: there is nothing in that direction.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return KeyButton(
      label: '',
      semanticLabel: semanticLabel,
      kind: KeyKind.small,
      leading: EraGlyph(
        forward ? EraGlyphKind.stepForward : EraGlyphKind.stepBack,
        color: onPressed == null ? tokens.muted : tokens.ink,
      ),
      onPressed: onPressed,
    );
  }
}

/// The painted icon that marks a record's area (XP-authentic shell spec 7).
/// Announced by the area's name.
final class AreaKey extends StatelessWidget {
  const AreaKey({required this.area, super.key});

  final LifeOSArea area;

  @override
  Widget build(BuildContext context) =>
      EraIcon(areaIcon(area), semanticLabel: area.label);
}

/// An orange count for something waiting on the owner, such as drafts or
/// due rows. [semanticLabel] says what is counted.
final class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.count,
    required this.semanticLabel,
    super.key,
  });

  final int count;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      label: '$count $semanticLabel',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: skin.painters.countBadge(skin.tokens),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            '$count',
            style: skin.typography.figure.copyWith(
              color: skin.painters.countBadgeInk(skin.tokens),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Property-sheet tabs (spec 5.5): inactive tabs are white-to-face, the
/// active tab is joined to the page with a warm top edge. Tabs hug their
/// labels and sit on a line the page continues.
final class PropertySheetTabs extends StatelessWidget {
  const PropertySheetTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: MillenniumColors.tabLine)),
    ),
    child: Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          for (var index = 0; index < labels.length; index++)
            _Tab(
              label: labels[index],
              selected: index == selectedIndex,
              onTap: () => onSelected(index),
            ),
        ],
      ),
    ),
  );
}

final class _Tab extends StatefulWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

final class _TabState extends State<_Tab> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final selected = widget.selected;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: ExcludeSemantics(
              child: Container(
                margin: EdgeInsets.only(top: selected ? 0 : 2, right: 1),
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: selected ? 5 : 4,
                ),
                decoration: BoxDecoration(
                  color: selected ? MillenniumColors.page : null,
                  gradient: selected
                      ? null
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [tokens.paper, tokens.chrome],
                        ),
                  border: Border(
                    top: BorderSide(
                      color: selected
                          ? MillenniumColors.tabAccent
                          : MillenniumColors.tabLine,
                      width: selected ? 2 : 1,
                    ),
                    left: const BorderSide(color: MillenniumColors.tabLine),
                    right: const BorderSide(color: MillenniumColors.tabLine),
                  ),
                ),
                foregroundDecoration: _focused
                    ? DottedFocusRectangle(color: tokens.focus)
                    : null,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skin.typography.body.copyWith(color: tokens.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
