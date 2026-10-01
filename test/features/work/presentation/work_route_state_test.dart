import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';

void main() {
  const employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');

  test('the sheet and void filter round-trip as structural parameters', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: WorkSheet.payslips,
      showVoid: true,
    );
    final uri = workRouteUri(state);
    expect(
      uri.toString(),
      '/work?employment=${employment.value}&sheet=payslips&void=1'
      '&mode=inspect',
    );
    final parsed = (parseWorkRoute(uri) as ValidWorkRoute).state;
    expect(parsed.sheet, WorkSheet.payslips);
    expect(parsed.showVoid, isTrue);
  });

  test('Shifts and hidden void rows are the defaults and stay implicit', () {
    final parsed = (parseWorkRoute(
      Uri.parse('/work?employment=${employment.value}'),
    ) as ValidWorkRoute).state;
    expect(parsed.sheet, WorkSheet.shifts);
    expect(parsed.showVoid, isFalse);
    expect(workRouteUri(parsed).query, isNot(contains('sheet')));
  });

  test('an unknown sheet or void value is invalid', () {
    expect(
      parseWorkRoute(Uri.parse('/work?sheet=ledger')),
      isA<InvalidWorkRoute>(),
    );
    expect(
      parseWorkRoute(Uri.parse('/work?void=yes')),
      isA<InvalidWorkRoute>(),
    );
  });

  test('copyWith keeps the sheet when the record changes', () {
    const state = WorkRouteState(
      employmentId: employment,
      scope: null,
      record: null,
      mode: WorkInspectorMode.inspect,
      sheet: WorkSheet.agreements,
    );
    final next = state.copyWith(mode: WorkInspectorMode.create);
    expect(next.sheet, WorkSheet.agreements);
    expect(next.mode, WorkInspectorMode.create);
  });
}
