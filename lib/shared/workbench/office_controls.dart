import 'package:flutter/widgets.dart';

import 'lifeos_skin.dart';
import 'lifeos_tokens.dart';

/// A labelled key with a pressable bottom edge. Every action in LifeOS is a
/// visible key; the label is always shown.
final class KeyButton extends StatefulWidget {
  const KeyButton({
    required this.label,
    required this.onPressed,
    this.kind = KeyKind.secondary,
    this.leading,
    super.key,
  });

  final String label;

  /// Null disables the key.
  final VoidCallback? onPressed;
  final KeyKind kind;
  final Widget? leading;

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
    final small = widget.kind == KeyKind.small;
    final surface = skin.painters.key(
      skin.tokens,
      widget.kind,
      KeyState(enabled: _enabled, pressed: _pressed, hovered: _hovered),
    );
    final face = Container(
      key: const ValueKey('key-edge'),
      margin: EdgeInsets.only(top: surface.topInset),
      padding: EdgeInsets.only(bottom: surface.edgeWidth),
      decoration: BoxDecoration(
        color: surface.edgeColor,
        borderRadius: surface.radius,
      ),
      child: Container(
        key: const ValueKey('key-face'),
        constraints: BoxConstraints(minHeight: small ? 26 : 30, minWidth: 24),
        padding: EdgeInsets.symmetric(horizontal: small ? 9 : 10),
        decoration: surface.decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (small ? skin.typography.small : skin.typography.body)
                    .copyWith(
                      color: surface.ink,
                      fontWeight: widget.kind == KeyKind.primary
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
    // One merged node per key: label, button, enabled, focus and tap.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.label,
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
          left: -4,
          top: -4,
          right: -4,
          bottom: -4,
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

/// The keycap that marks a record's area. Announced by the area's name.
final class AreaKey extends StatelessWidget {
  const AreaKey({required this.area, super.key});

  final LifeOSArea area;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      label: area.label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: skin.painters.areaMarker(skin.tokens, area),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            area.letter,
            style: skin.typography.label.copyWith(
              color: skin.tokens.areaKeys[area]!.ink,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
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
              color: skin.tokens.actionInk,
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

/// A row of mutually exclusive segments, such as the inspector's Record and
/// History tabs.
final class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++)
          Expanded(
            child: _Segment(
              label: labels[index],
              selected: index == selectedIndex,
              first: index == 0,
              last: index == labels.length - 1,
              onTap: () => onSelected(index),
            ),
          ),
      ],
    );
  }
}

final class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

final class _SegmentState extends State<_Segment> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: widget.selected,
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
              child: _FocusRing(
                visible: _focused,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 26),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: skin.painters.segment(
                    skin.tokens,
                    selected: widget.selected,
                    first: widget.first,
                    last: widget.last,
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: skin.typography.body.copyWith(
                        color: skin.painters.segmentInk(
                          skin.tokens,
                          selected: widget.selected,
                        ),
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
