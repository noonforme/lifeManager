import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/data_register.dart';
import '../../../shared/workbench/lifeos_skin.dart' show KeyKind;
import '../../../shared/workbench/office_controls.dart';
import '../../../shared/workbench/operational_state.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import 'work_controller.dart';
import 'work_route_state.dart';
import 'work_sheets.dart' show workRowId;

/// "In use", "Ended" or "Future" on [today].
String scheduleState(WorkSchedule version, LocalDate today) =>
    version.isInUseOn(today)
    ? 'In use'
    : version.inUseFrom.compareTo(today) > 0
    ? 'Future'
    : 'Ended';

WorkRecordRef _ref(WorkSchedule version) =>
    WorkRecordRef(kind: WorkRecordKind.schedule, id: version.id);

/// The Schedules sheet (schedules spec 6.4): every version of every
/// schedule, newest first within a schedule.
final class SchedulesSheet extends StatelessWidget {
  const SchedulesSheet({
    required this.versions,
    required this.today,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    super.key,
  });

  final List<WorkSchedule> versions;
  final LocalDate today;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final ValueChanged<WorkRecordRef>? onProperties;

  @override
  Widget build(BuildContext context) {
    final latest = <ScheduleId, int>{};
    for (final value in versions) {
      final known = latest[value.id];
      if (known == null || value.version > known) {
        latest[value.id] = value.version;
      }
    }
    final rows = [...versions]
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        return byName != 0 ? byName : b.version.compareTo(a.version);
      });
    // The latest version's row is the schedule's own, so selecting the
    // schedule selects it; older versions are told apart by their number.
    String rowId(WorkSchedule value) => latest[value.id] == value.version
        ? workRowId(_ref(value))
        : '${workRowId(_ref(value))}@${value.version}';
    return DataRegister<WorkSchedule>(
      label: 'Schedules',
      lines: [for (final row in rows) RowLine(row)],
      sortedColumn: 'name',
      rowId: rowId,
      rowLabel: (row) => '${row.name}, version ${row.version}',
      selectedId: selectedId,
      onOpen: (row) => onOpen(_ref(row)),
      onActivate: onProperties == null
          ? null
          : (row) => onProperties!(_ref(row)),
      actions: onProperties == null
          ? null
          : (row) => [
              RowAction(
                label: 'Properties',
                isDefault: true,
                onInvoke: () => onProperties!(_ref(row)),
              ),
            ],
      columns: [
        RegisterColumn(
          key: 'name',
          label: 'Name',
          kind: ColumnKind.text,
          width: 160,
          value: (row) => row.name,
        ),
        RegisterColumn(
          key: 'version',
          label: 'Version',
          kind: ColumnKind.quantity,
          width: 64,
          value: (row) => '${row.version}',
        ),
        RegisterColumn(
          key: 'from',
          label: 'In use from',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => '${row.inUseFrom}',
        ),
        RegisterColumn(
          key: 'until',
          label: 'Until',
          kind: ColumnKind.date,
          width: 104,
          value: (row) => row.inUseUntil?.toString() ?? '',
        ),
        RegisterColumn(
          key: 'cycle',
          label: 'Cycle',
          kind: ColumnKind.quantity,
          width: 72,
          value: (row) =>
              row.cycleLength == 1 ? '1 day' : '${row.cycleLength} days',
        ),
        RegisterColumn(
          key: 'state',
          label: 'State',
          kind: ColumnKind.state,
          width: 72,
          value: (row) => scheduleState(row, today),
        ),
      ],
    );
  }
}

/// The employment's schedules, live.
final class SchedulesSheetHost extends ConsumerWidget {
  const SchedulesSheetHost({
    required this.employmentId,
    required this.today,
    required this.selectedId,
    required this.onOpen,
    this.onProperties,
    required this.onNew,
    super.key,
  });

  final EmploymentId employmentId;
  final LocalDate today;
  final String? selectedId;
  final ValueChanged<WorkRecordRef> onOpen;
  final ValueChanged<WorkRecordRef>? onProperties;

  /// Opens a new schedule; null until the employment has an agreement.
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(employmentSchedulesProvider(employmentId))) {
        AsyncData(:final value) when value.isEmpty => OperationalState(
          kind: OperationalStateKind.empty,
          title: 'No schedules yet',
          message:
              'Describe your rotation once to see every planned shift and '
              'its pay ahead of time.',
          action: onNew == null
              ? null
              : KeyButton(
                  label: 'New schedule…',
                  kind: KeyKind.primary,
                  onPressed: onNew,
                ),
        ),
        AsyncData(:final value) => SchedulesSheet(
          versions: value,
          today: today,
          selectedId: selectedId,
          onOpen: onOpen,
          onProperties: onProperties,
        ),
        AsyncError() => const OperationalState(
          kind: OperationalStateKind.unavailable,
          title: 'Schedules unavailable',
          message: 'Reload Work to read the schedules again.',
        ),
        _ => const OperationalState(
          kind: OperationalStateKind.loading,
          title: 'Reading schedules',
          message: 'Reading the local schedules.',
        ),
      };
}
