import '../../../core/database/app_database.dart' show AppDatabase;
import '../../../core/outcomes/mutation_outcome.dart';
import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import 'daos/agreement_dao.dart';
import 'daos/employment_dao.dart';
import 'work_write_store.dart';

final class DriftWorkRepository implements WorkWriteStore {
  DriftWorkRepository(this._database)
    : _employments = EmploymentDao(_database),
      _agreements = AgreementDao(_database);

  final AppDatabase _database;
  final EmploymentDao _employments;
  final AgreementDao _agreements;

  @override
  Future<int> insertEmployment(Employment value) => _employments.insert(value);

  @override
  Future<int> updateEmployment(
    Employment value, {
    required Revision expected,
  }) => _employments.update(value, expected);

  Future<Employment?> employmentById(EmploymentId id) => _employments.byId(id);

  Stream<Employment?> watchEmployment(EmploymentId id) =>
      _employments.watchById(id);

  @override
  Future<List<PayAgreement>> agreementsFor(EmploymentId id) =>
      _agreements.forEmployment(id);

  Stream<List<PayAgreement>> watchAgreements(EmploymentId id) =>
      _agreements.watchForEmployment(id);

  @override
  Future<int> insertAgreement(PayAgreement value) => _agreements.insert(value);

  Future<MutationOutcome<PayAgreement>> createAgreement(PayAgreement value) {
    return _database.transaction(() async {
      final existing = await _agreements.forEmployment(value.employmentId);
      final validation = validateAgreementSet([...existing, value]);
      if (!validation.isValid) {
        return const Invalid<PayAgreement>({
          'effectiveRange': [FieldIssue(FieldIssueCode.conflict)],
        });
      }
      await _agreements.insert(value);
      return Committed<PayAgreement>(value);
    });
  }

  @override
  Future<int> updateUnusedAgreement(
    PayAgreement value, {
    required Revision expected,
  }) {
    return _database.transaction(() async {
      final existing = await _agreements.forEmployment(value.employmentId);
      final withoutCurrent = existing.where((item) => item.id != value.id);
      final validation = validateAgreementSet([...withoutCurrent, value]);
      if (!validation.isValid) return 0;
      return _agreements.updateUnused(value, expected);
    });
  }
}
