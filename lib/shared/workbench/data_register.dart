import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/explain/explanation.dart';
import 'cell_selection.dart';
import 'lifeos_skin.dart';

/// What a column holds. Numeric kinds are right-aligned in tabular figures.
enum ColumnKind {
  text,
  date,
  time,
  duration,
  money,
  quantity,
  state,
  area,
  derived;

  bool get isNumeric => switch (this) {
    duration || money || quantity || derived => true,
    text || date || time || state || area => false,
  };

  bool get usesFigures => isNumeric || this == date || this == time;
}

/// One register column. [explain] gives a derived cell its calculation for
/// the formula bar; [optional] columns hide before the table scrolls.
final class RegisterColumn<T> {
  const RegisterColumn({
    required this.key,
    required this.label,
    required this.kind,
    required this.width,
    required this.value,
    this.explain,
    this.cell,
    this.optional = false,
  });

  final String key;
  final String label;
  final ColumnKind kind;
  final double width;
  final String Function(T row) value;
  final Explanation? Function(T row)? explain;

  /// Draws the cell instead of [value] text, for example an area key.
  final Widget Function(T row)? cell;
  final bool optional;
}

/// The state a row is drawn and announced in.
enum RowState {
  normal(null),
  draft('Draft'),
  running('Running'),
  voided('Void');

  const RowState(this.announcement);

  final String? announcement;
}

/// One line of a register.
sealed class RegisterLine<T> {
  const RegisterLine();
}

/// A heading such as "September 2026", with an optional right-aligned
/// summary. Not selectable.
final class GroupLine<T> extends RegisterLine<T> {
  const GroupLine({required this.label, this.summary});

  final String label;
  final String? summary;
}

/// A record.
final class RowLine<T> extends RegisterLine<T> {
  const RowLine(this.row, {this.state = RowState.normal});

  final T row;
  final RowState state;
}

/// Totals under a group. [cells] maps column keys to values; [label] sits in
/// the first column. Not selectable.
final class SubtotalLine<T> extends RegisterLine<T> {
  const SubtotalLine({required this.cells, this.label});

  final Map<String, String> cells;
  final String? label;
}

/// The last line of a register, opening its create form in place.
final class EntryLine<T> extends RegisterLine<T> {
  const EntryLine({required this.hint, required this.onOpen});

  final String hint;
  final VoidCallback onOpen;
}

/// An action offered on a row's right-click menu. Null [onInvoke] shows the
/// action disabled.
final class RowAction {
  const RowAction({required this.label, required this.onInvoke});

  final String label;
  final VoidCallback? onInvoke;
}

/// A cell position: the row's identity and the column key.
@immutable
final class CellRef {
  const CellRef(this.rowId, this.columnKey);

  final String rowId;
  final String columnKey;

  @override
  bool operator ==(Object other) =>
      other is CellRef && other.rowId == rowId && other.columnKey == columnKey;

  @override
  int get hashCode => Object.hash(rowId, columnKey);
}

/// The shared register (spec 6.2). Click places the cell cursor and opens
/// the row; arrow keys move the cursor; Enter or Space opens the row under
/// it. The open row ([selectedId]) and the cursor are drawn and announced
/// separately.
final class DataRegister<T> extends StatefulWidget {
  const DataRegister({
    required this.label,
    required this.lines,
    required this.columns,
    required this.rowId,
    required this.rowLabel,
    required this.selectedId,
    required this.onOpen,
    this.actions,
    super.key,
  });

  final String label;
  final List<RegisterLine<T>> lines;
  final List<RegisterColumn<T>> columns;
  final String Function(T row) rowId;
  final String Function(T row) rowLabel;

  /// The row whose record is open in the inspector.
  final String? selectedId;
  final ValueChanged<T> onOpen;

  /// Right-click actions for a row. The register adds nothing of its own.
  final List<RowAction> Function(T row)? actions;

  @override
  State<DataRegister<T>> createState() => _DataRegisterState<T>();
}

final class _DataRegisterState<T> extends State<DataRegister<T>> {
  final FocusNode _focus = FocusNode(debugLabel: 'Data register');
  final ScrollController _horizontal = ScrollController();

  /// Index into the selectable rows, and the cursor's column key.
  int? _cursorRow;
  String? _cursorColumn;
  CellSelectionController? _selection;

  List<RowLine<T>> get _rows =>
      widget.lines.whereType<RowLine<T>>().toList(growable: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selection = CellSelectionScope.read(context);
  }

  @override
  void didUpdateWidget(covariant DataRegister<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = _rows.length;
    final cursor = _cursorRow;
    if (cursor != null && cursor >= count) {
      _cursorRow = count == 0 ? null : count - 1;
    }
  }

  @override
  void dispose() {
    // Clearing notifies the formula bar, which cannot rebuild while the tree
    // is being torn down, so it waits for the end of this frame.
    final selection = _selection;
    if (selection != null) {
      final owner = this;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => selection.clearFrom(owner),
      );
    }
    _focus.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _moveCursor(int row, String column, List<RegisterColumn<T>> visible) {
    setState(() {
      _cursorRow = row;
      _cursorColumn = column;
    });
    _publish(visible);
  }

  void _publish(List<RegisterColumn<T>> visible) {
    final rowIndex = _cursorRow;
    final key = _cursorColumn;
    if (rowIndex == null || key == null) return;
    final line = _rows[rowIndex];
    final columnIndex = visible.indexWhere((column) => column.key == key);
    if (columnIndex < 0) return;
    final column = visible[columnIndex];
    final lineNumber = widget.lines.indexOf(line) + 1;
    _selection?.value = CellSelection(
      owner: this,
      reference: '${_columnLetter(columnIndex)}$lineNumber',
      columnLabel: column.label,
      display: column.value(line.row),
      explanation: column.explain?.call(line.row),
    );
  }

  KeyEventResult _handleKey(KeyEvent event, List<RegisterColumn<T>> visible) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final rows = _rows;
    if (rows.isEmpty || visible.isEmpty) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final row = _cursorRow;
    final columnIndex = math.max(
      0,
      visible.indexWhere((column) => column.key == _cursorColumn),
    );
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(
        row == null ? 0 : math.min(row + 1, rows.length - 1),
        visible[columnIndex].key,
        visible,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveCursor(
        row == null ? rows.length - 1 : math.max(row - 1, 0),
        visible[columnIndex].key,
        visible,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && row != null) {
      _moveCursor(
        row,
        visible[math.min(columnIndex + 1, visible.length - 1)].key,
        visible,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && row != null) {
      _moveCursor(row, visible[math.max(columnIndex - 1, 0)].key, visible);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) &&
        row != null) {
      widget.onOpen(rows[row].row);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showActions(T row, Offset position) async {
    final actions = widget.actions?.call(row) ?? const <RowAction>[];
    if (actions.isEmpty) return;
    final tokens = LifeOSSkinScope.of(context).tokens;
    final chosen = await showMenu<int>(
      context: context,
      color: tokens.paper,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        for (var index = 0; index < actions.length; index++)
          PopupMenuItem<int>(
            value: index,
            enabled: actions[index].onInvoke != null,
            child: Text(actions[index].label),
          ),
      ],
    );
    if (chosen != null) actions[chosen].onInvoke?.call();
  }

  /// Hides optional columns from the end until the table fits [available].
  List<RegisterColumn<T>> _visibleColumns(double available) {
    final visible = [...widget.columns];
    double total() => visible.fold(0, (sum, column) => sum + column.width);
    for (
      var index = visible.length - 1;
      index >= 0 && total() > available;
      index--
    ) {
      if (visible[index].optional) visible.removeAt(index);
    }
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = _visibleColumns(constraints.maxWidth);
        final tableWidth = math.max(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0,
          visible.fold<double>(0, (sum, column) => sum + column.width),
        );
        var rowIndex = -1;
        final body = <Widget>[
          for (final line in widget.lines)
            switch (line) {
              GroupLine(:final label, :final summary) => _GroupRow(
                label: label,
                summary: summary,
                skin: skin,
              ),
              SubtotalLine(:final cells, :final label) => _SubtotalRow<T>(
                columns: visible,
                cells: cells,
                label: label,
                skin: skin,
              ),
              EntryLine(:final hint, :final onOpen) => _EntryRow(
                hint: hint,
                onOpen: onOpen,
                skin: skin,
              ),
              RowLine<T>() => () {
                rowIndex++;
                final index = rowIndex;
                final row = line.row;
                final cursorHere = _cursorRow == index;
                return _DataRow<T>(
                  line: line,
                  columns: visible,
                  label: widget.rowLabel(row),
                  selected: widget.rowId(row) == widget.selectedId,
                  cursor: cursorHere,
                  cursorColumn: cursorHere ? _cursorColumn : null,
                  skin: skin,
                  onCellTap: (column) {
                    _focus.requestFocus();
                    _moveCursor(index, column, visible);
                    widget.onOpen(row);
                  },
                  onSecondaryTap: (column, position) {
                    _focus.requestFocus();
                    _moveCursor(index, column, visible);
                    _showActions(row, position);
                  },
                );
              }(),
            },
        ];
        return Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: (_, event) => _handleKey(event, visible),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: widget.label,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: '${widget.label}, horizontally scrollable',
              child: Scrollbar(
                controller: _horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    height: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : null,
                    child: Column(
                      mainAxisSize: constraints.maxHeight.isFinite
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeaderRow<T>(columns: visible, skin: skin),
                        if (constraints.maxHeight.isFinite)
                          Expanded(child: ListView(children: body))
                        else
                          ...body,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _columnLetter(int index) {
  var value = index;
  var letters = '';
  do {
    letters = String.fromCharCode(65 + value % 26) + letters;
    value = value ~/ 26 - 1;
  } while (value >= 0);
  return letters;
}

TextStyle _cellStyle(LifeOSSkinData skin, ColumnKind kind) =>
    (kind.usesFigures ? skin.typography.figure : skin.typography.body).copyWith(
      color: skin.tokens.ink,
      fontWeight: FontWeight.w400,
    );

final class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.skin});

  final List<RegisterColumn<T>> columns;
  final LifeOSSkinData skin;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.band,
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          for (final column in columns)
            SizedBox(
              width: column.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  column.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: column.kind.isNumeric
                      ? TextAlign.right
                      : TextAlign.left,
                  style: skin.typography.label.copyWith(color: tokens.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.label,
    required this.summary,
    required this.skin,
  });

  final String label;
  final String? summary;
  final LifeOSSkinData skin;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    final style = skin.typography.body.copyWith(
      color: tokens.headInk,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      header: true,
      label: summary == null ? label : '$label, $summary',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 25),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: tokens.head,
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            if (summary != null)
              Text(
                summary!,
                style: style.copyWith(fontWeight: FontWeight.w400),
              ),
          ],
        ),
      ),
    );
  }
}

final class _SubtotalRow<T> extends StatelessWidget {
  const _SubtotalRow({
    required this.columns,
    required this.cells,
    required this.label,
    required this.skin,
  });

  final List<RegisterColumn<T>> columns;
  final Map<String, String> cells;
  final String? label;
  final LifeOSSkinData skin;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.band,
        border: Border(
          top: BorderSide(color: tokens.ink, width: 2),
          bottom: BorderSide(color: tokens.rule),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            SizedBox(
              width: columns[index].width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  cells[columns[index].key] ?? (index == 0 ? label ?? '' : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: columns[index].kind.isNumeric
                      ? TextAlign.right
                      : TextAlign.left,
                  style: _cellStyle(
                    skin,
                    cells.containsKey(columns[index].key)
                        ? columns[index].kind
                        : ColumnKind.text,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.hint,
    required this.onOpen,
    required this.skin,
  });

  final String hint;
  final VoidCallback onOpen;
  final LifeOSSkinData skin;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      onTap: onOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            constraints: const BoxConstraints(minHeight: 25),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.rule)),
            ),
            child: Text(
              hint,
              style: skin.typography.body.copyWith(
                color: tokens.muted,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _DataRow<T> extends StatelessWidget {
  const _DataRow({
    required this.line,
    required this.columns,
    required this.label,
    required this.selected,
    required this.cursor,
    required this.cursorColumn,
    required this.skin,
    required this.onCellTap,
    required this.onSecondaryTap,
  });

  final RowLine<T> line;
  final List<RegisterColumn<T>> columns;
  final String label;
  final bool selected;
  final bool cursor;
  final String? cursorColumn;
  final LifeOSSkinData skin;
  final ValueChanged<String> onCellTap;
  final void Function(String column, Offset position) onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    final voided = line.state == RowState.voided;
    return Semantics(
      button: true,
      selected: selected,
      focused: cursor,
      label: label,
      value: line.state.announcement,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? tokens.selWash : tokens.paper,
          border: Border(bottom: BorderSide(color: tokens.rule)),
        ),
        foregroundDecoration: cursor && cursorColumn == null
            ? BoxDecoration(border: Border.all(color: tokens.focus, width: 2))
            : null,
        child: Row(
          children: [
            for (final column in columns)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onCellTap(column.key),
                onSecondaryTapUp: (details) =>
                    onSecondaryTap(column.key, details.globalPosition),
                child: Container(
                  width: column.width,
                  constraints: const BoxConstraints(minHeight: 25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  alignment: column.kind.isNumeric
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  foregroundDecoration: cursorColumn == column.key
                      ? BoxDecoration(
                          border: Border.all(
                            color: skin.painters.cellCursor(tokens),
                            width: 2,
                          ),
                        )
                      : null,
                  child:
                      column.cell?.call(line.row) ??
                      Text(
                        column.value(line.row),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: column.kind.isNumeric
                            ? TextAlign.right
                            : TextAlign.left,
                        style: _cellStyle(skin, column.kind).copyWith(
                          // Selection wins, so every cell of a selected
                          // row reads on selWash in every skin.
                          color: selected
                              ? tokens.selInk
                              : voided
                              ? tokens.muted
                              : column.kind == ColumnKind.state &&
                                    line.state == RowState.running
                              ? tokens.runInk
                              : tokens.ink,
                          fontWeight:
                              column.kind == ColumnKind.state &&
                                  line.state == RowState.running
                              ? FontWeight.w700
                              : null,
                          decoration: voided
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: tokens.negative,
                          decorationThickness: 2,
                        ),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
