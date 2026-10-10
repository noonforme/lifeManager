import 'package:flutter/widgets.dart';

import '../../core/explain/explanation.dart';

/// The cell under the register cursor, as the formula bar shows it.
@immutable
final class CellSelection {
  const CellSelection({
    required this.owner,
    required this.reference,
    required this.columnLabel,
    required this.display,
    this.explanation,
  });

  /// The register that published this selection.
  final Object owner;

  /// Spreadsheet-style reference such as "D4".
  final String reference;
  final String columnLabel;

  /// The cell's value as displayed.
  final String display;

  /// How a derived value was worked out. Null for a recorded fact.
  final Explanation? explanation;

  bool get isDerived => explanation != null;
}

/// Holds the current cell selection for the whole window.
final class CellSelectionController extends ValueNotifier<CellSelection?> {
  CellSelectionController() : super(null);

  bool _disposed = false;

  /// Clears the selection only if [owner] published it, so one register
  /// leaving does not wipe another's selection. A register clears after its
  /// last frame, which may come after the window has disposed this
  /// controller; then there is nothing left to clear.
  void clearFrom(Object owner) {
    if (_disposed) return;
    if (value?.owner == owner) value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Shares the cell selection between registers and the formula bar.
final class CellSelectionScope
    extends InheritedNotifier<CellSelectionController> {
  const CellSelectionScope({
    required CellSelectionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static CellSelectionController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CellSelectionScope>()
      ?.notifier;

  /// Reads the controller without depending on its changes.
  static CellSelectionController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CellSelectionScope>()?.notifier;
}
