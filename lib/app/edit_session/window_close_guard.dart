import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// The window's close button, as the guard needs it.
abstract interface class WindowCloseApi {
  /// From now on a close request calls [onCloseRequested] and leaves the
  /// window open.
  Future<void> interceptClose(Future<void> Function() onCloseRequested);

  /// Gives the close button back if [onCloseRequested] still holds it;
  /// one that another has since taken stays theirs.
  Future<void> releaseClose(Future<void> Function() onCloseRequested);

  /// Closes the window for good.
  Future<void> destroy();
}

/// [WindowCloseApi] over `window_manager`: prevent-close plus a listener.
/// There is one window, so every instance shares its one interception.
final class WindowManagerCloseApi
    with WindowListener
    implements WindowCloseApi {
  static Future<void> Function()? _onCloseRequested;
  static WindowManagerCloseApi? _listening;

  @override
  Future<void> interceptClose(Future<void> Function() onCloseRequested) async {
    _onCloseRequested = onCloseRequested;
    if (_listening == null) windowManager.addListener(_listening = this);
    await windowManager.setPreventClose(true);
  }

  @override
  Future<void> releaseClose(Future<void> Function() onCloseRequested) async {
    if (_onCloseRequested != onCloseRequested) return;
    _stopListening();
    await windowManager.setPreventClose(false);
  }

  static void _stopListening() {
    _onCloseRequested = null;
    if (_listening case final listening?) {
      windowManager.removeListener(listening);
    }
    _listening = null;
  }

  @override
  void onWindowClose() => unawaited(_onCloseRequested?.call());

  @override
  Future<void> destroy() async {
    await windowManager.destroy();
    _stopListening();
  }
}

/// Closing the application (database shell spec 4.8): the native close
/// button and File › Quit take the same path. The window closes only when
/// [mayClose] agrees; then [beforeClose] remembers the route and releases
/// resources, and the window is destroyed. Requests while one is deciding
/// join it, so they neither resubmit nor bypass the guard.
final class WindowCloseGuard {
  WindowCloseGuard({
    required this.api,
    required this.mayClose,
    this.beforeClose,
  });

  final WindowCloseApi api;

  /// Usually `LeaveCoordinator.quit`.
  final Future<bool> Function() mayClose;
  final Future<void> Function()? beforeClose;

  Future<void>? _closing;
  bool _detached = false;

  /// Takes over the window's close button.
  Future<void> attach() => api.interceptClose(requestClose);

  /// Gives the close button back for good, as when what [mayClose] asks
  /// is gone; later requests do nothing.
  Future<void> detach() {
    _detached = true;
    return api.releaseClose(requestClose);
  }

  /// Closes when the guard agrees; otherwise the window stays as it was.
  Future<void> requestClose() {
    if (_detached) return Future.value();
    if (_closing case final closing?) return closing;
    final done = Completer<void>();
    _closing = done.future;
    () async {
      var closed = false;
      try {
        if (await mayClose()) {
          // A failed clean-up is reported but never keeps the window open:
          // later requests would only fail it again.
          try {
            await beforeClose?.call();
          } catch (error, stack) {
            _report(error, stack);
          }
          await api.destroy();
          closed = true;
        }
      } catch (error, stack) {
        _report(error, stack);
      }
      // A window that is going keeps answering later requests with this
      // close; one that stays may be asked again.
      if (!closed) _closing = null;
      done.complete();
    }();
    return done.future;
  }

  void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'window close guard',
    ),
  );
}
