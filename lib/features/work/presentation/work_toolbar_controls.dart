import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
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
    return PopupMenuButton<_SwitcherChoice>(
      tooltip: 'Switch employment',
      onSelected: (choice) => switch (choice) {
        _OpenEmployment(:final id) => onOpen?.call(id),
        _AllEmployments() => onAll?.call(),
        _CreateEmployment() => onCreate(),
      },
      itemBuilder: (context) => [
        for (final employment in employments)
          PopupMenuItem(
            value: _OpenEmployment(employment.id),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: employment.id == current
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                Text(employment.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _AllEmployments(),
          child: Text('All employments'),
        ),
        const PopupMenuItem(
          value: _CreateEmployment(),
          child: Text('Create employment'),
        ),
      ],
      child: _MenuFace(label: 'Employment', detail: currentName),
    );
  }
}

sealed class _ScopeChoice {
  const _ScopeChoice();
}

final class _Scope extends _ScopeChoice {
  const _Scope(this.scope);

  final WorkTemporalScope? scope;
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
    super.key,
  });

  final WorkTemporalScope? scope;

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
      builder: (context) => _RangeDialog(initial: scope),
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
        KeyButton(
          label: '‹',
          semanticLabel: previous == null
              ? 'Previous period, unavailable'
              : 'Previous period',
          kind: KeyKind.small,
          onPressed: previous == null ? null : () => onScope(previous),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<_ScopeChoice>(
          tooltip: 'Choose period',
          onSelected: (choice) => switch (choice) {
            _Scope(:final scope) => onScope(scope),
            _AskRange() => _askRange(context),
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: _Scope(null), child: Text('All dates')),
            for (final period in periods.reversed)
              PopupMenuItem(
                value: _Scope(PayPeriodScope(period.id)),
                child: Text(periodName(period)),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: _AskRange(), child: Text('Date range…')),
          ],
          child: _MenuFace(label: 'Period', detail: _label),
        ),
        const SizedBox(width: 4),
        KeyButton(
          label: '›',
          semanticLabel: next == null
              ? 'Next period, unavailable'
              : 'Next period',
          kind: KeyKind.small,
          onPressed: next == null ? null : () => onScope(next),
        ),
      ],
    );
  }
}

final class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.initial});

  final WorkTemporalScope? initial;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

final class _RangeDialogState extends State<_RangeDialog> {
  late final _from = TextEditingController(
    text: switch (widget.initial) {
      DateRangeScope(:final start) => start.toString(),
      _ => '',
    },
  );
  late final _to = TextEditingController(
    text: switch (widget.initial) {
      DateRangeScope(:final end) => end.toString(),
      _ => '',
    },
  );
  String? _error;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _apply() {
    final from = LocalDate.tryParse(_from.text.trim());
    final to = LocalDate.tryParse(_to.text.trim());
    if (from == null || to == null) {
      setState(() => _error = 'Enter both dates as YYYY-MM-DD.');
      return;
    }
    if (to.compareTo(from) < 0) {
      setState(() => _error = 'The range must end on or after its start.');
      return;
    }
    Navigator.of(context).pop(DateRangeScope(start: from, end: to));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Date range'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('range-from'),
          controller: _from,
          decoration: const InputDecoration(labelText: 'From'),
        ),
        TextField(
          key: const ValueKey('range-to'),
          controller: _to,
          decoration: InputDecoration(labelText: 'To', errorText: _error),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey('range-apply'),
        onPressed: _apply,
        child: const Text('Apply'),
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
  Widget build(BuildContext context) => PopupMenuButton<bool>(
    tooltip: 'Filter by state',
    onSelected: onChanged,
    itemBuilder: (context) => [
      CheckedPopupMenuItem(
        value: false,
        checked: !showVoid,
        child: const Text('Effective and drafts'),
      ),
      CheckedPopupMenuItem(
        value: true,
        checked: showVoid,
        child: const Text('Include void'),
      ),
    ],
    child: _MenuFace(
      label: 'Status',
      detail: showVoid ? 'Including void' : 'Effective',
    ),
  );
}

/// What a toolbar menu looks like closed: "Label: detail" and a drop arrow.
final class _MenuFace extends StatelessWidget {
  const _MenuFace({required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final style = skin.typography.body.copyWith(color: skin.tokens.ink);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: skin.tokens.muted),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: style),
            if (detail case final detail?) ...[
              Text(': ', style: style),
              Text(detail, style: style),
            ],
            Icon(Icons.arrow_drop_down, size: 18, color: skin.tokens.ink),
          ],
        ),
      ),
    );
  }
}

int _days(LocalDate start, LocalDate end) => DateTime.utc(
  end.year,
  end.month,
  end.day,
).difference(DateTime.utc(start.year, start.month, start.day)).inDays;

LocalDate _addDays(LocalDate date, int days) {
  final value = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(value.year, value.month, value.day);
}
