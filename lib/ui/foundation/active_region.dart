import 'package:flutter/widgets.dart';

/// Whether a selection is in the window's active region (DESIGN.md:
/// selection is blue in the active region, face grey in an inactive one).
/// [AppFrame] marks each of its panes; [DataGrid], [TreeView],
/// [PropertyGrid] and [DayCalendar] light their selection only where both
/// their own `active` and the region's hold. Outside any mark every region
/// is active.
abstract final class ActiveRegion {
  /// [child] marked as in the active region, or not.
  static Widget mark({required bool active, required Widget child}) =>
      _ActiveRegionScope(active: active, child: child);

  /// Whether [context] is in the active region; true outside any mark.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ActiveRegionScope>()
          ?.active ??
      true;
}

final class _ActiveRegionScope extends InheritedWidget {
  const _ActiveRegionScope({required this.active, required super.child});

  final bool active;

  @override
  bool updateShouldNotify(_ActiveRegionScope oldWidget) =>
      active != oldWidget.active;
}
