import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/desks/saved_views.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/features/work/presentation/work_views.dart';

const _employment = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _period = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');

void main() {
  test('a Work route saves as a valid shape and reopens identically', () {
    for (final route in [
      const WorkRouteState(
        employmentId: _employment,
        scope: PayPeriodScope(_period),
        record: null,
        mode: WorkInspectorMode.inspect,
        sheet: WorkSheet.payslips,
        showVoid: true,
      ),
      const WorkRouteState(
        employmentId: null,
        scope: DateRangeScope(
          start: LocalDate(2026, 10, 1),
          end: LocalDate(2026, 10, 7),
        ),
        record: null,
        mode: WorkInspectorMode.inspect,
      ),
    ]) {
      final shape = workViewShape(route);
      expect(viewShapeIssues(shape), isEmpty);
      expect(workViewRoute(shape), workRouteUri(route).toString());
    }
  });

  test('the open record, form and mode are not saved', () {
    final shape = workViewShape(
      const WorkRouteState(
        employmentId: _employment,
        scope: null,
        record: WorkRecordRef(kind: WorkRecordKind.payPeriod, id: _period),
        mode: WorkInspectorMode.edit,
        sheet: WorkSheet.periods,
        adding: WorkAddKind.payslip,
        fromLast: true,
      ),
    );
    expect(shape.sheetRef, ViewSheets.workPeriods);
    expect(shape.filters, {'employment': _employment.value});
  });

  test('a view of another area has no Work route', () {
    expect(workViewState(const ViewShape(sheetRef: 'finance.ledger')), isNull);
  });
}
