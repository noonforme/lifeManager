import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

abstract interface class DesktopWindowService {
  Future<void> prepare();
  Future<void> show();
}

final class WindowManagerDesktopWindowService implements DesktopWindowService {
  @override
  Future<void> prepare() async {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        title: 'LifeOS',
        minimumSize: Size(1280, 760),
        size: Size(1440, 900),
        center: true,
      ),
    );
  }

  @override
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Closes the window, ending the app (File › Quit).
  Future<void> close() => windowManager.close();
}
