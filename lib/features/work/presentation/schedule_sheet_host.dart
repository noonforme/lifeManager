import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/local_date.dart';
import '../../../shared/shell/status_line.dart';
import '../../../ui/ui.dart';
import '../domain/ids.dart';
import '../domain/schedule.dart';
import 'schedule_editor.dart';
import 'work_controller.dart';
import 'work_route_state.dart';

/// Binds the schedule editor to [ScheduleService]: a new schedule when
/// [scheduleId] is null, otherwise that schedule's latest version.
final class ScheduleSheetHost extends ConsumerWidget {
  const ScheduleSheetHost({
    required this.employmentId,
    required this.employmentName,
    required this.scheduleId,
    required this.today,
    required this.defaultTimezoneId,
    required this.onCreated,
    required this.onDeleted,
    super.key,
  });

  final EmploymentId employmentId;
  final String employmentName;
  final ScheduleId? scheduleId;
  final LocalDate today;
  final String defaultTimezoneId;
  final VoidCallback onCreated;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final register = switch (ref.watch(
      employmentRegisterProvider(employmentId),
    )) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final agreements = [
      if (register != null)
        for (final row in register.agreementSheet) row.agreement,
    ];
    final zones = ref.watch(zoneClocksProvider);
    final timezones = ref.watch(timezoneServiceProvider);
    final service = ref.read(scheduleServiceProvider);
    void notice(String text) => StatusNoticeScope.read(context)?.value = text;

    final id = scheduleId;
    if (id == null) {
      return ScheduleEditor(
        key: const ValueKey('new-schedule'),
        employmentId: employmentId,
        employmentName: employmentName,
        today: today,
        defaultTimezoneId: defaultTimezoneId,
        agreements: agreements,
        zoneClocks: zones,
        timezones: timezones,
        onSave: (draft, {newVersionFrom}) async {
          final outcome = await service.create(draft);
          if (outcome is Committed<WorkSchedule>) {
            notice('Schedule saved.');
            onCreated();
          }
          return outcome;
        },
      );
    }
    return switch (ref.watch(employmentSchedulesProvider(employmentId))) {
      AsyncData(:final value) => () {
        final versions = [
          for (final version in value)
            if (version.id == id) version,
        ];
        if (versions.isEmpty) {
          return const OperationalState(
            kind: OperationalStateKind.unavailable,
            title: 'Schedule unavailable',
            message: 'This schedule no longer exists.',
          );
        }
        final latest = versions.reduce(
          (a, b) => a.version >= b.version ? a : b,
        );
        final used = versions.any((version) => version.usedByConfirmedDay);
        return ScheduleEditor(
          key: ValueKey(('schedule', id, latest.version, latest.revision)),
          employmentId: employmentId,
          employmentName: employmentName,
          today: today,
          defaultTimezoneId: defaultTimezoneId,
          agreements: agreements,
          zoneClocks: zones,
          timezones: timezones,
          initial: latest,
          // History is kept per version (work_history.dart).
          historyRecord: WorkRecordRef(
            kind: WorkRecordKind.schedule,
            id: ScheduleId('${id.value}@${latest.version}'),
          ),
          onSave: (draft, {newVersionFrom}) async {
            final outcome = await service.update(
              id,
              expected: latest.revision,
              draft: draft,
              newVersionFrom: newVersionFrom,
            );
            if (outcome is Committed<WorkSchedule>) notice('Schedule saved.');
            return outcome;
          },
          onDelete: used
              ? null
              : () async {
                  final outcome = await service.delete(
                    id,
                    expected: latest.revision,
                  );
                  if (outcome is Committed<WorkSchedule>) {
                    notice('Schedule deleted.');
                    onDeleted();
                  }
                  return outcome;
                },
        );
      }(),
      AsyncError() => const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Schedule unavailable',
        message: 'Reload Work to read the schedule again.',
      ),
      _ => const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Reading the schedule',
        message: 'Reading the local schedule.',
      ),
    };
  }
}
