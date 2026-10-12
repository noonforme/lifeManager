import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/era_icons.dart';
import '../foundation/lifeos_skin.dart';
import 'era_controls.dart';
import 'era_editor_host.dart';
import 'era_form.dart';

/// One row of an era combo list.
@immutable
final class EraComboItem<T> {
  const EraComboItem(
    this.value,
    this.label, {
    this.icon,
    this.depth = 0,
    this.muted = false,
    this.command = false,
  });

  final T value;
  final String label;
  final EraIconKind? icon;

  /// Indent steps, for a tree such as the Address list.
  final int depth;

  /// Grey text, for a place that is not built yet; it can still be chosen.
  final bool muted;

  /// A row that does something ("Date range…") rather than naming a value:
  /// Up and Down on the closed box never step onto it.
  final bool command;
}

/// An era drop-down list combo box: the value in a white box beside the
/// blue arrow. Its list drops directly below, at least as wide as the box,
/// with the current value lit; the light follows the pointer and the arrow
/// keys. Up and Down on the closed box step the value, as in the era;
/// Enter, Space, Alt+Down or F4 open the list, Esc or a click outside close
/// it.
///
/// Inside an [EraEditorHostScope] (database shell spec 4.6) the list opens
/// and picks by mouse only: its rows never take focus, which stays on the
/// box; the box neither opens nor steps from the keyboard; Enter, Tab and
/// Esc close an open list without taking its lit row and reach the host;
/// and a read-only [EraFormScope] greys and locks the box.
final class EraCombo<T> extends StatefulWidget {
  const EraCombo({
    required this.items,
    required this.value,
    required this.onSelected,
    required this.semanticLabel,
    this.semanticValue,
    this.face,
    this.minWidth = 60,
    this.focusNode,
    super.key,
  });

  final List<EraComboItem<T>> items;
  final T? value;
  final ValueChanged<T> onSelected;
  final String semanticLabel;

  /// Announced after [semanticLabel]; the current row's label by default.
  final String? semanticValue;

  /// Draws the closed box; [focused] lights its text, and
  /// [EraCombo.enabledOf] tells whether the box is locked. Defaults to an
  /// [EraComboFace] showing the current row's label.
  final Widget Function(BuildContext context, bool focused)? face;
  final double minWidth;

  /// The closed box's focus node, for a host that moves the keyboard to
  /// it; the combo owns one when null.
  final FocusNode? focusNode;

  /// Whether the combo whose [face] [context] builds takes input: false
  /// for a hosted combo in a read-only [EraFormScope], so a custom face can
  /// grey as the default one does. True outside a combo.
  static bool enabledOf(BuildContext context) =>
      context.findAncestorStateOfType<EraComboState<Object?>>()?._enabled ??
      true;

  @override
  State<EraCombo<T>> createState() => EraComboState<T>();
}

/// Lets the shell open or focus a combo from the keyboard (F4, Alt+D).
final class EraComboState<T> extends State<EraCombo<T>> {
  final _controller = MenuController();
  final _ownFace = FocusNode(debugLabel: 'EraCombo');
  FocusNode get _faceNode => widget.focusNode ?? _ownFace;
  final _faceKey = GlobalKey();
  List<FocusNode> _rows = const [];
  double _width = 0;
  bool _focused = false;

  /// The row under the pointer in a hosted list, whose rows light by
  /// hover alone; null lights the current row instead.
  int? _hovered;

  @override
  void initState() {
    super.initState();
    _rows = _nodesFor(widget.items);
  }

  @override
  void didUpdateWidget(EraCombo<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      final old = _rows;
      _rows = _nodesFor(widget.items);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in old) {
          node.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    _ownFace.dispose();
    for (final node in _rows) {
      node.dispose();
    }
    super.dispose();
  }

  List<FocusNode> _nodesFor(List<EraComboItem<T>> items) => [
    for (final item in items) FocusNode(debugLabel: item.label),
  ];

  int get _current =>
      widget.items.indexWhere((item) => item.value == widget.value);

  bool get _hosted => EraEditorHostScope.maybeOf(context) != null;

  /// False only for a hosted combo in a read-only form; a legacy combo
  /// keeps working there, as it always has.
  bool get _enabled => !_hosted || EraFormScope.enabledOf(context);

  /// Puts focus in the closed box.
  void focus() => _faceNode.requestFocus();

  /// Drops the list, with focus on the current row.
  void open() => _open();

  void _open() {
    if (_controller.isOpen || widget.items.isEmpty || !_enabled) return;
    _faceNode.requestFocus();
    final box = _faceKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() => _width = box?.size.width ?? 0);
    _controller.open();
    if (_hosted) {
      setState(() => _hovered = null);
      return;
    }
    // The current row starts lit, so the arrow keys move on from it.
    final index = _current < 0 ? 0 : _current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isOpen) _rows[index].requestFocus();
    });
  }

  void _toggle() => _controller.isOpen ? _controller.close() : _open();

  /// Moves the closed box's value to the next row that names one.
  void _step(int direction) {
    var index = _current;
    while (true) {
      index += direction;
      if (index < 0 || index >= widget.items.length) return;
      if (!widget.items[index].command) break;
    }
    widget.onSelected(widget.items[index].value);
  }

  KeyEventResult _onFaceKey(FocusNode node, KeyEvent event) {
    if (_hosted) {
      if (_controller.isOpen && EraEditorHostScope.editorKeyOf(event) != null) {
        _controller.close();
      }
      return EraEditorHostScope.handleKey(context, event);
    }
    if (event is KeyUpEvent || _controller.isOpen) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final alt = HardwareKeyboard.instance.isAltPressed;
    if ((key == LogicalKeyboardKey.arrowDown && alt) ||
        key == LogicalKeyboardKey.f4 ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _open();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final skin = LifeOSSkinScope.of(context);
    final t = skin.tokens;
    final current = _current;
    final label = current < 0 ? '' : widget.items[current].label;
    final hosted = EraEditorHostScope.watch(context) != null;
    final enabled = !hosted || EraFormScope.enabledOf(context);
    // A hosted list is a popup choice: its rows light under the pointer
    // but never take focus from the box.
    Widget row(Widget button) => hosted ? ExcludeFocus(child: button) : button;
    return MenuAnchor(
      controller: _controller,
      consumeOutsideTap: true,
      // Lets the list take the box's width as its minimum; unconstrained,
      // it would shrink to its longest row.
      crossAxisUnconstrained: false,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.paper),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: t.ink)),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(_width, 0)),
      ),
      menuChildren: [
        for (final (index, item) in widget.items.indexed)
          row(
            MenuItemButton(
              focusNode: _rows[index],
              style: _rowStyle(
                skin,
                item,
                alwaysLit: hosted && (_hovered ?? current) == index,
              ),
              onHover: hosted
                  ? (hovering) => setState(() {
                      if (hovering) {
                        _hovered = index;
                      } else if (_hovered == index) {
                        _hovered = null;
                      }
                    })
                  : null,
              onPressed: () => widget.onSelected(item.value),
              child: Padding(
                padding: EdgeInsets.only(left: item.depth * 16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.icon case final icon?) ...[
                      EraIcon(icon, disabled: item.muted),
                      const SizedBox(width: 4),
                    ],
                    Text(item.label),
                  ],
                ),
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        button: true,
        enabled: enabled ? null : false,
        label: '${widget.semanticLabel}, ${widget.semanticValue ?? label}',
        onTap: enabled ? _toggle : null,
        excludeSemantics: true,
        child: Focus(
          focusNode: _faceNode,
          canRequestFocus: enabled ? null : false,
          onKeyEvent: _onFaceKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggle : null,
            child: KeyedSubtree(
              key: _faceKey,
              child:
                  widget.face?.call(context, _focused) ??
                  EraComboFace(
                    value: label,
                    minWidth: widget.minWidth,
                    focused: _focused,
                    enabled: enabled,
                    // A hosted box fills its cell or field with the arrow
                    // at its right edge.
                    fill: hosted,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  /// A row's look; [alwaysLit] lights it whatever its state, as a hosted
  /// list lights the hovered or current row without focus.
  ButtonStyle _rowStyle(
    LifeOSSkinData skin,
    EraComboItem<T> item, {
    bool alwaysLit = false,
  }) {
    final t = skin.tokens;
    bool lit(Set<WidgetState> states) =>
        alwaysLit ||
        states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused);
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll(skin.typography.body),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => lit(states)
            ? t.selInk
            : item.muted
            ? t.muted
            : t.ink,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => lit(states) ? t.selWash : Colors.transparent,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
      animationDuration: Duration.zero,
      // A list box row, as tall as a details-list row.
      minimumSize: const WidgetStatePropertyAll(Size(0, 20)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
  }
}

/// The closed era list box's text: lit in selection blue while the box
/// has focus, for a face its owner draws.
TextStyle eraComboText(LifeOSSkinData skin, {required bool focused}) =>
    skin.typography.body.copyWith(
      color: focused ? skin.tokens.selInk : skin.tokens.ink,
      backgroundColor: focused ? skin.tokens.selWash : null,
    );
