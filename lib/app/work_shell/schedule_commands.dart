import '../../features/work/domain/schedule.dart';
import '../edit_session/confirm.dart';

/// The Delete schedule… window (spec 4.7): what goes with the schedule.
ConfirmRequest deleteScheduleRequest(WorkSchedule value) {
  final types = value.shiftTypes.length;
  return ConfirmRequest(
    title: 'Delete schedule',
    message:
        'Delete ${value.name}? No confirmed day uses it. Its $types shift '
        "type${types == 1 ? '' : 's'} and its ${value.cycleLength}-day cycle "
        "go with it. This can't be undone.",
    proceed: 'Delete',
  );
}

/// What a schedule command outside the session came to.
abstract final class ScheduleCommandWords {
  static const stale =
      'This schedule changed since you opened it. It shows as stored now.';
  static const missing = 'This schedule no longer exists.';
  static const unavailable =
      'Not done: local storage is unavailable. Try again.';
  static const inUse =
      'Confirmed days use this schedule. Change it from a date instead.';
  static const notDeleted = 'It was not deleted. Try again when ready.';
  static const deleteUnknown =
      'It is not known whether it was deleted; the sheet shows it as it is '
      'now.';
}
