import 'package:flutter/foundation.dart';

/// The owner's answer in a confirmation window (database shell spec 4.7).
enum ConfirmAnswer {
  /// The affirmative key: "Save", "Save and finalize", "Save and reprice".
  proceed,

  /// Drop the pending values and go on: "Revert", "Discard".
  revert,

  /// Stay with the pending values: "Cancel", "Keep editing", the close key.
  cancel,
}

/// What a save, an undo or a leave asks before it writes or discards
/// (spec 4.2, 4.3, 4.7): one or two sentences and two or three keys, the
/// affirmative first. It never holds a form.
@immutable
final class ConfirmRequest {
  const ConfirmRequest({
    required this.title,
    required this.message,
    required this.proceed,
    this.revert,
    this.cancel = 'Cancel',
    this.warning = true,
    this.consent,
  });

  final String title;
  final String message;

  /// The affirmative key's label; null when the window offers none (an
  /// invalid draft offers only Discard and Keep editing).
  final String? proceed;

  /// The label of the key that drops the pending values, or null.
  final String? revert;

  /// The label of the key that stays; the close key answers it too.
  final String cancel;

  /// A warning sign (money, finalization, loss) rather than information.
  final bool warning;

  /// What proceeding consents to, such as an agreement correction's
  /// previewed repricing impact. The session hands it to
  /// `RecordEditAdapter.submit` unchanged and never reuses it for another
  /// request.
  final Object? consent;
}

/// Shows [ConfirmRequest] and completes with the owner's answer; closing
/// the window is [ConfirmAnswer.cancel].
typedef Confirm = Future<ConfirmAnswer> Function(ConfirmRequest request);
