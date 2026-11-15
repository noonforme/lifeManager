import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/leave_coordinator.dart';
import 'package:lifeos/app/edit_session/record_edit_session.dart';

import '../../support/fake_record_adapter.dart';

void main() {
  late List<String> log;
  late LeaveCoordinator guard;

  setUp(() {
    log = [];
    guard = LeaveCoordinator(confirm: ScriptedConfirm().call);
  });

  test('with nobody to ask, navigation goes at once', () async {
    expect(await guard.navigate(() => log.add('go')), isTrue);
    expect(log, ['go']);
  });

  test('settled while every participant is and nothing is deciding', () async {
    expect(guard.settled, isTrue);
    final session = ScriptedParticipant('session', log);
    guard.add(session);
    expect(guard.settled, isTrue);
    session.settled = false;
    expect(guard.settled, isFalse);
    session
      ..settled = true
      ..hold = Completer<LeaveDecision>();
    final going = guard.navigate(() => log.add('go'));
    await Future<void>.delayed(Duration.zero);
    expect(guard.settled, isFalse, reason: 'a decision runs');
    session.hold!.complete(LeaveDecision.proceed);
    await going;
    expect(guard.settled, isTrue);
  });

  test('everyone is asked in order, then the navigation goes once', () async {
    guard
      ..add(ScriptedParticipant('session', log))
      ..add(ScriptedParticipant('panel', log));
    expect(await guard.navigate(() => log.add('go')), isTrue);
    expect(log, ['session:navigate', 'panel:navigate', 'go']);
  });

  test('the first that stays stops the rest and the navigation', () async {
    guard
      ..add(ScriptedParticipant('session', log, answer: LeaveDecision.stay))
      ..add(ScriptedParticipant('panel', log));
    expect(await guard.navigate(() => log.add('go')), isFalse);
    expect(log, ['session:navigate']);
  });

  test('a removed participant is not asked', () async {
    final panel = ScriptedParticipant('panel', log);
    guard
      ..add(panel)
      ..remove(panel);
    await guard.navigate(() => log.add('go'));
    expect(log, ['go']);
  });

  test('navigation requested while deciding joins it; only the latest '
      'goes', () async {
    final session = ScriptedParticipant('session', log)
      ..hold = Completer<LeaveDecision>();
    guard.add(session);
    final first = guard.navigate(() => log.add('go B'));
    final second = guard.navigate(() => log.add('go C'));
    await pumpEventQueue();
    session.hold!.complete(LeaveDecision.proceed);
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(log, ['session:navigate', 'go C'], reason: 'asked once');
  });

  test('quitting asks with the quit kind', () async {
    guard.add(ScriptedParticipant('session', log));
    expect(await guard.quit(), isTrue);
    expect(log, ['session:quit']);
  });

  test('a quit during a navigation waits for it, then decides', () async {
    final session = ScriptedParticipant('session', log)
      ..hold = Completer<LeaveDecision>();
    guard.add(session);
    final navigating = guard.navigate(() => log.add('go'));
    final quitting = guard.quit();
    await pumpEventQueue();
    expect(log, ['session:navigate']);
    session
      ..hold!.complete(LeaveDecision.proceed)
      ..hold = null;
    expect(await navigating, isTrue);
    expect(await quitting, isTrue);
    expect(log, ['session:navigate', 'go', 'session:quit']);
  });

  test('navigation during quit stays put and quit requests join', () async {
    final session = ScriptedParticipant('session', log)
      ..hold = Completer<LeaveDecision>();
    guard.add(session);
    final first = guard.quit();
    final second = guard.quit();
    expect(await guard.navigate(() => log.add('go')), isFalse);
    session.hold!.complete(LeaveDecision.proceed);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(log, ['session:quit']);
  });

  test('a participant that throws keeps the owner where they are', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    guard.add(ScriptedParticipant('panel', log)..throwing = StateError('bug'));
    expect(await guard.navigate(() => log.add('go')), isFalse);
    expect(await guard.quit(), isFalse);
    expect(reported, hasLength(2));
    expect(log, isNot(contains('go')));
  });

  test('participants are asked with the coordinator\'s confirm', () async {
    final confirm = ScriptedConfirm([ConfirmAnswer.cancel]);
    final asking = LeaveCoordinator(confirm: confirm.call);
    final seen = <Confirm>[];
    asking.add(_Capturing(seen));
    await asking.quit();
    expect(seen.single, confirm.call);
  });

  test('clicks while a finalize window is open ask once and go to the last '
      'click', () async {
    final answer = Completer<ConfirmAnswer>();
    final confirm = ScriptedConfirm()..hold = answer;
    final adapter = FakeShiftAdapter()..guardRequest = finalizeRequest;
    final edit = RecordEditSession(
      adapter: adapter,
      baseline: const SavedShift(end: 19, breaks: [12], revision: 3),
    )..edit(const ShiftDraft(end: 20, breaks: [12]));
    addTearDown(edit.dispose);
    final guard = LeaveCoordinator(confirm: confirm.call)..add(edit);
    final went = <String>[];
    final toB = guard.navigate(() => went.add('B'));
    final toC = guard.navigate(() => went.add('C'));
    await pumpEventQueue();
    answer.complete(ConfirmAnswer.proceed);
    expect(await toB, isFalse);
    expect(await toC, isTrue);
    expect(confirm.asked, hasLength(1));
    expect(adapter.submits, hasLength(1));
    expect(went, ['C']);
  });
}

final class _Capturing implements LeaveParticipant {
  _Capturing(this.seen);

  @override
  bool get settled => true;

  final List<Confirm> seen;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    seen.add(confirm);
    return LeaveDecision.proceed;
  }
}
