import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';

abstract interface class WorkWriteStore {
  Future<int> insertEmployment(Employment value);

  Future<int> updateEmployment(Employment value, {required Revision expected});

  Future<List<PayAgreement>> agreementsFor(EmploymentId id);

  Future<int> insertAgreement(PayAgreement value);

  Future<int> updateUnusedAgreement(
    PayAgreement value, {
    required Revision expected,
  });
}
