import 'package:flutter/material.dart';

import '../../core/time/timezone_service.dart';
import '../../shared/workbench/data_register.dart';
import '../../shared/workbench/lifeos_skin.dart';
import '../../shared/workbench/office_controls.dart';
import '../../shared/workbench/operational_state.dart';
import '../work/presentation/work_formats.dart';
import '../work/presentation/work_sheets.dart' show workRowId;
import 'journal_controller.dart';
import 'journal_projection.dart';

/// The Journal sheet (shell spec 6.5): days of Work events, newest first,
/// each day summarised by paid time, expected pay and money paid in.
final class JournalSheet extends StatelessWidget {
  const JournalSheet({
    required this.range,
    required this.entries,
    required this.timezones,
    required this.onRange,
    required this.onOpen,
    super.key,
  });

  final JournalRange range;

  /// Null while loading.
  final List<JournalEntry>? entries;
  final TimezoneService timezones;
  final ValueChanged<JournalRange> onRange;
  final ValueChanged<JournalEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final loaded = entries;
    return ColoredBox(
      color: skin.tokens.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                KeyButton(
                  label: '‹',
                  semanticLabel: 'Earlier days',
                  kind: KeyKind.small,
                  onPressed: () => onRange(range.step(-1)),
                ),
                const SizedBox(width: 8),
                Text(
                  '${range.from} – ${range.to}',
                  style: skin.typography.body.copyWith(color: skin.tokens.ink),
                ),
                const SizedBox(width: 8),
                KeyButton(
                  label: '›',
                  semanticLabel: 'Later days',
                  kind: KeyKind.small,
                  onPressed: () => onRange(range.step(1)),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (loaded) {
              null => const OperationalState(
                kind: OperationalStateKind.loading,
                title: 'Reading the Journal',
                message: 'Collecting what happened on these days.',
              ),
              [] => const OperationalState(
                kind: OperationalStateKind.empty,
                title: 'Nothing recorded on these days',
                message: 'Work events appear here as they happen.',
              ),
              final rows => _register(rows),
            },
          ),
        ],
      ),
    );
  }

  Widget _register(List<JournalEntry> rows) {
    final lines = <RegisterLine<JournalEntry>>[];
    for (final day in journalDays(rows)) {
      lines.add(
        GroupLine(
          label: '${day.date}',
          summary: [
            if (day.paidSeconds > 0) 'paid ${formatDuration(day.paidSeconds)}',
            if (day.expected.minorUnits != 0)
              'expected ${formatMoney(day.expected)}',
            if (day.paidIn.minorUnits != 0)
              'paid in ${formatMoney(day.paidIn)}',
          ].join(' · '),
        ),
      );
      for (final entry in day.entries) {
        lines.add(
          RowLine(
            entry,
            state: entry.state == 'Void' ? RowState.voided : RowState.normal,
          ),
        );
      }
    }
    return DataRegister<JournalEntry>(
      label: 'Journal',
      lines: lines,
      rowId: (entry) => '${workRowId(entry.record)}@${entry.sequence}',
      rowLabel: (entry) => '${entry.kind.label}, ${entry.summary}',
      selectedId: null,
      onOpen: onOpen,
      columns: [
        RegisterColumn(
          key: 'time',
          label: 'Time',
          kind: ColumnKind.time,
          width: 64,
          value: (entry) => timezones
              .localTimeAt(entry.atUtc, entry.zoneId)
              .toString()
              .substring(0, 5),
        ),
        RegisterColumn(
          key: 'area',
          label: 'Area',
          kind: ColumnKind.area,
          width: 56,
          value: (entry) => entry.area.label,
          cell: (entry) => Align(
            alignment: Alignment.centerLeft,
            child: AreaKey(area: entry.area),
          ),
        ),
        RegisterColumn(
          key: 'entry',
          label: 'Entry',
          kind: ColumnKind.text,
          width: 320,
          value: (entry) => '${entry.kind.label} · ${entry.summary}',
        ),
        RegisterColumn(
          key: 'amount',
          label: 'Amount',
          kind: ColumnKind.money,
          width: 112,
          value: (entry) =>
              entry.amount == null ? '' : formatMoney(entry.amount!),
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 96,
          value: (entry) => entry.state,
        ),
      ],
    );
  }
}
