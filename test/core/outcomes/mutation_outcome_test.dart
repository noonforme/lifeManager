import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';

void main() {
  test('outcomes distinguish stale and uncertain', () {
    expect(const Stale<void>(), isNot(isA<Uncertain<void>>()));
    expect(
      const Uncertain<void>(SafeFailureCode.commitOutcomeUnknown).code,
      SafeFailureCode.commitOutcomeUnknown,
    );
  });

  test('invalid outcome groups field-safe issues', () {
    const issue = FieldIssue(FieldIssueCode.required);
    const outcome = Invalid<void>({
      'employment': [issue],
    });

    expect(outcome.fields['employment'], [issue]);
  });

  test('committed carries the transaction value', () {
    expect(const Committed<int>(42).value, 42);
  });
}
