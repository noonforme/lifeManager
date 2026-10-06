import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/explain/explanation.dart';
import 'cell_selection.dart';
import 'era_controls.dart';
import 'era_menu.dart';
import 'era_scrollbar.dart';
import 'lifeos_skin.dart';
import 'millennium_style.dart';

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
    this.description,
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

  /// The header's full name in a tooltip, for a short label such as "OT".
  final String? description;
}

/// The state a row is drawn and announced in.
enum RowState {
  normal(null),
  draft('Draft'),
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

/// An action offered on a row's right-click menu. Null [onInvoke] shows the
/// action disabled.
final class RowAction {
  const RowAction({
    required this.label,
    required this.onInvoke,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback? onInvoke;

  /// Bold in the menu: the action a double-click or Enter runs.
  final bool isDefault;
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
    this.onActivate,
    this.actions,
    this.sortedColumn,
    this.sortDescending = false,
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

  /// Opens the row's Properties: Enter, Alt+Enter or a double-click.
  /// Without it, Enter opens the row as Space does.
  final ValueChanged<T>? onActivate;

  /// Right-click actions for a row. The register adds nothing of its own.
  final List<RowAction> Function(T row)? actions;

  /// The column the lines are ordered by, marked in its header.
  final String? sortedColumn;

  /// Whether that order is descending.
  final bool sortDescending;

  @override
  State<DataRegister<T>> createState() => _DataRegisterState<T>();
}

final class _DataRegisterState<T> extends State<DataRegister<T>> {
  final FocusNode _focus = FocusNode(debugLabel: 'Data register');
  final ScrollController _horizontal = ScrollController();
  final ScrollController _vertical = ScrollController();

  /// Whether the rows overflow, so the table leaves room for the vertical
  /// era scrollbar beside it.
  bool _overflowing = false;

  bool _onVerticalMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth == 0 && metrics.axis == Axis.vertical) {
      final overflowing = metrics.maxScrollExtent > metrics.minScrollExtent;
      if (overflowing != _overflowing) {
        setState(() => _overflowing = overflowing);
      }
    }
    return false;
  }

  /// Index into the selectable rows, and the cursor's column key.
  int? _cursorRow;
  String? _cursorColumn;
  CellSelectionController? _selection;

  /// The last primary press: row index and event time, for double-clicks.
  (int, Duration)? _lastPress;
  bool _activatePending = false;
  final _menu = GlobalKey<EraContextMenuState>();

  /// The cursor row, where Shift+F10 opens its menu.
  final _cursorRowKey = GlobalKey();

  /// The desktop's double-click time (GTK's default), longer than
  /// Flutter's touch-oriented double-tap timeout.
  static const _doubleClick = Duration(milliseconds: 400);

  void _press(int index, PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    // Every press starts fresh: a second press that never became a click
    // (dragged away) must not arm a later one.
    _activatePending = false;
    final last = _lastPress;
    _lastPress = (index, event.timeStamp);
    // Synthetic events without a time stamp never pair into a double-click.
    if (last != null &&
        event.timeStamp > Duration.zero &&
        last.$1 == index &&
        event.timeStamp - last.$2 <= _doubleClick) {
      _lastPress = null;
      _activatePending = true;
    }
  }

  List<RowLine<T>> get _rows =>
      widget.lines.whereType<RowLine<T>>().toList(growable: false);

  /// Whether the list has keyboard focus; a selected row is blue only then
  /// and grey otherwise, as era lists drew it.
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (_focus.hasFocus != _hasFocus) {
      setState(() => _hasFocus = _focus.hasFocus);
    }
  }

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
    _vertical.dispose();
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
    // Alt chords are the window's (Alt+Left is Back), except Alt+Enter,
    // which opens the row's Properties as in the era.
    if (HardwareKeyboard.instance.isAltPressed &&
        key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final row = _cursorRow;
    // Shift+F10 or the Menu key opens the cursor row's menu at the row, as
    // a right-click does at the pointer.
    if (row != null &&
        (key == LogicalKeyboardKey.contextMenu ||
            (key == LogicalKeyboardKey.f10 &&
                HardwareKeyboard.instance.isShiftPressed))) {
      final box =
          _cursorRowKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        _showActions(
          rows[row].row,
          box.localToGlobal(Offset(16, box.size.height)),
        );
      }
      return KeyEventResult.handled;
    }
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
    if (key == LogicalKeyboardKey.space && row != null) {
      widget.onOpen(rows[row].row);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && row != null) {
      (widget.onActivate ?? widget.onOpen)(rows[row].row);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showActions(T row, Offset position) {
    final actions = widget.actions?.call(row) ?? const <RowAction>[];
    _menu.currentState?.show(position, [
      for (final action in actions)
        EraMenuItem(action.label, action.onInvoke, isDefault: action.isDefault),
    ]);
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
        // The vertical scrollbar sits outside the sideways scroll, at the
        // list's right edge; the rows keep the room it leaves.
        final available =
            constraints.maxWidth -
            (_overflowing && constraints.maxWidth.isFinite
                ? EraScrollbar.thickness
                : 0);
        final visible = _visibleColumns(available);
        final tableWidth = math.max(
          available.isFinite ? available : 0.0,
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
              RowLine<T>() => () {
                rowIndex++;
                final index = rowIndex;
                final row = line.row;
                final cursorHere = _cursorRow == index;
                return _DataRow<T>(
                  key: cursorHere ? _cursorRowKey : null,
                  rowId: widget.rowId(row),
                  focused: _hasFocus,
                  sortedColumn: widget.sortedColumn,
                  line: line,
                  columns: visible,
                  label: widget.rowLabel(row),
                  selected: widget.rowId(row) == widget.selectedId,
                  cursor: cursorHere,
                  cursorColumn: cursorHere ? _cursorColumn : null,
                  skin: skin,
                  onPress: (event) => _press(index, event),
                  onCellTap: (column) {
                    _focus.requestFocus();
                    _moveCursor(index, column, visible);
                    if (_activatePending) {
                      _activatePending = false;
                      (widget.onActivate ?? widget.onOpen)(row);
                    } else {
                      widget.onOpen(row);
                    }
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
        return EraContextMenu(
          key: _menu,
          child: Focus(
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
                child: EraScrollbar(
                  controller: _vertical,
                  axis: Axis.vertical,
                  depth: 1,
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
                          _HeaderRow<T>(
                            columns: visible,
                            skin: skin,
                            sortedColumn: widget.sortedColumn,
                            sortDescending: widget.sortDescending,
                          ),
                          if (constraints.maxHeight.isFinite)
                            Expanded(
                              child:
                                  NotificationListener<
                                    ScrollMetricsNotification
                                  >(
                                    onNotification: _onVerticalMetrics,
                                    // Its bar is drawn outside the sideways scroll.
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(scrollbars: false),
                                      child: ListView(
                                        controller: _vertical,
                                        children: body,
                                      ),
                                    ),
                                  ),
                            )
                          else
                            ...body,
                        ],
                      ),
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
  const _HeaderRow({
    required this.columns,
    required this.skin,
    required this.sortedColumn,
    required this.sortDescending,
  });

  final List<RegisterColumn<T>> columns;
  final LifeOSSkinData skin;
  final String? sortedColumn;
  final bool sortDescending;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.paper, tokens.band],
        ),
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: Row(
        children: [
          for (final column in columns)
            _HeaderCell<T>(
              column: column,
              skin: skin,
              sorted: column.key == sortedColumn,
              sortDescending: sortDescending,
            ),
        ],
      ),
    );
  }
}

/// One column header: the sort arrow when sorted, and the era's amber
/// bottom edge while the pointer is over it.
final class _HeaderCell<T> extends StatefulWidget {
  const _HeaderCell({
    required this.column,
    required this.skin,
    required this.sorted,
    required this.sortDescending,
  });

  final RegisterColumn<T> column;
  final LifeOSSkinData skin;
  final bool sorted;
  final bool sortDescending;

  @override
  State<_HeaderCell<T>> createState() => _HeaderCellState<T>();
}

final class _HeaderCellState<T> extends State<_HeaderCell<T>> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final tokens = skin.tokens;
    final column = widget.column;
    final cell = MouseRegion(
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: Container(
        key: _hot ? ValueKey('header-hot-${column.key}') : null,
        width: column.width,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: tokens.chromeLine),
            bottom: _hot
                ? const BorderSide(color: MillenniumColors.sortAccent, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: column.kind.isNumeric
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                column.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: column.kind.isNumeric
                    ? TextAlign.right
                    : TextAlign.left,
                style: skin.typography.label.copyWith(color: tokens.ink),
              ),
            ),
            if (widget.sorted) ...[
              const SizedBox(width: 4),
              // The order is said, not only drawn.
              Semantics(
                label: widget.sortDescending
                    ? 'sorted descending'
                    : 'sorted ascending',
                child: EraGlyph(
                  widget.sortDescending
                      ? EraGlyphKind.sortDown
                      : EraGlyphKind.sortUp,
                  color: tokens.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    final description = column.description;
    return description == null
        ? cell
        : Tooltip(
            message: description,
            excludeFromSemantics: true,
            child: cell,
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
      color: tokens.head,
      fontWeight: FontWeight.w700,
    );
    return Semantics(
      header: true,
      label: summary == null ? label : '$label, $summary',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 22),
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 1),
        decoration: BoxDecoration(
          color: tokens.paper,
          border: const Border(
            bottom: BorderSide(color: MillenniumColors.groupRowRule),
          ),
        ),
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
          top: BorderSide(color: tokens.ink),
          bottom: BorderSide(color: tokens.rule),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            SizedBox(
              width: columns[index].width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

final class _DataRow<T> extends StatelessWidget {
  const _DataRow({
    required this.rowId,
    required this.focused,
    required this.sortedColumn,
    required this.line,
    required this.columns,
    required this.label,
    required this.selected,
    required this.cursor,
    required this.cursorColumn,
    required this.skin,
    required this.onPress,
    required this.onCellTap,
    required this.onSecondaryTap,
    super.key,
  });

  final String rowId;
  final bool focused;
  final String? sortedColumn;
  final RowLine<T> line;
  final List<RegisterColumn<T>> columns;
  final String label;
  final bool selected;
  final bool cursor;
  final String? cursorColumn;
  final LifeOSSkinData skin;
  final ValueChanged<PointerDownEvent> onPress;
  final ValueChanged<String> onCellTap;
  final void Function(String column, Offset position) onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    final voided = line.state == RowState.voided;
    // Blue with white ink only while the list has focus.
    final lit = selected && focused;
    return Listener(
      onPointerDown: onPress,
      child: Semantics(
        button: true,
        selected: selected,
        focused: cursor,
        label: label,
        value: line.state.announcement,
        excludeSemantics: true,
        child: Container(
          key: ValueKey('register-row-$rowId'),
          decoration: BoxDecoration(
            color: selected
                ? (focused ? tokens.selWash : tokens.chrome)
                : tokens.paper,
          ),
          foregroundDecoration: cursor && cursorColumn == null
              ? skin.painters.cellCursor(tokens, onSelection: lit)
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
                    color: !selected && column.key == sortedColumn
                        ? MillenniumColors.sortTint
                        : null,
                    constraints: const BoxConstraints(minHeight: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    alignment: column.kind.isNumeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    foregroundDecoration: cursorColumn == column.key
                        ? skin.painters.cellCursor(tokens, onSelection: lit)
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
                            // A focused selection wins, so every cell of the
                            // row reads white on selWash.
                            color: lit
                                ? tokens.selInk
                                : voided
                                ? tokens.muted
                                : tokens.ink,
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
      ),
    );
  }
}
