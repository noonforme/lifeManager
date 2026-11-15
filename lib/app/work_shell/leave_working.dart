import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/leave.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import 'leave_sheet_part.dart' show leaveAverage, leavePercent;
import 'pay_sheet_part.dart' show payBasis;

/// How [pay] for leave on [date] is worked out: the average window and
/// its totals, the percent and who pays. The Leave sheet's Working tab and
/// a planned leave day's on Shifts (bead 9pk.4.19); it explains the price
/// and calculates nothing.
Widget leaveWorking({
  required LeavePay pay,
  required LocalDate date,
  required EditorSessionController editors,
}) {
  final average = pay.average;
  final facts = <(String, String)>[
    (
      'Average window',
      '${date.firstOfMonth.addMonths(-3)} – ${date.firstOfMonth.addDays(-1)}',
    ),
    if (average != null) ...[
      (
        'Confirmed pay in window',
        formatMoney(Money(minorUnits: average.minorUnits)),
      ),
      ('Paid time in window', formatDuration(average.paidSeconds)),
    ],
    ('Average used', leaveAverage(pay)),
    if (pay.usedFallback)
      (
        'Why agreement rate',
        pay.otherBasisLeftOut
            ? 'No confirmed ${_basis(pay.basis)} paid time in the three months '
                  'before this day.'
            : 'No confirmed paid time in the three months before this day.',
      ),
    if (pay.otherBasisLeftOut)
      (
        'Left out',
        '${payBasis(_other(pay.basis))} pay in the window: this day is paid '
            '${_basis(pay.basis)}, and gross and net are never combined.',
      ),
    ('Paid time', formatDuration(pay.paidSeconds)),
    ('Percent', leavePercent(pay)),
    (
      'Employer pays',
      pay.employerPaid
          ? 'Yes'
          : 'No; paid by the social insurer, not on your payslip.',
    ),
    ('Pay', formatMoney(pay.amount)),
  ];
  return _grid(facts, editors, footerLabel: 'Pay ${formatMoney(pay.amount)}');
}

String _basis(RateBasis basis) => payBasis(basis).toLowerCase();

RateBasis _other(RateBasis basis) =>
    basis is GrossBasis ? const NetBasis() : const GrossBasis();

/// The Working table with nothing selected or no pay to explain.
Widget noLeaveWorking(EditorSessionController editors) =>
    _grid(const [], editors);

Widget _grid(
  List<(String, String)> facts,
  EditorSessionController editors, {
  String? footerLabel,
}) => DataGrid<(String, String)>(
  label: 'Leave working',
  columns: [
    GridColumn(
      key: 'fact',
      label: 'Working',
      kind: ValueKind.text,
      width: 175,
      value: (row) => row.$1,
    ),
    GridColumn(
      key: 'value',
      label: 'Value',
      kind: ValueKind.text,
      width: 410,
      value: (row) => row.$2,
    ),
  ],
  lines: [for (final fact in facts) GridRow(fact)],
  rowId: (row) => row.$1,
  rowLabel: (row) => '${row.$1}: ${row.$2}',
  selectedId: null,
  editorController: editors,
  showNavigator: false,
  footerLabel: footerLabel,
);
