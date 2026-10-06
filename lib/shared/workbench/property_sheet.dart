import 'package:flutter/widgets.dart';

/// Applies a sheet's edits; true when they were saved.
typedef ApplySheet = Future<bool> Function();

/// The edits on an open property sheet, for its **OK**, **Cancel** and
/// **Apply** keys. Editable content attaches how to save itself and says
/// when a field has changed; read-only content attaches nothing.
final class PropertySheetController extends ChangeNotifier {
  ApplySheet? _apply;
  bool _dirty = false;
  bool _applying = false;

  /// A field has changed since the sheet opened or was last applied.
  bool get dirty => _dirty;

  /// A save is under way; the keys wait for it.
  bool get applying => _applying;

  void attach({required ApplySheet apply}) => _apply = apply;

  void detach(ApplySheet apply) {
    if (_apply != apply) return;
    _apply = null;
    markDirty(false);
  }

  void markDirty(bool dirty) {
    if (_dirty == dirty) return;
    _dirty = dirty;
    notifyListeners();
  }

  /// Saves when there is something to save. True when there was nothing to
  /// save or the save went through; false keeps the sheet open.
  Future<bool> apply() async {
    final apply = _apply;
    if (!_dirty || apply == null || _applying) return !_applying;
    _applying = true;
    notifyListeners();
    final saved = await apply();
    _applying = false;
    if (saved) _dirty = false;
    notifyListeners();
    return saved;
  }
}

/// Gives a sheet's content its [PropertySheetController].
final class PropertySheetScope
    extends InheritedNotifier<PropertySheetController> {
  const PropertySheetScope({
    required PropertySheetController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The open sheet. A form reading it re-attaches when the sheet changes.
  static PropertySheetController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PropertySheetScope>()
      ?.notifier;
}
