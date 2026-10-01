import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/history/record_events.dart';
import '../../../shared/workbench/office_controls.dart';
import 'work_controller.dart';
import 'work_route_state.dart';

/// Details and History tabs over a record's inspector content.
final class RecordTabs extends StatefulWidget {
  const RecordTabs({required this.record, required this.details, super.key});

  final WorkRecordRef record;
  final Widget details;

  @override
  State<RecordTabs> createState() => _RecordTabsState();
}

final class _RecordTabsState extends State<RecordTabs> {
  var _history = false;

  @override
  void didUpdateWidget(covariant RecordTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) _history = false;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SegmentedTabs(
          labels: const ['Details', 'History'],
          selectedIndex: _history ? 1 : 0,
          onSelected: (index) => setState(() => _history = index == 1),
        ),
      ),
      Expanded(
        child: _history
            ? RecordHistoryPanel(record: widget.record)
            : widget.details,
      ),
    ],
  );
}

/// A record's append-only history, oldest first.
final class RecordHistoryPanel extends ConsumerWidget {
  const RecordHistoryPanel({required this.record, super.key});

  final WorkRecordRef record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Record history',
      child: switch (ref.watch(recordEventsProvider(record))) {
        AsyncData(value: final events) when events.isEmpty => const Padding(
          padding: EdgeInsets.all(20),
          child: Text('No history yet.'),
        ),
        AsyncData(value: final events) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final event in events.reversed) ...[
              Text(_kindWord(event.kind), style: text.titleSmall),
              Text(
                '${event.atUtc.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} UTC',
                style: text.bodySmall,
              ),
              if (event.reason case final reason?) Text('Reason: $reason'),
              for (final change in event.changes)
                Text(
                  change.before == null
                      ? '${change.field}: ${change.after}'
                      : '${change.field}: ${change.before} → '
                            '${change.after ?? '—'}',
                ),
              const SizedBox(height: 14),
            ],
          ],
        ),
        AsyncError() => const Padding(
          padding: EdgeInsets.all(20),
          child: Text('History is unavailable. Reload Work to try again.'),
        ),
        AsyncLoading() => const SizedBox.shrink(),
      },
    );
  }
}

String _kindWord(RecordEventKind kind) => switch (kind) {
  RecordEventKind.created => 'Created',
  RecordEventKind.changed => 'Changed',
  RecordEventKind.finalized => 'Finalized',
  RecordEventKind.voided => 'Voided',
  RecordEventKind.replaced => 'Created as a replacement',
  RecordEventKind.reviewed => 'Reviewed',
};
