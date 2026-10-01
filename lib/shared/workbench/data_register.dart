import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lifeos_theme.dart';

final class RegisterColumn<T> {
  const RegisterColumn({
    required this.label,
    required this.width,
    required this.value,
    this.numeric = false,
  });

  final String label;
  final double width;
  final String Function(T) value;
  final bool numeric;
}

final class DataRegister<T> extends StatefulWidget {
  const DataRegister({
    required this.label,
    required this.rows,
    required this.columns,
    required this.rowId,
    required this.rowLabel,
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final String label;
  final List<T> rows;
  final List<RegisterColumn<T>> columns;
  final String Function(T) rowId;
  final String Function(T) rowLabel;
  final String? selectedId;
  final ValueChanged<T> onSelect;

  @override
  State<DataRegister<T>> createState() => _DataRegisterState<T>();
}

final class _DataRegisterState<T> extends State<DataRegister<T>> {
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'Data register');
  int? _focusedIndex;

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DataRegister<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = _focusedIndex;
    if (index != null && index >= widget.rows.length) {
      _focusedIndex = widget.rows.isEmpty ? null : widget.rows.length - 1;
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || widget.rows.isEmpty) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusedIndex = _focusedIndex == null
            ? 0
            : (_focusedIndex! + 1).clamp(0, widget.rows.length - 1);
      });
      return;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusedIndex = _focusedIndex == null
            ? widget.rows.length - 1
            : (_focusedIndex! - 1).clamp(0, widget.rows.length - 1);
      });
      return;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) &&
        _focusedIndex != null) {
      widget.onSelect(widget.rows[_focusedIndex!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.columns.fold<double>(
      0,
      (sum, item) => sum + item.width,
    );
    return KeyboardListener(
      autofocus: true,
      focusNode: _keyboardFocus,
      onKeyEvent: _handleKey,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              explicitChildNodes: true,
              label: '${widget.label}, horizontally scrollable',
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header<T>(columns: widget.columns),
                      for (var index = 0; index < widget.rows.length; index++)
                        _RegisterRow<T>(
                          row: widget.rows[index],
                          columns: widget.columns,
                          label: widget.rowLabel(widget.rows[index]),
                          selected:
                              widget.rowId(widget.rows[index]) ==
                              widget.selectedId,
                          focused: index == _focusedIndex,
                          onSelect: () => widget.onSelect(widget.rows[index]),
                        ),
                    ],
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

final class _Header<T> extends StatelessWidget {
  const _Header({required this.columns});

  final List<RegisterColumn<T>> columns;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LifeOSColors.rail,
        border: Border(bottom: BorderSide(color: LifeOSColors.boundary)),
      ),
      child: Row(
        children: [
          for (final column in columns)
            SizedBox(
              width: column.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  column.label,
                  textAlign: column.numeric ? TextAlign.right : TextAlign.left,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _RegisterRow<T> extends StatelessWidget {
  const _RegisterRow({
    required this.row,
    required this.columns,
    required this.label,
    required this.selected,
    required this.focused,
    required this.onSelect,
  });

  final T row;
  final List<RegisterColumn<T>> columns;
  final String label;
  final bool selected;
  final bool focused;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      focused: focused,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onSelect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? LifeOSColors.selectionWash : LifeOSColors.surface,
            border: Border(
              left: BorderSide(
                color: focused ? LifeOSColors.focus : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: LifeOSColors.boundary),
            ),
          ),
          child: Row(
            children: [
              for (final column in columns)
                SizedBox(
                  width: column.width,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      column.value(row),
                      textAlign: column.numeric
                          ? TextAlign.right
                          : TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LifeOSColors.ink,
                        fontFeatures: column.numeric
                            ? const [FontFeature.tabularFigures()]
                            : null,
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
