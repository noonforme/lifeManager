import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/window_close_guard.dart';

final class _FakeWindow implements WindowCloseApi {
  _FakeWindow(this.log);

  final List<String> log;
  bool failDestroy = false;
  Future<void> Function()? closeButton;

  @override
  Future<void> interceptClose(Future<void> Function() onCloseRequested) async {
    log.add('intercept');
    closeButton = onCloseRequested;
  }

  @override
  Future<void> releaseClose(Future<void> Function() onCloseRequested) async {
    log.add('release');
    if (closeButton == onCloseRequested) closeButton = null;
  }

  @override
  Future<void> destroy() async {
    if (failDestroy) throw StateError('destroy failed');
    log.add('destroy');
  }
}

void main() {
  late List<String> log;
  late _FakeWindow window;

  setUp(() {
    log = [];
    window = _FakeWindow(log);
  });

  WindowCloseGuard guard(Future<bool> Function() mayClose) => WindowCloseGuard(
    api: window,
    mayClose: mayClose,
    beforeClose: () async => log.add('remember route, close database'),
  );

  test('attaching takes over the close button', () async {
    await guard(() async => true).attach();
    expect(log, ['intercept']);
    expect(window.closeButton, isNotNull);
  });

  test('detaching gives the close button back', () async {
    final closing = guard(() async => true);
    await closing.attach();
    await closing.detach();
    expect(log, ['intercept', 'release']);
    expect(window.closeButton, isNull);
  });

  test('a detached guard neither asks nor closes', () async {
    var asks = 0;
    final closing = guard(() async {
      asks++;
      return true;
    });
    await closing.attach();
    final button = window.closeButton!;
    await closing.detach();
    await button();
    await closing.requestClose();
    expect(asks, 0);
    expect(log, ['intercept', 'release']);
  });

  test(
    'the close button closes once the guard agrees, after the clean-up',
    () async {
      await guard(() async => true).attach();
      await window.closeButton!();
      expect(log, ['intercept', 'remember route, close database', 'destroy']);
    },
  );

  test(
    'when the guard refuses the window stays and may be asked again',
    () async {
      var asks = 0;
      final closing = guard(() async => ++asks > 1);
      await closing.requestClose();
      expect(log, isEmpty);
      await closing.requestClose();
      expect(asks, 2);
      expect(log, ['remember route, close database', 'destroy']);
    },
  );

  test('a clean-up that throws is reported and the window still closes '
      'once', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    var cleanUps = 0;
    final closing = WindowCloseGuard(
      api: window,
      mayClose: () async => true,
      beforeClose: () async {
        cleanUps++;
        throw StateError('route store unwritable');
      },
    );
    await closing.requestClose();
    await closing.requestClose();
    expect(reported.single.exception, isA<StateError>());
    expect(cleanUps, 1);
    expect(log, ['destroy']);
  });

  test('a failed mayClose or destroy is reported and can be retried', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    var failDecision = true;
    final closing = guard(() async {
      if (failDecision) throw StateError('decision failed');
      return true;
    });
    await closing.requestClose();
    expect(log, isEmpty);
    failDecision = false;
    window.failDestroy = true;
    await closing.requestClose();
    expect(reported, hasLength(2));
    window.failDestroy = false;
    await closing.requestClose();
    expect(log.where((entry) => entry == 'destroy'), hasLength(1));
  });

  test('repeated requests while deciding join the first', () async {
    final decision = Completer<bool>();
    var asks = 0;
    final closing = guard(() {
      asks++;
      return decision.future;
    });
    final first = closing.requestClose();
    final second = closing.requestClose();
    decision.complete(true);
    await Future.wait([first, second]);
    expect(asks, 1);
    expect(log.where((entry) => entry == 'destroy'), hasLength(1));
  });
}
