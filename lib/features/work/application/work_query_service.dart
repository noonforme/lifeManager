import '../data/projections/work_record_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';

abstract interface class WorkQueryRepository {
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope);

  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id);
}

final class WorkQueryService {
  const WorkQueryService(this._repository);

  final WorkQueryRepository _repository;

  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      _repository.watchRegister(scope);

  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      _repository.watchRecord(id);
}
