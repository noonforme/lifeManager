import 'package:flutter/widgets.dart';

import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

/// The blue task pane on the left (spec 5.2): rounded groups of links.
final class TaskPane extends StatelessWidget {
  const TaskPane({required this.groups, super.key});

  final List<Widget> groups;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [MillenniumColors.paneTop, MillenniumColors.paneBottom],
      ),
    ),
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final group in groups) ...[group, const SizedBox(height: 12)],
      ],
    ),
  );
}

/// One collapsible task-pane group. The [special] group has a solid blue
/// header. Collapsed state lasts for the session (page storage).
final class TaskGroup extends StatefulWidget {
  const TaskGroup({
    required this.title,
    required this.child,
    this.special = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool special;

  @override
  State<TaskGroup> createState() => _TaskGroupState();
}

final class _TaskGroupState extends State<TaskGroup> {
  late bool _open =
      PageStorage.maybeOf(context)
              ?.readState(context, identifier: 'task-group-${widget.title}')
          as bool? ??
      true;

  void _toggle() {
    setState(() => _open = !_open);
    PageStorage.maybeOf(context)
        ?.writeState(context, _open, identifier: 'task-group-${widget.title}');
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final special = widget.special;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 25),
            padding: const EdgeInsets.fromLTRB(9, 2, 4, 2),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
              gradient: LinearGradient(
                colors: special
                    ? [tokens.head, MillenniumColors.specialHeaderEnd]
                    : [tokens.paper, MillenniumColors.groupHeaderEnd],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: skin.typography.body.copyWith(
                        color: special ? tokens.headInk : tokens.head,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _CollapseKey(
                  open: _open,
                  special: special,
                  title: widget.title,
                  onPressed: _toggle,
                ),
              ],
            ),
          ),
          if (_open)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MillenniumColors.paneBody,
                border: Border(
                  left: BorderSide(color: tokens.paper),
                  right: BorderSide(color: tokens.paper),
                  bottom: BorderSide(color: tokens.paper),
                ),
              ),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

final class _CollapseKey extends StatelessWidget {
  const _CollapseKey({
    required this.open,
    required this.special,
    required this.title,
    required this.onPressed,
  });

  final bool open;
  final bool special;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Semantics(
      button: true,
      label: open ? 'Collapse $title' : 'Expand $title',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: special
                      ? MillenniumColors.specialHeaderEnd
                      : tokens.paper,
                  border: Border.all(
                    color: special
                        ? tokens.paper
                        : MillenniumColors.groupHeaderEnd,
                  ),
                ),
                child: Text(
                  open ? '︽' : '︾',
                  style: skin.typography.small.copyWith(
                    color: special ? tokens.headInk : tokens.head,
                    height: 1,
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

/// A task-pane link (spec 5.2): link blue, underlined on hover, at least
/// 24 px high. Null [onPressed] shows it unavailable.
final class TaskLink extends StatefulWidget {
  const TaskLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<TaskLink> createState() => _TaskLinkState();
}

final class _TaskLinkState extends State<TaskLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final enabled = widget.onPressed != null;
    return MergeSemantics(
      child: Semantics(
        link: true,
        enabled: enabled,
        label: widget.label,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 24),
                alignment: Alignment.centerLeft,
                foregroundDecoration: _focused
                    ? DottedFocusRectangle(color: tokens.focus, inset: 0.5)
                    : null,
                child: Text(
                  widget.label,
                  style: skin.typography.body.copyWith(
                    color: enabled ? MillenniumColors.link : tokens.muted,
                    decoration: _hovered && enabled
                        ? TextDecoration.underline
                        : null,
                    decorationColor: MillenniumColors.link,
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

/// Plain lines in a Details group.
final class TaskDetails extends StatelessWidget {
  const TaskDetails({required this.lines, super.key});

  final List<Widget> lines;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return DefaultTextStyle.merge(
      style: skin.typography.body.copyWith(color: skin.tokens.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(padding: const EdgeInsets.only(bottom: 2), child: line),
        ],
      ),
    );
  }
}
