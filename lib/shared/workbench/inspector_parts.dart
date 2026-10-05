import 'package:flutter/widgets.dart';

import 'era_controls.dart';
import 'era_icons.dart';
import 'lifeos_skin.dart';

/// The property-sheet page's inset.
const inspectorInset = EdgeInsets.all(8);

/// A scrolling inspector page, laid out on the inspector inset.
final class InspectorPane extends StatelessWidget {
  const InspectorPane({required this.children, super.key});

  final List<Widget> children;

  @override
  // Shrink-wrapped, so a short page lets its dialog fit its content.
  Widget build(BuildContext context) =>
      ListView(shrinkWrap: true, padding: inspectorInset, children: children);
}

/// The record's name at the top of a Properties page, as an era
/// file-properties sheet opened: the name, an optional secondary line,
/// then an etched separator (XP-authentic shell spec 4.3).
final class InspectorTitle extends StatelessWidget {
  const InspectorTitle(this.title, {this.meta, this.icon, super.key});

  final String title;
  final String? meta;

  /// The record kind's 32 px icon beside the name.
  final EraIconKind? icon;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon case final icon?) ...[
                EraIcon(icon, size: 32),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: skin.typography.strong.copyWith(
                        color: skin.tokens.ink,
                      ),
                    ),
                    if (meta case final meta?) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: skin.typography.small.copyWith(
                          color: skin.tokens.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const EtchedLine(),
        ],
      ),
    );
  }
}

/// A 2 px etched separator: a grey line over a white one.
final class EtchedLine extends StatelessWidget {
  const EtchedLine({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: tokens.chromeLine),
          Container(height: 1, color: tokens.paper),
        ],
      ),
    );
  }
}

/// A block of "Label:" rows closed by an etched line, as an era
/// file-properties page groups its facts. [legend] names the block for
/// screen readers.
final class InspectorFacts extends StatelessWidget {
  const InspectorFacts(this.facts, {this.legend, super.key});

  final List<Fact> facts;
  final String? legend;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: legend,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final fact in facts) InspectorFactRow(fact: fact),
        const EtchedLine(),
      ],
    ),
  );
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

/// The width of a Properties page's label column.
const _labelColumn = 96.0;

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
    final labelStyle = skin.typography.body.copyWith(color: tokens.ink);
    final label = Text('${fact.label}:', style: labelStyle);
    final value = Text(fact.value, style: valueStyle);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The label column is 96 px and the value follows it, when
              // both fit at their own width; otherwise the value moves under
              // its label, so nothing is squeezed into a narrow column.
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
                  width('${fact.label}:', labelStyle) <= _labelColumn - 4 &&
                  _labelColumn + width(fact.value, valueStyle) <=
                      constraints.maxWidth;
              if (!fits) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, value],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(width: _labelColumn, child: label),
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

/// The record's keys at the foot of the page, right-aligned and wrapping.
final class InspectorActions extends StatelessWidget {
  const InspectorActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => FormFooter(children: children);
}
