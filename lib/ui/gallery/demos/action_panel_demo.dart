import 'package:flutter/widgets.dart';

import '../../../core/time/local_time.dart';
import '../../ui.dart';
import '../gallery_demo.dart';

/// A synthetic "Confirm worked days" panel beside a stand-in pick column,
/// at the property column's width and a bounded height.
final actionPanelDemo = GalleryDemo(
  id: 'shell/action_panel',
  widget: 'ActionPanel',
  summary:
      'An inline multi-step action: the title in the object box, group boxes '
      'of fields that scroll, result and error rows, and the primary verb '
      'and Cancel pinned below. Enter/Tab walk the fields and never press a '
      'key. The primary key goes busy (fields, picks and keys locked) until '
      '"Finish synthetic run" reports two days done and one failed. Error '
      'shows that partial result; Long text lengthens labels and the title.',
  size: const Size(480, 440),
  build: (context, knobs) => _ActionPanelDemo(knobs: knobs),
);

const _days = ['Mon 2026-10-05', 'Tue 2026-10-06', 'Wed 2026-10-07'];

/// The synthetic day that fails in a run.
const _failing = 'Wed 2026-10-07';

const _kinds = [
  EraComboItem<Object?>('planned', 'As planned'),
  EraComboItem<Object?>('changed', 'With changes'),
];

const _failure = 'The synthetic store is busy.';

final class _ActionPanelDemo extends StatefulWidget {
  const _ActionPanelDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_ActionPanelDemo> createState() => _ActionPanelDemoState();
}

final class _ActionPanelDemoState extends State<_ActionPanelDemo> {
  final _controller = EditorSessionController();
  late Map<String, Object?> _values;
  late Set<String> _picks;
  late List<ActionResult> _results;
  String? _error;
  bool _busy = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _reset();
    // The Error knob opens on a partly failed run.
    if (widget.knobs.error) _report();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reset() {
    _values = {
      'kind': 'planned',
      'hours': '11',
      'start': const LocalTime(7, 0),
      'day': galleryToday,
      'note': '',
      'final': true,
    };
    _picks = {..._days};
    _results = [];
    _error = null;
    _busy = false;
  }

  void _start() => setState(() {
    _busy = true;
    _error = null;
    _status = 'Running: ${_picks.length} days submitted.';
  });

  void _finish() => setState(_report);

  /// The synthetic outcome: every picked day is confirmed, except that the
  /// failing day fails on its first run; it alone stays picked, and a retry
  /// replaces its row in place. Completed rows are never touched.
  void _report() {
    for (final day in _days.where(_picks.contains)) {
      final at = _results.indexWhere((result) => result.label == day);
      final result = day == _failing && at < 0
          ? const ActionResult.failed(_failing, _failure)
          : ActionResult.done(day, detail: 'Confirmed; pay is final.');
      if (at < 0) {
        _results.add(result);
      } else {
        _results[at] = result;
      }
    }
    _picks = {
      for (final result in _results)
        if (result.outcome != ActionOutcome.done) result.label,
    };
    final failed = _picks.length;
    _error = failed == 0
        ? null
        : '$failed of ${_results.length} days failed. The others stay '
              'confirmed; Confirm again retries only the failed day.';
    _busy = false;
    _status = '';
  }

  ActionField _field(
    String id,
    String label,
    ValueKind kind, {
    String? Function(Object? draft)? validate,
    List<EraComboItem<Object?>> choices = const [],
    String? error,
  }) => ActionField(
    id: id,
    label: label,
    kind: kind,
    value: _values[id],
    validate: validate,
    choices: choices,
    error: error,
    fieldKey: ValueKey('action-$id'),
  );

  @override
  Widget build(BuildContext context) {
    final knobs = widget.knobs;
    final skin = LifeOSSkinScope.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final muted = skin.typography.small.copyWith(color: skin.tokens.muted);
    final left = _days.where(
      (day) => !_results.any(
        (r) => r.label == day && r.outcome == ActionOutcome.done,
      ),
    );
    final count = _picks.length;
    return SizedBox(
      width: scale.scale(450),
      height: scale.scale(410),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The grid's pick column stand-in: the owner locks it while busy.
          SizedBox(
            width: scale.scale(136),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pick days:', style: skin.typography.label),
                for (final day in left)
                  EraCheckBox(
                    label: day,
                    value: _picks.contains(day),
                    onChanged: _busy
                        ? null
                        : (on) => setState(
                            () => on ? _picks.add(day) : _picks.remove(day),
                          ),
                  ),
                const SizedBox(height: 8),
                KeyButton(
                  label: 'Finish synthetic run',
                  kind: KeyKind.small,
                  wrapLabel: true,
                  onPressed: _busy ? knobs.press(_finish) : null,
                ),
                if (_status.isNotEmpty) Text(_status, style: muted),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ActionPanel(
              title: knobs.text(
                'Confirm worked days',
                'Confirm the worked days of Synthetic depot, October 2026',
              ),
              record: 'action:confirm-days',
              controller: _controller,
              today: galleryToday,
              groups: () => [
                ActionGroup(
                  legend: 'Worked',
                  fields: [
                    _field(
                      'kind',
                      knobs.text('Worked', 'Worked as the plan said'),
                      ValueKind.choice,
                      choices: _kinds,
                    ),
                    _field(
                      'hours',
                      knobs.text('Paid hours', 'Paid hours per day (whole)'),
                      ValueKind.number,
                      validate: (draft) => int.tryParse('$draft') == null
                          ? 'Enter whole hours.'
                          : null,
                      error: knobs.errorText,
                    ),
                    _field('start', 'Start', ValueKind.time),
                  ],
                ),
                ActionGroup(
                  legend: 'Confirmation',
                  fields: [
                    _field(
                      'day',
                      knobs.text('Confirm on', 'Confirmation dated'),
                      ValueKind.date,
                    ),
                    _field(
                      'note',
                      'Note',
                      ValueKind.text,
                      validate: (draft) => '$draft'.length > 40
                          ? 'Keep the note to 40 characters.'
                          : null,
                    ),
                    _field(
                      'final',
                      knobs.text(
                        'Pay is final',
                        'Make the pay of these days '
                            'final',
                      ),
                      ValueKind.check,
                    ),
                  ],
                  children: [
                    Text(
                      '$count ${count == 1 ? 'day' : 'days'} picked.',
                      style: muted,
                    ),
                  ],
                ),
              ],
              onChanged: (field, value) =>
                  setState(() => _values[field] = value),
              primaryLabel: knobs.text(
                'Confirm $count ${count == 1 ? 'day' : 'days'}',
                'Confirm $count worked days and make their pay final',
              ),
              onPrimary: count == 0 ? null : _start,
              onCancel: () => setState(() {
                _reset();
                _status = 'Cancel asked: the owner closes the panel.';
              }),
              results: _results,
              error: _error,
              busy: _busy,
            ),
          ),
        ],
      ),
    );
  }
}
