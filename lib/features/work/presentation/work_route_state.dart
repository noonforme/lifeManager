import '../../../core/time/local_date.dart';
import '../data/projections/work_register_projection.dart';
import '../domain/ids.dart';

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

final class WorkRouteState {
  const WorkRouteState({
    required this.employmentId,
    required this.scope,
    required this.record,
    required this.mode,
  });

  final EmploymentId? employmentId;
  final WorkTemporalScope? scope;
  final WorkRecordRef? record;
  final WorkInspectorMode mode;
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
    ),
  );
}
