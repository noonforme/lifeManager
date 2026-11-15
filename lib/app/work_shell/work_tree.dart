import '../../features/work/domain/employment.dart';
import '../../features/work/domain/ids.dart';
import '../../ui/ui.dart';
import '../work_edit/work_records.dart';
import 'work_location.dart';
import 'work_shell_controller.dart' show PastDayCounts;

/// An employment's sheets in the tree's order (spec 3): key, label, icon,
/// and the sheet the shell shows for it.
const employmentSheets = <(String, String, EraIconKind?, WorkSheetKind)>[
  ('calendar', 'Calendar', EraIconKind.calendar, WorkSheetKind.calendar),
  ('shifts', 'Shifts', EraIconKind.shift, WorkSheetKind.shifts),
  ('leave', 'Leave', EraIconKind.leave, WorkSheetKind.leave),
  ('schedules', 'Schedules', EraIconKind.schedule, WorkSheetKind.schedules),
  ('periods', 'Pay periods', EraIconKind.payPeriod, WorkSheetKind.periods),
  ('payslips', 'Payslips', EraIconKind.payslip, WorkSheetKind.payslips),
  ('agreements', 'Agreements', EraIconKind.agreement, WorkSheetKind.agreements),
  ('toConfirm', 'To confirm', EraIconKind.reviewed, WorkSheetKind.toConfirm),
];

/// The tree node id of [place]: the Work root, an employment, or one of
/// its live sheets.
String treeIdOf(WorkLocation place) => switch (place) {
  WorkLocation(employmentId: null) => 'work',
  WorkLocation(:final employmentId?, sheet: final kind?) =>
    '${kind.treeKey}:${employmentId.value}',
  WorkLocation(:final employmentId?) => 'employment:${employmentId.value}',
};

/// The Work tree (spec 3): Work, each active employment with its sheets
/// and their counts, then "Ended employments" holding the archived ones.
/// To confirm is a warning while days wait. Counts are left out while
/// [countsKnown] is false (the employments could not be read).
List<TreeNodeData> workTreeNodes({
  required List<EmploymentSummary> employments,
  required Map<EmploymentId, PastDayCounts> pastDays,
  required WorkLocation place,
  bool countsKnown = true,
}) {
  bool active(EmploymentSummary summary) =>
      summary.employment.status == EmploymentStatus.active;
  final current = [
    for (final summary in employments)
      if (active(summary)) summary,
  ];
  final ended = [
    for (final summary in employments)
      if (!active(summary)) summary,
  ];
  TreeNodeData employmentNode(EmploymentSummary summary) {
    final employment = summary.employment;
    final id = employment.id.value;
    final counts = summary.counts;
    final waiting = pastDays[employment.id]?.toConfirm;
    int? count(String key) => !countsKnown
        ? null
        : switch (key) {
            'shifts' => counts.shifts,
            'leave' => counts.leave,
            'schedules' => counts.schedules,
            'periods' => counts.periods,
            'payslips' => counts.payslips,
            'agreements' => counts.agreements,
            'toConfirm' => waiting,
            _ => null,
          };
    return TreeNodeData(
      id: 'employment:$id',
      label: employment.name,
      icon: EraIconKind.employment,
      muted: !active(summary),
      expanded: place.employmentId == employment.id,
      children: [
        for (final (key, label, icon, _) in employmentSheets)
          TreeNodeData(
            id: '$key:$id',
            label: label,
            icon: icon,
            count: count(key),
            warning: key == 'toConfirm' && (waiting ?? 0) > 0,
          ),
      ],
    );
  }

  return [
    TreeNodeData(
      id: 'work',
      label: 'Work',
      icon: EraIconKind.work,
      bold: true,
      expanded: true,
      count: current.length,
      children: [
        for (final summary in current) employmentNode(summary),
        if (ended.isNotEmpty)
          TreeNodeData(
            id: 'ended',
            label: 'Ended employments',
            count: ended.length,
            muted: true,
            expanded: ended.any(
              (summary) => summary.employment.id == place.employmentId,
            ),
            children: [for (final summary in ended) employmentNode(summary)],
          ),
      ],
    ),
  ];
}
