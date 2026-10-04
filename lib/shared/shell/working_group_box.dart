import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/explain/explanation.dart';
import '../workbench/cell_selection.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

/// **Working** in the task pane's Details group (XP-authentic shell spec
/// 4.2): for a derived figure under the cursor, its reference and how it
/// was worked out, with operands linking to their source. Otherwise it
/// shows [fallback], the selected record or the scope's summary.
final class WorkingDetails extends StatefulWidget {
  const WorkingDetails({
    required this.onNavigate,
    required this.fallback,
    super.key,
  });

  /// Opens the record or rule an operand came from.
  final ValueChanged<Uri> onNavigate;

  /// Shown when no derived figure is selected.
  final Widget fallback;

  @override
  State<WorkingDetails> createState() => _WorkingDetailsState();
}

final class _WorkingDetailsState extends State<WorkingDetails> {
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
    if (selection == null) return widget.fallback;
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final figure = skin.typography.figure.copyWith(color: tokens.ink);
    final explanation = selection.explanation;

    if (explanation == null) return widget.fallback;

    final spans = <InlineSpan>[
      TextSpan(text: '${selection.reference}: ${explanation.label} = '),
      for (final token in explanation.tokens)
        switch (token) {
          TextToken(:final text) => TextSpan(text: text),
          ResultToken(:final text) => TextSpan(
            text: text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          OperandToken(:final text, :final source) => TextSpan(
            text: text,
            style: const TextStyle(
              color: MillenniumColors.link,
              decoration: TextDecoration.underline,
              decorationColor: MillenniumColors.link,
            ),
            mouseCursor: SystemMouseCursors.click,
            recognizer: _recognizer(source.route),
          ),
        },
    ];
    final source = explanation.source;
    final sourceLabel = explanation.sourceLabel;
    return Semantics(
      liveRegion: true,
      label: '${selection.reference}, ${explanation.plainText}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Working: ${selection.columnLabel}',
            style: skin.typography.body.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text.rich(TextSpan(style: figure, children: spans)),
          if (source != null && sourceLabel != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => onNavigate(source.route),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  sourceLabel,
                  style: skin.typography.small.copyWith(
                    color: MillenniumColors.link,
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
