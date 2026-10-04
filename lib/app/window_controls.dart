import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../shared/shell/era_window_frame.dart';

/// The painted frame's requests, carried out by window_manager.
final class WindowManagerControls
    with WindowListener
    implements WindowControls {
  WindowManagerControls() {
    windowManager.addListener(this);
    _sync();
  }

  final _state = ValueNotifier(const WindowFrameState());

  @override
  ValueListenable<WindowFrameState> get state => _state;

  Future<void> _sync() async {
    _state.value = WindowFrameState(
      maximized: await windowManager.isMaximized(),
      active: await windowManager.isFocused(),
    );
  }

  @override
  void onWindowMaximize() => _sync();

  @override
  void onWindowUnmaximize() => _sync();

  @override
  void onWindowFocus() => _sync();

  @override
  void onWindowBlur() => _sync();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async => await windowManager.isMaximized()
      ? windowManager.unmaximize()
      : windowManager.maximize();

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> startResizing(WindowEdge edge) =>
      windowManager.startResizing(switch (edge) {
        WindowEdge.top => ResizeEdge.top,
        WindowEdge.bottom => ResizeEdge.bottom,
        WindowEdge.left => ResizeEdge.left,
        WindowEdge.right => ResizeEdge.right,
        WindowEdge.topLeft => ResizeEdge.topLeft,
        WindowEdge.topRight => ResizeEdge.topRight,
        WindowEdge.bottomLeft => ResizeEdge.bottomLeft,
        WindowEdge.bottomRight => ResizeEdge.bottomRight,
      });

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);
}
