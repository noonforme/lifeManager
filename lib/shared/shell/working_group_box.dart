import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/explain/explanation.dart';
import '../workbench/cell_selection.dart';
import '../workbench/era_controls.dart';
import '../workbench/lifeos_skin.dart';
import '../workbench/millennium_style.dart';

/// The **Working** group box (Millennium shell spec 5.5): the selected
/// cell's reference and, for a derived value, how it was worked out.
/// Operands link to their source. With nothing selected it shows nothing.
final class WorkingGroupBox extends StatefulWidget {
  const WorkingGroupBox({required this.onNavigate, super.key});

  /// Opens the record or rule an operand came from.
  final ValueChanged<Uri> onNavigate;

  @override
  State<WorkingGroupBox> createState() => _WorkingGroupBoxState();
}

final class _WorkingGroupBoxState extends State<WorkingGroupBox> {
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

    if (explanation == null) {
      return Semantics(
        liveRegion: true,
        label:
            '${selection.reference}, ${selection.columnLabel}, '
            'recorded fact, ${selection.display}',
        excludeSemantics: true,
        child: GroupBox(
          legend: 'Working: ${selection.columnLabel}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selection.reference} = ${selection.display}',
                style: figure,
              ),
              Text(
                'Recorded fact',
                style: skin.typography.small.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
      );
    }

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
      child: GroupBox(
        legend: 'Working: ${selection.columnLabel}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
      ),
    );
  }
}
