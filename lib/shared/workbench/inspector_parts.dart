import 'package:flutter/widgets.dart';

import 'lifeos_skin.dart';

/// The inspector's content inset. It matches the Details and History tabs
/// above it, so titles, facts and keys share one left edge.
const inspectorInset = EdgeInsets.fromLTRB(16, 14, 16, 16);

/// A scrolling inspector page, laid out on the inspector inset.
final class InspectorPane extends StatelessWidget {
  const InspectorPane({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      ListView(padding: inspectorInset, children: children);
}

/// The record title in Title type, with an optional secondary line.
final class InspectorTitle extends StatelessWidget {
  const InspectorTitle(this.title, {this.meta, super.key});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: skin.typography.title.copyWith(color: skin.tokens.ink),
            ),
            if (meta case final meta?) ...[
              const SizedBox(height: 2),
              Text(
                meta,
                style: skin.typography.small.copyWith(color: skin.tokens.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A section label in Label type, like a register's column headers.
final class InspectorSection extends StatelessWidget {
  const InspectorSection(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Text(
          label.toUpperCase(),
          style: skin.typography.label.copyWith(color: skin.tokens.muted),
        ),
      ),
    );
  }
}

/// Label and value pairs drawn as register rows: Rule separators, the
/// label on the left and the value right-aligned.
final class InspectorFacts extends StatelessWidget {
  const InspectorFacts(this.facts, {super.key});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final rule = BorderSide(color: skin.tokens.rule);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final fact in facts)
            DecoratedBox(
              decoration: BoxDecoration(border: Border(bottom: rule)),
              child: InspectorFactRow(fact: fact),
            ),
        ],
      ),
    );
  }
}

/// One inspector fact. Dates, times, durations and amounts are [figure]s
/// and line up in the figure face; words stay in body type.
final class Fact {
  const Fact(this.label, this.value, {this.figure = true, this.tone});

  const Fact.words(this.label, this.value) : figure = false, tone = null;

  final String label;
  final String value;
  final bool figure;

  /// Supports a value's words, such as "under", with a meaning colour.
  final FactTone? tone;
}

enum FactTone { negative, positive }

/// One row of [InspectorFacts].
final class InspectorFactRow extends StatelessWidget {
  const InspectorFactRow({required this.fact, super.key});

  final Fact fact;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final ink = switch (fact.tone) {
      FactTone.negative => tokens.negative,
      FactTone.positive => tokens.positive,
      null => tokens.ink,
    };
    final valueStyle = fact.figure
        ? skin.typography.figure.copyWith(color: ink)
        : skin.typography.body.copyWith(color: ink);
    final labelStyle = skin.typography.body.copyWith(color: tokens.muted);
    final label = Text(fact.label, style: labelStyle);
    final value = Text(fact.value, textAlign: TextAlign.end, style: valueStyle);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 25),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Label and value share a line when both fit at their own
              // width; otherwise the value moves under its label, still
              // right-aligned, so nothing is squeezed into a narrow column.
              final scaler = MediaQuery.textScalerOf(context);
              double width(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(text: text, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: scaler,
                  maxLines: 1,
                )..layout();
                final result = painter.width;
                painter.dispose();
                return result;
              }

              final fits =
                  width(fact.label, labelStyle) +
                      16 +
                      width(fact.value, valueStyle) <=
                  constraints.maxWidth;
              if (!fits) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [label, value],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 16),
                  value,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A secondary line, such as an explanation under the facts.
final class InspectorNote extends StatelessWidget {
  const InspectorNote(this.text, {this.tone, super.key});

  final String text;
  final FactTone? tone;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final color = switch (tone) {
      FactTone.negative => skin.tokens.negative,
      FactTone.positive => skin.tokens.positive,
      null => skin.tokens.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: skin.typography.small.copyWith(color: color)),
    );
  }
}

/// Body text in the inspector, for a sentence that is the content itself.
final class InspectorText extends StatelessWidget {
  const InspectorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Text(
      text,
      style: skin.typography.body.copyWith(color: skin.tokens.ink),
    );
  }
}

/// The record's keys, left-aligned at their own width and wrapping when
/// the inspector is narrow.
final class InspectorActions extends StatelessWidget {
  const InspectorActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );
}
