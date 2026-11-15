import '../../core/time/local_date.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/leave.dart';
import '../../features/work/domain/shift.dart';
import '../../ui/ui.dart' show eraBoxDate;
import '../work_edit/work_records.dart';

/// What the one-click day commands say: Confirm and Restore shift
/// (plan 4d-1, Tasks 3 and 4).
abstract final class DayCommandWords {
  static String confirmed(LocalDate date) =>
      'Confirmed ${eraBoxDate(date)}. Its pay is final; Correct… or Void… '
      'changes it.';
  static String confirmedLeave(LocalDate date) =>
      'Confirmed ${eraBoxDate(date)} as leave. It is corrected on the Leave '
      'sheet.';
  static const confirmOnly =
      'Confirm applies to a planned day or leave on or before today.';
  static const noAgreement =
      'No pay agreement covers this day. Extend pay agreement… first.';
  static const alreadyConfirmed = 'This day is already confirmed.';
  static const notDone = 'It was not confirmed. Try again when ready.';
  static const unknown =
      'It is not known whether the day was confirmed; it is shown as it is '
      'now.';
  static const noLastShift = 'No finalized shift to copy yet.';
  static const finalizeOnlyDraft =
      'Finalize applies to a draft with no unsaved change.';
  static const finalizeChanged = 'Save finalizes a changed draft.';
  static const extraOnlyOff =
      'Pick an Off day first; a planned day is changed instead.';
  static const restored = 'Shift restored: the day follows its schedule again.';
  static const extraRemoved = 'Extra shift removed.';
  static const restoreOnly =
      'Restore shift applies to a changed, cancelled, extra or leave day not '
      'yet confirmed.';
}

/// What confirming [date] made, as stored now: its finalized shift, its
/// confirmed leave, or null when neither is found (a day not confirmed).
/// Throws when storage cannot be read.
Future<ConfirmedDay?> confirmedOn(
  DayPlanService plans,
  WorkReads reads,
  EmploymentId employmentId,
  LocalDate date,
) async {
  final shift = (await reads.shiftsOf(employmentId))
      .where(
        (value) =>
            value.state == ShiftState.finalized &&
            value.schedule?.plannedDate == date,
      )
      .firstOrNull;
  if (shift != null) return ConfirmedShift(shift);
  final LeaveRecord? leave = (await plans.repository.leaveFor(employmentId))
      .where((value) => value.isEffective && value.date == date)
      .firstOrNull;
  return leave == null ? null : ConfirmedLeave(leave);
}
