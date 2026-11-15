import '../../core/outcomes/mutation_outcome.dart';
import 'confirm.dart';

/// Connects a `RecordEditSession` to one record kind's existing commands
/// (database shell spec 4.2, 6). [S] is the saved object; [D] the pending
/// draft of the record together with its children, an immutable value
/// with `==`, so one draft saves or reverts the parent and its children
/// together. Collection fields must compare their contents, not list identity.
/// Adapters call existing services only; they add no domain
/// behavior.
abstract interface class RecordEditAdapter<S, D> {
  /// The draft [saved] starts from; for a new record (null) its defaults.
  D draftOf(S? saved);

  /// The problems of the complete draft by field key (`end`, `breaks.1`),
  /// empty when it may be submitted. Synchronous and free of storage.
  Map<String, String> validate(D draft);

  /// The words for a command's Invalid fields, by the same field keys.
  Map<String, String> describe(Map<String, List<FieldIssue>> fields);

  /// The confirmation saving [draft] needs before any write (finalization,
  /// repricing with its previewed impact as consent, recording money
  /// evidence), or null to save without asking. A new record's request must
  /// offer a revert/discard choice, including when returned via Reconfirm,
  /// so Undo and leaving can discard it without submitting.
  Future<ConfirmRequest?> guard(S? baseline, D draft);

  /// Calls the existing command exactly once. [consent] is the consent of
  /// the request the owner proceeded with, or null.
  Future<SubmitResult<S>> submit(S? baseline, D draft, {Object? consent});

  /// Reads the record again: for Reload record after Stale ([submitted]
  /// null) and for Reload and check after Uncertain ([submitted] is the
  /// draft last sent).
  Future<ReadBack<S>> readBack(S? baseline, D? submitted);
}

/// What a submit came to.
sealed class SubmitResult<S> {
  const SubmitResult();
}

/// The command ran and returned [outcome].
final class Submitted<S> extends SubmitResult<S> {
  const Submitted(this.outcome);

  final MutationOutcome<S> outcome;
}

/// What the owner consented to changed before the commit (a repricing
/// impact): nothing was written; ask [request] and submit again with its
/// consent only (spec 4.2 repricing guard).
final class Reconfirm<S> extends SubmitResult<S> {
  const Reconfirm(this.request);

  final ConfirmRequest request;
}

/// What reading the record again established (spec 9).
sealed class ReadBack<S> {
  const ReadBack();
}

/// The record as stored now; [saved] says whether it holds the submitted
/// draft (always false for a reload).
final class ReadFound<S> extends ReadBack<S> {
  const ReadFound(this.value, {required this.saved});

  final S value;
  final bool saved;
}

/// A new record was established not to have been created.
final class ReadNotSaved<S> extends ReadBack<S> {
  const ReadNotSaved();
}

/// The record no longer exists.
final class ReadGone<S> extends ReadBack<S> {
  const ReadGone();
}

/// Reading back could not establish anything.
final class ReadUnknown<S> extends ReadBack<S> {
  const ReadUnknown();
}
