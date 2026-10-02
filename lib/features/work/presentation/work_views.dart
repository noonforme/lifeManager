import '../../../core/desks/saved_views.dart';
import '../data/projections/work_register_projection.dart';
import 'work_route_state.dart';

const _sheets = {
  WorkSheet.shifts: ViewSheets.workShifts,
  WorkSheet.periods: ViewSheets.workPeriods,
  WorkSheet.payslips: ViewSheets.workPayslips,
  WorkSheet.agreements: ViewSheets.workAgreements,
};

/// What Save as view stores for a Work route: the sheet and its structural
/// filters. The open record, form and mode are not part of a view.
ViewShape workViewShape(WorkRouteState route) => ViewShape(
  sheetRef: _sheets[route.sheet]!,
  filters: {
    if (route.employmentId case final employment?)
      'employment': employment.value,
    ...switch (route.scope) {
      PayPeriodScope(:final periodId) => {'period': periodId.value},
      DateRangeScope(:final start, :final end) => {
        'from': '$start',
        'to': '$end',
      },
      null => const <String, String>{},
    },
    if (route.showVoid) 'void': '1',
  },
);

/// The Work route a view reopens, or null for a view of another area.
WorkRouteState? workViewState(ViewShape shape) {
  final sheet = _sheets.entries
      .where((entry) => entry.value == shape.sheetRef)
      .map((entry) => entry.key)
      .firstOrNull;
  if (sheet == null) return null;
  final parsed = parseWorkRoute(
    Uri(
      path: '/work',
      queryParameters: {...shape.filters, 'sheet': sheet.name},
    ),
  );
  return switch (parsed) {
    ValidWorkRoute(:final state) => state,
    InvalidWorkRoute() => null,
  };
}

/// The route a view opens at full size.
String? workViewRoute(ViewShape shape) => switch (workViewState(shape)) {
  final state? => workRouteUri(state).toString(),
  null => null,
};
