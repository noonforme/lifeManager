import '../data/projections/reconciliation_projection.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/reconciliation.dart';
import 'work_query_service.dart';

final class ReconciliationSummary {
  const ReconciliationSummary({
    required this.projection,
    required this.overallStatus,
  });

  final ReconciliationProjection projection;
  final ReconciliationStatus overallStatus;

  List<ReconciliationGroup> get groups => projection.groups;
}

final class ReconciliationService {
  ReconciliationService(WorkQueryRepository repository)
    : _queries = WorkQueryService(repository);

  final WorkQueryService _queries;

  Stream<ReconciliationSummary> watch(WorkScope scope) async* {
    await for (final register in _queries.watchRegister(scope)) {
      final projection = register.reconciliation;
      if (projection == null) continue;
      yield ReconciliationSummary(
        projection: projection,
        overallStatus: _overallStatus(projection.groups),
      );
    }
  }
}

ReconciliationStatus _overallStatus(List<ReconciliationGroup> groups) {
  final bases = groups.map((group) => group.basis.runtimeType).toSet();
  if (bases.length > 1) return const MixedBasis();
  if (groups.isEmpty) return const EmptyReconciliation();
  return groups.single.status;
}
