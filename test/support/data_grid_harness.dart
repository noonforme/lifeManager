import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/ui/gallery/gallery_host.dart';
import 'package:lifeos/ui/ui.dart';

/// A synthetic shift the DataGrid tests edit: its saved values and the
/// pending values the grid's commits write.
final class TestShift {
  TestShift(
    this.id,
    this.date, {
    this.type = 'day',
    this.start = const LocalTime(7, 0),
    this.end = const LocalTime(19, 0),
    this.breakMinutes = 30,
    this.confirmed = false,
    this.note = '',
    this.lockReason,
    this.state = GridRowState.normal,
    this.pickable = true,
  });

  final String id;
  LocalDate date;
  String type;
  LocalTime start;
  LocalTime end;
  int breakMinutes;
  bool confirmed;
  String note;

  /// Why the whole row is read-only (a finalized shift), or null.
  String? lockReason;
  GridRowState state;
  bool pickable;

  TestShift copy() => TestShift(
    id,
    date,
    type: type,
    start: start,
    end: end,
    breakMinutes: breakMinutes,
    confirmed: confirmed,
    note: note,
    lockReason: lockReason,
    state: state,
    pickable: pickable,
  );

  int get paidMinutes {
    var minutes =
        (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
    if (minutes <= 0) minutes += 24 * 60;
    return minutes - breakMinutes;
  }

  Object? field(String key) => switch (key) {
    'date' => date,
    'type' => type,
    'start' => start,
    'end' => end,
    'break' => breakMinutes,
    'paid' => paidMinutes,
    'ok' => confirmed,
    'note' => note,
    _ => throw ArgumentError(key),
  };
}

String minutesText(Object minutes) {
  final value = minutes as int;
  return '${value ~/ 60}:${(value % 60).toString().padLeft(2, '0')}';
}

const shiftTypes = [
  EraComboItem<Object?>('day', 'Day'),
  EraComboItem<Object?>('night', 'Night'),
  EraComboItem<Object?>('off', 'Off'),
];

/// The test grid's columns: date, type (choice), start, end, break
/// (duration), paid (derived), ok (check), note (text).
List<GridColumn<TestShift>> shiftColumns({
  double noteWidth = 120,
  double dateWidth = 110,
}) => [
  GridColumn<TestShift>(
    key: 'date',
    label: 'Date',
    kind: ValueKind.date,
    width: dateWidth,
    value: (shift) => shift.date,
    editable: true,
  ),
  GridColumn<TestShift>(
    key: 'type',
    label: 'Type',
    kind: ValueKind.choice,
    width: 70,
    value: (shift) => shift.type,
    choices: shiftTypes,
    editable: true,
  ),
  GridColumn<TestShift>(
    key: 'start',
    label: 'Start',
    kind: ValueKind.time,
    width: 56,
    value: (shift) => shift.start,
    editable: true,
  ),
  GridColumn<TestShift>(
    key: 'end',
    label: 'End',
    kind: ValueKind.time,
    width: 56,
    value: (shift) => shift.end,
    editable: true,
  ),
  GridColumn<TestShift>(
    key: 'break',
    label: 'Break',
    kind: ValueKind.duration,
    width: 56,
    value: (shift) => shift.breakMinutes,
    display: minutesText,
    editable: true,
  ),
  GridColumn<TestShift>(
    key: 'paid',
    label: 'Paid',
    kind: ValueKind.duration,
    width: 56,
    value: (shift) => shift.paidMinutes,
    display: minutesText,
    description: 'Paid time is calculated from start, end and break.',
  ),
  GridColumn<TestShift>(
    key: 'ok',
    label: 'Confirmed',
    kind: ValueKind.check,
    width: 40,
    value: (shift) => shift.confirmed,
    editable: true,
  ),
  GridColumn<TestShift>(
    key: 'note',
    label: 'Note',
    kind: ValueKind.text,
    width: noteWidth,
    value: (shift) => shift.note,
    editable: true,
  ),
];

/// How the harness answers a selection request.
enum SelectionAnswer { accept, refuse, delay }

const testToday = LocalDate(2026, 10, 8);

List<TestShift> testShifts(int count) => [
  for (var i = 0; i < count; i++)
    TestShift('s$i', const LocalDate(2026, 10, 1).addDays(i)),
];

/// Hosts a DataGrid the way an owner does: it owns the records, the
/// selection, the pending edits, sort, picks and widths, and logs every
/// request and commit.
final class GridHarness extends StatefulWidget {
  const GridHarness({
    required this.shifts,
    this.selectedId,
    this.controller,
    this.answer = SelectionAnswer.accept,
    this.enabled = true,
    this.pickMode = false,
    this.footer = true,
    this.width = 900,
    this.height = 360,
    this.columns,
    this.extra,
    this.groups = false,
    this.liveRows = false,
    super.key,
  });

  final List<TestShift> shifts;
  final String? selectedId;
  final EditorSessionController? controller;
  final SelectionAnswer answer;
  final bool enabled;
  final bool pickMode;
  final bool footer;
  final double width;
  final double height;
  final List<GridColumn<TestShift>>? columns;

  /// Drawn beside the grid, such as a stand-in property editor or Save.
  final Widget Function(GridHarnessState state)? extra;
  final bool groups;
  final bool liveRows;

  @override
  State<GridHarness> createState() => GridHarnessState();
}

final class GridHarnessState extends State<GridHarness> {
  late final EditorSessionController controller =
      widget.controller ?? EditorSessionController();
  late List<TestShift> shifts = widget.shifts;
  late String? selectedId = widget.selectedId;
  late SelectionAnswer answer = widget.answer;
  late bool enabled = widget.enabled;
  late bool pickMode = widget.pickMode;

  /// The surrounding form scope's enabled state.
  bool formEnabled = true;
  final log = <String>[];
  final pending = <String>{};
  final changed = <GridCell>{};
  final errors = <GridCell, String>{};

  /// Cells read-only for a reason of their own.
  final cellLocks = <GridCell, String>{};
  final picked = <String>{};
  final widths = <String, double>{};
  String? sortColumn;
  bool sortDescending = false;
  String? delayed;
  int news = 0;
  int rowBuilds = 0;
  String? rejectChecks;
  List<GridColumn<TestShift>>? columnOverride;
  void Function(GridCell cell)? afterCommit;

  void update(VoidCallback change) => setState(change);

  /// Answers a delayed selection request now.
  void answerDelayed() => setState(() => selectedId = delayed);

  TestShift? shift(String id) {
    for (final shift in shifts) {
      if (shift.id == id) return shift;
    }
    return null;
  }

  EditResult commit(GridCell cell, Object? draft) {
    log.add('commit ${cell.rowId}.${cell.column}=$draft');
    if (cell.column == 'ok' && rejectChecks != null) {
      return EditResult.rejected(rejectChecks!);
    }
    // Records are replaced, never changed in place, as an owner with
    // immutable records does: the grid's built rows go stale until the
    // owner rebuilds it.
    final record = shift(cell.rowId)?.copy();
    if (record == null) {
      return const EditResult.rejected('This shift was removed.');
    }
    switch (cell.column) {
      case 'date':
        record.date = draft! as LocalDate;
      case 'type':
        record.type = draft! as String;
      case 'start':
        // A new start moves the end twelve hours on.
        record.start = draft! as LocalTime;
        record.end = LocalTime(
          (record.start.hour + 12) % 24,
          record.start.minute,
        );
      case 'end':
        record.end = draft! as LocalTime;
      case 'break':
        final match = RegExp(r'^(\d+):(\d\d)$').firstMatch('$draft');
        if (match == null) {
          return const EditResult.rejected('Enter a break like 0:30.');
        }
        record.breakMinutes =
            int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
      case 'ok':
        record.confirmed = draft! as bool;
      case 'note':
        record.note = '$draft';
    }
    setState(() {
      shifts = [
        for (final shift in shifts) shift.id == record.id ? record : shift,
      ];
      pending.add(cell.rowId);
      changed.add(cell);
    });
    afterCommit?.call(cell);
    return const EditResult.accepted();
  }

  void select(String id) {
    log.add('select $id');
    switch (answer) {
      case SelectionAnswer.accept:
        setState(() => selectedId = id);
      case SelectionAnswer.refuse:
        break;
      case SelectionAnswer.delay:
        delayed = id;
    }
  }

  void sort(String column) {
    log.add('sort $column');
    setState(() {
      sortDescending = sortColumn == column && !sortDescending;
      sortColumn = column;
      final columns = widget.columns ?? shiftColumns();
      final key = columns.firstWhere((c) => c.key == column);
      int compare(TestShift a, TestShift b) {
        final x = key.value(a);
        final y = key.value(b);
        final order = x is Comparable && y is Comparable
            ? Comparable.compare(x, y)
            : '$x'.compareTo('$y');
        return sortDescending ? -order : order;
      }

      shifts = [...shifts]..sort(compare);
    });
  }

  List<GridLine<TestShift>> get lines => [
    if (widget.groups)
      const GridGroup(label: 'October 2026', summary: '3 shifts'),
    for (final shift in shifts) GridRow(shift, state: shift.state),
  ];

  int get pickedMinutes => [
    for (final shift in shifts)
      if (picked.contains(shift.id)) shift.paidMinutes,
  ].fold(0, (sum, minutes) => sum + minutes);

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = EraFormScope(
      enabled: formEnabled,
      child: DataGrid<TestShift>(
        label: 'Shifts',
        columns: columnOverride ?? widget.columns ?? shiftColumns(),
        lines: lines,
        rowId: (shift) => shift.id,
        rowLabel: (shift) {
          rowBuilds++;
          return 'Shift ${eraBoxDate(shift.date)}';
        },
        selectedId: selectedId,
        onSelect: select,
        editorController: controller,
        onEdit: commit,
        currentRow: widget.liveRows ? shift : null,
        readOnlyReason: (shift, column) =>
            shift.lockReason ??
            cellLocks[GridCell(shift.id, column.key)] ??
            (shift.type == 'off' &&
                    {'start', 'end', 'break'}.contains(column.key)
                ? 'An off day has no times.'
                : null),
        onExplain: (cell, reason) => log.add('explain ${cell.column}: $reason'),
        today: testToday,
        enabled: enabled,
        pendingIds: pending,
        changed: changed,
        errors: errors,
        onNew: () {
          log.add('new');
          setState(() {
            news++;
            final shift = TestShift('new$news', testToday);
            shifts = [...shifts, shift];
            selectedId = shift.id;
          });
        },
        sortColumn: sortColumn,
        sortDescending: sortDescending,
        onSort: sort,
        footer: widget.footer
            ? {
                'paid': minutesText(
                  pickMode
                      ? pickedMinutes
                      : shifts.fold<int>(
                          0,
                          (sum, shift) => sum + shift.paidMinutes,
                        ),
                ),
              }
            : null,
        footerLabel: widget.footer
            ? pickMode
                  ? 'Total (${picked.length} picked)'
                  : 'Total (${shifts.length} shifts)'
            : null,
        pickMode: pickMode,
        pickedIds: picked,
        canPick: (shift) => shift.pickable,
        onPick: (id, value) {
          log.add('pick $id $value');
          setState(() => value ? picked.add(id) : picked.remove(id));
        },
        widths: widths,
        onResize: (column, width) {
          log.add('resize $column ${width.round()}');
          setState(() => widths[column] = width);
        },
        note: 'Filtered: Period',
      ),
    );
    final extra = widget.extra;
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: extra == null
            ? grid
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: grid),
                  extra(this),
                ],
              ),
      ),
    );
  }
}

/// Pumps [harness] in the gallery host (theme, skin, EraScrollBehavior)
/// on a desktop-sized view, at [textScale].
Future<GridHarnessState> pumpGrid(
  WidgetTester tester,
  GridHarness harness, {
  double textScale = 1,
  Size view = const Size(1000, 600),
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey<GridHarnessState>();
  await tester.pumpWidget(
    GalleryHost(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: ColoredBox(
            color: MillenniumColors.page,
            child: GridHarness(
              key: key,
              shifts: harness.shifts,
              selectedId: harness.selectedId,
              controller: harness.controller,
              answer: harness.answer,
              enabled: harness.enabled,
              pickMode: harness.pickMode,
              footer: harness.footer,
              width: harness.width,
              height: harness.height,
              columns: harness.columns,
              extra: harness.extra,
              groups: harness.groups,
              liveRows: harness.liveRows,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key.currentState!;
}

/// The painted cell of [column] in row [id] (closed or open).
Finder gridCell(String id, String column) =>
    find.byKey(ValueKey('grid-cell:$id:$column'));

/// The row line of [id].
Finder gridRow(String id) => find.byKey(ValueKey('grid-row:$id'));

/// The open CellEditor, if any.
Finder get openEditor => find.descendant(
  of: find.byType(DataGrid<TestShift>),
  matching: find.byType(CellEditor),
);

/// Clicks [finder] with a desktop mouse.
Future<void> click(
  WidgetTester tester,
  Finder finder, {
  int buttons = kPrimaryButton,
}) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget, reason: 'Mouse target: $finder');
  await tester.tap(finder, kind: PointerDeviceKind.mouse, buttons: buttons);
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

/// Types [text] into the focused text editor, replacing its text.
Future<void> typeText(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(of: openEditor, matching: find.byType(EditableText)),
    text,
  );
  await tester.pumpAndSettle();
}
