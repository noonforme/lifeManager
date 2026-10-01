import '../../../core/time/local_date.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';
import '../domain/pay_period.dart';
import '../domain/payslip.dart';
import '../domain/shift.dart';

enum WorkInspectorMode { inspect, create, edit, correct }

enum WorkRouteProblem { malformedId, malformedScope, invalidMode }

enum WorkRecordKind {
  employment,
  agreement,
  shift,
  shiftBreak,
  payPeriod,
  payslip,
}

sealed class WorkRouteParseResult {
  const WorkRouteParseResult();
}

final class ValidWorkRoute extends WorkRouteParseResult {
  const ValidWorkRoute(this.state);

  final WorkRouteState state;
}

final class InvalidWorkRoute extends WorkRouteParseResult {
  const InvalidWorkRoute(this.reason);

  final WorkRouteProblem reason;
}

final class WorkRecordRef {
  const WorkRecordRef({required this.kind, required this.id});

  final WorkRecordKind kind;
  final WorkRecordId id;

  static WorkRecordRef? tryParse(String? value) {
    if (value == null) return null;
    final separator = value.indexOf(':');
    if (separator <= 0 || separator != value.lastIndexOf(':')) return null;
    final kindText = value.substring(0, separator);
    final idText = value.substring(separator + 1);
    return switch (kindText) {
      'employment' => _record(
        WorkRecordKind.employment,
        EmploymentId.tryParse(idText),
      ),
      'agreement' => _record(
        WorkRecordKind.agreement,
        AgreementId.tryParse(idText),
      ),
      'shift' => _record(WorkRecordKind.shift, ShiftId.tryParse(idText)),
      'shiftBreak' => _record(
        WorkRecordKind.shiftBreak,
        ShiftBreakId.tryParse(idText),
      ),
      'payPeriod' => _record(
        WorkRecordKind.payPeriod,
        PayPeriodId.tryParse(idText),
      ),
      'payslip' => _record(WorkRecordKind.payslip, PayslipId.tryParse(idText)),
      _ => null,
    };
  }

  static WorkRecordRef? _record(WorkRecordKind kind, WorkRecordId? id) =>
      id == null ? null : WorkRecordRef(kind: kind, id: id);
}

WorkRouteState routeForCommittedShift(
  WorkShift shift, {
  WorkInspectorMode mode = WorkInspectorMode.inspect,
}) => WorkRouteState(
  employmentId: shift.employmentId,
  scope: DateRangeScope(start: shift.localStartDate, end: shift.localStartDate),
  record: WorkRecordRef(kind: WorkRecordKind.shift, id: shift.id),
  mode: mode,
);

WorkRouteState routeForCommittedPayPeriod(PayPeriod period) => WorkRouteState(
  employmentId: period.employmentId,
  scope: PayPeriodScope(period.id),
  record: WorkRecordRef(kind: WorkRecordKind.payPeriod, id: period.id),
  mode: WorkInspectorMode.inspect,
);

WorkRouteState routeForCommittedPayslip(
  Payslip payslip, {
  EmploymentId? employmentId,
}) => WorkRouteState(
  employmentId: employmentId,
  scope: PayPeriodScope(payslip.periodId),
  record: WorkRecordRef(kind: WorkRecordKind.payslip, id: payslip.id),
  mode: WorkInspectorMode.inspect,
);

final class WorkRouteState {
  const WorkRouteState({
    required this.employmentId,
    required this.scope,
    required this.record,
    required this.mode,
    this.sheet = WorkSheet.shifts,
    this.showVoid = false,
  });

  final EmploymentId? employmentId;
  final WorkTemporalScope? scope;
  final WorkRecordRef? record;
  final WorkInspectorMode mode;

  /// The sheet on the desk; Shifts unless the route names another.
  final WorkSheet sheet;

  /// Whether voided rows are listed; they are hidden by default.
  final bool showVoid;

  WorkRouteState copyWith({
    WorkTemporalScope? Function()? scope,
    WorkRecordRef? Function()? record,
    WorkInspectorMode? mode,
    WorkSheet? sheet,
    bool? showVoid,
  }) => WorkRouteState(
    employmentId: employmentId,
    scope: scope == null ? this.scope : scope(),
    record: record == null ? this.record : record(),
    mode: mode ?? this.mode,
    sheet: sheet ?? this.sheet,
    showVoid: showVoid ?? this.showVoid,
  );
}

Uri workRouteUri(WorkRouteState state) {
  final parameters = <String>[];
  if (state.employmentId case final employmentId?) {
    parameters.add('employment=${employmentId.value}');
  }
  switch (state.scope) {
    case PayPeriodScope(:final periodId):
      parameters.add('period=${periodId.value}');
    case DateRangeScope(:final start, :final end):
      parameters.add('from=$start');
      parameters.add('to=$end');
    case null:
  }
  if (state.sheet != WorkSheet.shifts) {
    parameters.add('sheet=${state.sheet.name}');
  }
  if (state.showVoid) parameters.add('void=1');
  if (state.record case final record?) {
    parameters.add('record=${record.kind.name}:${record.id.value}');
  }
  parameters.add('mode=${state.mode.name}');
  return Uri(path: '/work', query: parameters.join('&'));
}

WorkRouteParseResult parseWorkRoute(Uri uri) {
  if (uri.path != '/work') {
    return const InvalidWorkRoute(WorkRouteProblem.malformedScope);
  }
  final mode = switch (uri.queryParameters['mode'] ?? 'inspect') {
    'inspect' => WorkInspectorMode.inspect,
    'create' => WorkInspectorMode.create,
    'edit' => WorkInspectorMode.edit,
    'correct' => WorkInspectorMode.correct,
    _ => null,
  };
  if (mode == null) {
    return const InvalidWorkRoute(WorkRouteProblem.invalidMode);
  }

  final employmentText = uri.queryParameters['employment'];
  final employment = EmploymentId.tryParse(employmentText);
  if (employmentText != null && employment == null) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedId);
  }

  final recordText = uri.queryParameters['record'];
  final record = WorkRecordRef.tryParse(recordText);
  if (recordText != null && record == null) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedId);
  }

  final periodText = uri.queryParameters['period'];
  final period = PayPeriodId.tryParse(periodText);
  final fromText = uri.queryParameters['from'];
  final toText = uri.queryParameters['to'];
  final from = fromText == null ? null : LocalDate.tryParse(fromText);
  final to = toText == null ? null : LocalDate.tryParse(toText);
  final hasRange = fromText != null || toText != null;
  if ((periodText != null && period == null) ||
      (period != null && hasRange) ||
      (hasRange && (from == null || to == null || to.compareTo(from) < 0))) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedScope);
  }

  final sheetText = uri.queryParameters['sheet'];
  final sheet = sheetText == null
      ? WorkSheet.shifts
      : WorkSheet.values.where((value) => value.name == sheetText).firstOrNull;
  final voidText = uri.queryParameters['void'];
  if (sheet == null || (voidText != null && voidText != '1')) {
    return const InvalidWorkRoute(WorkRouteProblem.malformedScope);
  }

  final scope = period != null
      ? PayPeriodScope(period)
      : from != null && to != null
      ? DateRangeScope(start: from, end: to)
      : null;
  return ValidWorkRoute(
    WorkRouteState(
      employmentId: employment,
      scope: scope,
      record: record,
      mode: mode,
      sheet: sheet,
      showVoid: voidText == '1',
    ),
  );
}
