import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lifeos/app/edit_session/confirm.dart';
import 'package:lifeos/app/edit_session/leave.dart';
import 'package:lifeos/app/edit_session/record_edit_adapter.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

/// A synthetic shift as stored: it starts at 07:00 and ends at [end]
/// (hours, past 24 the next day), with breaks starting at [breaks].
@immutable
final class SavedShift {
  const SavedShift({
    required this.end,
    this.breaks = const [],
    this.revision = 0,
  });

  final int end;
  final List<int> breaks;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is SavedShift &&
      other.end == end &&
      listEquals(other.breaks, breaks) &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(end, Object.hashAll(breaks), revision);
}

/// The pending values of a [SavedShift]: the parent's end and its
/// children's break starts, saved and reverted together.
@immutable
final class ShiftDraft {
  const ShiftDraft({required this.end, this.breaks = const []});

  final int end;
  final List<int> breaks;

  ShiftDraft copyWith({int? end, List<int>? breaks}) =>
      ShiftDraft(end: end ?? this.end, breaks: breaks ?? this.breaks);

  @override
  bool operator ==(Object other) =>
      other is ShiftDraft &&
      other.end == end &&
      listEquals(other.breaks, breaks);

  @override
  int get hashCode => Object.hash(end, Object.hashAll(breaks));

  @override
  String toString() => 'ShiftDraft(end: $end, breaks: $breaks)';
}

const endProblem = 'End must be after 07:00 and at most 24 hours later.';
const breakProblem = 'Breaks must lie inside the shift.';

/// A scripted [RecordEditAdapter]: end must be 8 to 31, each break inside
/// the shift. Records every submit and read-back. [results] are handed out
/// in order (a Completer's future holds a save in flight); when empty, a
/// submit commits the draft as the next revision.
final class FakeShiftAdapter
    implements RecordEditAdapter<SavedShift, ShiftDraft> {
  FakeShiftAdapter({this.defaults = const ShiftDraft(end: 19)});

  final ShiftDraft defaults;
  ConfirmRequest? guardRequest;
  Object? throwOnGuard;
  Object? throwOnReadBack;
  final submits = <({ShiftDraft draft, Object? consent})>[];
  final results = <FutureOr<SubmitResult<SavedShift>>>[];
  Object? throwOnSubmit;
  ReadBack<SavedShift> readBackResult = const ReadUnknown();
  Future<ReadBack<SavedShift>>? heldReadBack;
  final readBacks = <ShiftDraft?>[];

  @override
  ShiftDraft draftOf(SavedShift? saved) => saved == null
      ? defaults
      : ShiftDraft(end: saved.end, breaks: saved.breaks);

  @override
  Map<String, String> validate(ShiftDraft draft) => {
    if (draft.end <= 7 || draft.end > 31) 'end': endProblem,
    for (final (index, start) in draft.breaks.indexed)
      if (start <= 7 || start >= draft.end) 'breaks.$index': breakProblem,
  };

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final key in fields.keys) key: 'The command refused $key.',
  };

  @override
  Future<ConfirmRequest?> guard(SavedShift? baseline, ShiftDraft draft) async {
    if (throwOnGuard case final error?) throw error;
    return guardRequest;
  }

  @override
  Future<SubmitResult<SavedShift>> submit(
    SavedShift? baseline,
    ShiftDraft draft, {
    Object? consent,
  }) async {
    submits.add((draft: draft, consent: consent));
    if (throwOnSubmit case final error?) throw error;
    if (results.isNotEmpty) return await results.removeAt(0);
    return Submitted(
      Committed(
        SavedShift(
          end: draft.end,
          breaks: draft.breaks,
          revision: (baseline?.revision ?? -1) + 1,
        ),
      ),
    );
  }

  @override
  Future<ReadBack<SavedShift>> readBack(
    SavedShift? baseline,
    ShiftDraft? submitted,
  ) async {
    readBacks.add(submitted);
    if (throwOnReadBack case final error?) throw error;
    return heldReadBack ?? readBackResult;
  }
}

/// Answers confirmation windows from a script and records each request.
/// An unscripted window fails the test. With [hold] set, the next window
/// waits for that completer.
final class ScriptedConfirm {
  ScriptedConfirm([List<ConfirmAnswer> answers = const []])
    : _answers = [...answers];

  final List<ConfirmAnswer> _answers;
  final asked = <ConfirmRequest>[];
  Completer<ConfirmAnswer>? hold;

  Future<ConfirmAnswer> call(ConfirmRequest request) async {
    asked.add(request);
    if (hold case final waiting?) {
      hold = null;
      return waiting.future;
    }
    if (_answers.isEmpty) {
      throw StateError('No answer scripted for "${request.title}"');
    }
    return _answers.removeAt(0);
  }
}

/// A [LeaveParticipant] that answers from a script and records each ask.
final class ScriptedParticipant implements LeaveParticipant {
  ScriptedParticipant(
    this.name,
    this.log, {
    this.answer = LeaveDecision.proceed,
  });

  final String name;
  final List<String> log;
  LeaveDecision answer;
  Completer<LeaveDecision>? hold;
  Object? throwing;

  @override
  bool settled = true;

  @override
  Future<LeaveDecision> leave(
    Confirm confirm, {
    LeaveKind kind = LeaveKind.navigate,
  }) async {
    log.add('$name:${kind.name}');
    if (throwing case final error?) throw error;
    if (hold case final waiting?) return waiting.future;
    return answer;
  }
}

const finalizeRequest = ConfirmRequest(
  title: 'Finalize shift',
  message: 'Saving finalizes this shift; later changes need Correct.',
  proceed: 'Save and finalize',
  revert: 'Revert',
);
