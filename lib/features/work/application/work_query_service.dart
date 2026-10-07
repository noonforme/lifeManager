import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';

abstract interface class WorkQueryRepository {
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope);

  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id);
}

/// The Shifts sheet's planned days, kept apart from the register so only
/// that sheet pays for planning (schedules spec 6.6).
abstract interface class PlannedShiftSource {
  /// Planned work days in [scope] that no confirmed day covers, by start,
  /// live.
  Stream<List<PlannedShiftRow>> watchPlannedShifts(WorkScope scope);
}

final class WorkQueryService {
  const WorkQueryService(this._repository);

  final WorkQueryRepository _repository;

  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      _repository.watchRegister(scope);

  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      _repository.watchRecord(id);
}
