import 'package:flutter/material.dart';

import '../../../core/time/local_date.dart';
import '../../../shared/workbench/lifeos_skin.dart';
import '../../../shared/workbench/office_controls.dart';
import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/pay.dart';
import '../domain/pay_period.dart';
import '../domain/reconciliation.dart';
import '../domain/shift.dart';
import 'work_formats.dart';
import 'work_route_state.dart';
import 'work_sheets.dart' show periodName;

/// Work's desk tiles (shell spec 6.4). Each is computed from the
/// employments' records and states only facts.

/// Something waiting on the owner, with where it opens.
final class NeedsYouItem {
  const NeedsYouItem({required this.text, required this.route});

  final String text;
  final String route;
}

/// The running shift, drafts and open periods with a difference.
List<NeedsYouItem> needsYou({
  required ShiftRecordProjection? active,
  required String Function(ShiftRecordProjection active) activeLabel,
  required List<WorkRegisterProjection> registers,
}) {
  String open(WorkRegisterProjection register, WorkRecordRef record) =>
      workRouteUri(
        WorkRouteState(
          employmentId: register.scope.employmentId,
          scope: null,
          record: record,
          mode: WorkInspectorMode.inspect,
        ),
      ).toString();
  return [
    if (active case final active?)
      NeedsYouItem(
        text: activeLabel(active),
        route: workRouteUri(
          WorkRouteState(
            employmentId: active.shift.employmentId,
            scope: null,
            record: WorkRecordRef(
              kind: WorkRecordKind.shift,
              id: active.shift.id,
            ),
            mode: WorkInspectorMode.inspect,
          ),
        ).toString(),
      ),
    for (final register in registers) ...[
      for (final row in register.shiftSheet)
        if (row.shift.state == ShiftState.draft)
          NeedsYouItem(
            text:
                'Shift on ${row.shift.localStartDate} is a draft and needs '
                'finalizing',
            route: open(
              register,
              WorkRecordRef(kind: WorkRecordKind.shift, id: row.shift.id),
            ),
          ),
      for (final row in register.periodSheet)
        if (row.period.state == PayPeriodState.open &&
            row.group?.status is Difference)
          NeedsYouItem(
            text:
                'Pay period ${periodName(row.period)} differs from expected '
                'by ${formatMoney(row.group!.difference!)}',
            route: open(
              register,
              WorkRecordRef(kind: WorkRecordKind.payPeriod, id: row.period.id),
            ),
          ),
    ],
  ];
}

/// Paid time and expected pay so far in the period containing today.
final class ThisPeriodRow {
  const ThisPeriodRow({
    required this.employment,
    required this.period,
    required this.paidSeconds,
    required this.expected,
  });

  final String employment;
  final PayPeriod period;
  final int paidSeconds;
  final Money expected;
}

List<ThisPeriodRow> workThisPeriod(
  List<WorkRegisterProjection> registers,
  LocalDate today,
) => [
  for (final register in registers)
    for (final row in register.periodSheet)
      if (row.period.contains(today))
        () {
          final shifts = register.shiftSheet.where(
            (shift) =>
                shift.shift.state == ShiftState.finalized &&
                row.period.contains(shift.shift.localStartDate) &&
                shift.shift.localStartDate.compareTo(today) <= 0,
          );
          return ThisPeriodRow(
            employment: register.employment?.name ?? 'Employment',
            period: row.period,
            paidSeconds: shifts.fold(
              0,
              (total, shift) => total + (shift.paidSeconds ?? 0),
            ),
            expected: Money(
              minorUnits: shifts.fold(
                0,
                (total, shift) => total + (shift.pay?.amount.minorUnits ?? 0),
              ),
            ),
          );
        }(),
];

/// One factual check of the Month close checklist.
final class ChecklistItem {
  const ChecklistItem({
    required this.label,
    required this.done,
    required this.detail,
  });

  final String label;
  final bool done;
  final String detail;
}

/// Month close checks over [month]'s dates. Each item is true only when the
/// data says so.
List<ChecklistItem> monthChecklist(
  List<WorkRegisterProjection> registers,
  ({LocalDate start, LocalDate end}) month,
) {
  bool inMonth(LocalDate date) =>
      date.compareTo(month.start) >= 0 && date.compareTo(month.end) <= 0;
  bool overlaps(PayPeriod period) =>
      period.start.compareTo(month.end) <= 0 &&
      period.end.compareTo(month.start) >= 0;
  final open = [
    for (final register in registers)
      for (final row in register.shiftSheet)
        if (inMonth(row.shift.localStartDate) &&
            switch (row.shift.state) {
              ShiftState.draft ||
              ShiftState.running ||
              ShiftState.onBreak => true,
              ShiftState.finalized || ShiftState.voided => false,
            })
          row,
  ];
  final periods = [
    for (final register in registers)
      for (final row in register.periodSheet)
        if (overlaps(row.period)) row,
  ];
  final withoutPayslip = periods.where(
    (row) => row.groups.every((group) => group.paid == null),
  );
  final unreviewed = periods.where(
    (row) =>
        row.group?.status is Difference &&
        row.period.state != PayPeriodState.reviewed,
  );
  String count(int n, String one, String many) =>
      n == 1 ? '1 $one' : '$n $many';
  return [
    ChecklistItem(
      label: 'Every shift this month is finalized',
      done: open.isEmpty,
      detail: open.isEmpty
          ? 'No drafts or running shifts'
          : '${count(open.length, 'shift', 'shifts')} still open',
    ),
    ChecklistItem(
      label: 'Every pay period has a payslip',
      done: periods.isNotEmpty && withoutPayslip.isEmpty,
      detail: periods.isEmpty
          ? 'No pay period covers this month yet'
          : withoutPayslip.isEmpty
          ? 'All recorded'
          : '${count(withoutPayslip.length, 'period', 'periods')} without one',
    ),
    ChecklistItem(
      label: 'Every difference is reviewed',
      done: unreviewed.isEmpty,
      detail: unreviewed.isEmpty
          ? 'Nothing left to review'
          : '${count(unreviewed.length, 'period', 'periods')} to review',
    ),
  ];
}

/// Lines of text in a tile, or its empty copy.
final class TileList extends StatelessWidget {
  const TileList({
    required this.lines,
    required this.empty,
    this.onOpen,
    this.action,
    super.key,
  });

  final List<({String text, String? detail, String? route, bool? done})> lines;
  final String empty;
  final ValueChanged<String>? onOpen;

  /// A key under the empty copy, such as Add employment, with its route.
  final ({String label, String route})? action;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              empty,
              style: skin.typography.body.copyWith(color: tokens.muted),
            ),
            if ((action, onOpen) case (final action?, final open?)) ...[
              const SizedBox(height: 10),
              KeyButton(
                label: action.label,
                kind: KeyKind.primary,
                onPressed: () => open(action.route),
              ),
            ],
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        for (final line in lines)
          InkWell(
            onTap: line.route == null || onOpen == null
                ? null
                : () => onOpen!(line.route!),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (line.done case final done?) ...[
                    Icon(
                      done ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                      semanticLabel: done ? 'Done' : 'Not done',
                      color: done ? tokens.positive : tokens.negative,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.text,
                          style: skin.typography.body.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                        if (line.detail case final detail?)
                          Text(
                            detail,
                            style: skin.typography.small.copyWith(
                              color: tokens.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
