import 'confirm.dart';

/// Why the owner is leaving the current record (database shell spec 4.2,
/// 4.8).
enum LeaveKind {
  /// Another row, sheet, area, tree node or route.
  navigate,

  /// The native window close or File › Quit.
  quit,
}

enum LeaveDecision { proceed, stay }

/// Something that may hold the owner on the current record: its edit
/// session, an action panel with entered input.
abstract interface class LeaveParticipant {
  /// Resolves pending work for [kind], asking [confirm] when the owner must
  /// choose, and says whether the owner may go.
  Future<LeaveDecision> leave(Confirm confirm, {LeaveKind kind});

  /// Whether nothing is pending: leaving now would neither save, ask nor
  /// wait. An open action panel never is.
  bool get settled;
}

/// Quitting while a save may have gone through and was not checked yet
/// (owner decision 2026-10-13, spec 4.8, 9): check it first. The window
/// stays open either way.
const uncheckedQuitRequest = ConfirmRequest(
  title: 'Quit',
  message: 'A save may have gone through. Check it before quitting.',
  proceed: 'Reload and check',
  cancel: 'Keep editing',
);

/// Quitting after a Reload and check that could not tell whether a save
/// went through (owner decision 2026-10-13): the owner may quit anyway.
const unresolvedQuitRequest = ConfirmRequest(
  title: 'Quit',
  message:
      'The save may or may not have gone through; LifeOS could not tell. '
      'Quit anyway?',
  proceed: 'Quit anyway',
  cancel: 'Keep checking',
);

/// The quit guard of an uncertain outcome (owner decision 2026-10-13):
/// before any check it offers [check] and stays; after a check that could
/// not tell ([unresolved]) it lets the owner quit anyway.
Future<LeaveDecision> leaveUncertain(
  Confirm confirm, {
  required bool unresolved,
  required Future<void> Function() check,
}) async {
  if (!unresolved) {
    if (await confirm(uncheckedQuitRequest) == ConfirmAnswer.proceed) {
      await check();
    }
    return LeaveDecision.stay;
  }
  return await confirm(unresolvedQuitRequest) == ConfirmAnswer.proceed
      ? LeaveDecision.proceed
      : LeaveDecision.stay;
}
