import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// The trace in force for the era date boxes and their calendars; null,
/// the default, traces nothing. LIFEOS_TRACE_DATES=1 turns it on for a
/// run (bead lifeManager-7qj: a real mouse misbehaves where tests do not).
///
/// Call sites write `dateTrace?.log(...)`: while it is null the arguments
/// are never built, so the trace costs nothing when off.
DateTrace? dateTrace = DateTrace.fromEnvironment(Platform.environment);

/// One line per event, `<ms since epoch> [<field>] <event>`, appended to
/// ~/.local/share/lifeos/date-trace.log as it happens, so a run that hangs
/// or is killed keeps every line before it.
final class DateTrace {
  /// Appends to [file], creating its folders. With [hooks], it also logs
  /// every pointer press, release and cancel in the app, the app's
  /// lifecycle and each move of the primary focus, under "[app]".
  DateTrace(File file, {bool hooks = true})
    : _out = (file..parent.createSync(recursive: true)).openSync(
        mode: FileMode.append,
      ) {
    if (hooks) _hook();
  }

  /// On only when [environment] has LIFEOS_TRACE_DATES=1 and a HOME.
  static DateTrace? fromEnvironment(
    Map<String, String> environment, {
    bool hooks = true,
  }) {
    final home = environment['HOME'];
    if (environment['LIFEOS_TRACE_DATES'] != '1' || home == null) return null;
    return DateTrace(
      File(p.join(home, '.local', 'share', 'lifeos', 'date-trace.log')),
      hooks: hooks,
    );
  }

  final RandomAccessFile _out;
  AppLifecycleListener? _lifecycle;
  FocusNode? _focus;
  bool _closed = false;

  void log(String field, String event) {
    if (_closed) return;
    _out.writeStringSync(
      '${DateTime.now().millisecondsSinceEpoch} [$field] $event\n',
    );
  }

  /// "down mouse buttons=1 at (12.0, 30.5)": a pointer event, said briefly.
  static String pointer(PointerEvent event, {Offset? local}) {
    final kind = switch (event) {
      PointerDownEvent() => 'down',
      PointerUpEvent() => 'up',
      PointerCancelEvent() => 'cancel',
      PointerEnterEvent() => 'enter',
      PointerExitEvent() => 'exit',
      PointerAddedEvent() => 'added',
      PointerRemovedEvent() => 'removed',
      PointerScrollEvent() => 'scroll',
      _ => event.runtimeType.toString(),
    };
    final at = local == null ? '' : ' local ${_offset(local)}';
    return 'pointer $kind ${event.kind.name} buttons=${event.buttons}'
        ' #${event.pointer} global ${_offset(event.position)}$at';
  }

  /// The frame timings the engine reports, while a calendar is open.
  void frames(String field, List<FrameTiming> timings) {
    for (final timing in timings) {
      log(
        field,
        'frame build ${timing.buildDuration.inMicroseconds} µs'
        ' raster ${timing.rasterDuration.inMicroseconds} µs'
        ' total ${timing.totalSpan.inMicroseconds} µs',
      );
    }
  }

  static String _offset(Offset offset) =>
      '(${offset.dx.toStringAsFixed(1)}, ${offset.dy.toStringAsFixed(1)})';

  void _hook() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => log('app', 'lifecycle $state'),
    );
    FocusManager.instance.addListener(_focusMoved);
  }

  void _route(PointerEvent event) {
    if (event is PointerDownEvent ||
        event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerAddedEvent ||
        event is PointerRemovedEvent ||
        event is PointerScrollEvent) {
      log('app', pointer(event));
    }
  }

  void _focusMoved() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == _focus) return;
    _focus = focus;
    log('app', 'primary focus ${focus?.debugLabel ?? focus?.runtimeType}');
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_lifecycle case final lifecycle?) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_route);
      lifecycle.dispose();
      FocusManager.instance.removeListener(_focusMoved);
    }
    _out.closeSync();
  }
}

/// Logs [child]'s pointer presses, releases and cancels as
/// `[name] <prefix>pointer … on <target>` while the trace is on; [child]
/// itself otherwise.
Widget traceTarget(
  String name,
  String target,
  Widget child, {
  String prefix = '',
}) {
  final trace = dateTrace;
  if (trace == null) return child;
  void log(PointerEvent event) => trace.log(
    name,
    '$prefix${DateTrace.pointer(event, local: event.localPosition)} on $target',
  );
  return Listener(
    onPointerDown: log,
    onPointerUp: log,
    onPointerCancel: log,
    child: child,
  );
}
