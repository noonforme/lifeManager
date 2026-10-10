import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../../../ui/ui.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/employment.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import 'work_sheets.dart' show periodName;

/// The register toolbar's controls (shell spec 7.1): the employment
/// switcher, the period picker and the state filter.

sealed class _SwitcherChoice {
  const _SwitcherChoice();
}

final class _OpenEmployment extends _SwitcherChoice {
  const _OpenEmployment(this.id);

  final EmploymentId id;

  @override
  bool operator ==(Object other) => other is _OpenEmployment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class _AllEmployments extends _SwitcherChoice {
  const _AllEmployments();
}

final class _CreateEmployment extends _SwitcherChoice {
  const _CreateEmployment();
}

/// Each active employment with a check on the current one, then All
/// employments and Create employment (premiums spec 8.4).
final class EmploymentSwitcher extends StatelessWidget {
  const EmploymentSwitcher({
    required this.current,
    required this.currentName,
    required this.employments,
    required this.onOpen,
    required this.onAll,
    required this.onCreate,
    super.key,
  });

  final EmploymentId? current;
  final String? currentName;
  final List<Employment> employments;
  final ValueChanged<EmploymentId>? onOpen;
  final VoidCallback? onAll;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final open = current == null ? null : _OpenEmployment(current!);
    return _Labelled(
      label: 'Employment',
      child: EraCombo<_SwitcherChoice>(
        semanticLabel: 'Employment',
        value: open,
        minWidth: 100,
        items: [
          for (final employment in employments)
            EraComboItem(_OpenEmployment(employment.id), employment.name),
          const EraComboItem(_AllEmployments(), 'All employments'),
          const EraComboItem(
            _CreateEmployment(),
            'Create employment…',
            command: true,
          ),
        ],
        face: (context, focused) => EraComboFace(
          value: currentName ?? 'All employments',
          minWidth: 100,
          focused: focused,
        ),
        onSelected: (choice) => switch (choice) {
          _OpenEmployment(:final id) => onOpen?.call(id),
          _AllEmployments() => onAll?.call(),
          _CreateEmployment() => onCreate(),
        },
      ),
    );
  }
}

sealed class _ScopeChoice {
  const _ScopeChoice();
}

final class _Scope extends _ScopeChoice {
  const _Scope(this.scope);

  final WorkTemporalScope? scope;

  @override
  bool operator ==(Object other) => other is _Scope && other.scope == scope;

  @override
  int get hashCode => scope.hashCode;
}

final class _AskRange extends _ScopeChoice {
  const _AskRange();
}

/// ‹ and › step between pay periods, or move an explicit range by its own
/// length; the menu picks All dates, a pay period or a date range.
final class PeriodPicker extends StatelessWidget {
  const PeriodPicker({
    required this.scope,
    required this.periods,
    required this.onScope,
    this.today,
    super.key,
  });

  final WorkTemporalScope? scope;

  /// The date a new range ends on; the device date when null.
  final LocalDate? today;

  /// The employment's pay periods in start order.
  final List<PayPeriod> periods;
  final ValueChanged<WorkTemporalScope?> onScope;

  WorkTemporalScope? _step(int direction) {
    final current = scope;
    switch (current) {
      case PayPeriodScope(:final periodId):
        final index = periods.indexWhere((period) => period.id == periodId);
        final next = index + direction;
        if (index < 0 || next < 0 || next >= periods.length) return null;
        return PayPeriodScope(periods[next].id);
      case DateRangeScope(:final start, :final end):
        final days = _days(start, end) + 1;
        return DateRangeScope(
          start: _addDays(start, days * direction),
          end: _addDays(end, days * direction),
        );
      case null:
        return direction < 0 && periods.isNotEmpty
            ? PayPeriodScope(periods.last.id)
            : null;
    }
  }

  String get _label => switch (scope) {
    null => 'All dates',
    PayPeriodScope(:final periodId) => switch (periods
        .where((period) => period.id == periodId)
        .firstOrNull) {
      final period? => periodName(period),
      null => 'Pay period',
    },
    DateRangeScope(:final start, :final end) => '$start – $end',
  };

  Future<void> _askRange(BuildContext context) async {
    final range = await showDialog<DateRangeScope>(
      context: context,
      // A click beside the dialog would discard the picks, often while
      // only meaning to close a calendar; Cancel is the way out.
      barrierDismissible: false,
      builder: (context) =>
          _RangeDialog(initial: scope, today: today ?? _deviceToday()),
    );
    if (range != null) onScope(range);
  }

  @override
  Widget build(BuildContext context) {
    final previous = _step(-1);
    final next = _step(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StepKey(
          forward: false,
          semanticLabel: previous == null
              ? 'Previous period, unavailable'
              : 'Previous period',
          onPressed: previous == null ? null : () => onScope(previous),
        ),
        const SizedBox(width: 4),
        _Labelled(
          label: 'Period',
          child: EraCombo<_ScopeChoice>(
            semanticLabel: 'Period',
            value: _Scope(scope),
            items: [
              const EraComboItem(_Scope(null), 'All dates'),
              for (final period in periods.reversed)
                EraComboItem(
                  _Scope(PayPeriodScope(period.id)),
                  periodName(period),
                ),
              const EraComboItem(_AskRange(), 'Date range…', command: true),
            ],
            face: (context, focused) =>
                EraComboFace(value: _label, focused: focused),
            onSelected: (choice) => switch (choice) {
              _Scope(:final scope) => onScope(scope),
              _AskRange() => _askRange(context),
            },
          ),
        ),
        const SizedBox(width: 4),
        StepKey(
          forward: true,
          semanticLabel: next == null
              ? 'Next period, unavailable'
              : 'Next period',
          onPressed: next == null ? null : () => onScope(next),
        ),
      ],
    );
  }
}

final class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.initial, required this.today});

  final WorkTemporalScope? initial;
  final LocalDate today;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

final class _RangeDialogState extends State<_RangeDialog> {
  late LocalDate _from = switch (widget.initial) {
    DateRangeScope(:final start) => start,
    _ => widget.today.firstOfMonth,
  };
  late LocalDate _to = switch (widget.initial) {
    DateRangeScope(:final end) => end,
    _ => widget.today,
  };
  String? _error;

  void _apply() {
    if (_to.compareTo(_from) < 0) {
      setState(() => _error = 'The range must end on or after its start.');
      return;
    }
    Navigator.of(context).pop(DateRangeScope(start: _from, end: _to));
  }

  @override
  Widget build(BuildContext context) => EraDialog(
    title: 'Date range',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EraDateField(
          label: 'From',
          fieldKey: const ValueKey('range-from'),
          value: _from,
          today: widget.today,
          onChanged: (value) => setState(() => _from = value!),
        ),
        const SizedBox(height: 10),
        EraDateField(
          label: 'To',
          fieldKey: const ValueKey('range-to'),
          value: _to,
          today: widget.today,
          error: _error,
          onChanged: (value) => setState(() => _to = value!),
        ),
      ],
    ),
    actions: [
      KeyButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
      KeyButton(
        key: const ValueKey('range-apply'),
        label: 'Apply',
        kind: KeyKind.primary,
        onPressed: _apply,
      ),
    ],
  );
}

/// Hides voided rows unless the owner asks for them.
final class StateFilter extends StatelessWidget {
  const StateFilter({
    required this.showVoid,
    required this.onChanged,
    super.key,
  });

  final bool showVoid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Labelled(
    label: 'Status',
    child: EraCombo<bool>(
      semanticLabel: 'Status',
      value: showVoid,
      items: const [
        EraComboItem(false, 'Effective'),
        EraComboItem(true, 'Including void'),
      ],
      onSelected: onChanged,
    ),
  );
}

/// A toolbar combo after its "Label:", as the era's filter bars read.
final class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            '$label:',
            style: skin.typography.body.copyWith(color: skin.tokens.ink),
          ),
        ),
        const SizedBox(width: 4),
        child,
      ],
    );
  }
}

int _days(LocalDate start, LocalDate end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

LocalDate _deviceToday() {
  final now = DateTime.now();
  return LocalDate(now.year, now.month, now.day);
}

LocalDate _addDays(LocalDate date, int days) {
  final value = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(value.year, value.month, value.day);
}

/// The sheet shown in the list (spec 5.3 "View:").
final class SheetPicker extends StatelessWidget {
  const SheetPicker({required this.sheet, required this.onSheet, super.key});

  /// The sheet shown; the caller resolves the employment's default.
  final WorkSheet sheet;
  final ValueChanged<WorkSheet> onSheet;

  static const labels = {
    WorkSheet.calendar: 'Calendar',
    WorkSheet.shifts: 'Shifts',
    WorkSheet.leave: 'Leave',
    WorkSheet.schedules: 'Schedules',
    WorkSheet.periods: 'Pay periods',
    WorkSheet.payslips: 'Payslips',
    WorkSheet.agreements: 'Agreements',
  };

  @override
  Widget build(BuildContext context) => _Labelled(
    label: 'View',
    child: EraCombo<WorkSheet>(
      key: const ValueKey('work-view-combo'),
      semanticLabel: 'View',
      value: sheet,
      items: [
        for (final MapEntry(key: value, value: label) in labels.entries)
          EraComboItem(value, label),
      ],
      onSelected: onSheet,
    ),
  );
}
