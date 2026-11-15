import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/work_shell/work_history.dart';
import 'package:lifeos/app/work_shell/work_location.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/domain/ids.dart';

const _employment = EmploymentId('0190f5d2-6a00-7000-8000-000000000001');
const _october = WorkLocation.shifts(
  _employment,
  month: LocalDate(2026, 10, 1),
);
const _november = WorkLocation.shifts(
  _employment,
  month: LocalDate(2026, 11, 1),
);

void main() {
  test('a new history has nowhere to go', () {
    final history = WorkHistory(const WorkLocation.overview());
    expect(history.canBack, isFalse);
    expect(history.canForward, isFalse);
    expect(history.previous, isNull);
    expect(history.next, isNull);
  });

  test('push, back and forward walk the places', () {
    final history = WorkHistory(const WorkLocation.overview())
      ..push(_october)
      ..push(_november);
    expect(history.current, _november);
    history.back(history.previous!);
    expect(history.current, _october);
    expect(history.canForward, isTrue);
    history.forward(history.next!);
    expect(history.current, _november);
  });

  test('pushing after Back drops the places ahead', () {
    final history = WorkHistory(const WorkLocation.overview())
      ..push(_october)
      ..push(_november);
    history
      ..back(history.previous!)
      ..push(const WorkLocation.employment(_employment));
    expect(history.canForward, isFalse);
    history.back(history.previous!);
    expect(history.current, _october);
  });

  test('the current place again adds nothing', () {
    final history = WorkHistory(_october)..push(_october);
    expect(history.canBack, isFalse);
  });

  test('replace changes the current place without a Back step', () {
    final history = WorkHistory(const WorkLocation.overview())
      ..push(_october)
      ..replace(_october.withRow('day:2026-10-07'));
    expect(history.current.day, const LocalDate(2026, 10, 7));
    history.back(history.previous!);
    expect(history.current, const WorkLocation.overview());
  });

  test('a step takes the place as it was resolved', () {
    final history = WorkHistory(_october)..push(_november);
    history.back(_october.withRow('day:2026-10-09'));
    expect(history.current.day, const LocalDate(2026, 10, 9));
    expect(history.next, _november);
  });
}
