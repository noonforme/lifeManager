import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;

import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/application/day_plan_service.dart';
import '../../features/work/data/projections/work_register_projection.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay.dart';
import '../../features/work/domain/pay_period.dart';
import '../../features/work/domain/payslip.dart';
import '../../features/work/domain/planner.dart';
import '../../features/work/domain/schedule.dart';
import '../../features/work/domain/shift.dart';
import '../production_work_providers.dart';

/// What one month of an employment holds, for the Details box (spec 3).
final class MonthFacts {
  const MonthFacts({
    required this.month,
    required this.finalized,
    required this.toConfirm,
    required this.withoutAgreementDays,
    required this.planned,
    required this.leave,
    required this.off,
  });

  /// Its first day.
  final LocalDate month;

  /// Stored shifts finalized and not void, starting in the month.
  final int finalized;

  /// Past planned days not confirmed, in the month: those an agreement
  /// covers, and those none does (schedules spec 5).
  final int toConfirm;

  /// The past planned days no agreement covers, in date order.
  final List<LocalDate> withoutAgreementDays;
  int get withoutAgreement => withoutAgreementDays.length;

  /// Planned work days from today to the month's end.
  final int planned;
  final int leave;
  final int off;
}

/// The facts of one employment that its Details box shows (spec 3).
final class EmploymentDetails {
  const EmploymentDetails({
    required this.agreement,
    required this.schedule,
    required this.openPeriod,
    required this.confirmedSoFar,
    required this.lastPayslip,
    required this.month,
    required this.nextShift,
    required this.nextShiftStart,
    this.periods = const [],
  });

  /// The agreement covering today, else the latest.
  final PayAgreement? agreement;

  /// The schedule version in use today.
  final WorkSchedule? schedule;

  /// The open pay period containing today, else the latest open one.
  final PayPeriod? openPeriod;

  /// [openPeriod]'s expected pay so far, when it has one comparable basis.
  final Money? confirmedSoFar;

  /// The payslip in effect issued last.
  final Payslip? lastPayslip;
  final MonthFacts month;

  /// The first planned shift starting after now on the app clock, within
  /// the 62 days after today, and its local start time.
  final PlannedShift? nextShift;
  final LocalTime? nextShiftStart;

  /// Every pay period of the employment, by start.
  final List<PayPeriod> periods;
}

/// One employment's [EmploymentDetails], live, over the existing services
/// (nothing new is stored). The next shift follows the app clock: once it
/// starts, the one after it is shown. A feed that fails ends the details:
/// [failed] is set and nothing more is emitted.
final class EmploymentDetailsSource {
  EmploymentDetailsSource({
    required this.work,
    required this.employmentId,
    required this.month,
    required this.today,
  }) {
    final monthEnd = month.lastOfMonth;
    _listen(
      work.workRepository.watchRegister(
        WorkScope(employmentId: employmentId, temporal: null),
      ),
      (value) => _register = value,
    );
    _listen(work.plans.watchInputs(employmentId), (inputs) {
      _schedules = inputs.schedules;
      _confirmedDates = inputs.confirmedDates;
      _past = work.plans.pastFromInputs(inputs, employmentId, today);
      _monthPlan = work.plans.planFromInputs(inputs, month, monthEnd);
      _ahead = work.plans.planFromInputs(
        inputs,
        today,
        today.addDays(_horizon),
      );
    });
  }

  /// How many days after today the next shift is looked for.
  static const _horizon = 62;

  final ProductionWorkProviders work;
  final EmploymentId employmentId;

  /// The first day of the month whose facts are shown.
  final LocalDate month;
  final LocalDate today;

  final _out = StreamController<EmploymentDetails>.broadcast();
  final _feeds = <StreamSubscription<Object?>>[];
  Timer? _nextStarts;
  bool _failed = false;
  bool _disposed = false;
  EmploymentDetails? _latest;

  WorkRegisterProjection? _register;
  Set<LocalDate>? _confirmedDates;
  List<WorkSchedule>? _schedules;
  PastPlannedDays? _past;
  List<PlannedDay>? _monthPlan;
  List<PlannedDay>? _ahead;

  /// Every new set of details.
  Stream<EmploymentDetails> get details => _out.stream;

  /// The last details; null before every feed has answered, or once one
  /// failed.
  EmploymentDetails? get latest => _failed ? null : _latest;

  /// Whether a feed failed: the box then shows no figures.
  bool get failed => _failed;

  void _listen<T>(Stream<T> feed, void Function(T value) take) {
    _feeds.add(
      feed.listen((value) {
        if (_failed || _disposed) return;
        take(value);
        _emit();
      }, onError: (Object error, StackTrace stack) => _fail()),
    );
  }

  void _fail() {
    if (_failed || _disposed) return;
    _failed = true;
    _stop();
    if (!_out.isClosed) _out.addError(StateError('Work details unreadable'));
  }

  void _emit() {
    final register = _register;
    final schedules = _schedules;
    final past = _past;
    final monthPlan = _monthPlan;
    final ahead = _ahead;
    if (register == null ||
        schedules == null ||
        past == null ||
        monthPlan == null ||
        ahead == null) {
      return;
    }
    // A plan removes a day as soon as it is confirmed. Wait until the
    // register contains that same set before replacing the displayed facts.
    final recordedDates = <LocalDate>{
      for (final row in register.shiftSheet)
        if (row.shift.state != ShiftState.voided && row.shift.schedule != null)
          row.shift.schedule!.plannedDate,
      for (final row in register.leaveSheet)
        if (row.record.isEffective) row.record.date,
    };
    if (!setEquals(recordedDates, _confirmedDates)) return;
    final now = work.clock.nowUtc();
    final next = ahead
        .whereType<PlannedShift>()
        .where((day) => day.startUtc.isAfter(now))
        .firstOrNull;
    _nextStarts?.cancel();
    if (next != null) {
      // When it starts it is no longer next (bead ejh.10).
      _nextStarts = Timer(
        next.startUtc.difference(now) + const Duration(milliseconds: 1),
        _emit,
      );
    }
    final period = _openPeriod(register.periodSheet);
    final details = EmploymentDetails(
      agreement: _agreement(register.agreementSheet),
      schedule: _schedule(schedules),
      openPeriod: period?.period,
      confirmedSoFar: period?.group?.expected,
      lastPayslip: _lastPayslip(register.payslipSheet),
      month: _monthFacts(register, past, monthPlan),
      nextShift: next,
      nextShiftStart: next == null
          ? null
          : work.timezones.localTimeAt(next.startUtc, next.timezoneId),
      periods: [for (final row in register.periodSheet) row.period]
        ..sort((a, b) => a.start.compareTo(b.start)),
    );
    _latest = details;
    if (!_out.isClosed) _out.add(details);
  }

  bool _inMonth(LocalDate date) =>
      date.year == month.year && date.month == month.month;

  bool _covers(LocalDate from, LocalDate? until) =>
      from.compareTo(today) <= 0 &&
      (until == null || until.compareTo(today) >= 0);

  PayAgreement? _agreement(List<AgreementSheetRow> rows) {
    final agreements = [for (final row in rows) row.agreement];
    return agreements
            .where((value) => _covers(value.effectiveStart, value.effectiveEnd))
            .lastOrNull ??
        agreements.lastOrNull;
  }

  WorkSchedule? _schedule(List<WorkSchedule> versions) => versions
      .where((value) => _covers(value.inUseFrom, value.inUseUntil))
      .lastOrNull;

  PeriodSheetRow? _openPeriod(List<PeriodSheetRow> rows) {
    final open = [
      for (final row in rows)
        if (row.period.state == PayPeriodState.open) row,
    ];
    return open
            .where((row) => _covers(row.period.start, row.period.end))
            .firstOrNull ??
        open.lastOrNull;
  }

  Payslip? _lastPayslip(List<Payslip> payslips) {
    Payslip? last;
    for (final payslip in payslips) {
      if (!payslip.isEffective) continue;
      if (last == null || payslip.issuedDate.compareTo(last.issuedDate) > 0) {
        last = payslip;
      }
    }
    return last;
  }

  MonthFacts _monthFacts(
    WorkRegisterProjection register,
    PastPlannedDays past,
    List<PlannedDay> plan,
  ) => MonthFacts(
    month: month,
    finalized: register.shiftSheet
        .where(
          (row) =>
              row.shift.state == ShiftState.finalized &&
              _inMonth(row.shift.localStartDate),
        )
        .length,
    toConfirm: past.toConfirm.where((day) => _inMonth(day.date)).length,
    withoutAgreementDays: [
      for (final day in past.withoutAgreement)
        if (_inMonth(day.date)) day.date,
    ]..sort(),
    planned: plan
        .whereType<PlannedShift>()
        .where((day) => day.date.compareTo(today) >= 0)
        .length,
    leave: {
      for (final day in plan.whereType<PlannedLeave>()) day.date,
      for (final row in register.leaveSheet)
        if (row.record.isEffective && _inMonth(row.record.date))
          row.record.date,
    }.length,
    off: plan.whereType<OffDay>().length,
  );

  void _stop() {
    _nextStarts?.cancel();
    for (final feed in _feeds) {
      unawaited(feed.cancel());
    }
    _feeds.clear();
  }

  void dispose() {
    _disposed = true;
    _stop();
    unawaited(_out.close());
  }
}
