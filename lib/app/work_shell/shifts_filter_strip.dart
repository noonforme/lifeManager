import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/pay_period.dart';
import '../../ui/ui.dart';
import 'schedules_subform.dart' show toneOf;
import 'shifts_filter.dart';
import 'work_location.dart';

/// The words of the Shifts filter strip.
/// A scope that is not a whole month, as the Period combo and the grid's
/// heading name it.
String scopeTitle(LocalDate from, LocalDate to) =>
    '${eraBoxDate(from)} – ${eraBoxDate(to)}';

abstract final class ShiftsFilterWords {
  static const previous = 'Previous period';
  static const next = 'Next period';
  static const range = 'Date range…';
  static const apply = 'Apply';
  static const all = 'All';
  static const allPastDays = 'All past days';
}

/// The Shifts sheet's filter strip (spec 3): Period (◂ a combo of the
/// months around the shown one, the employment's pay periods and Date
/// range… ▸, then From and To while a range is open or shown), Status,
/// Type, Off days and Clear. It holds no state: the shell moves the place
/// and owns the From and To boxes' [fromFocus] and [toFocus], so Tab can
/// go from one to the other.
Widget shiftsFilterStrip({
  required WorkLocation place,
  required List<String> types,
  required List<PayPeriod> periods,
  required LocalDate today,
  required bool rangeOpen,
  required void Function(LocalDate from, LocalDate to) onScope,
  LocalDate? draftFrom,
  LocalDate? draftTo,
  required void Function(LocalDate from, LocalDate to) onDraft,
  required VoidCallback onApply,
  required void Function(int direction) onStep,
  required ValueChanged<ShiftsFilter> onFilter,
  required VoidCallback onRange,
  required VoidCallback? onClear,
  bool leave = false,
  FocusNode? fromFocus,
  FocusNode? toFocus,
}) {
  final from = place.from!;
  final to = place.to!;
  final filter = place.filter;
  final period = periods
      .where((value) => value.start == from && value.end == to)
      .firstOrNull;
  final custom = !place.wholeMonth && period == null;
  final value = place.wholeMonth
      ? 'month:$from'
      : period != null
      ? 'period:${period.start}:${period.end}'
      : 'custom';
  return FilterStrip(
    onClear: onClear,
    items: [
      FilterStripItem(
        label: 'Period',
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StepKey(
              forward: false,
              semanticLabel: ShiftsFilterWords.previous,
              onPressed: () => onStep(-1),
            ),
            EraCombo<String>(
              semanticLabel: 'Period',
              value: value,
              items: [
                for (var step = -6; step <= 6; step++)
                  () {
                    final month = place.month!.addMonths(step);
                    return EraComboItem('month:$month', eraMonthTitle(month));
                  }(),
                for (final value in periods)
                  EraComboItem(
                    'period:${value.start}:${value.end}',
                    value.label ?? scopeTitle(value.start, value.end),
                  ),
                if (custom) EraComboItem('custom', scopeTitle(from, to)),
                const EraComboItem(
                  'range',
                  ShiftsFilterWords.range,
                  command: true,
                ),
              ],
              onSelected: (chosen) {
                final parts = chosen.split(':');
                switch (parts.first) {
                  case 'month':
                    final month = LocalDate.parse(parts[1]);
                    onScope(month, month.lastOfMonth);
                  case 'period':
                    onScope(
                      LocalDate.parse(parts[1]),
                      LocalDate.parse(parts[2]),
                    );
                  case 'range':
                    onRange();
                }
              },
            ),
            StepKey(
              forward: true,
              semanticLabel: ShiftsFilterWords.next,
              onPressed: () => onStep(1),
            ),
          ],
        ),
      ),
      if (rangeOpen || custom || draftFrom != null || draftTo != null) ...[
        // Typed or picked dates are a draft until Apply or Enter: a date
        // box reports every digit, and none of them moves the sheet.
        FilterStripItem(
          label: 'From',
          editor: true,
          child: _RangeDateBox(
            label: 'From',
            value: draftFrom ?? from,
            today: today,
            onDraft: (date) => onDraft(date, draftTo ?? to),
            onApply: onApply,
            focusNode: fromFocus,
            next: toFocus,
          ),
        ),
        FilterStripItem(
          label: 'To',
          editor: true,
          child: _RangeDateBox(
            label: 'To',
            value: draftTo ?? to,
            today: today,
            onDraft: (date) => onDraft(draftFrom ?? from, date),
            onApply: onApply,
            focusNode: toFocus,
          ),
        ),
        FilterStripItem(
          child: KeyButton(label: ShiftsFilterWords.apply, onPressed: onApply),
        ),
      ],
      if (leave)
        FilterStripItem(
          label: 'Status',
          child: EraCombo<ShiftsStatusFilter>(
            semanticLabel: 'Status',
            value: filter.status,
            items: const [
              EraComboItem(ShiftsStatusFilter.effective, 'Confirmed'),
              EraComboItem(ShiftsStatusFilter.all, 'All'),
              EraComboItem(ShiftsStatusFilter.voided, 'Void'),
            ],
            onSelected: (value) => onFilter(filter.copyWith(status: value)),
          ),
        )
      else
        _statusItem(filter, onFilter),
      if (leave)
        FilterStripItem(
          label: 'Type',
          child: EraCombo<String>(
            semanticLabel: 'Type',
            value: filter.type ?? '',
            items: const [
              EraComboItem('', 'All'),
              EraComboItem('Vacation', 'Vacation'),
              EraComboItem('Sick', 'Sick'),
            ],
            onSelected: (value) => onFilter(
              filter.copyWith(type: () => value.isEmpty ? null : value),
            ),
          ),
        )
      else
        _typeItem(filter, types, onFilter),
      if (!leave)
        FilterStripItem(
          child: EraCheckBox(
            value: filter.offDays,
            onChanged: (on) => onFilter(filter.copyWith(offDays: on)),
            label: 'Off days',
          ),
        ),
    ],
  );
}

/// A date box of the range: data entry, so it keeps the editor host's
/// keyboard rules (spec 4.6). Each date it reports is a draft. Enter
/// applies the range; Tab opens [next], or from the last box applies the
/// range; Esc puts back the date the box had when it took focus and
/// closes it, leaving the other box's draft be (bead 9pk.4.44).
final class _RangeDateBox extends StatefulWidget {
  const _RangeDateBox({
    required this.label,
    required this.value,
    required this.today,
    required this.onDraft,
    required this.onApply,
    this.focusNode,
    this.next,
  });

  final String label;
  final LocalDate value;
  final LocalDate today;
  final ValueChanged<LocalDate> onDraft;
  final VoidCallback onApply;

  /// The box's own node; the shell's, so the other box can open it.
  final FocusNode? focusNode;

  /// The box Tab opens; null for the last.
  final FocusNode? next;

  @override
  State<_RangeDateBox> createState() => _RangeDateBoxState();
}

final class _RangeDateBoxState extends State<_RangeDateBox> {
  final _ownNode = FocusNode(debugLabel: 'RangeDateBox');
  FocusNode get _node => widget.focusNode ?? _ownNode;
  late LocalDate _entry = widget.value;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_RangeDateBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.focusNode ?? _ownNode;
    if (old != _node) {
      old.removeListener(_onFocus);
      _node.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocus);
    _ownNode.dispose();
    super.dispose();
  }

  /// The date the edit started from: the value as the box takes focus.
  void _onFocus() {
    if (_node.hasFocus && !_focused) _entry = widget.value;
    _focused = _node.hasFocus;
  }

  void _onKey(EraEditorKey key) {
    switch (key) {
      case EraEditorKey.enter:
        widget.onApply();
      case EraEditorKey.tab:
        if (widget.next case final next?) {
          next.requestFocus();
        } else {
          widget.onApply();
        }
      case EraEditorKey.escape:
        if (widget.value != _entry) widget.onDraft(_entry);
        _node.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => EraEditorHostScope(
    bare: true,
    onKey: _onKey,
    child: EraDateField(
      label: widget.label,
      value: widget.value,
      today: widget.today,
      focusNode: _node,
      fieldKey: ValueKey('filter-${widget.label}'),
      onChanged: (date) {
        if (date != null) widget.onDraft(date);
      },
    ),
  );
}

/// The Calendar's filter strip (plan 4d-2): Period (◂ a combo of the 13
/// months around the shown one ▸), Type, and the key to the day swatches.
/// Status and Off days do not apply: every day shows.
Widget calendarFilterStrip({
  required WorkLocation place,
  required List<String> types,
  required void Function(LocalDate month) onMonth,
  required void Function(int direction) onStep,
  required ValueChanged<ShiftsFilter> onFilter,
  required VoidCallback? onClear,
  bool enabled = true,
}) {
  final month = place.month!;
  final filter = place.filter;
  return FilterStrip(
    enabled: enabled,
    onClear: onClear,
    items: [
      FilterStripItem(
        label: 'Period',
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StepKey(
              forward: false,
              semanticLabel: ShiftsFilterWords.previous,
              onPressed: () => onStep(-1),
            ),
            EraCombo<LocalDate>(
              semanticLabel: 'Period',
              value: month,
              items: [
                for (var step = -6; step <= 6; step++)
                  EraComboItem(
                    month.addMonths(step),
                    eraMonthTitle(month.addMonths(step)),
                  ),
              ],
              onSelected: onMonth,
            ),
            StepKey(
              forward: true,
              semanticLabel: ShiftsFilterWords.next,
              onPressed: () => onStep(1),
            ),
          ],
        ),
      ),
      _typeItem(filter, types, onFilter),
      FilterStripItem(
        label: 'Key',
        child: DayCalendarKey([
          for (final (index, type) in types.indexed) (toneOf(index), type),
          (DayTone.third, 'Extra'),
          (DayTone.fourth, 'Leave'),
        ]),
      ),
    ],
  );
}

/// Type (spec 3): All, the sheet's types, Extra and Manual.
FilterStripItem _typeItem(
  ShiftsFilter filter,
  List<String> types,
  ValueChanged<ShiftsFilter> onFilter,
) {
  final names = {...types, 'Extra', 'Manual', ?filter.type}.toList()..sort();
  return FilterStripItem(
    label: 'Type',
    child: EraCombo<String>(
      semanticLabel: 'Type',
      value: filter.type ?? '',
      items: [
        const EraComboItem('', ShiftsFilterWords.all),
        for (final type in names) EraComboItem(type, type),
      ],
      onSelected: (type) =>
          onFilter(filter.copyWith(type: () => type.isEmpty ? null : type)),
    ),
  );
}

/// Status (spec 3): which rows the sheet keeps.
FilterStripItem _statusItem(
  ShiftsFilter filter,
  ValueChanged<ShiftsFilter> onFilter,
) => FilterStripItem(
  label: 'Status',
  child: EraCombo<ShiftsStatusFilter>(
    semanticLabel: 'Status',
    value: filter.status,
    items: [
      for (final status in ShiftsStatusFilter.values)
        EraComboItem(status, status.label),
    ],
    onSelected: (status) => onFilter(filter.copyWith(status: status)),
  ),
);

/// To confirm's filter strip (plan 4d-2): Period (◂ All past days or one
/// of the 13 months to this one ▸), Status and Type. ◂ and ▸ step a month
/// and rest on All past days; ◂ rests on the oldest month listed, ▸ on
/// this month.
Widget toConfirmFilterStrip({
  required WorkLocation place,
  required List<String> types,
  required LocalDate today,
  required void Function(LocalDate? month) onMonth,
  required void Function(int direction) onStep,
  required ValueChanged<ShiftsFilter> onFilter,
  required VoidCallback? onClear,
  bool enabled = true,
}) {
  final month = place.allPastDays ? null : place.month;
  final now = today.firstOfMonth;
  final oldest = now.addMonths(-12);
  return FilterStrip(
    enabled: enabled,
    onClear: onClear,
    items: [
      FilterStripItem(
        label: 'Period',
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StepKey(
              forward: false,
              semanticLabel: ShiftsFilterWords.previous,
              onPressed: month == null || month.compareTo(oldest) <= 0
                  ? null
                  : () => onStep(-1),
            ),
            EraCombo<String>(
              semanticLabel: 'Period',
              value: month == null ? 'all' : '$month',
              items: [
                const EraComboItem('all', ShiftsFilterWords.allPastDays),
                for (var step = 0; step <= 12; step++)
                  EraComboItem(
                    '${now.addMonths(-step)}',
                    eraMonthTitle(now.addMonths(-step)),
                  ),
                // An older month routed to is shown as itself.
                if (month != null && month.compareTo(oldest) < 0)
                  EraComboItem('$month', eraMonthTitle(month)),
              ],
              onSelected: (chosen) =>
                  onMonth(chosen == 'all' ? null : LocalDate.parse(chosen)),
            ),
            StepKey(
              forward: true,
              semanticLabel: ShiftsFilterWords.next,
              onPressed: month == null || month.compareTo(now) >= 0
                  ? null
                  : () => onStep(1),
            ),
          ],
        ),
      ),
      _statusItem(place.filter, onFilter),
      _typeItem(place.filter, types, onFilter),
    ],
  );
}
