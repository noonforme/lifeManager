import 'dart:async';

import 'package:drift/drift.dart';

/// Storage a test makes unreadable at will: while [failing], every read
/// through the executor it intercepts throws. Writes still go through.
final class ReadGate extends QueryInterceptor {
  ReadGate({this.failing = false});

  bool failing;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (failing) throw StateError('Local storage cannot be read.');
    return executor.runSelect(statement, args);
  }
}

/// Storage a test slows at will: while [held], every read through the
/// executor it intercepts waits for [release].
final class ReadHold extends QueryInterceptor {
  Completer<void>? _held;

  bool get held => _held != null;

  /// From now on reads wait.
  void hold() => _held ??= Completer<void>();

  /// Lets the waiting reads, and later ones, through.
  void release() {
    _held?.complete();
    _held = null;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (_held case final held?) await held.future;
    return executor.runSelect(statement, args);
  }
}

/// Storage that counts its reads, so a test can bound a query's cost.
final class ReadCount extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return executor.runSelect(statement, args);
  }
}
