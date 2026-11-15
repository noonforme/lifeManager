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
        // The shell lays out down to 800 × 600, so a 1366 × 768 laptop
        // with a panel still fits it.
        minimumSize: Size(800, 600),
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

  /// Names the window, "Shifts - LifeOS".
  Future<void> setTitle(String title) => windowManager.setTitle(title);

  /// Closes the window, ending the app (File › Quit).
  Future<void> close() => windowManager.close();
}
