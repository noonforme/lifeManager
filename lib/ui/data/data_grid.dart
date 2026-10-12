import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../core/time/local_date.dart';
import '../controls/cell_editor.dart';
import '../controls/editor_session_controller.dart';
import '../controls/era_combo.dart';
import '../controls/era_controls.dart';
import '../controls/era_form.dart';
import '../controls/era_scrollbar.dart';
import '../controls/value_editor.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/lifeos_tokens.dart';
import '../foundation/millennium_style.dart';
import 'record_navigator.dart';

/// How a record line is drawn and announced.
enum GridRowState {
  /// An ordinary record.
  normal(null),

  /// Greyed: a record not stored yet or not in effect, such as a planned or
  /// off day. Its row label says what it is.
  muted(null),

  /// Greyed and struck through: a voided record.
  voided('Void');

  const GridRowState(this.announcement);

  /// What the row's semantics add, if anything.
  final String? announcement;
}

/// One cell of a [DataGrid]: the row's id and the column's key. Pending
/// marks ([DataGrid.changed]), errors ([DataGrid.errors]) and commits
/// ([DataGrid.onEdit]) name cells this way.
@immutable
final class GridCell {
  const GridCell(this.rowId, this.column);

  final String rowId;
  final String column;

  /// The cell's field in an [EditorSessionController]: record [rowId],
  /// field [column]. Another editor of the same value (a property row)
  /// uses the same identity, so both show one draft.
  EditIdentity get identity => EditIdentity(record: rowId, field: column);

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.rowId == rowId && other.column == column;

  @override
  int get hashCode => Object.hash(rowId, column);

  @override
  String toString() => 'GridCell($rowId, $column)';
}

/// One line of a [DataGrid]: a group heading or a record.
sealed class GridLine<T> {
  const GridLine();
}

/// A heading such as "October 2026", with an optional right-hand summary.
/// Not selectable.
final class GridGroup<T> extends GridLine<T> {
  const GridGroup({required this.label, this.summary});

  final String label;
  final String? summary;
}

/// A record.
final class GridRow<T> extends GridLine<T> {
  const GridRow(this.row, {this.state = GridRowState.normal});

  final T row;
  final GridRowState state;
}

/// One typed column of a [DataGrid].
@immutable
final class GridColumn<T> {
  const GridColumn({
    required this.key,
    required this.label,
    required this.kind,
    required this.width,
    required this.value,
    this.display,
    this.editText,
    this.choices = const [],
    this.editable = false,
    this.optional = false,
    this.sortable = true,
    this.description,
    this.minWidth = 24,
  });

  /// The field's key: the [GridCell.column] and the edit identity's field.
  final String key;
  final String label;
  final ValueKind kind;

  /// The baseline width at 100 % text; it scales with text. A width the
  /// owner stored ([DataGrid.widths]) replaces it. Neither goes below the
  /// column's usable minimum: an editable column's open editor, with its
  /// chrome, at the current text size.
  final double width;

  /// The row's current (pending) value of this field.
  final Object? Function(T row) value;

  /// The text of a value [formatValue] cannot name by itself, such as an
  /// amount or a duration.
  final String Function(Object value)? display;

  /// The text an editor of a kind typed as text starts from, such as an
  /// amount without its currency. Defaults to the shown text.
  final String? Function(T row)? editText;

  /// The choices of a [ValueKind.choice] column.
  final List<EraComboItem<Object?>> choices;

  /// False for a derived column: always read-only.
  final bool editable;

  /// A date that may be empty.
  final bool optional;

  /// Whether a header click asks to sort by this column.
  final bool sortable;

  /// The header's tooltip, and the reason a derived column is read-only.
  final String? description;

  /// The narrowest a read-only column gets, at 100 % text.
  final double minWidth;

  /// [row]'s value as its cell shows it.
  String text(T row) =>
      formatValue(kind, value(row), choices: choices, display: display);
}

/// The database shell's editable datasheet (spec 3, 4.1–4.3, 6): bevelled
/// sortable and resizable headers, group headings, a row selector (current
/// ▸, pending ✎, new `*`), virtualised rows, typed cells edited in place
/// through the shared [EditorSessionController], a totals footer, the
/// [RecordNavigator] and pick mode.
///
/// Everything the owner decides is controlled: [selectedId], the sort, the
/// picked ids, the pending marks, errors and the stored column widths. The
/// grid reports requests ([onSelect], [onSort], [onPick], [onNew],
/// [onResize]) and offers drafts to [onEdit]; it never saves a record.
/// Every request that may use or replace the open draft flushes the editor
/// first and is dropped when that flush is rejected.
///
/// Mouse: a click selects (asks to select) a row; a click on an editable
/// cell of the selected row opens it; a click on a read-only cell of the
/// selected row shows why it is read-only. Keyboard: only inside an open
/// editor (spec 4.6). Enter or Tab commits and opens the next eligible cell
/// of the same row, then closes at the last; Esc drops the typed value.
/// Outside an editor the grid holds every key.
///
/// The grid needs a bounded height.
final class DataGrid<T> extends StatefulWidget {
  const DataGrid({
    required this.label,
    required this.columns,
    required this.lines,
    required this.rowId,
    required this.rowLabel,
    required this.selectedId,
    required this.editorController,
    this.onSelect,
    this.onEdit,
    this.currentRow,
    this.readOnlyReason,
    this.onExplain,
    this.today,
    this.enabled = true,
    this.active = true,
    this.pendingIds = const {},
    this.changed = const {},
    this.errors = const {},
    this.onNew,
    this.sortColumn,
    this.sortDescending = false,
    this.onSort,
    this.footer,
    this.footerLabel,
    this.pickMode = false,
    this.pickedIds = const {},
    this.onPick,
    this.canPick,
    this.widths = const {},
    this.onResize,
    this.showNavigator = true,
    this.note,
    super.key,
  });

  /// What the records are ("Shifts"): the grid's and navigator's name.
  final String label;
  final List<GridColumn<T>> columns;

  /// Pass a new list whenever a line changes. Stable row/index lookups are
  /// rebuilt when this input changes, rather than during cell building.
  final List<GridLine<T>> lines;

  /// A record's stable id, unique within [lines].
  final String Function(T row) rowId;

  /// A record's spoken name, such as "Shift Thu 2026-10-01".
  final String Function(T row) rowLabel;

  /// The selected record; the grid changes it only by asking [onSelect].
  final String? selectedId;

  /// Asked to select a record, after the open draft was accepted. The
  /// owner answers by supplying [selectedId] (at once, later or never).
  final ValueChanged<String>? onSelect;

  /// The shared editor session of the owner's pending aggregate.
  final EditorSessionController editorController;

  /// UI draft acceptance of a cell, synchronous: apply the draft to the
  /// cell's record ([GridCell.rowId], which may no longer be shown) and
  /// return accepted, or return rejected with the reason and change
  /// nothing. Null makes every cell read-only.
  final EditResult Function(GridCell cell, Object? draft)? onEdit;

  /// The owner's current record [rowId], read when opening a field.
  /// Return null for a record no longer there. Without it the grid uses
  /// the latest [lines]. After flushing another field, both mouse and
  /// Enter/Tab transitions wait for the owner's next build: a commit may
  /// replace rows and columns. Immutable replacement works without this
  /// optional lookup.
  final T? Function(String rowId)? currentRow;

  /// Why [column] of [row] is read-only now (a finalized record, a field
  /// the record's state locks), or null when an editable column may be
  /// edited. A derived column is always read-only; its reason is this, or
  /// its [GridColumn.description].
  final String? Function(T row, GridColumn<T> column)? readOnlyReason;

  /// Told when a click on a read-only cell of the selected row shows its
  /// reason, for a description pane.
  final void Function(GridCell cell, String reason)? onExplain;

  /// Today for date editors: explicit and fixed, never the wall clock.
  /// Required when a date column is editable.
  final LocalDate? today;

  /// False: no selection, sort, pick, resize, new row or edit; the grid
  /// still scrolls. A locked [EraFormScope] disables it too.
  final bool enabled;

  /// Whether the grid is the active region: its selection is blue, else
  /// face grey (spec 4.1).
  final bool active;

  /// Records with pending edits: their selector shows ✎.
  final Set<String> pendingIds;

  /// Cells whose pending value differs from the saved one: drawn bold.
  final Set<GridCell> changed;

  /// Cells with a problem: a red edge, the reason announced (and shown
  /// under an open editor).
  final Map<GridCell, String> errors;

  /// Asked to start a new record from the `*` line or the navigator.
  /// Null hides the line.
  final VoidCallback? onNew;

  /// The column the lines are sorted by, and in which direction.
  final String? sortColumn;
  final bool sortDescending;

  /// Asked to sort by a column (the owner chooses the direction).
  final ValueChanged<String>? onSort;

  /// The totals line: column key to the owner's total text. Null hides it.
  final Map<String, String>? footer;

  /// The totals line's caption, such as "Total (15 shifts)", spanning the
  /// columns before the first total.
  final String? footerLabel;

  /// Shows the tick column; [onPick] asks to tick or untick a record.
  final bool pickMode;
  final Set<String> pickedIds;
  final void Function(String rowId, bool picked)? onPick;

  /// Whether a record may be picked; an ineligible one has no tick box.
  final bool Function(T row)? canPick;

  /// The owner's stored column widths, by column key.
  final Map<String, double> widths;

  /// Told the width the owner dragged a column to (never below its
  /// minimum). Null fixes the widths.
  final void Function(String column, double width)? onResize;

  /// Shows the record navigator under the rows.
  final bool showNavigator;

  /// The navigator's note, such as the active filter.
  final String? note;

  @override
  State<DataGrid<T>> createState() => _DataGridState<T>();
}

/// The width of the row selector column.
const double _selectorWidth = 18;

/// The width of pick mode's tick column.
const double _pickWidth = 22;

/// The region token a grid opens its fields with ([EditSession.host]).
final class _GridHost {
  _GridHost(this.label);

  final String label;

  @override
  String toString() => 'DataGrid($label)';
}

/// Sizes that follow the text scale, worked out once per build input.
final class _Geometry {
  _Geometry({
    required this.widths,
    required this.minimums,
    required this.lead,
    required this.rowHeight,
    required this.groupHeight,
    required this.headerHeight,
    required this.editorHeight,
  }) {
    var x = lead;
    for (final width in widths) {
      starts.add(x);
      x += width;
    }
    tableWidth = x;
  }

  /// Each column's width, and the least it may be dragged to.
  final List<double> widths;
  final List<double> minimums;

  /// The selector and tick columns before the first column.
  final double lead;

  /// A closed record line, its 1 px rule included.
  final double rowHeight;
  final double groupHeight;
  final double headerHeight;

  /// The least height of a line holding an open editor (its box).
  final double editorHeight;
  final starts = <double>[];
  late final double tableWidth;
}

/// What the geometry depends on, compared to reuse it between builds.
@immutable
final class _GeometryInput {
  const _GeometryInput({
    required this.columns,
    required this.widths,
    required this.dragged,
    required this.pickMode,
    required this.scaler,
  });

  final List<Object?> columns;
  final Map<String, double> widths;
  final Map<String, double> dragged;
  final bool pickMode;
  final TextScaler scaler;

  @override
  bool operator ==(Object other) =>
      other is _GeometryInput &&
      identical(other.columns, columns) &&
      _sameMap(other.widths, widths) &&
      _sameMap(other.dragged, dragged) &&
      other.pickMode == pickMode &&
      other.scaler == scaler;

  @override
  int get hashCode => Object.hash(columns, pickMode, scaler);

  static bool _sameMap(Map<String, double> a, Map<String, double> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

final class _DataGridState<T> extends State<DataGrid<T>> {
  late final _host = _GridHost(widget.label);
  final _region = FocusNode(debugLabel: 'DataGrid');
  final _vertical = _RevealController();
  final _horizontal = _RevealController();

  /// Record lines currently mounted, by id, so one can be scrolled to.
  final _mounted = <String, _RowLineState<T>>{};

  // Lookups built once per input update.
  final _rowIds = <String>[];
  final _rowIndex = <String, int>{};
  final _lineIndex = <String, int>{};
  final _rowById = <String, T>{};
  final _lineKeys = <Key>[];
  final _keyIndex = <Key, int>{};
  final _groups = <int, GridGroup<T>>{};

  /// The width of a column being dragged, until the owner answers.
  final _dragWidths = <String, double>{};

  /// The read-only cell whose reason is shown, and the reason.
  (GridCell, String)? _explained;

  /// Whether the rows overflow, so the table leaves room for the bar.
  bool _overflowing = false;

  /// What the grid last drew of the session: field, host and error.
  (EditIdentity?, Object?, String?) _drawn = (null, null, null);

  _Geometry? _geometry;
  _GeometryInput? _geometryInput;

  bool _enabled = true;
  int _request = 0;
  final _lineHeights = <int, double>{};

  EditorSessionController get _controller => widget.editorController;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSession);
    _vertical.addListener(_onVerticalScroll);
    _reindex();
  }

  @override
  void didUpdateWidget(DataGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorController != widget.editorController) {
      _request++;
      oldWidget.editorController.removeListener(_onSession);
      widget.editorController.addListener(_onSession);
    }
    if (!identical(oldWidget.lines, widget.lines) ||
        oldWidget.rowId != widget.rowId ||
        (oldWidget.onNew == null) != (widget.onNew == null)) {
      _reindex();
      final session = _controller.session;
      if (session?.host == _host &&
          !_rowById.containsKey(session?.id.record) &&
          _region.hasFocus) {
        _region.requestFocus();
      }
    }
    if (oldWidget.selectedId != widget.selectedId) {
      _explained = null;
      if (widget.selectedId case final id?) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _reveal(id));
      }
    }
    // Widths the owner stored replace a dragged one.
    _dragWidths.removeWhere(
      (key, _) => widget.widths[key] != oldWidget.widths[key],
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onSession);
    _region.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  /// Rebuilds the id and key lookups from [DataGrid.lines].
  void _reindex() {
    _rowIds.clear();
    _rowIndex.clear();
    _lineIndex.clear();
    _rowById.clear();
    _lineKeys.clear();
    _keyIndex.clear();
    _groups.clear();
    final groups = <String, int>{};
    for (final (index, line) in widget.lines.indexed) {
      final Key key;
      switch (line) {
        case GridGroup(:final label):
          _groups[index] = line;
          final seen = groups[label] = (groups[label] ?? 0) + 1;
          key = ValueKey('grid-group:$label#$seen');
        case GridRow(:final row):
          final id = widget.rowId(row);
          assert(!_rowById.containsKey(id), 'Duplicate DataGrid row id $id.');
          _rowIndex[id] = _rowIds.length;
          _rowIds.add(id);
          _lineIndex[id] = index;
          _rowById[id] = row;
          key = ValueKey('grid-row:$id');
      }
      _lineKeys.add(key);
      _keyIndex[key] = index;
    }
    const newKey = ValueKey('grid-new-row');
    _keyIndex[newKey] = widget.lines.length;
  }

  // Session and keyboard.

  void _onSession() {
    if (!mounted) return;
    _request++;
    final session = _controller.session;
    final drawn = (session?.id, session?.host, session?.error);
    if (drawn == _drawn) return;
    final (_, wasHost, _) = _drawn;
    _drawn = drawn;
    // Our editor closed (its last field, Esc, or a flush from outside):
    // the keyboard stays in the grid, which holds every key, rather than
    // falling back to a scope where Tab could traverse.
    if (wasHost == _host && session == null && _region.hasFocus) {
      _region.requestFocus();
    }
    setState(() {});
  }

  /// Outside an open editor the grid takes no key (spec 4.6). Keys an open
  /// editor declines pass on, so text editing keeps working.
  KeyEventResult _onRegionKey(FocusNode node, KeyEvent event) =>
      _region.hasPrimaryFocus ? KeyEventResult.handled : KeyEventResult.ignored;

  /// Takes the keyboard into the grid, unless a field is open.
  void _claimKeyboard() {
    if (_controller.session == null && !_region.hasPrimaryFocus) {
      _region.requestFocus();
    }
  }

  /// Flushes the open field before a request; false when it is rejected,
  /// so the request is dropped and the red editor is brought into view.
  bool _flushFirst() {
    _request++;
    if (_controller.flush().isAccepted) {
      _claimKeyboard();
      return true;
    }
    final session = _controller.session;
    final id = session?.id.record;
    if (id is String && _rowById.containsKey(id)) _reveal(id);
    return false;
  }

  // Editing.

  /// Null when [column] of [row] may be edited now, else why not.
  String? _lockReason(T row, GridColumn<T> column) {
    final reason = widget.readOnlyReason?.call(row, column);
    if (column.editable) return reason;
    return reason ??
        column.description ??
        '${column.label} is calculated; it cannot be edited.';
  }

  bool _canEdit(T row, GridColumn<T> column) =>
      _enabled && widget.onEdit != null && _lockReason(row, column) == null;

  EditField _field(String id, T row, GridColumn<T> column) => EditField(
    id: GridCell(id, column.key).identity,
    kind: column.kind,
    value: column.value(row),
    text: column.kind.typedAsText
        ? column.editText?.call(row) ?? column.text(row)
        : null,
    commit: _commit,
  );

  EditResult _commit(EditIdentity id, Object? draft) {
    if (!mounted) {
      return const EditResult.rejected('This list is no longer open.');
    }
    final onEdit = widget.onEdit;
    final record = id.record;
    if (onEdit == null || record is! String) {
      return const EditResult.rejected('This list cannot be edited.');
    }
    return onEdit(GridCell(record, id.field), draft);
  }

  /// The next cell of the same record that may be edited, after [column];
  /// null at the last. Checks and choices count. Called right after a
  /// commit; after the owner rebuilds, both the column order and the
  /// record's current value and eligibility are read again.
  EditField? _next(String id, String column) {
    // CellEditor flushes synchronously. A setState in the owner has not
    // rebuilt our immutable rows yet. Close for this frame, then open the
    // next field using the refreshed index. Any intervening action wins.
    _afterOwnerBuild(id, () {
      final current = widget.currentRow;
      final next = _nextField(
        id,
        current == null ? _rowById[id] : current(id),
        column,
      );
      if (next != null) _controller.begin(next, host: _host);
    });
    return null;
  }

  void _afterOwnerBuild(String id, VoidCallback action) {
    final request = ++_request;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted ||
            request != _request ||
            _controller.session != null ||
            widget.selectedId != id ||
            !_rowById.containsKey(id) ||
            !_enabled) {
          return;
        }
        action();
      })
      ..ensureVisualUpdate();
  }

  EditField? _nextField(String id, T? row, String column) {
    if (row == null) return null;
    final columns = widget.columns;
    final at = columns.indexWhere((c) => c.key == column);
    if (at < 0) return null;
    for (var index = at + 1; index < columns.length; index++) {
      if (_canEdit(row, columns[index])) {
        return _field(id, row, columns[index]);
      }
    }
    return null;
  }

  // Mouse requests.

  void _select(String id) {
    if (!_enabled || !_flushFirst()) return;
    if (id == widget.selectedId) return;
    setState(() => _explained = null);
    widget.onSelect?.call(id);
  }

  void _tapCell(String id, String columnKey) {
    if (!_enabled) return;
    _request++;
    if (id != widget.selectedId) {
      _select(id);
      return;
    }
    // A click on another cell is subject to the same acceptance boundary
    // as Enter/Tab, including changes to the clicked field's eligibility.
    if (_controller.active != null &&
        _controller.active != GridCell(id, columnKey).identity) {
      if (!_flushFirst()) return;
      // Even a live row lookup cannot supply the rebuilt column schema.
      // Keep only the clicked key; resolve its current definition below.
      _afterOwnerBuild(id, () => _openCell(id, columnKey));
      return;
    }
    _openCell(id, columnKey);
  }

  void _openCell(String id, String columnKey) {
    final at = widget.columns.indexWhere((column) => column.key == columnKey);
    if (at < 0 || !_rowById.containsKey(id)) return;
    final column = widget.columns[at];
    final current = widget.currentRow;
    final row = current == null ? _rowById[id] : current(id);
    if (row == null) return;
    final reason = widget.onEdit == null
        ? '${column.label} cannot be edited here.'
        : _lockReason(row, column);
    if (reason != null) {
      _claimKeyboard();
      setState(() => _explained = (GridCell(id, column.key), reason));
      widget.onExplain?.call(GridCell(id, column.key), reason);
      return;
    }
    final field = _field(id, row, column);
    // The grid holds the keyboard just before the editor takes it, so the
    // keyboard falls back to the grid, never to a scope where Tab could
    // traverse, when the editor goes away (scrolled off, closed).
    if (!_region.hasFocus) _region.requestFocus();
    if (!_controller.begin(field, host: _host).isAccepted) return;
    if (_explained != null) setState(() => _explained = null);
    // A click on a check box ticks it, as the era's grids did.
    if (column.kind == ValueKind.check) {
      _controller.update(field.id, !(column.value(row) as bool? ?? false));
    }
  }

  void _tapHeader(GridColumn<T> column) {
    final onSort = widget.onSort;
    if (!_enabled || onSort == null || !column.sortable) {
      _claimKeyboard();
      return;
    }
    if (_flushFirst()) onSort(column.key);
  }

  void _tapPick(String id) {
    final onPick = widget.onPick;
    final committedDraft = _controller.session?.changed ?? false;
    if (!_enabled || onPick == null || !_flushFirst()) return;
    void pick() {
      final row = widget.currentRow == null
          ? _rowById[id]
          : widget.currentRow!(id);
      if (row != null && (widget.canPick?.call(row) ?? true)) {
        onPick(id, !widget.pickedIds.contains(id));
      }
    }

    // Eligibility can have changed in the just-accepted draft too.
    if (committedDraft && widget.currentRow == null) {
      final request = ++_request;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && request == _request && _enabled) pick();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
    } else {
      pick();
    }
  }

  void _tapNew() {
    final onNew = widget.onNew;
    if (!_enabled || onNew == null || !_flushFirst()) return;
    onNew();
  }

  void _go(int position) {
    if (position < 1 || position > _rowIds.length) return;
    _select(_rowIds[position - 1]);
  }

  /// Drags [column] to [width], kept at its minimum; the draft stays open.
  void _drag(int column, double width) {
    final geometry = _geometry;
    if (geometry == null) return;
    setState(() {
      _dragWidths[widget.columns[column].key] = math.max(
        width,
        geometry.minimums[column],
      );
    });
  }

  void _dragEnd(int column) {
    final key = widget.columns[column].key;
    final width = _dragWidths[key];
    if (width != null) widget.onResize?.call(key, width);
  }

  // Scrolling.

  void _onVerticalScroll() {
    final session = _controller.session;
    if (session?.host != _host ||
        !_region.hasFocus ||
        _region.hasPrimaryFocus) {
      return;
    }
    final object = _mounted[session!.id.record]?.context.findRenderObject();
    if (object == null || !object.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null) return;
    final top = viewport.getOffsetToReveal(object, 0).offset;
    final position = _vertical.position;
    final height = object.paintBounds.height;
    if (top + height <= position.pixels ||
        top >= position.pixels + position.viewportDimension) {
      // Only relinquish our own offscreen editor. No root-scope listener
      // or lifecycle hook may steal focus from another editor or window.
      _region.requestFocus();
    }
  }

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

  /// Scrolls record [id] into view, vertically only and only as far as
  /// needed; a record far away is built first by jumping near it.
  void _reveal(String id) {
    if (!mounted || !_vertical.hasClients) return;
    final shown = _mounted[id]?.context.findRenderObject();
    if (shown != null && shown.attached) {
      _vertical.position.reveal(shown);
      return;
    }
    final index = _lineIndex[id];
    final geometry = _geometry;
    if (index == null || geometry == null) return;
    final position = _vertical.position;
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _lineHeights[i] ?? geometry.rowHeight;
    }
    position.jumpTo(
      (offset - (position.viewportDimension - geometry.rowHeight) / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final built = _mounted[id]?.context.findRenderObject();
      if (mounted && built != null && built.attached) {
        _vertical.position.reveal(built);
      }
    });
  }

  // Layout.

  _Geometry _geometryFor(LifeOSSkinData skin, TextScaler scaler) {
    final input = _GeometryInput(
      columns: widget.columns,
      widths: {...widget.widths},
      dragged: {..._dragWidths},
      pickMode: widget.pickMode,
      scaler: scaler,
    );
    final cached = _geometry;
    if (cached != null && input == _geometryInput) return cached;
    final widths = <double>[];
    final minimums = <double>[];
    for (final column in widget.columns) {
      final minimum = _minimumWidth(column, skin, scaler);
      final width =
          _dragWidths[column.key] ??
          widget.widths[column.key] ??
          scaler.scale(column.width);
      minimums.add(minimum);
      widths.add(math.max(width, minimum).ceilToDouble());
    }
    final line = scaler.scale(14);
    _geometryInput = input;
    return _geometry = _Geometry(
      widths: widths,
      minimums: minimums,
      lead: _selectorWidth + (widget.pickMode ? _pickWidth : 0),
      rowHeight: math.max(20, (line + 5).ceilToDouble()),
      groupHeight: math.max(22, (line + 7).ceilToDouble()),
      headerHeight: math.max(22, (line + 8).ceilToDouble()),
      editorHeight: math.max(24, (line + 14).ceilToDouble()),
    );
  }

  /// A column's usable minimum: a read-only column's [GridColumn.minWidth]
  /// scaled; an editable column's open editor with all its chrome (box
  /// border, padding, caret, drop or spin button), measured at the
  /// current text size so the editor never spills into the next cell.
  double _minimumWidth(
    GridColumn<T> column,
    LifeOSSkinData skin,
    TextScaler scaler,
  ) {
    final base = scaler.scale(column.minWidth);
    if (!column.editable) return base;
    final type = skin.typography;
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width.ceilToDouble();
    }

    // Box border 2 and padding 10, plus the caret: EraField.
    const field = 14.0;
    // Border 2, padding 10 and the 17 px drop button: EraDateField.
    const date = 29.0;
    // Border 2, padding 6, 1 px either side of each part and the 17 px
    // spin keys: EraTimeField.
    const time = 32.0;
    // Border 2, padding 4 and the 17 px arrow: the combo face.
    const combo = 23.0;
    final editor = switch (column.kind) {
      ValueKind.text => measure('00000000', type.body) + field,
      ValueKind.number => measure('000000', type.figure) + field,
      ValueKind.money => measure('000000.00', type.figure) + field,
      ValueKind.duration => measure('000:00', type.figure) + field,
      ValueKind.date =>
        measure('Wed 0000-00-00', type.figure) +
            date +
            (column.optional ? 24 : 0),
      ValueKind.time => measure('00:00', type.figure) + time,
      ValueKind.choice => math.max(
        60.0,
        column.choices.fold(
              0.0,
              (widest, item) =>
                  math.max(widest, measure(item.label, type.body)),
            ) +
            combo,
      ),
      ValueKind.check => 24.0,
    };
    return math.max(base, editor);
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    _enabled = widget.enabled && EraFormScope.enabledOf(context);
    final geometry = _geometryFor(skin, MediaQuery.textScalerOf(context));
    final tokens = skin.tokens;
    final session = _controller.session;
    final orphan =
        session != null &&
        session.host == _host &&
        !_rowById.containsKey(session.id.record);
    final picked = widget.pickMode
        ? widget.pickedIds.where(_rowById.containsKey).length
        : 0;
    final selected = _rowIndex[widget.selectedId];
    final notes = <Widget>[
      if (widget.pickMode)
        Text(
          '$picked picked',
          key: const ValueKey('grid-picked'),
          style: skin.typography.body.copyWith(color: tokens.ink),
        ),
      if (_explained case (_, final reason))
        Text(
          reason,
          key: const ValueKey('grid-reason'),
          style: skin.typography.body.copyWith(color: tokens.muted),
        ),
      if (orphan)
        Text(
          'A changed value of a record no longer shown is kept: save it or '
          'undo it.',
          key: const ValueKey('grid-orphan'),
          style: skin.typography.body.copyWith(color: tokens.negative),
        ),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label,
      child: Focus(
        focusNode: _region,
        skipTraversal: true,
        onKeyEvent: _onRegionKey,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.paper,
            border: Border.all(color: MillenniumColors.fieldLine),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _table(context, skin, geometry, constraints),
                  ),
                ),
                if (widget.showNavigator || notes.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: tokens.chrome,
                      border: Border(top: BorderSide(color: tokens.chromeLine)),
                    ),
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.showNavigator)
                          RecordNavigator(
                            label: widget.label,
                            position: selected == null ? 0 : selected + 1,
                            count: _rowIds.length,
                            onGo: _enabled && widget.onSelect != null
                                ? _go
                                : null,
                            onNew: _enabled && widget.onNew != null
                                ? _tapNew
                                : null,
                            note: widget.note,
                          ),
                        ...notes,
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(
    BuildContext context,
    LifeOSSkinData skin,
    _Geometry geometry,
    BoxConstraints constraints,
  ) {
    // The vertical bar sits outside the sideways scroll, at the right
    // edge; the table keeps the room it leaves.
    final available =
        constraints.maxWidth - (_overflowing ? EraScrollbar.thickness : 0);
    final tableWidth = math.max(available, geometry.tableWidth);
    final count = widget.lines.length + (widget.onNew != null ? 1 : 0);
    _measureLines(geometry, skin, tableWidth);
    return EraScrollbar(
      controller: _vertical,
      axis: Axis.vertical,
      depth: 1,
      child: SingleChildScrollView(
        controller: _horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow<T>(grid: this, geometry: geometry, skin: skin),
              Expanded(
                child: NotificationListener<ScrollMetricsNotification>(
                  onNotification: _onVerticalMetrics,
                  // Its bar is drawn outside the sideways scroll.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: ListView.builder(
                      controller: _vertical,
                      itemCount: count,
                      itemExtentBuilder: (index, _) =>
                          _lineHeights[index] ?? geometry.rowHeight,
                      findChildIndexCallback: (key) => _keyIndex[key],
                      itemBuilder: (context, index) =>
                          _line(index, geometry, skin),
                    ),
                  ),
                ),
              ),
              if (widget.footer != null || widget.footerLabel != null)
                _FooterRow<T>(grid: this, geometry: geometry, skin: skin),
            ],
          ),
        ),
      ),
    );
  }

  /// Only groups and the one open editor differ from the ordinary row
  /// extent. Supplying extents lets a far jump skip thousands of rows
  /// without constructing their widgets, including when an error wraps.
  void _measureLines(_Geometry geometry, LifeOSSkinData skin, double width) {
    _lineHeights.clear();
    final scaler = MediaQuery.textScalerOf(context);
    Size measure(String text, TextStyle style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: math.max(1, maxWidth));
      final size = painter.size;
      painter.dispose();
      return size;
    }

    for (final MapEntry(:key, :value) in _groups.entries) {
      final summary = value.summary == null
          ? Size.zero
          : measure(value.summary!, skin.typography.body, double.infinity);
      final label = measure(
        value.label,
        skin.typography.body.copyWith(fontWeight: FontWeight.w700),
        width - geometry.lead - 10 - summary.width,
      );
      _lineHeights[key] = math.max(
        geometry.groupHeight,
        math.max(label.height, summary.height).ceilToDouble() + 6,
      );
    }
    final session = _controller.session;
    if (session == null) return;
    final index = _lineIndex[session.id.record];
    final column = widget.columns.indexWhere(
      (column) => column.key == session.id.field && column.editable,
    );
    if (index == null || column < 0) return;
    final error =
        session.error ??
        widget.errors[GridCell(session.id.record as String, session.id.field)];
    _lineHeights[index] =
        geometry.editorHeight +
        1 +
        (error == null
            ? 0
            : 2 +
                  measure(
                    error,
                    skin.typography.small,
                    geometry.widths[column],
                  ).height.ceilToDouble());
  }

  Widget _line(int index, _Geometry geometry, LifeOSSkinData skin) {
    if (index >= widget.lines.length) {
      return _NewLine(
        key: const ValueKey('grid-new-row'),
        geometry: geometry,
        skin: skin,
        enabled: _enabled,
        onTap: _tapNew,
      );
    }
    final key = _lineKeys[index];
    return switch (widget.lines[index]) {
      GridGroup<T>(:final label, :final summary) => _GroupLine(
        key: key,
        label: label,
        summary: summary,
        geometry: geometry,
        skin: skin,
      ),
      final GridRow<T> line => _RowLine<T>(
        key: key,
        grid: this,
        id: widget.rowId(line.row),
        line: line,
        geometry: geometry,
        skin: skin,
      ),
    };
  }

  /// One record line: selector, tick, cells (the open one an editor).
  Widget _buildRow(
    String id,
    GridRow<T> line,
    _Geometry geometry,
    LifeOSSkinData skin,
  ) {
    final tokens = skin.tokens;
    final row = line.row;
    final selected = id == widget.selectedId;
    final lit = selected && widget.active && _enabled;
    final pending = widget.pendingIds.contains(id);
    final session = _controller.session;
    final open = session != null && session.id.record == id
        ? session.id.field
        : null;
    final columns = widget.columns;
    final openIndex = open == null
        ? -1
        : columns.indexWhere((c) => c.key == open && c.editable);
    final cellHeight = (_lineHeights[_lineIndex[id]] ?? geometry.rowHeight) - 1;
    final muted = line.state != GridRowState.normal || !_enabled;
    final ink = lit
        ? tokens.selInk
        : muted
        ? tokens.muted
        : tokens.ink;
    final sorted = columns.indexWhere((c) => c.key == widget.sortColumn);
    final errorColumns = <int>[];
    final cells = <Widget>[];
    for (final (index, column) in columns.indexed) {
      final cell = GridCell(id, column.key);
      final error = widget.errors[cell];
      final width = geometry.widths[index];
      if (index == openIndex) {
        final openError = session?.error ?? error;
        final editor = CellEditor(
          key: ValueKey('grid-editor:${column.key}'),
          controller: _controller,
          field: _field(id, row, column),
          label: column.label,
          host: _host,
          next: () => _next(id, column.key),
          choices: column.choices,
          today: widget.today,
          optional: column.optional,
          enabled: _canEdit(row, column),
          error: error,
        );
        // Checks have no built-in error caption; provide the same wrapped
        // caption and red edge as the other value editors.
        final checkError = column.kind == ValueKind.check && openError != null;
        if (checkError) errorColumns.add(index);
        cells.add(
          SizedBox(
            key: ValueKey('grid-cell:$id:${column.key}'),
            width: width,
            child: checkError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      editor,
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          openError,
                          style: skin.typography.small.copyWith(
                            color: tokens.negative,
                          ),
                        ),
                      ),
                    ],
                  )
                : editor,
          ),
        );
        continue;
      }
      if (error != null) errorColumns.add(index);
      final text = column.text(row);
      final reason = selected ? _lockReason(row, column) : null;
      final explained = _explained?.$1 == cell;
      final style =
          (column.kind.usesFigures
                  ? skin.typography.figure
                  : skin.typography.body)
              .copyWith(
                color: ink,
                fontWeight: widget.changed.contains(cell)
                    ? FontWeight.w700
                    : FontWeight.w400,
                decoration: line.state == GridRowState.voided
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: tokens.negative,
                decorationThickness: 2,
              );
      cells.add(
        Semantics(
          key: ValueKey('grid-cell:$id:${column.key}'),
          label: column.label,
          value: [
            if (column.kind == ValueKind.check)
              (column.value(row) as bool? ?? false) ? 'ticked' : 'not ticked'
            else
              text,
            if (widget.changed.contains(cell)) 'changed',
            ?error,
          ].join(', '),
          hint: reason,
          readOnly: reason != null,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _tapCell(id, column.key),
            child: Container(
              width: width,
              constraints: BoxConstraints(minHeight: cellHeight),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              alignment: column.kind.isNumeric
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              foregroundDecoration: explained
                  ? skin.painters.cellCursor(tokens, onSelection: lit)
                  : null,
              child: column.kind == ValueKind.check
                  ? _TickBox(
                      checked: column.value(row) as bool? ?? false,
                      enabled: !muted,
                    )
                  : Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: column.kind.align,
                      style: style,
                    ),
            ),
          ),
        ),
      );
    }
    final picked = widget.pickedIds.contains(id);
    final eligible = widget.canPick?.call(row) ?? true;
    final status = [
      ?line.state.announcement,
      if (pending) 'pending changes',
      if (widget.pickMode)
        eligible ? (picked ? 'picked' : 'not picked') : 'cannot be picked',
      for (final MapEntry(:key, :value) in widget.errors.entries)
        if (key.rowId == id) value,
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      selected: selected,
      label: widget.rowLabel(row),
      value: status.isEmpty ? null : status.join(', '),
      onTap: _enabled && widget.onSelect != null ? () => _select(id) : null,
      child: CustomPaint(
        painter: _RowBackdrop(
          fill: selected
              ? (lit ? tokens.selWash : tokens.chrome)
              : tokens.paper,
          selector: selected,
          tokens: tokens,
          tint: !selected && sorted >= 0
              ? (geometry.starts[sorted], geometry.widths[sorted])
              : null,
          errors: [
            for (final index in errorColumns)
              (geometry.starts[index], geometry.widths[index]),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                key: ValueKey('grid-selector:$id'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(id),
                child: SizedBox(
                  width: _selectorWidth,
                  height: cellHeight,
                  child: Center(
                    child: pending
                        ? const _SelectorGlyph(_Mark.pending)
                        : selected
                        ? const _SelectorGlyph(_Mark.current)
                        : null,
                  ),
                ),
              ),
              if (widget.pickMode)
                Semantics(
                  key: ValueKey('grid-pick:$id'),
                  checked: eligible ? picked : null,
                  label: 'Pick',
                  onTap: eligible && _enabled && widget.onPick != null
                      ? () => _tapPick(id)
                      : null,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: eligible ? () => _tapPick(id) : null,
                    child: SizedBox(
                      width: _pickWidth,
                      height: cellHeight,
                      child: eligible
                          ? Center(
                              child: _TickBox(
                                checked: picked,
                                enabled: _enabled && widget.onPick != null,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ...cells,
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(id),
                  child: SizedBox(height: cellHeight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scroll position that reveals a target only as far as needed: an editor
/// that asks to be shown (`Scrollable.ensureVisible`) moves the table only
/// when it is not already in view, and never past it.
final class _RevealController extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _RevealPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );

  @override
  _RevealPosition get position => super.position as _RevealPosition;
}

final class _RevealPosition extends ScrollPositionWithSingleContext {
  _RevealPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  /// Brings [object] into view by the least movement; its start wins when
  /// it is longer than the viewport.
  void reveal(RenderObject object, {RenderObject? target}) {
    super.ensureVisible(
      object,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      targetRenderObject: target,
    );
    super.ensureVisible(
      object,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      targetRenderObject: target,
    );
  }

  @override
  Future<void> ensureVisible(
    RenderObject object, {
    double alignment = 0.0,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
    ScrollPositionAlignmentPolicy alignmentPolicy =
        ScrollPositionAlignmentPolicy.explicit,
    RenderObject? targetRenderObject,
  }) async {
    if (alignmentPolicy != ScrollPositionAlignmentPolicy.explicit ||
        duration != Duration.zero) {
      return super.ensureVisible(
        object,
        alignment: alignment,
        duration: duration,
        curve: curve,
        alignmentPolicy: alignmentPolicy,
        targetRenderObject: targetRenderObject,
      );
    }
    reveal(object, target: targetRenderObject);
  }
}

/// A record line; it registers itself so the grid can scroll to it.
final class _RowLine<T> extends StatefulWidget {
  const _RowLine({
    required this.grid,
    required this.id,
    required this.line,
    required this.geometry,
    required this.skin,
    super.key,
  });

  final _DataGridState<T> grid;
  final String id;
  final GridRow<T> line;
  final _Geometry geometry;
  final LifeOSSkinData skin;

  @override
  State<_RowLine<T>> createState() => _RowLineState<T>();
}

final class _RowLineState<T> extends State<_RowLine<T>> {
  @override
  void initState() {
    super.initState();
    widget.grid._mounted[widget.id] = this;
  }

  @override
  void didUpdateWidget(_RowLine<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      if (identical(widget.grid._mounted[oldWidget.id], this)) {
        widget.grid._mounted.remove(oldWidget.id);
      }
      widget.grid._mounted[widget.id] = this;
    }
  }

  @override
  void dispose() {
    if (identical(widget.grid._mounted[widget.id], this)) {
      widget.grid._mounted.remove(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.grid._buildRow(
    widget.id,
    widget.line,
    widget.geometry,
    widget.skin,
  );
}

/// Paints a record line's ground: its fill, the selector's bevel, the
/// sorted column's tint, red error edges and the rule underneath, all at
/// the line's full height.
final class _RowBackdrop extends CustomPainter {
  const _RowBackdrop({
    required this.fill,
    required this.selector,
    required this.tokens,
    this.tint,
    this.errors = const [],
  });

  final Color fill;

  /// Whether the selector shows the current record's warm face.
  final bool selector;
  final LifeOSTokens tokens;
  final (double, double)? tint;
  final List<(double, double)> errors;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    _paintSelector(canvas, size.height, t, current: selector);
    if (tint case (final x, final width)) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, width, size.height - 1),
        Paint()..color = MillenniumColors.sortTint,
      );
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = t.negative;
    for (final (x, width) in errors) {
      canvas.drawRect(
        Rect.fromLTWH(x + 0.5, 0.5, width - 1, size.height - 2),
        edge,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(_selectorWidth, size.height - 1, size.width, 1),
      Paint()..color = t.rule,
    );
  }

  @override
  bool shouldRepaint(_RowBackdrop oldDelegate) =>
      fill != oldDelegate.fill ||
      selector != oldDelegate.selector ||
      tint != oldDelegate.tint ||
      !_sameRanges(errors, oldDelegate.errors);

  static bool _sameRanges(List<(double, double)> a, List<(double, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The selector column's bevel: paper fading to the band (warm on the
/// current record), with its edge line.
void _paintSelector(
  Canvas canvas,
  double height,
  LifeOSTokens tokens, {
  bool current = false,
}) {
  final rect = Rect.fromLTWH(0, 0, _selectorWidth, height);
  canvas
    ..drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            tokens.paper,
            current ? MillenniumColors.hotRingInner : tokens.band,
          ],
        ).createShader(rect),
    )
    ..drawRect(
      Rect.fromLTWH(_selectorWidth - 1, 0, 1, height),
      Paint()..color = tokens.chromeLine,
    );
}

enum _Mark { current, pending, fresh }

/// The selector's painted mark: ▸ current, ✎ pending, `*` new.
final class _SelectorGlyph extends StatelessWidget {
  const _SelectorGlyph(this.mark);

  final _Mark mark;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size.square(9),
    painter: _MarkPainter(mark, LifeOSSkinScope.of(context).tokens.ink),
  );
}

final class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.mark, this.color);

  final _Mark mark;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    switch (mark) {
      case _Mark.current:
        canvas.drawPath(
          Path()
            ..moveTo(3, 0.5)
            ..lineTo(7, 4.5)
            ..lineTo(3, 8.5)
            ..close(),
          fill,
        );
      case _Mark.pending:
        // A pencil leaning right, its point at the bottom left.
        canvas
          ..drawPath(
            Path()
              ..moveTo(0.5, 8.5)
              ..lineTo(1, 6)
              ..lineTo(6.5, 0.5)
              ..lineTo(8.5, 2.5)
              ..lineTo(3, 8)
              ..close(),
            fill,
          )
          ..drawLine(
            const Offset(5.5, 1.5),
            const Offset(7.5, 3.5),
            Paint()
              ..color = MillenniumColors.hotRingInner
              ..strokeWidth = 0.8,
          );
      case _Mark.fresh:
        final stroke = Paint()
          ..color = color
          ..strokeWidth = 1.3;
        canvas
          ..drawLine(const Offset(4.5, 0.5), const Offset(4.5, 8.5), stroke)
          ..drawLine(const Offset(1, 2.5), const Offset(8, 6.5), stroke)
          ..drawLine(const Offset(1, 6.5), const Offset(8, 2.5), stroke);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      mark != oldDelegate.mark || color != oldDelegate.color;
}

/// A painted 13 px tick box: a picked record, or a check value.
final class _TickBox extends StatelessWidget {
  const _TickBox({required this.checked, required this.enabled});

  final bool checked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: enabled ? tokens.paper : tokens.chrome,
        border: Border.all(
          color: enabled ? MillenniumColors.choiceLine : tokens.chromeLine,
        ),
      ),
      child: checked
          ? Center(
              child: EraGlyph(
                EraGlyphKind.tick,
                color: enabled ? MillenniumColors.choiceMark : tokens.muted,
              ),
            )
          : null,
    );
  }
}

/// The header: the selector's corner, the tick column and one bevelled
/// head per column; a head sorts on click and resizes from its right edge.
final class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.grid,
    required this.geometry,
    required this.skin,
  });

  final _DataGridState<T> grid;
  final _Geometry geometry;
  final LifeOSSkinData skin;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    final widget = grid.widget;
    return Container(
      constraints: BoxConstraints(minHeight: geometry.headerHeight),
      decoration: BoxDecoration(
        gradient: skin.painters.columnHead(tokens),
        border: Border(bottom: BorderSide(color: tokens.chromeLine)),
      ),
      child: _EqualHeightLine(
        children: [
          SizedBox(width: geometry.lead, child: const _HeadEdge()),
          for (final (index, column) in widget.columns.indexed)
            _HeaderCell<T>(
              key: ValueKey('grid-head:${column.key}'),
              grid: grid,
              index: index,
              column: column,
              width: geometry.widths[index],
              skin: skin,
            ),
        ],
      ),
    );
  }
}

/// Lays children side by side, each as tall as the tallest, without
/// intrinsic measurement: children are laid out once loosely, then again
/// at the common height.
final class _EqualHeightLine extends MultiChildRenderObjectWidget {
  const _EqualHeightLine({super.children});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLine();
}

final class _LineData extends ContainerBoxParentData<RenderBox> {}

final class _RenderLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LineData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LineData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LineData) child.parentData = _LineData();
  }

  @override
  void performLayout() {
    var height = constraints.minHeight;
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints(maxHeight: constraints.maxHeight),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = childAfter(child);
    }
    height = constraints.constrainHeight(height);
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: child.size.width, height: height),
        parentUsesSize: true,
      );
      (child.parentData! as _LineData).offset = Offset(x, 0);
      x += child.size.width;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(x, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// The lead corner's right edge: a chrome line with a white line beside it.
final class _HeadEdge extends StatelessWidget {
  const _HeadEdge();

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: tokens.chromeLine)),
      ),
      child: const SizedBox(),
    );
  }
}

final class _HeaderCell<T> extends StatefulWidget {
  const _HeaderCell({
    required this.grid,
    required this.index,
    required this.column,
    required this.width,
    required this.skin,
    super.key,
  });

  final _DataGridState<T> grid;
  final int index;
  final GridColumn<T> column;
  final double width;
  final LifeOSSkinData skin;

  @override
  State<_HeaderCell<T>> createState() => _HeaderCellState<T>();
}

final class _HeaderCellState<T> extends State<_HeaderCell<T>> {
  bool _hot = false;
  double _dragStart = 0;
  double _dragged = 0;

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    final skin = widget.skin;
    final tokens = skin.tokens;
    final column = widget.column;
    final enabled = grid._enabled;
    final sortable = enabled && grid.widget.onSort != null && column.sortable;
    final sorted = grid.widget.sortColumn == column.key;
    final descending = grid.widget.sortDescending;
    final resizable = enabled && grid.widget.onResize != null;
    final head = Container(
      width: widget.width,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      foregroundDecoration: _hot && sortable
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: MillenniumColors.sortAccent,
                  width: 3,
                ),
              ),
            )
          : null,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: tokens.chromeLine)),
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
              textAlign: column.kind.align,
              style: skin.typography.label.copyWith(
                color: enabled ? tokens.ink : tokens.muted,
              ),
            ),
          ),
          if (sorted) ...[
            const SizedBox(width: 4),
            EraGlyph(
              descending ? EraGlyphKind.sortDown : EraGlyphKind.sortUp,
              color: enabled ? tokens.ink : tokens.muted,
            ),
          ],
        ],
      ),
    );
    final cell = Semantics(
      key: ValueKey('grid-header:${column.key}'),
      button: sortable,
      label: [
        column.label,
        if (sorted) descending ? 'sorted descending' : 'sorted ascending',
      ].join(', '),
      onTap: sortable ? () => grid._tapHeader(column) : null,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hot = true),
        onExit: (_) => setState(() => _hot = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => grid._tapHeader(column),
          child: head,
        ),
      ),
    );
    final description = column.description;
    final labelled = description == null
        ? cell
        : Tooltip(
            message: description,
            excludeFromSemantics: true,
            child: cell,
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        labelled,
        if (resizable)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                key: ValueKey('grid-resize:${column.key}'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _dragStart = widget.width;
                  _dragged = 0;
                },
                onHorizontalDragUpdate: (details) {
                  _dragged += details.delta.dx;
                  grid._drag(widget.index, _dragStart + _dragged);
                },
                onHorizontalDragEnd: (_) => grid._dragEnd(widget.index),
              ),
            ),
          ),
      ],
    );
  }
}

/// A group heading, its summary on the right.
final class _GroupLine extends StatelessWidget {
  const _GroupLine({
    required this.label,
    required this.summary,
    required this.geometry,
    required this.skin,
    super.key,
  });

  final String label;
  final String? summary;
  final _Geometry geometry;
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
      child: CustomPaint(
        painter: _GroupBackdrop(tokens),
        child: Container(
          constraints: BoxConstraints(minHeight: geometry.groupHeight),
          padding: EdgeInsets.fromLTRB(geometry.lead + 5, 4, 5, 2),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Expanded(child: Text(label, style: style)),
              if (summary case final summary?)
                Text(
                  summary,
                  style: style.copyWith(fontWeight: FontWeight.w400),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _GroupBackdrop extends CustomPainter {
  const _GroupBackdrop(this.tokens);

  final LifeOSTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = tokens.paper);
    _paintSelector(canvas, size.height, tokens);
    canvas.drawRect(
      Rect.fromLTWH(_selectorWidth, size.height - 1, size.width, 1),
      Paint()..color = MillenniumColors.groupRowRule,
    );
  }

  @override
  bool shouldRepaint(_GroupBackdrop oldDelegate) => false;
}

/// The `*` line that starts a new record.
final class _NewLine extends StatelessWidget {
  const _NewLine({
    required this.geometry,
    required this.skin,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final _Geometry geometry;
  final LifeOSSkinData skin;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: 'New record',
    onTap: enabled ? onTap : null,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _RowBackdrop(
          fill: skin.tokens.paper,
          selector: false,
          tokens: skin.tokens,
        ),
        child: SizedBox(
          height: geometry.rowHeight,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: _selectorWidth,
              child: Center(child: _SelectorGlyph(_Mark.fresh)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The totals line, aligned with the columns: the caption spans the
/// columns before the first total.
final class _FooterRow<T> extends StatelessWidget {
  const _FooterRow({
    required this.grid,
    required this.geometry,
    required this.skin,
  });

  final _DataGridState<T> grid;
  final _Geometry geometry;
  final LifeOSSkinData skin;

  @override
  Widget build(BuildContext context) {
    final tokens = skin.tokens;
    final widget = grid.widget;
    final values = widget.footer ?? const {};
    final columns = widget.columns;
    var first = columns.indexWhere((c) => values.containsKey(c.key));
    if (first < 0) first = columns.length;
    final style = skin.typography.figure.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w700,
    );
    final captionWidth =
        geometry.lead +
        geometry.widths.take(first).fold<double>(0, (sum, w) => sum + w);
    return Semantics(
      container: true,
      label: [
        ?widget.footerLabel,
        for (final column in columns)
          if (values[column.key] case final value?) '${column.label} $value',
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('grid-footer'),
        constraints: BoxConstraints(minHeight: geometry.rowHeight),
        decoration: BoxDecoration(
          color: tokens.chrome,
          border: Border(top: BorderSide(color: tokens.chromeLine)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: captionWidth,
              padding: EdgeInsets.fromLTRB(geometry.lead + 5, 3, 5, 2),
              child: Text(
                widget.footerLabel ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontFeatures: null),
              ),
            ),
            for (var index = first; index < columns.length; index++)
              Container(
                width: geometry.widths[index],
                padding: const EdgeInsets.fromLTRB(5, 3, 5, 2),
                child: Text(
                  values[columns[index].key] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: columns[index].kind.align,
                  style: style,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
