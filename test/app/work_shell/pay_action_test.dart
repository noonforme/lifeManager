import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_edit/pay_edit.dart';
import 'package:lifeos/app/work_shell/pay_action.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/pay_period_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';

import '../../support/schedule_fixture.dart';
import '../../support/shifts_sheet_fixture.dart';

/// A period store that refuses every state change as invalid.
final class _Refusing implements PayPeriodRepository {
  @override
  Future<MutationOutcome<PayPeriod>> createPeriod(PayPeriod value) =>
      throw UnimplementedError();

  @override
  Future<MutationOutcome<PayPeriod>> setPeriodState(
    PayPeriodId id, {
    required PayPeriodState state,
    required Revision expected,
    required DateTime nowUtc,
  }) async => const Invalid({});
}

void main() {
  late ShiftsSheetFixture fixture;
  late PayPeriod period;

  setUp(() async {
    fixture = await ShiftsSheetFixture.create();
    period = (await fixture.work.periods.createPeriod(
      const CreatePayPeriodCommand(
        employmentId: fixtureEmployment,
        start: LocalDate(2026, 10, 1),
        end: LocalDate(2026, 10, 31),
        label: null,
      ),
    ) as Committed<PayPeriod>).value;
  });
  tearDown(() => fixture.dispose());

  for (final (kind, words) in [
    (PayActionKind.review, PayActionWords.reviewRefused),
    (PayActionKind.reopen, PayActionWords.reopenRefused),
  ]) {
    test(
      'a refused ${kind.name} names the period, not replacement values',
      () async {
        final action = PayAction(
          kind: kind,
          original: PayRecord.period(period),
          work: fixture.work.replacing(
            periods: PayPeriodService(
              _Refusing(),
              idFactory: fixture.schedule.ids,
              clock: fixture.schedule.clock,
            ),
          ),
          reads: fixture.reads,
        );
        addTearDown(action.dispose);
        expect(await action.submit(), isNull);
        expect(action.error, words);
        expect(action.error, isNot(contains('replacement')));
      },
    );
  }
}
