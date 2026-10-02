import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/explain/explanation.dart';
import '../workbench/cell_selection.dart';
import '../workbench/lifeos_skin.dart';

/// The formula bar's content (spec 6.3): the selected cell's reference and,
/// for a derived value, how it was worked out. Operands link to their
/// source. With nothing selected it shows nothing.
final class FormulaBar extends StatefulWidget {
  const FormulaBar({required this.onNavigate, super.key});

  /// Opens the record or rule an operand came from.
  final ValueChanged<Uri> onNavigate;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

final class _FormulaBarState extends State<FormulaBar> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _recognizer(Uri route) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () => widget.onNavigate(route);
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final onNavigate = widget.onNavigate;
    final selection = CellSelectionScope.maybeOf(context)?.value;
    if (selection == null) return const SizedBox.shrink();
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final figure = skin.typography.figure.copyWith(color: tokens.ink);
    final explanation = selection.explanation;

    final reference = Container(
      constraints: const BoxConstraints(minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      margin: const EdgeInsets.only(right: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.band,
        border: Border.all(color: tokens.rule),
      ),
      child: Text(
        selection.reference,
        style: figure.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    if (explanation == null) {
      return Semantics(
        label:
            '${selection.reference}, ${selection.columnLabel}, '
            'recorded fact, ${selection.display}',
        excludeSemantics: true,
        child: Row(
          children: [
            reference,
            Flexible(
              child: Text(
                '${selection.columnLabel}: ${selection.display}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: figure,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Recorded fact',
              style: skin.typography.small.copyWith(color: tokens.muted),
            ),
          ],
        ),
      );
    }

    final spans = <InlineSpan>[
      TextSpan(text: '${explanation.label} = '),
      for (final token in explanation.tokens)
        switch (token) {
          TextToken(:final text) => TextSpan(text: text),
          ResultToken(:final text) => TextSpan(
            text: text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          OperandToken(:final text, :final source) => TextSpan(
            text: text,
            style: TextStyle(
              color: tokens.ink,
              decoration: TextDecoration.underline,
              decorationColor: tokens.signal,
              decorationThickness: 2,
            ),
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(source.route),
          ),
        },
    ];
    final source = explanation.source;
    final sourceLabel = explanation.sourceLabel;
    return Semantics(
      label: '${selection.reference}, ${explanation.plainText}',
      excludeSemantics: true,
      child: Row(
        children: [
          reference,
          Expanded(
            child: Text.rich(
              TextSpan(style: figure, children: spans),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (source != null && sourceLabel != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => onNavigate(source.route),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  sourceLabel,
                  style: skin.typography.small.copyWith(
                    color: tokens.ink,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
