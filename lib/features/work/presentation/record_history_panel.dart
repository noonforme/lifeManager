import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/history/record_events.dart';
import '../../../shared/shell/shell_frame.dart';
import '../../../shared/shell/working_group_box.dart';
import '../../../shared/workbench/inspector_parts.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/millennium_style.dart';
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
  Widget build(BuildContext context) {
    final chrome = ShellChrome.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PropertySheetTabs(
          labels: const ['General', 'History'],
          selectedIndex: _history ? 1 : 0,
          onSelected: (index) => setState(() => _history = index == 1),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: MillenniumColors.page,
              border: Border(
                left: BorderSide(color: MillenniumColors.tabLine),
                right: BorderSide(color: MillenniumColors.tabLine),
                bottom: BorderSide(color: MillenniumColors.tabLine),
              ),
            ),
            child: _history
                ? RecordHistoryPanel(record: widget.record)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: WorkingGroupBox(
                          onNavigate: (route) =>
                              chrome?.onNavigate(route.toString()),
                        ),
                      ),
                      Expanded(child: widget.details),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// A record's append-only history, oldest first.
final class RecordHistoryPanel extends ConsumerWidget {
  const RecordHistoryPanel({required this.record, super.key});

  final WorkRecordRef record;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Record history',
    child: switch (ref.watch(recordEventsProvider(record))) {
      AsyncData(value: final events) when events.isEmpty => const InspectorPane(
        children: [InspectorText('No history yet.')],
      ),
      AsyncData(value: final events) => InspectorPane(
        children: [
          for (final event in events.reversed) _HistoryEntry(event: event),
        ],
      ),
      AsyncError() => const InspectorPane(
        children: [
          InspectorText('History is unavailable. Reload Work to try again.'),
        ],
      ),
      AsyncLoading() => const SizedBox.shrink(),
    },
  );
}

/// One event as a register row: what happened and when, then its reason
/// and field changes in small type.
final class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.event});

  final RecordEvent event;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final small = skin.typography.small.copyWith(color: tokens.muted);
    final at = event.atUtc.toIso8601String().substring(0, 16);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  _kindWord(event.kind),
                  style: skin.typography.body.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${at.replaceFirst('T', ' ')} UTC',
                style: skin.typography.figure.copyWith(color: tokens.muted),
              ),
            ],
          ),
          if (event.reason case final reason?)
            Text('Reason: $reason', style: small),
          for (final change in event.changes)
            Text(
              change.before == null
                  ? '${change.field}: ${change.after}'
                  : '${change.field}: ${change.before} → '
                        '${change.after ?? '—'}',
              style: small,
            ),
        ],
      ),
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
