import '../../../core/time/local_date.dart';
import 'facts.dart';
import 'ids.dart';

enum PayPeriodState { open, reviewed }

final class PayPeriod {
  const PayPeriod._({
    required this.id,
    required this.employmentId,
    required this.start,
    required this.end,
    required this.label,
    required this.state,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  });

  factory PayPeriod.rehydrate({
    required PayPeriodId id,
    required EmploymentId employmentId,
    required LocalDate start,
    required LocalDate end,
    required String? label,
    required PayPeriodState state,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    required Revision revision,
  }) {
    if (end.compareTo(start) < 0) {
      throw ArgumentError.value(end, 'end');
    }
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
    if (!updatedAtUtc.isUtc) {
      throw ArgumentError.value(updatedAtUtc, 'updatedAtUtc');
    }
    return PayPeriod._(
      id: id,
      employmentId: employmentId,
      start: start,
      end: end,
      label: label,
      state: state,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      revision: revision,
    );
  }

  factory PayPeriod.create({
    required PayPeriodId id,
    required EmploymentId employmentId,
    required LocalDate start,
    required LocalDate end,
    required String? label,
    required DateTime nowUtc,
  }) {
    if (end.compareTo(start) < 0) {
      throw ArgumentError.value(end, 'end');
    }
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc');
    }
    final normalizedLabel = label?.trim();
    return PayPeriod._(
      id: id,
      employmentId: employmentId,
      start: start,
      end: end,
      label: normalizedLabel?.isEmpty == true ? null : normalizedLabel,
      state: PayPeriodState.open,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      revision: const Revision(0),
    );
  }

  final PayPeriodId id;
  final EmploymentId employmentId;
  final LocalDate start;
  final LocalDate end;
  final String? label;
  final PayPeriodState state;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  bool contains(LocalDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
}
