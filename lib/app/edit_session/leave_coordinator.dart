import 'dart:async';

import 'package:flutter/foundation.dart';

import 'confirm.dart';
import 'leave.dart';

/// Guards every way of leaving the current record (database shell spec
/// 4.2, 4.5, 4.8): another row, sheet, area, tree node or route, and
/// closing the application. Each [LeaveParticipant] is asked in the order
/// added; the first that stays stops the rest. One decision runs at a
/// time: requests of the same kind made meanwhile join it, and a quit
/// waits for a navigation in progress. Navigation during a quit stays
/// put, so it cannot replace the record while resources are being released.
final class LeaveCoordinator {
  LeaveCoordinator({required this.confirm});

  /// Shows confirmation windows for every participant.
  final Confirm confirm;

  final List<LeaveParticipant> _participants = [];
  _Decision? _deciding;
  Object? _latest;

  void add(LeaveParticipant participant) => _participants.add(participant);

  void remove(LeaveParticipant participant) =>
      _participants.remove(participant);

  /// Whether nothing is pending and nothing is being decided: the place
  /// may be shown again without asking anyone (a new day, bead 9pk.4.25).
  bool get settled =>
      _deciding == null &&
      _participants.every((participant) => participant.settled);

  /// Runs [go] once every participant lets the owner leave; returns whether
  /// it ran. Navigation requested while a decision runs joins it, and only
  /// the latest request's [go] runs when it proceeds: the owner's last click
  /// wins, and no request issues a second save.
  Future<bool> navigate(VoidCallback go) async {
    if (_deciding?.kind == LeaveKind.quit) return false;
    final ticket = Object();
    _latest = ticket;
    final decision = await _decide(LeaveKind.navigate);
    if (decision == LeaveDecision.stay || !identical(_latest, ticket)) {
      return false;
    }
    _latest = null;
    go();
    return true;
  }

  /// The native close or File › Quit: whether the application may close.
  Future<bool> quit() async =>
      await _decide(LeaveKind.quit) == LeaveDecision.proceed;

  Future<LeaveDecision> _decide(LeaveKind kind) {
    final current = _deciding;
    if (current != null && current.kind == kind) return current.future;
    final done = Completer<LeaveDecision>();
    final decision = _Decision(kind, done.future);
    _deciding = decision;
    () async {
      var result = LeaveDecision.proceed;
      try {
        if (current != null) await current.future;
        for (final participant in List.of(_participants)) {
          final answer = await participant.leave(confirm, kind: kind);
          if (answer == LeaveDecision.stay) {
            result = LeaveDecision.stay;
            break;
          }
        }
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'leave coordinator',
          ),
        );
        result = LeaveDecision.stay;
      }
      if (identical(_deciding, decision)) _deciding = null;
      done.complete(result);
    }();
    return done.future;
  }
}

final class _Decision {
  _Decision(this.kind, this.future);

  final LeaveKind kind;
  final Future<LeaveDecision> future;
}
