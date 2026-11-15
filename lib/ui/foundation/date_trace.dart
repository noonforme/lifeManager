import 'dart:io';
import 'dart:ui' show FrameTiming;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// Fixed diagnostic vocabulary. Never add entered values, field labels,
/// key labels, focus debug labels or pointer target text to the trace.
enum DateTraceEvent {
  boxCreated,
  boxDisposed,
  valueChanged,
  calendarOpened,
  calendarClosed,
  calendarFocusRequested,
  dayPicked,
  changeSent,
  boxFocusChanged,
  partSelected,
  checkToggled,
  boxTapped,
  keyPressed,
  anchorLaidOut,
  calendarCreated,
  calendarDisposed,
  calendarSelectionChanged,
  calendarFocusChanged,
  cursorMoved,
  pointerDown,
  pointerUp,
  pointerCancel,
  pointerEnter,
  pointerExit,
  pointerAdded,
  pointerRemoved,
  pointerScroll,
  pointerOther,
  frameTiming,
  lifecycleChanged,
  focusChanged,
}

/// Off by default; LIFEOS_TRACE_DATES=1 enables event order only.
/// The typed sink cannot accept application data or free-form messages.
DateTrace? dateTrace = DateTrace.fromEnvironment(Platform.environment);

final class DateTrace {
  DateTrace(File file, {bool hooks = true})
    : _out = (file..parent.createSync(recursive: true)).openSync(
        mode: FileMode.append,
      ) {
    if (hooks) _hook();
  }

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

  void log(DateTraceEvent event) {
    if (_closed) return;
    _out.writeStringSync(
      '${DateTime.now().millisecondsSinceEpoch} ${event.name}\n',
    );
  }

  static DateTraceEvent pointer(PointerEvent event) => switch (event) {
    PointerDownEvent() => DateTraceEvent.pointerDown,
    PointerUpEvent() => DateTraceEvent.pointerUp,
    PointerCancelEvent() => DateTraceEvent.pointerCancel,
    PointerEnterEvent() => DateTraceEvent.pointerEnter,
    PointerExitEvent() => DateTraceEvent.pointerExit,
    PointerAddedEvent() => DateTraceEvent.pointerAdded,
    PointerRemovedEvent() => DateTraceEvent.pointerRemoved,
    PointerScrollEvent() => DateTraceEvent.pointerScroll,
    _ => DateTraceEvent.pointerOther,
  };

  void frames(List<FrameTiming> timings) {
    for (final _ in timings) {
      log(DateTraceEvent.frameTiming);
    }
  }

  void _hook() {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_route);
    _lifecycle = AppLifecycleListener(
      onStateChange: (_) => log(DateTraceEvent.lifecycleChanged),
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
      log(pointer(event));
    }
  }

  void _focusMoved() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == _focus) return;
    _focus = focus;
    log(DateTraceEvent.focusChanged);
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

/// Names are retained for caller compatibility, but never recorded.
Widget traceTarget(
  String name,
  String target,
  Widget child, {
  String prefix = '',
}) {
  final trace = dateTrace;
  if (trace == null) return child;
  void log(PointerEvent event) => trace.log(DateTrace.pointer(event));
  return Listener(
    onPointerDown: log,
    onPointerUp: log,
    onPointerCancel: log,
    child: child,
  );
}
