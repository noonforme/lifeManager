import '../../../core/time/local_date.dart';
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

  /// Moves only an agreement's dates, used or not, when its revision
  /// matches; returns the number of agreements changed.
  Future<int> updateAgreementRange(
    PayAgreement value, {
    required Revision expected,
  });

  /// Deletes an agreement, and its history, when its revision matches and
  /// no shift or leave refers to it; returns the number deleted.
  Future<int> deleteUnusedAgreement(
    AgreementId id, {
    required Revision expected,
  });

  /// The last date a finalized shift or confirmed leave was paid under the
  /// agreement; null when none was.
  Future<LocalDate?> lastAgreementUse(AgreementId id);
}
