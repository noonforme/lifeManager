import 'package:flutter/widgets.dart';

import '../../../core/time/local_date.dart';
import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

final eraEditorHostScopeDemo = GalleryDemo(
  id: 'controls/era_editor_host_scope',
  widget: 'EraEditorHostScope',
  summary:
      'Era controls under the database shell keyboard: data entry only, '
      'Enter/Tab/Esc to the host, calendar and list by mouse. A labelled '
      'host above, bare cells below.',
  size: const Size(480, 500),
  build: (context, knobs) => _HostDemo(knobs: knobs),
);

/// A labelled host and a row of bare cells, each telling the last key it
/// was handed.
final class _HostDemo extends StatefulWidget {
  const _HostDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_HostDemo> createState() => _HostDemoState();
}

final class _HostDemoState extends State<_HostDemo> {
  LocalDate _date = const LocalDate(2026, 10, 7);
  LocalTime _time = const LocalTime(19, 45);
  String _view = 'Shifts';
  EraEditorKey? _last;

  void _onKey(EraEditorKey key) => setState(() => _last = key);

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    final skin = LifeOSSkinScope.of(context);
    Widget date() => EraDateField(
      label: knobs.text('Starts on', 'Agreement starts on (first paid day)'),
      value: _date,
      today: galleryToday,
      error: knobs.errorText,
      onChanged: (value) => setState(() => _date = value!),
    );
    Widget time() => EraTimeField(
      label: knobs.text('End', 'End of the shift (next day after midnight)'),
      value: _time,
      error: knobs.errorText,
      onChanged: (value) => setState(() => _time = value),
    );
    // A grid cell: its column's width at the text scale, or the editor's
    // own width for a time box, which grows rather than split "19:45".
    final scale = MediaQuery.textScalerOf(context);
    Widget cell(Widget editor, {double? width}) {
      final box = Container(
        width: width == null ? null : scale.scale(width),
        decoration: BoxDecoration(border: Border.all(color: skin.tokens.rule)),
        child: editor,
      );
      return width == null ? IntrinsicWidth(child: box) : box;
    }

    final received = switch (_last) {
      null => 'none yet',
      EraEditorKey.enter => 'Enter',
      EraEditorKey.tab => 'Tab',
      EraEditorKey.escape => 'Esc',
    };
    return SizedBox(
      width: scale.scale(440),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GroupBox(
            legend: 'Labelled host',
            child: EraEditorHostScope(
              onKey: _onKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [date(), time()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bare cells:',
            style: skin.typography.body.copyWith(color: skin.tokens.ink),
          ),
          const SizedBox(height: 2),
          EraEditorHostScope(
            bare: true,
            onKey: _onKey,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                cell(date(), width: EraFieldWidth.date + 2),
                cell(time()),
                cell(
                  width: EraFieldWidth.date + 2,
                  EraCombo<String>(
                    semanticLabel: 'View',
                    minWidth: scale.scale(EraFieldWidth.date),
                    value: _view,
                    items: const [
                      EraComboItem('Shifts', 'Shifts'),
                      EraComboItem('Pay periods', 'Pay periods'),
                      EraComboItem('Payslips', 'Payslips'),
                    ],
                    onSelected: (value) => setState(() => _view = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The host received: $received',
            style: skin.typography.body.copyWith(color: skin.tokens.muted),
          ),
        ],
      ),
    );
  }
}
