import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'value_editor.dart';

/// Which value one editor edits: a field of a record within the caller's
/// pending aggregate. Two records' fields with the same key are different
/// fields, so an old draft never lands on a new record.
@immutable
final class EditIdentity {
  const EditIdentity({required this.record, required this.field});

  /// The record, as the caller identifies it within the edit session: a
  /// stored id, or a temporary id for a new or child row. Compared with
  /// `==`, so use a value with value equality.
  final Object record;

  /// The field's key within the record, such as `end`.
  final String field;

  @override
  bool operator ==(Object other) =>
      other is EditIdentity && other.record == record && other.field == field;

  @override
  int get hashCode => Object.hash(record, field);

  @override
  String toString() => 'EditIdentity($record, $field)';
}

/// The outcome of offering a draft: accepted, or rejected with the reason
/// shown at the field.
@immutable
final class EditResult {
  const EditResult.accepted() : error = null;
  const EditResult.rejected(String this.error);

  /// Why the draft was rejected; null when it was accepted.
  final String? error;

  bool get isAccepted => error == null;

  @override
  bool operator ==(Object other) => other is EditResult && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => isAccepted ? 'accepted' : 'rejected($error)';
}

/// A field's UI draft acceptance: parse and check [draft] and, when it
/// holds, write it into the caller's pending record **before returning**
/// [EditResult.accepted]. Otherwise return [EditResult.rejected] with the
/// reason and change nothing. Synchronous; never a database save.
///
/// Apply the draft to the record [id] names (`id.record`, the record the
/// field was opened on), never to whatever record is current: a flush may
/// come after the caller moved on. When that record is gone, reject, so the
/// orphaned draft stays identifiable until the caller resolves it (keeps
/// editing, or [EditorSessionController.cancel]s).
///
/// [draft] is the raw text for kinds [ValueKind.typedAsText] (text,
/// number, money, duration), and the typed value for the others: a
/// `LocalDate?`, `LocalTime?`, the choice's value or a `bool`.
typedef EditCommit = EditResult Function(EditIdentity id, Object? draft);

/// What opening a field needs: who it is, its kind, the caller's current
/// value and where an accepted draft goes.
@immutable
final class EditField {
  const EditField({
    required this.id,
    required this.kind,
    required this.value,
    required this.commit,
    this.text,
  });

  final EditIdentity id;
  final ValueKind kind;

  /// The caller's current (pending) value of the field.
  final Object? value;

  /// Bound to the current record and host by the caller; it applies a draft
  /// to `id.record` only (see [EditCommit]).
  final EditCommit commit;

  /// The text a kind typed as text starts from, such as an amount in the
  /// caller's format. Defaults to [formatValue] of [value].
  final String? text;

  /// What the editor starts from: the text for kinds typed as text,
  /// otherwise [value].
  Object? get entry =>
      kind.typedAsText ? text ?? formatValue(kind, value) : value;
}

/// The open field: its entry value, the current draft and the last
/// rejection. Read it from [EditorSessionController.session].
@immutable
final class EditSession {
  const EditSession._({
    required this.field,
    required this.draft,
    this.host,
    this.editing,
    this.error,
  });

  final EditField field;

  /// The host the field was opened from (a grid, a property grid, a
  /// panel), so that host's editor takes the keyboard rather than another
  /// region's editor of the same field. Null lets any editor answer.
  final Object? host;

  /// The current draft: raw text for kinds typed as text (kept even when
  /// it does not parse), the typed value otherwise.
  final Object? draft;

  /// The text editor's selection and composition with [draft], so a
  /// remounted editor resumes where typing was.
  final TextEditingValue? editing;

  /// Why the last flush was rejected; it stays until the next flush.
  final String? error;

  EditIdentity get id => field.id;
  ValueKind get kind => field.kind;

  /// The caller's value when the field opened.
  Object? get original => field.value;

  /// What the editor started from ([EditField.entry]).
  Object? get entry => field.entry;

  /// Whether [draft] differs from [entry]; an unchanged field closes
  /// without a commit.
  bool get changed => draft != entry;

  EditSession _with({
    Object? draft,
    TextEditingValue? editing,
    String? error,
    bool clearError = false,
  }) => EditSession._(
    field: field,
    host: host,
    draft: draft,
    editing: editing,
    error: clearError ? null : error ?? this.error,
  );
}

/// Coordinates the one open field of a caller's pending aggregate (UI
/// library editor contract). The caller owns it and shares it between the
/// widgets that edit the same aggregate: its grid, property grid, subform
/// and action panel. It holds UI drafts only: no database, service,
/// navigation or asynchronous save.
///
/// Every command that may use or replace the draft calls [flush] first
/// and proceeds only when it is accepted: Save, another row or cell, sort,
/// filter, navigation, new row, tab or tree change, an action panel's
/// primary action, window close. Undo and the field's Esc call [cancel].
/// The draft lives here, not in an editor widget, so a recycled cell
/// remounts with it and scrolling is neither commit nor cancel.
final class EditorSessionController extends ChangeNotifier {
  EditSession? _session;
  bool _flushing = false;
  int _focusRequests = 0;
  int _focusTaken = 0;

  /// The open field, or null.
  EditSession? get session => _session;

  /// The open field's identity, or null.
  EditIdentity? get active => _session?.id;

  /// Whether [id] is the open field.
  bool isActive(EditIdentity id) => _session?.id == id;

  /// Opens [field] from [host] (any token naming the region, such as the
  /// grid's state; see [EditSession.host]). A different open field is
  /// flushed first; when that is rejected, [field] does not open and the
  /// rejection is returned. The open field itself is left as it is, draft
  /// and all, and moves to [host]. Asks the field's editor for focus
  /// ([requestFocus]).
  EditResult begin(EditField field, {Object? host}) {
    if (_session case final session? when session.id == field.id) {
      if (session.host != host) {
        _session = EditSession._(
          field: session.field,
          host: host,
          draft: session.draft,
          editing: session.editing,
          error: session.error,
        );
      }
      requestFocus();
      return const EditResult.accepted();
    }
    final flushed = flush();
    if (!flushed.isAccepted) return flushed;
    _session = EditSession._(field: field, host: host, draft: field.entry);
    _focusRequests++;
    notifyListeners();
    return const EditResult.accepted();
  }

  /// Keeps [draft] as the open field's value, with the text editor's
  /// [editing] state for text. Ignored unless [id] is the open field. No
  /// validation or commit happens here.
  void update(EditIdentity id, Object? draft, {TextEditingValue? editing}) {
    final session = _session;
    if (session == null || session.id != id) return;
    if (session.draft == draft && session.editing == editing) return;
    final notify = session.draft != draft;
    _session = session._with(draft: draft, editing: editing);
    if (notify) notifyListeners();
  }

  /// Offers the open field's draft to its commit callback, synchronously.
  /// With no open field, or an unchanged draft, the field closes and the
  /// result is accepted without a commit. Accepted: the caller has taken
  /// the draft and the field closes once. Rejected: the draft, editor and
  /// error stay for a correction and another attempt, and the editor is
  /// asked for focus. A flush from inside a commit is rejected.
  EditResult flush() {
    final session = _session;
    if (session == null) return const EditResult.accepted();
    if (_flushing) {
      return const EditResult.rejected('The value is being saved.');
    }
    if (!session.changed) {
      _session = null;
      notifyListeners();
      return const EditResult.accepted();
    }
    _flushing = true;
    final EditResult result;
    try {
      result = session.field.commit(session.id, session.draft);
    } finally {
      _flushing = false;
    }
    // The commit may have moved on (cancelled, begun another field).
    if (!identical(_session, session)) return result;
    if (result.isAccepted) {
      _session = null;
    } else {
      _session = session._with(
        draft: session.draft,
        editing: session.editing,
        error: result.error,
      );
      _focusRequests++;
    }
    notifyListeners();
    return result;
  }

  /// Throws away the open field's draft and closes it: the caller's value
  /// stays as it was when the field opened. Other fields' accepted values
  /// are untouched.
  void cancel() {
    if (_session == null) return;
    _session = null;
    notifyListeners();
  }

  /// Asks the open field's mounted editor to take the keyboard, scrolled
  /// into view; for a host whose own control took focus. [begin] and a
  /// rejected [flush] ask by themselves.
  void requestFocus() {
    if (_session == null) return;
    _focusRequests++;
    notifyListeners();
  }

  /// Whether a focus request is waiting for the open field's editor: none
  /// of its host's editors has taken it yet.
  bool get focusRequestPending =>
      _session != null && _focusTaken != _focusRequests;

  /// For editor widgets (`CellEditor`): true once per focus request while
  /// [id] is the open field and [host] its host (or it has none), so
  /// exactly one editor answers it and a remount from scrolling does not
  /// take focus.
  bool takeFocusRequest(EditIdentity id, {Object? host}) {
    final session = _session;
    if (session == null ||
        session.id != id ||
        (session.host != null && session.host != host) ||
        _focusTaken == _focusRequests) {
      return false;
    }
    _focusTaken = _focusRequests;
    return true;
  }
}
