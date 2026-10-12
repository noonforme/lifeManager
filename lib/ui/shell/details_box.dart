import 'package:flutter/widgets.dart';

import '../controls/era_scrollbar.dart';
import '../controls/etched_line.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/millennium_style.dart';

/// One "Label: value" fact of a [DetailsBox]. The caller supplies the display
/// text; the box calculates nothing. With [onFollow] the value is a follow
/// link (mouse only: it never takes keyboard focus). The callback is plain:
/// a caller that leaves a record with a pending edit flushes its editor
/// before acting, as every command does.
@immutable
final class DetailsFact {
  const DetailsFact(
    this.label,
    this.value, {
    this.onFollow,
    this.figure = true,
  });

  final String label;
  final String value;

  /// Makes the value a follow link, or null for plain text.
  final VoidCallback? onFollow;

  /// Dates, times, durations and amounts line up in the figure face; words
  /// (and links) are better in body type.
  final bool figure;
}

/// A warning line of a [DetailsBox]: a painted warning mark and text in run
/// ink, announced as "Warning: ...". With [onFollow] the text is a link.
@immutable
final class DetailsWarning {
  const DetailsWarning(this.text, {this.onFollow});

  final String text;
  final VoidCallback? onFollow;
}

/// One block of a [DetailsBox]: an optional [title], its [facts], then its
/// [warnings] under an etched rule. Blocks are separated by etched rules.
@immutable
final class DetailsSection {
  const DetailsSection({
    this.title,
    this.facts = const [],
    this.warnings = const [],
  });

  final String? title;
  final List<DetailsFact> facts;
  final List<DetailsWarning> warnings;
}

/// The Details box of the object tree's pane (database shell spec 3): a
/// caption, then facts, follow links and warnings that scroll on their own.
///
/// Under a bounded height the caption is pinned and the sections fill the
/// rest and scroll (era scrollbar, mouse wheel); under an unbounded height
/// the box takes its content height. Labels and values wrap at any text
/// scale, and a value that does not fit beside its label moves under it, so
/// a long value never hides the label.
final class DetailsBox extends StatefulWidget {
  const DetailsBox({
    required this.caption,
    required this.sections,
    this.emptyText,
    super.key,
  });

  final String caption;
  final List<DetailsSection> sections;

  /// Shown when there are no sections.
  final String? emptyText;

  @override
  State<DetailsBox> createState() => _DetailsBoxState();
}

final class _DetailsBoxState extends State<DetailsBox> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.sections.isEmpty && widget.emptyText != null)
            Text(
              widget.emptyText!,
              style: skin.typography.small.copyWith(color: tokens.muted),
            ),
          for (final (index, section) in widget.sections.indexed) ...[
            if (index > 0) const EtchedLine(),
            _Section(section: section),
          ],
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.caption,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border.all(color: tokens.chromeLine),
            ),
            child: Column(
              mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.chrome,
                      border: Border(
                        bottom: BorderSide(color: tokens.chromeLine),
                      ),
                    ),
                    child: Text(
                      widget.caption,
                      style: skin.typography.strong.copyWith(color: tokens.ink),
                    ),
                  ),
                ),
                if (bounded)
                  Expanded(
                    child: EraScrollbar(
                      controller: _scroll,
                      axis: Axis.vertical,
                      // The era bar is drawn here, so the host's own is off.
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          controller: _scroll,
                          child: content,
                        ),
                      ),
                    ),
                  )
                else
                  content,
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.section});

  final DetailsSection section;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (section.title != null)
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                section.title!,
                style: skin.typography.label.copyWith(color: skin.tokens.ink),
              ),
            ),
          ),
        for (final fact in section.facts) _FactRow(fact: fact),
        if (section.warnings.isNotEmpty) ...[
          if (section.facts.isNotEmpty) const EtchedLine(),
          for (final warning in section.warnings) _WarningRow(warning: warning),
        ],
      ],
    );
  }
}

/// The width of the label column at 100 % text.
const _labelColumn = 96.0;

double _textWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

final class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final DetailsFact fact;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final follow = fact.onFollow;
    final labelStyle = skin.typography.body.copyWith(color: tokens.ink);
    final valueStyle =
        (fact.figure && follow == null
                ? skin.typography.figure
                : skin.typography.body)
            .copyWith(
              color: follow == null ? tokens.ink : MillenniumColors.link,
              decoration: follow == null ? null : TextDecoration.underline,
              decorationColor: MillenniumColors.link,
            );
    final label = Text('${fact.label}:', style: labelStyle);
    Widget value = Text(fact.value, style: valueStyle);
    if (follow != null) {
      value = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: follow,
          child: value,
        ),
      );
    }
    return Semantics(
      container: true,
      label: '${fact.label}: ${fact.value}',
      link: follow != null,
      onTap: follow,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final column = scaler.scale(_labelColumn);
              // Side by side while the label fits its column and the value
              // keeps a usable share; otherwise the value goes under its
              // label, and both wrap to the full width.
              final sideBySide =
                  _textWidth(context, '${fact.label}:', labelStyle) <=
                      column - 4 &&
                  column + scaler.scale(40) <= constraints.maxWidth;
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, value],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: column, child: label),
                  Expanded(child: value),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _WarningRow extends StatelessWidget {
  const _WarningRow({required this.warning});

  final DetailsWarning warning;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final follow = warning.onFollow;
    Widget text = Text(
      warning.text,
      style: skin.typography.body.copyWith(
        color: skin.tokens.runInk,
        decoration: follow == null ? null : TextDecoration.underline,
        decorationColor: skin.tokens.runInk,
      ),
    );
    if (follow != null) {
      text = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: follow,
          child: text,
        ),
      );
    }
    return Semantics(
      container: true,
      label: 'Warning: ${warning.text}',
      link: follow != null,
      onTap: follow,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EraIcon(EraIconKind.warning),
            const SizedBox(width: 4),
            Expanded(child: text),
          ],
        ),
      ),
    );
  }
}
