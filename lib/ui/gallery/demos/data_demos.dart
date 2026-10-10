import 'package:flutter/widgets.dart';

import '../../ui.dart';
import '../gallery_demo.dart';

final dataDemos = <GalleryDemo>[
  GalleryDemo(
    id: 'data/data_register',
    widget: 'DataRegister',
    summary:
        'The details list: bevelled sortable headers, group rows, 20 px rows, '
        'planned rows greyed, a subtotal.',
    size: const Size(640, 260),
    build: (context, knobs) => GalleryValue<String?>(
      initial: '2026-10-06',
      builder: (context, selected, select) => SizedBox(
        width: 600 * knobs.textScale,
        height: 220 * knobs.textScale,
        child: DataRegister<_Day>(
          label: 'Shifts',
          lines: [
            GroupLine<_Day>(
              label: 'October 2026',
              summary: knobs.text(
                '3 shifts',
                '3 shifts, 34:30 paid, EUR 634.80 expected',
              ),
            ),
            for (final day in _days)
              RowLine<_Day>(
                day,
                state: day.planned ? RowState.planned : RowState.normal,
              ),
            const SubtotalLine<_Day>(
              label: 'Total',
              cells: {'paid': '34:30', 'pay': 'EUR 634.80'},
            ),
          ],
          columns: [
            RegisterColumn<_Day>(
              key: 'date',
              label: 'Date',
              kind: ColumnKind.date,
              width: 96,
              value: (day) => day.date,
            ),
            RegisterColumn<_Day>(
              key: 'type',
              label: 'Type',
              kind: ColumnKind.text,
              width: 64,
              value: (day) => day.type,
            ),
            RegisterColumn<_Day>(
              key: 'paid',
              label: 'Paid',
              kind: ColumnKind.duration,
              width: 64,
              value: (day) => day.paid,
            ),
            RegisterColumn<_Day>(
              key: 'pay',
              label: 'Est. pay',
              kind: ColumnKind.money,
              width: 96,
              value: (day) => day.pay,
            ),
            RegisterColumn<_Day>(
              key: 'state',
              label: 'State',
              kind: ColumnKind.state,
              width: 96,
              value: (day) => day.state,
            ),
          ],
          rowId: (day) => day.date,
          rowLabel: (day) => 'Shift ${day.date}',
          selectedId: selected,
          onOpen: (day) => select(day.date),
          sortedColumn: 'date',
        ),
      ),
    ),
  ),
  GalleryDemo(
    id: 'data/cell_selection_scope',
    widget: 'CellSelectionScope',
    summary:
        'Shares the selected list cell with the window, for a derived '
        "figure's explanation.",
    build: (context, knobs) => _CellSelectionDemo(knobs: knobs),
  ),
  GalleryDemo(
    id: 'data/operational_state',
    widget: 'OperationalState',
    summary:
        "A sheet's loading, empty, unavailable, conflict and uncertain "
        'states.',
    build: (context, knobs) => SizedBox(
      width: 420 * knobs.textScale,
      height: 180 * knobs.textScale,
      child: OperationalState(
        kind: knobs.error
            ? OperationalStateKind.unavailable
            : OperationalStateKind.empty,
        title: knobs.error ? 'Shifts are unavailable' : 'No shifts yet',
        message: knobs.text(
          'Add a shift or set up a schedule.',
          'Add a shift by hand, or set up a pay agreement and a schedule so '
              'planned days appear here.',
        ),
        action: KeyButton(label: 'Add a shift', onPressed: knobs.press(() {})),
      ),
    ),
  ),
];

final class _Day {
  const _Day(
    this.date,
    this.type,
    this.paid,
    this.pay,
    this.state, {
    this.planned = false,
  });

  final String date;
  final String type;
  final String paid;
  final String pay;
  final String state;
  final bool planned;
}

const _days = [
  _Day('2026-10-05', 'Day', '11:30', 'EUR 211.60', 'Finalized'),
  _Day('2026-10-06', 'Day', '11:30', 'EUR 211.60', 'To confirm'),
  _Day('2026-10-07', 'Day', '11:30', 'EUR 211.60', 'To confirm'),
  _Day('2026-10-11', 'Night', '11:30', 'EUR 280.60', 'Planned', planned: true),
];

final class _CellSelectionDemo extends StatefulWidget {
  const _CellSelectionDemo({required this.knobs});

  final GalleryKnobs knobs;

  @override
  State<_CellSelectionDemo> createState() => _CellSelectionDemoState();
}

final class _CellSelectionDemoState extends State<_CellSelectionDemo> {
  final _cells = CellSelectionController();

  @override
  void dispose() {
    _cells.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CellSelectionScope(
    controller: _cells,
    child: ValueListenableBuilder<CellSelection?>(
      valueListenable: _cells,
      builder: (context, cell, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cell == null
                ? 'No cell selected.'
                : '${cell.columnLabel}: ${cell.display}',
          ),
          KeyButton(
            label: 'Select paid time',
            onPressed: widget.knobs.press(
              () => _cells.value = CellSelection(
                owner: this,
                reference: 'D1',
                columnLabel: 'Paid',
                display: '11:30',
              ),
            ),
          ),
          KeyButton(
            label: 'Clear selection',
            onPressed: widget.knobs.press(() => _cells.clearFrom(this)),
          ),
        ],
      ),
    ),
  );
}
