import 'package:flutter/widgets.dart';

import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

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
