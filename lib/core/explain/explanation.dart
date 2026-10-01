import 'package:flutter/foundation.dart';

/// Where an operand came from: a structural route to the fact or rule that
/// produced it. Routes never carry money, notes or labels.
@immutable
final class SourceRef {
  const SourceRef(this.route);

  final Uri route;

  @override
  bool operator ==(Object other) => other is SourceRef && other.route == route;

  @override
  int get hashCode => route.hashCode;
}

/// One piece of a calculation shown in the formula bar.
sealed class ExplanationToken {
  const ExplanationToken();

  String get text;
}

/// Plain words or operators, such as " × " or "regular".
final class TextToken extends ExplanationToken {
  const TextToken(this.text);

  @override
  final String text;
}

/// An input to the calculation that links to its [source].
final class OperandToken extends ExplanationToken {
  const OperandToken(this.text, this.source);

  @override
  final String text;
  final SourceRef source;
}

/// The value the calculation produces; matches the cell exactly.
final class ResultToken extends ExplanationToken {
  const ResultToken(this.text);

  @override
  final String text;
}

/// How a derived value was worked out (spec 6.3). Built from the same result
/// object that produced the cell, never from a second calculation.
@immutable
final class Explanation {
  const Explanation({
    required this.label,
    required this.tokens,
    this.source,
    this.sourceLabel,
  });

  /// What the value is, for example "Est. pay, Tue 29 Sep".
  final String label;
  final List<ExplanationToken> tokens;

  /// The rule or record behind the whole calculation, such as an agreement.
  final SourceRef? source;

  /// How [source] is named in the formula bar, for example
  /// 'Agreement "Standard" v2'.
  final String? sourceLabel;

  /// The calculation as one line of plain text, for copying.
  String get plainText =>
      '$label = ${tokens.map((token) => token.text).join()}';
}
