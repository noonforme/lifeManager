import '../../../core/database/database_identity.dart';
import '../../../core/outcomes/mutation_outcome.dart';
import '../../../core/time/app_clock.dart';
import '../domain/facts.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import 'work_commands.dart';

abstract interface class PayPeriodRepository {
  Future<MutationOutcome<PayPeriod>> createPeriod(PayPeriod value);

  Future<MutationOutcome<PayPeriod>> setPeriodState(
    PayPeriodId id, {
    required PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  });
}

final class PayPeriodService {
  const PayPeriodService(
    this._repository, {
    required this.idFactory,
    required this.clock,
  });

  final PayPeriodRepository _repository;
  final WorkEvidenceIdFactory idFactory;
  final AppClock clock;

  Future<MutationOutcome<PayPeriod>> createPeriod(
    CreatePayPeriodCommand command,
  ) async {
    try {
      final period = PayPeriod.create(
        id: idFactory.payPeriodId(),
        employmentId: command.employmentId,
        start: command.start,
        end: command.end,
        label: command.label,
        nowUtc: clock.nowUtc(),
      );
      return await _repository.createPeriod(period);
    } on ArgumentError {
      return const Invalid<PayPeriod>({
        'range': [FieldIssue(FieldIssueCode.invalid)],
      });
    } on DatabaseOpenFailure {
      return const Unavailable<PayPeriod>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<PayPeriod>(SafeFailureCode.storageUnavailable);
    }
  }

  Future<MutationOutcome<PayPeriod>> setState(
    SetPayPeriodStateCommand command,
  ) async {
    try {
      return await _repository.setPeriodState(
        command.id,
        state: command.state,
        expected: command.expectedRevision,
        nowUtc: clock.nowUtc(),
      );
    } on DatabaseOpenFailure {
      return const Unavailable<PayPeriod>(SafeFailureCode.storageUnavailable);
    } on DatabaseValidationFailure {
      return const Unavailable<PayPeriod>(SafeFailureCode.storageUnavailable);
    }
  }
}
