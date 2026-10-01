import '../domain/agreement.dart';
import '../domain/employment.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';

abstract interface class WorkWriteStore {
  Future<int> insertEmployment(Employment value);

  Future<Employment?> employmentById(EmploymentId id);

  Future<int> updateEmployment(Employment value, {required Revision expected});

  /// Whether any shift, pay period or payslip belongs to the employment.
  Future<bool> employmentHasHistory(EmploymentId id);

  /// Deletes the employment and its agreements when its revision matches;
  /// returns the number of employments deleted.
  Future<int> deleteEmployment(EmploymentId id, {required Revision expected});

  Future<List<PayAgreement>> agreementsFor(EmploymentId id);

  Future<int> insertAgreement(PayAgreement value);

  Future<int> updateUnusedAgreement(
    PayAgreement value, {
    required Revision expected,
  });
}
