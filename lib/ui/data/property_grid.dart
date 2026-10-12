import 'dart:math' as math;

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../controls/cell_editor.dart';
import '../controls/editor_session_controller.dart';
import '../controls/era_combo.dart';
import '../controls/era_form.dart';
import '../controls/era_scrollbar.dart';
import '../controls/value_editor.dart';
import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import '../foundation/lifeos_tokens.dart';
import '../foundation/millennium_style.dart';

/// How a [PropertyGrid] orders its properties: under collapsible category
/// headings, in the caller's order (Categorized), or by label without
/// categories (A–Z). Only the display order changes, never an identity.
enum PropertyGridOrder { categorized, alphabetical }

/// One property of the record a [PropertyGrid] shows: immutable data from
/// the caller, no widget state.
///
/// [key] is unique within the record and, with the grid's record, makes
/// the field's [EditIdentity]. A property is editable unless it is
/// disabled, read-only (it has a [readOnlyReason]) or a follow link (it has
/// [onFollow]).
@immutable
final class PropertyItem {
  const PropertyItem({
    required this.key,
    required this.label,
    required this.category,
    this.kind = ValueKind.text,
    this.value,
    this.display,
    this.text,
    this.readOnlyReason,
    this.was,
    this.description,
    this.choices = const [],
    this.optional = false,
    this.onFollow,
    this.error,
    this.enabled = true,
  });

  /// The field key within the record, such as `end`.
  final String key;
  final String label;

  /// The heading it sits under in the categorized view.
  final String category;
  final ValueKind kind;

  /// The caller's current (pending) value; what an editor starts from.
  final Object? value;

  /// The caller's text for [value] (an amount, a duration, a link's
  /// target); defaults to [formatValue].
  final String? display;

  /// The text a kind typed as text is edited from ([EditField.text]).
  final String? text;

  /// Why the value cannot be edited here; null for an editable value. The
  /// value is muted and the description pane shows the reason.
  final String? readOnlyReason;

  /// The saved value's display while the pending value differs: the value
  /// is bold and followed by "(was …)".
  final String? was;

  /// One or two lines for the description pane.
  final String? description;

  /// The choices of a [ValueKind.choice] value.
  final List<EraComboItem<Object?>> choices;

  /// A date that may be empty.
  final bool optional;

  /// Makes the value a follow link ("Belongs to"); mouse only. The grid
  /// flushes the open field before calling it.
  final VoidCallback? onFollow;

  /// The caller's error for the value, shown while no rejected draft of
  /// the field has one.
  final String? error;

  /// A disabled property is greyed and can be neither selected, edited
  /// nor followed.
  final bool enabled;

  bool get readOnly => readOnlyReason != null;

  /// Whether an editor can open on it: enabled, not read-only, no link.
  bool get editable => enabled && readOnlyReason == null && onFollow == null;
}

/// The property grid (database shell spec 3, 4.1, 4.2, 6): the key/value
/// editor of the selected record, as Visual Basic's Properties window
/// draws it. A Categorized / A–Z toolbar, collapsible category headings,
/// a name column with the selection, kind-specific in-row editors, muted
/// read-only values, "(was …)" after changed values, follow links and a
/// description pane under the list.
///
/// The grid edits through the caller's [controller], shared with the data
/// grid and subform of the same pending aggregate. A click on an editable
/// value opens its editor (a bare [CellEditor]); Enter or Tab commits it
/// through [onCommit] and opens the next eligible value down, computed
/// from the caller's refreshed [items], so a commit that changes another
/// property's eligibility is respected. At the last eligible value the
/// editor closes; nothing wraps. Esc throws away the open value only.
///
/// Every command flushes the open field first and runs only when the flush
/// is accepted: selecting another property, collapsing a category,
/// changing the order and following a link. A refused flush leaves the
/// field, its category, the order and the selection as they were.
///
/// Mouse only outside an open editor: the grid holds the keyboard on its
/// own node (so Tab cannot traverse out when an editor closes) and no key
/// selects, opens, collapses, sorts or scrolls.
///
/// Layout is measured: the label column is clamped to leave the widest
/// editor its minimum, a label that still does not fit goes above its
/// value, and an editor wider than the whole grid scrolls sideways. The
/// description pane grows with its text up to a share of the grid's height
/// and scrolls beyond it. The grid needs a bounded height and fills it.
///
/// Selection, collapse and order are local view state. A new [record]
/// resets selection and collapse; the controller's drafts stay keyed by
/// their own record, so nothing typed for one record shows on another.
final class PropertyGrid extends StatefulWidget {
  const PropertyGrid({
    required this.record,
    required this.controller,
    required this.items,
    required this.onCommit,
    this.today,
    this.active = true,
    this.enabled = true,
    this.initialOrder = PropertyGridOrder.categorized,
    this.onOrderChanged,
    this.edited = false,
    this.label = 'Properties',
    super.key,
  });

  /// The record shown, as the caller identifies it in the edit session
  /// ([EditIdentity.record]); compared with `==`.
  final Object record;

  /// The pending aggregate's shared editor controller.
  final EditorSessionController controller;

  /// The record's properties, in category order. Keys are unique.
  final List<PropertyItem> items;

  /// UI draft acceptance for every editable property: synchronous, applied
  /// to `id.record` before it returns accepted ([EditCommit]).
  final EditCommit onCommit;

  /// Today for date calendars: fixed by the caller, never the wall clock.
  /// Required when any item is a date.
  final LocalDate? today;

  /// Only the selection paint: blue when the grid is the active region,
  /// face grey otherwise.
  final bool active;

  /// False greys the grid: nothing selects, opens, collapses, sorts or
  /// follows. A read-only [EraFormScope] does the same.
  final bool enabled;

  /// The order the grid starts in.
  final PropertyGridOrder initialOrder;

  /// Told when the owner switches the order, to remember it.
  final ValueChanged<PropertyGridOrder>? onOrderChanged;

  /// Shows the "Edited" marker in the toolbar while an edit is pending.
  final bool edited;

  /// The grid's accessible name.
  final String label;

  @override
  State<PropertyGrid> createState() => _PropertyGridState();
}

/// The token the grid's editors pass as their host.
final class _GridHost {
  @override
  String toString() => 'PropertyGrid';
}

/// The column of category boxes left of every row.
const _gutter = 13.0;

/// The baseline name column (100 % text).
const _labelColumn = 128.0;

/// The narrowest a value is shown beside its label, at 100 % text.
const _displayMin = 40.0;

/// The narrowest each kind's editor stays usable, at 100 % text.
double _editorMin(PropertyItem item) => switch (item.kind) {
  ValueKind.text || ValueKind.choice => 96,
  ValueKind.number || ValueKind.money || ValueKind.duration => 64,
  ValueKind.date => item.optional ? 140 : 120,
  ValueKind.time => 72,
  ValueKind.check => 16,
};

/// [word]'s width in a name cell, measured bold (a changed property's
/// name is bold).
double _wordWidth(String word, LifeOSSkinData skin, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: word, style: skin.typography.strong),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The measured column layout of one grid width.
final class _Columns {
  const _Columns({
    required this.label,
    required this.available,
    required this.content,
    required this.scaler,
    required this.longWords,
  });

  /// The name column's width.
  final double label;

  /// The width beside the gutter.
  final double available;

  /// The rows' width: the viewport, or wider when an editor needs it.
  final double content;
  final TextScaler scaler;

  /// Labels with a word wider than the name column.
  final Set<String> longWords;

  double minOf(PropertyItem item) =>
      scaler.scale(item.editable ? _editorMin(item) : _displayMin);

  /// Whether [item]'s label goes above its value: beside it the value
  /// would be narrower than its minimum, or a word of the label would
  /// break.
  bool stacked(PropertyItem item) =>
      label + 1 + minOf(item) > available || longWords.contains(item.key);

  /// [wordWidth] measures one word of a label as the name cell draws it.
  static _Columns measure(
    double width,
    List<PropertyItem> items,
    TextScaler scaler,
    double Function(String word) wordWidth,
  ) {
    final available = math.max(0.0, width - _gutter);
    double minOf(PropertyItem item) =>
        scaler.scale(item.editable ? _editorMin(item) : _displayMin);
    var widest = 0.0;
    for (final item in items) {
      widest = math.max(widest, minOf(item));
    }
    final high = scaler.scale(_labelColumn);
    final low = math.min(high, math.max(scaler.scale(48), available * 0.35));
    final label = (available - 1 - widest).clamp(low, high);
    var content = width;
    final longWords = <String>{};
    for (final item in items) {
      final words = item.label.split(RegExp(r'\s+'));
      if (words.any((word) => wordWidth(word) > label - 8)) {
        longWords.add(item.key);
      }
      if (label + 1 + minOf(item) > available || longWords.contains(item.key)) {
        content = math.max(content, _gutter + minOf(item));
      }
    }
    return _Columns(
      label: label,
      available: available,
      content: content,
      scaler: scaler,
      longWords: longWords,
    );
  }
}

final class _PropertyGridState extends State<PropertyGrid> {
  final _host = _GridHost();
  final _region = FocusNode(debugLabel: 'PropertyGrid', skipTraversal: true);
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _describe = ScrollController();
  late PropertyGridOrder _order = widget.initialOrder;
  final _collapsed = <String>{};
  Map<String, PropertyItem> _byKey = const {};
  String? _selected;

  /// The property whose accepted Enter or Tab waits for the next field,
  /// opened once the caller has rebuilt the grid with its new values.
  String? _advanceFrom;

  /// The surrounding form's enabled state, as last built.
  bool _formEnabled = true;

  EditorSessionController get _controller => widget.controller;
  bool get _interactive => widget.enabled && _formEnabled;

  @override
  void initState() {
    super.initState();
    _index();
    _controller.addListener(_onSession);
  }

  @override
  void didUpdateWidget(PropertyGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSession);
      widget.controller.addListener(_onSession);
    }
    if (oldWidget.record != widget.record) {
      // Another record: nothing of the old one's view carries over. Its
      // open draft, if any, stays in the controller under its own record.
      _selected = null;
      _collapsed.clear();
      _advanceFrom = null;
      if (_region.hasFocus) _region.requestFocus();
    }
    _index();
  }

  @override
  void dispose() {
    _controller.removeListener(_onSession);
    _region.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    _describe.dispose();
    super.dispose();
  }

  void _index() {
    final byKey = <String, PropertyItem>{};
    for (final item in widget.items) {
      if (byKey.containsKey(item.key)) {
        throw ArgumentError.value(item.key, 'items', 'duplicate property key');
      }
      byKey[item.key] = item;
    }
    _byKey = byKey;
  }

  EditIdentity _id(String key) =>
      EditIdentity(record: widget.record, field: key);

  /// The open field's property, when it is one of this record's.
  String? get _activeKey {
    final session = _controller.session;
    if (session == null || session.id.record != widget.record) return null;
    return _byKey.containsKey(session.id.field) ? session.id.field : null;
  }

  void _onSession() {
    if (!mounted) return;
    if (_activeKey case final key?) _selected = key;
    // The editor that had the keyboard closed (or the field moved to
    // another region): the grid keeps the keyboard, so no key traverses.
    final session = _controller.session;
    if (_region.hasFocus &&
        !_region.hasPrimaryFocus &&
        (session == null || session.host != _host)) {
      _region.requestFocus();
    }
    setState(() {});
  }

  /// The properties in display order, including collapsed ones.
  List<PropertyItem> get _ordered {
    if (_order == PropertyGridOrder.alphabetical) {
      final indexed = widget.items.indexed.toList()
        ..sort((a, b) {
          final byLabel = a.$2.label.toLowerCase().compareTo(
            b.$2.label.toLowerCase(),
          );
          return byLabel != 0 ? byLabel : a.$1.compareTo(b.$1);
        });
      return [for (final (_, item) in indexed) item];
    }
    return [for (final (_, items) in _groups) ...items];
  }

  /// The categories in the order they first appear, with their items.
  List<(String, List<PropertyItem>)> get _groups {
    final groups = <String, List<PropertyItem>>{};
    for (final item in widget.items) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    return [for (final MapEntry(:key, :value) in groups.entries) (key, value)];
  }

  /// The selected property: the open field of this record, else the
  /// owner's last pick, else the first enabled property.
  PropertyItem? get _selection {
    final key = _activeKey ?? _selected;
    final picked = key == null ? null : _byKey[key];
    if (picked != null && (picked.enabled || key == _activeKey)) return picked;
    for (final item in _ordered) {
      if (item.enabled) return item;
    }
    return null;
  }

  EditField _field(PropertyItem item) => EditField(
    id: _id(item.key),
    kind: item.kind,
    value: item.value,
    commit: widget.onCommit,
    text: item.text,
  );

  bool _eligible(PropertyItem item) => _interactive && item.editable;

  /// Called by the open editor right after its draft was accepted. The
  /// caller's new values reach the grid with its next build, so the next
  /// field is chosen then, from them.
  EditField? _next(String key) {
    _advanceFrom = key;
    final record = widget.record;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _advance(record, key))
      ..ensureVisualUpdate();
    return null;
  }

  void _advance(Object record, String key) {
    if (!mounted || _advanceFrom != key || widget.record != record) return;
    _advanceFrom = null;
    if (_controller.session != null) return;
    final ordered = _ordered;
    final at = ordered.indexWhere((item) => item.key == key);
    if (at < 0) return;
    for (final item in ordered.skip(at + 1)) {
      if (!_eligible(item)) continue;
      if (_order == PropertyGridOrder.categorized &&
          _collapsed.contains(item.category)) {
        setState(() => _collapsed.remove(item.category));
      }
      _controller.begin(_field(item), host: _host);
      return;
    }
  }

  /// The grid takes the keyboard unless its own editor has it.
  void _hold() {
    if (_controller.session?.host != _host) _region.requestFocus();
  }

  void _select(PropertyItem item) {
    if (!_interactive || !item.enabled) return;
    if (_selection?.key != item.key) {
      if (!_controller.flush().isAccepted) return;
      setState(() => _selected = item.key);
    }
    _hold();
  }

  void _edit(PropertyItem item) {
    if (!_eligible(item)) return;
    if (!_controller.begin(_field(item), host: _host).isAccepted) return;
    setState(() => _selected = item.key);
  }

  void _follow(PropertyItem item) {
    final follow = item.onFollow;
    if (!_interactive || !item.enabled || follow == null) return;
    if (!_controller.flush().isAccepted) return;
    setState(() => _selected = item.key);
    _hold();
    follow();
  }

  void _toggle(String category) {
    if (!_interactive) return;
    if (!_controller.flush().isAccepted) return;
    setState(() {
      if (!_collapsed.remove(category)) _collapsed.add(category);
    });
    _hold();
  }

  void _setOrder(PropertyGridOrder order) {
    if (!_interactive || order == _order) return;
    if (!_controller.flush().isAccepted) return;
    setState(() {
      // The order moves rows, never the selection.
      _selected = _selection?.key;
      _order = order;
    });
    _hold();
    widget.onOrderChanged?.call(order);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.today != null ||
          !widget.items.any((item) => item.kind == ValueKind.date),
      'A property grid with dates needs an explicit today.',
    );
    _formEnabled = EraFormScope.enabledOf(context);
    final skin = LifeOSSkinScope.of(context);
    final selection = _selection;
    return Focus(
      focusNode: _region,
      // Outside an open editor every key is held here; an editor's keys
      // were already handled below.
      onKeyEvent: (node, event) => node.hasPrimaryFocus
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.label,
        child: LayoutBuilder(
          builder: (context, constraints) {
            assert(
              constraints.hasBoundedHeight,
              'A PropertyGrid needs a bounded height.',
            );
            // The description grows with its text up to a share of the
            // grid, so a long error cannot push the list away.
            final most = math.max(0.0, constraints.maxHeight * 0.35);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _toolbar(skin),
                Expanded(child: _list(skin, selection)),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.min(58, most),
                    maxHeight: most,
                  ),
                  child: _description(skin, selection),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _toolbar(LifeOSSkinData skin) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 26),
      child: Row(
        children: [
          const SizedBox(width: 2),
          for (final order in PropertyGridOrder.values) ...[
            _OrderKey(
              key: ValueKey('property-order-${order.name}'),
              order: order,
              on: _order == order,
              enabled: _interactive,
              onPressed: () => _setOrder(order),
            ),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: widget.edited
                ? Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const EraIcon(EraIconKind.correct, size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Edited',
                              style: skin.typography.body.copyWith(
                                color: skin.tokens.head,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );

  Widget _list(LifeOSSkinData skin, PropertyItem? selection) {
    final scaler = MediaQuery.textScalerOf(context);
    // Bars are drawn here: a vertical one beside the rows and a sideways
    // one under them, both outside the scrolled content.
    return DecoratedBox(
      key: const ValueKey('property-list'),
      decoration: BoxDecoration(
        color: skin.tokens.paper,
        border: Border.all(color: MillenniumColors.fieldLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: EraScrollbar(
            controller: _horizontal,
            axis: Axis.horizontal,
            depth: 1,
            child: EraScrollbar(
              controller: _vertical,
              axis: Axis.vertical,
              child: SingleChildScrollView(
                controller: _vertical,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = _Columns.measure(
                      constraints.maxWidth,
                      widget.items,
                      scaler,
                      (word) => _wordWidth(word, skin, scaler),
                    );
                    return SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: columns.content,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _rows(skin, columns, selection),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _rows(
    LifeOSSkinData skin,
    _Columns columns,
    PropertyItem? selection,
  ) {
    Widget row(PropertyItem item) => _PropertyRow(
      key: ValueKey('property-row:${item.key}'),
      item: item,
      columns: columns,
      selected: selection?.key == item.key,
      active: widget.active,
      interactive: _interactive,
      editor: _controller.isActive(_id(item.key)) ? _editor(item) : null,
      onSelect: () => _select(item),
      onEdit: () => _edit(item),
      onFollow: () => _follow(item),
    );

    if (_order == PropertyGridOrder.alphabetical) {
      return [for (final item in _ordered) row(item)];
    }
    return [
      for (final (category, items) in _groups) ...[
        _CategoryRow(
          key: ValueKey('property-category:$category'),
          category: category,
          open: !_collapsed.contains(category),
          enabled: _interactive,
          onToggle: () => _toggle(category),
        ),
        if (!_collapsed.contains(category)) ...items.map(row),
      ],
    ];
  }

  Widget _editor(PropertyItem item) => CellEditor(
    key: ValueKey(('property-editor', widget.record, item.key)),
    controller: _controller,
    field: _field(item),
    label: item.label,
    host: _host,
    next: () => _next(item.key),
    choices: item.choices,
    today: widget.today,
    optional: item.optional,
    enabled: item.editable && widget.enabled,
    error: item.error,
    fieldKey: ValueKey('property-editor:${item.key}'),
  );

  Widget _description(LifeOSSkinData skin, PropertyItem? item) {
    final tokens = skin.tokens;
    final session = _controller.session;
    final error = item == null
        ? null
        : (session != null && session.id == _id(item.key)
                  ? session.error
                  : null) ??
              item.error;
    final lines = [
      if (item != null)
        Text(
          item.label,
          style: skin.typography.strong.copyWith(color: tokens.ink),
        ),
      if (error != null)
        Text(
          error,
          style: skin.typography.body.copyWith(color: tokens.negative),
        ),
      if (item?.readOnlyReason case final reason?)
        Text(reason, style: skin.typography.body.copyWith(color: tokens.ink)),
      if (item?.description case final description?)
        Text(
          description,
          style: skin.typography.body.copyWith(color: tokens.ink),
        ),
    ];
    return DecoratedBox(
      key: const ValueKey('property-description'),
      decoration: BoxDecoration(
        color: tokens.chrome,
        border: Border(
          left: const BorderSide(color: MillenniumColors.fieldLine),
          right: const BorderSide(color: MillenniumColors.fieldLine),
          bottom: const BorderSide(color: MillenniumColors.fieldLine),
          top: BorderSide(color: tokens.paper),
        ),
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: EraScrollbar(
            controller: _describe,
            axis: Axis.vertical,
            child: SingleChildScrollView(
              controller: _describe,
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: lines,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One property: the name cell and the value, or the open editor.
final class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.item,
    required this.columns,
    required this.selected,
    required this.active,
    required this.interactive,
    required this.editor,
    required this.onSelect,
    required this.onEdit,
    required this.onFollow,
    super.key,
  });

  final PropertyItem item;
  final _Columns columns;
  final bool selected;
  final bool active;
  final bool interactive;

  /// The open editor of this property, or null.
  final Widget? editor;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    final live = interactive && item.enabled;
    final lit = selected && active && live;
    final changed = item.was != null;
    final nameFill = !selected
        ? null
        : lit
        ? tokens.selWash
        : tokens.chrome;
    final name = Padding(
      key: ValueKey('property-name:${item.key}'),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Text(
        item.label,
        style: skin.typography.body.copyWith(
          color: lit
              ? tokens.selInk
              : live
              ? tokens.ink
              : tokens.muted,
          fontWeight: changed ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
    final value = KeyedSubtree(
      key: ValueKey('property-value:${item.key}'),
      child: editor ?? _value(context, skin),
    );
    final stacked = columns.stacked(item);
    final Widget cells = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: nameFill ?? MillenniumColors.clear,
                child: name,
              ),
              value,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: columns.label, child: name),
              const SizedBox(width: 1),
              Expanded(child: value),
            ],
          );
    final row = CustomPaint(
      painter: _RowPainter(
        label: stacked ? null : columns.label,
        nameFill: stacked ? null : nameFill,
        gutter: tokens.chrome,
        rule: tokens.rule,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: _gutter, bottom: 1),
        child: cells,
      ),
    );
    final text = _text;
    final hints = [
      ?item.error,
      ?item.readOnlyReason,
      if (!item.enabled) 'Unavailable',
    ];
    final action = !live
        ? null
        : item.editable
        ? onEdit
        : item.onFollow != null
        ? onFollow
        : onSelect;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: live ? onSelect : null,
      child: editor != null
          ? Semantics(
              container: true,
              explicitChildNodes: true,
              selected: selected,
              label: item.label,
              child: row,
            )
          : Semantics(
              container: true,
              excludeSemantics: true,
              label: item.label,
              value: changed ? '$text, was ${item.was}' : text,
              hint: hints.isEmpty ? null : hints.join('. '),
              selected: selected,
              enabled: live,
              readOnly: item.readOnly,
              link: item.onFollow != null,
              onTap: action,
              child: row,
            ),
    );
  }

  String get _text =>
      item.display ?? formatValue(item.kind, item.value, choices: item.choices);

  /// The closed value: plain, muted, a link, bold with "(was …)", or
  /// outlined in red with the caller's error.
  Widget _value(BuildContext context, LifeOSSkinData skin) {
    final tokens = skin.tokens;
    final live = interactive && item.enabled;
    final link = item.onFollow != null;
    final style =
        (item.kind.usesFigures && !link
                ? skin.typography.figure
                : skin.typography.body)
            .copyWith(
              color: !live || item.readOnly
                  ? tokens.muted
                  : link
                  ? MillenniumColors.link
                  : tokens.ink,
              fontWeight: item.was != null ? FontWeight.w700 : FontWeight.w400,
              decoration: link ? TextDecoration.underline : null,
              decorationColor: MillenniumColors.link,
            );
    Widget value = Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: RichText(
        textScaler: MediaQuery.textScalerOf(context),
        text: TextSpan(
          children: [
            TextSpan(text: _text, style: style),
            if (item.was case final was?)
              TextSpan(
                text: ' (was $was)',
                style: skin.typography.figure.copyWith(
                  color: tokens.muted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
    if (item.error != null) {
      value = DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: tokens.negative)),
        child: value,
      );
    }
    final VoidCallback? tap = !live
        ? null
        : item.editable
        ? onEdit
        : link
        ? onFollow
        : null;
    if (tap == null) return value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: value,
      ),
    );
  }
}

/// Paints a property row's chrome at its final size, so no cell needs its
/// neighbour's height: the face-grey gutter, the selected name's fill, the
/// rule between name and value, and the rule under the row.
final class _RowPainter extends CustomPainter {
  const _RowPainter({
    required this.label,
    required this.nameFill,
    required this.gutter,
    required this.rule,
  });

  /// The name column's width; null when the label is stacked.
  final double? label;
  final Color? nameFill;
  final Color gutter;
  final Color rule;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _gutter, size.height),
      Paint()..color = gutter,
    );
    final rulePaint = Paint()..color = rule;
    if (label case final label?) {
      if (nameFill case final fill?) {
        canvas.drawRect(
          Rect.fromLTWH(_gutter, 0, label, size.height - 1),
          Paint()..color = fill,
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(_gutter + label, 0, 1, size.height),
        rulePaint,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(_gutter, size.height - 1, size.width - _gutter, 1),
      rulePaint,
    );
  }

  @override
  bool shouldRepaint(_RowPainter old) =>
      old.label != label ||
      old.nameFill != nameFill ||
      old.gutter != gutter ||
      old.rule != rule;
}

/// A category heading: a boxed plus or minus in the gutter and the name in
/// bold on the face colour. A click collapses or expands it.
final class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.open,
    required this.enabled,
    required this.onToggle,
    super.key,
  });

  final String category;
  final bool open;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final tokens = skin.tokens;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: category,
      expanded: open,
      enabled: enabled,
      onTap: enabled ? onToggle : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onToggle : null,
          child: CustomPaint(
            foregroundPainter: _ExpanderPainter(
              open: open,
              line: MillenniumColors.fieldLine,
              fill: tokens.paper,
              sign: enabled ? tokens.ink : tokens.muted,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.chrome,
                border: Border(bottom: BorderSide(color: tokens.chromeLine)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_gutter + 3, 2, 4, 1),
                child: Text(
                  category,
                  style: skin.typography.strong.copyWith(
                    color: enabled ? tokens.ink : tokens.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 9 px plus/minus box of a category, centred in the gutter.
final class _ExpanderPainter extends CustomPainter {
  const _ExpanderPainter({
    required this.open,
    required this.line,
    required this.fill,
    required this.sign,
  });

  final bool open;
  final Color line;
  final Color fill;
  final Color sign;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(
      2.5,
      ((size.height - 9) / 2).floorToDouble() + 0.5,
      9,
      9,
    );
    canvas
      ..drawRect(box, Paint()..color = fill)
      ..drawRect(
        box,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    final ink = Paint()..color = sign;
    canvas.drawRect(
      Rect.fromCenter(center: box.center, width: 5, height: 1),
      ink,
    );
    if (!open) {
      canvas.drawRect(
        Rect.fromCenter(center: box.center, width: 1, height: 5),
        ink,
      );
    }
  }

  @override
  bool shouldRepaint(_ExpanderPainter old) =>
      old.open != open ||
      old.line != line ||
      old.fill != fill ||
      old.sign != sign;
}

/// A flat toolbar key choosing the order, lit while it is the current one
/// and raised on hover. Mouse only: it takes no focus.
final class _OrderKey extends StatefulWidget {
  const _OrderKey({
    required this.order,
    required this.on,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final PropertyGridOrder order;
  final bool on;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<_OrderKey> createState() => _OrderKeyState();
}

final class _OrderKeyState extends State<_OrderKey> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = LifeOSSkinScope.of(context).tokens;
    final label = switch (widget.order) {
      PropertyGridOrder.categorized => 'Categorized',
      PropertyGridOrder.alphabetical => 'Alphabetical',
    };
    final enabled = widget.enabled;
    final BoxDecoration decoration;
    if (widget.on) {
      decoration = BoxDecoration(
        color: enabled ? MillenniumColors.paneBody : tokens.chrome,
        border: Border.all(color: enabled ? tokens.selWash : tokens.chromeLine),
      );
    } else if (_hover && enabled) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.paper, tokens.chrome],
        ),
        border: Border.all(color: tokens.chromeLine),
      );
    } else {
      decoration = BoxDecoration(
        border: Border.all(color: MillenniumColors.clear),
      );
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: label,
      selected: widget.on,
      enabled: enabled,
      onTap: enabled ? widget.onPressed : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? widget.onPressed : null,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: Container(
              height: 22,
              constraints: const BoxConstraints(minWidth: 23),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: decoration,
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size.square(16),
                painter: _OrderIconPainter(widget.order, enabled: enabled),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Categorized and A–Z icons of the Properties window, painted.
final class _OrderIconPainter extends CustomPainter {
  const _OrderIconPainter(this.order, {required this.enabled});

  final PropertyGridOrder order;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    const grey = MillenniumColors.sunkenEdge;
    Paint stroke(Color color, double width) => Paint()
      ..color = enabled ? color : grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round;
    switch (order) {
      case PropertyGridOrder.categorized:
        const heading = Rect.fromLTWH(2, 2.5, 12, 3);
        canvas
          ..drawRect(heading, Paint()..color = LifeOSTokens.millennium.chrome)
          ..drawRect(heading, stroke(grey, 1));
        for (final y in [8.0, 10.5, 13.0]) {
          canvas
            ..drawLine(
              Offset(5, y),
              Offset(14, y),
              stroke(MillenniumColors.link, 1.2),
            )
            ..drawLine(Offset(2.5, y), Offset(3.5, y), stroke(grey, 1));
        }
      case PropertyGridOrder.alphabetical:
        final letters = stroke(MillenniumColors.keyLine, 1.2);
        canvas
          ..drawPath(
            Path()
              ..moveTo(2.5, 9)
              ..lineTo(4.5, 2.5)
              ..lineTo(6.5, 9)
              ..moveTo(3.2, 6.8)
              ..lineTo(5.8, 6.8),
            letters,
          )
          ..drawPath(
            Path()
              ..moveTo(2.5, 10.5)
              ..lineTo(6.5, 10.5)
              ..lineTo(2.5, 14.5)
              ..lineTo(6.5, 14.5),
            letters,
          )
          ..drawLine(
            const Offset(11, 2.5),
            const Offset(11, 11),
            stroke(MillenniumColors.infoGlyph, 1.4),
          )
          ..drawPath(
            Path()
              ..moveTo(8.5, 10.5)
              ..lineTo(11, 14)
              ..lineTo(13.5, 10.5)
              ..close(),
            Paint()..color = enabled ? MillenniumColors.infoGlyph : grey,
          );
    }
  }

  @override
  bool shouldRepaint(_OrderIconPainter old) =>
      old.order != order || old.enabled != enabled;
}
