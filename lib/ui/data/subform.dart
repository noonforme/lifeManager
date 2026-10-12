import 'package:flutter/widgets.dart';

import '../controls/editor_session_controller.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';
import '../shell/tab_strip.dart';

/// One tab of a [Subform]: the tab's face (as a [TabItem]) and the content
/// [builder] shown under it while it is selected. [id] is the stable
/// identity of the tab and of its content: reordering the tabs never hands
/// one tab's state to another.
///
/// The content is any widget, so the owner can append a Properties or
/// action-panel tab beside the children tabs.
@immutable
final class SubformTab {
  const SubformTab({
    required this.id,
    required this.label,
    required this.builder,
    this.icon,
    this.enabled = true,
    this.disabledReason,
    this.tooltip,
    this.count,
    this.countLabel = 'waiting',
  });

  /// Unique within one subform.
  final String id;
  final String label;

  /// Builds the content. It runs while the tab is selected and again for
  /// rebuilds of a tab already built, so keep it pure.
  final WidgetBuilder builder;
  final EraIconKind? icon;
  final bool enabled;
  final String? disabledReason;
  final String? tooltip;
  final int? count;
  final String countLabel;

  TabItem get _item => TabItem(
    id: id,
    label: label,
    icon: icon,
    enabled: enabled,
    disabledReason: disabledReason,
    tooltip: tooltip,
    count: count,
    countLabel: countLabel,
  );
}

/// A record's children (database shell spec 5.5, 6): subform tabs
/// ([TabStripSize.subform], 20/22 px) over a bordered content region.
///
/// **Controlled by id**, like [TabStrip]. A tab request first flushes the
/// shared [controller], if given: when the open draft is rejected the tab
/// does not change and the owner is not asked; otherwise [onSelect] receives
/// the id and the owner supplies the new [selectedId] (or refuses by not
/// doing so).
///
/// **Content stays alive.** Every tab that has been selected keeps its
/// content, keyed by the tab id, in the tree while another tab shows, so a
/// grid's scroll position, a counter's state or a mounted editor survive a
/// round trip. Hidden content is not painted or hit-tested, takes no
/// keyboard focus and has no running tickers. A tab that is removed
/// disposes its content. An editor draft itself lives in the controller,
/// not in the content.
///
/// An unknown or null [selectedId] (a selected tab that was just removed)
/// shows no content and indexes nothing: the owner reconciles with
/// [TabStrip.resolveSelection]. With no tabs the region shows [emptyText].
/// Fills a bounded height; otherwise takes the selected content's height.
final class Subform extends StatefulWidget {
  const Subform({
    required this.tabs,
    required this.selectedId,
    required this.onSelect,
    this.controller,
    this.trailing,
    this.label,
    this.emptyText = 'Nothing to show.',
    super.key,
  });

  final List<SubformTab> tabs;
  final String? selectedId;

  /// The accepted request for another tab, after the controller flushed.
  final ValueChanged<String> onSelect;

  /// The editor session whose open draft must be accepted before the tab
  /// changes. Null for a subform with no editors.
  final EditorSessionController? controller;

  /// A caption beside the tabs (for example "3 of 12 rows").
  final Widget? trailing;

  /// The semantic name of the content region.
  final String? label;

  /// Shown in the region when there are no tabs.
  final String emptyText;

  @override
  State<Subform> createState() => _SubformState();
}

final class _SubformState extends State<Subform> {
  /// Ids whose content has been shown: only those are built and kept.
  final Set<String> _built = {};

  void _request(String id) {
    final controller = widget.controller;
    if (controller != null && !controller.flush().isAccepted) return;
    widget.onSelect(id);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final ids = {for (final tab in tabs) tab.id};
    if (ids.length != tabs.length) {
      throw FlutterError('A Subform needs unique tab ids.');
    }
    _built
      ..retainWhere(ids.contains)
      ..addAll(ids.where((id) => id == widget.selectedId));
    final selected = ids.contains(widget.selectedId) ? widget.selectedId : null;
    final skin = LifeOSSkinScope.of(context);
    Widget content = Stack(
      fit: StackFit.passthrough,
      children: [
        for (final tab in tabs)
          if (_built.contains(tab.id))
            _Pane(
              key: ValueKey(tab.id),
              visible: tab.id == selected,
              child: Builder(builder: tab.builder),
            ),
      ],
    );
    if (tabs.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          widget.emptyText,
          style: skin.typography.body.copyWith(color: skin.tokens.muted),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final region = Semantics(
          container: true,
          label: widget.label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: skin.tokens.chrome,
              border: const Border(
                left: BorderSide(color: MillenniumColors.tabLine),
                right: BorderSide(color: MillenniumColors.tabLine),
                bottom: BorderSide(color: MillenniumColors.tabLine),
              ),
            ),
            child: bounded ? SizedBox.expand(child: content) : content,
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabStrip(
              size: TabStripSize.subform,
              tabs: [for (final tab in tabs) tab._item],
              selectedId: selected,
              onSelect: _request,
              trailing: widget.trailing,
            ),
            if (bounded) Expanded(child: region) else region,
          ],
        );
      },
    );
  }
}

/// One tab's content: kept in the tree, but while hidden it is not
/// painted, hit-tested or announced (it is still laid out, at no size),
/// takes no focus and runs no tickers.
final class _Pane extends StatelessWidget {
  const _Pane({required this.visible, required this.child, super.key});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: TickerMode(enabled: visible, child: child),
    ),
  );
}
