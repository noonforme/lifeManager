import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/employment.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay_period.dart';
import '../../features/work/domain/payslip.dart';
import '../edit_session/confirm.dart';
import '../edit_session/leave_coordinator.dart';
import '../production_work_providers.dart';
import '../work_edit/pay_edit.dart';
import '../work_edit/work_records.dart';
import 'agreement_commands.dart' as commands show extendAgreement;
import 'agreements_sheet_controller.dart';
import 'employment_details.dart';
import 'employments_sheet_controller.dart';
import 'leave_sheet_controller.dart';
import 'location_store.dart';
import 'pay_sheet_controller.dart';
import 'schedules_sheet_controller.dart';
import 'shifts_filter.dart';
import 'shifts_rows.dart';
import 'shifts_sheet_controller.dart';
import 'work_history.dart';
import 'work_location.dart';

/// What the Work shell's status line says about places (spec 4.5).
abstract final class WorkShellNotices {
  static const employmentGone =
      'That employment no longer exists; showing the Work overview.';
  static const agreementGone =
      'That pay agreement no longer exists; showing the Agreements sheet.';
  static const scheduleGone =
      'That schedule no longer exists; showing the Schedules sheet.';
  static const recordGone = 'That shift no longer exists; showing its month.';
  static const unreadable =
      'Work could not be read from local storage. Try again.';
  static const placeUnreadable =
      'The place LifeOS was last closed on could not be read; starting as '
      'on a first run.';
}

bool _always() => true;

/// A pay sheet's Status with [period] or [slip] selected: kept while it
/// shows the record, else widened to All (bead 9pk.4.23). On Payslips null
/// is Effective; on Pay periods null is All.
String? _statusShowing(String? status, {PayPeriod? period, Payslip? slip}) {
  if (slip != null) {
    final shown = switch (status) {
      null => slip.isEffective,
      'void' => !slip.isEffective,
      _ => true,
    };
    return shown ? status : 'all';
  }
  if (period != null) {
    return status == null || status == period.state.name ? status : null;
  }
  return status;
}

/// An employment's past planned days not yet confirmed: those it can
/// confirm, and those no pay agreement covers (schedules spec 5).
typedef PastDayCounts = ({int toConfirm, int withoutAgreement});

/// A place as it exists now, what it fell back from, and whether it may
/// be remembered.
typedef _Resolved = ({WorkLocation place, String? notice, bool resolved});

/// The new shell's Work area (spec 4.5, 4.8): the current place, its Back
/// and Forward history, the sheet that shows it, and the one
/// [LeaveCoordinator] every record edit and action panel joins. Every move
/// to another place lets the current record go first; a selected row or
/// subform tab replaces the current place, so the route is always exact.
/// It holds no widgets: `WorkShell` renders it.
final class WorkShellController extends ChangeNotifier {
  WorkShellController({
    required this.work,
    required this.reads,
    required LocalDate today,
    required this.timezoneId,
    required Confirm confirm,
    required this.store,
    this.link,
  }) : _confirm = confirm,
       _today = today,
       _dayShown = today,
       coordinator = LeaveCoordinator(confirm: confirm);

  /// How often the local date is checked for a new day.
  static const dayCheck = Duration(minutes: 1);

  final ProductionWorkProviders work;
  final WorkReads reads;

  /// The local date: the day the shell started on, until [checkDay] finds
  /// a new one.
  LocalDate get today => _today;
  LocalDate _today;

  /// The day the open sheets were made on.
  LocalDate _dayShown;
  Timer? _dayTimer;

  /// Whether no editor holds a typed value; the shell that hosts the
  /// editors sets it. A new day waits for it.
  bool Function() editorClosed = _always;

  /// The zone new manual shifts are entered in.
  final String timezoneId;
  final LocationStore store;

  /// A `/work` link with a query to open instead of the remembered place
  /// (cutover spec 4g); null opens the remembered one.
  final Uri? link;
  final Confirm _confirm;

  /// Guards every way of leaving the current record, and closing.
  final LeaveCoordinator coordinator;

  WorkHistory _history = WorkHistory(const WorkLocation.overview());
  ShiftsSheetController? _sheet;
  EmploymentsSheetController? _employmentsSheet;
  AgreementsSheetController? _agreementsSheet;
  SchedulesSheetController? _schedulesSheet;
  PaySheetController? _paySheet;
  PaySheetController? get paySheet => _paySheet;
  LeaveSheetController? _leaveSheet;
  LeaveSheetController? get leaveSheet => _leaveSheet;
  List<EmploymentSummary> _employments = const [];
  StreamSubscription<List<EmploymentSummary>>? _employmentFeed;
  bool _employmentsFailed = false;
  final Map<EmploymentId, PastDayCounts> _pastDays = {};
  final Map<EmploymentId, StreamSubscription<Object?>> _pastFeeds = {};
  EmploymentDetailsSource? _details;
  StreamSubscription<EmploymentDetails>? _detailsFeed;
  String? _notice;
  String? _tab;

  /// The sheet's selection when it was last followed.
  String? _followed;
  bool _started = false;
  bool _resolved = false;
  bool _disposed = false;

  /// The move whose place is being shown: the sheet's selection follows
  /// it then, not the other way round.
  int? _showing;

  /// Counts moves: a move whose reads finish after a later one is dropped.
  int _moving = 0;

  /// The current place.
  WorkLocation get location => _history.current;
  bool get canBack => _history.canBack;
  bool get canForward => _history.canForward;

  /// The Shifts sheet of the current place; null elsewhere.
  ShiftsSheetController? get sheet => _sheet;

  /// The Employments sheet of the overview or an employment; null on
  /// Shifts.
  EmploymentsSheetController? get employmentsSheet => _employmentsSheet;

  /// The Agreements sheet of the current place; null elsewhere.
  AgreementsSheetController? get agreementsSheet => _agreementsSheet;

  /// The Schedules sheet of the current place; null elsewhere.
  SchedulesSheetController? get schedulesSheet => _schedulesSheet;

  /// Every employment, oldest first, with its sheet counts.
  List<EmploymentSummary> get employments => _employments;

  /// Whether the employments could not be read: [employments] is the last
  /// list read, and its counts are not shown.
  bool get employmentsFailed => _employmentsFailed;

  /// Each active employment's past days not yet confirmed, live; an
  /// employment whose days cannot be read has no entry.
  Map<EmploymentId, PastDayCounts> get pastDays => Map.unmodifiable(_pastDays);

  /// The current place's employment's details for the Details box; null
  /// on the overview, while they are read, or when they cannot be.
  EmploymentDetails? get details => _details?.latest;

  /// The current employment's pay periods by start: from its details, or
  /// while the details of another month load, the last ones read, so the
  /// Period combo and its steps keep to them.
  List<PayPeriod> get periods {
    if (details case final shown?) return shown.periods;
    final held = _heldPeriods;
    return held != null && held.$1 == location.employmentId
        ? held.$2
        : const [];
  }

  (EmploymentId, List<PayPeriod>)? _heldPeriods;

  /// Days to confirm over every active employment, for the status bar.
  /// Days no agreement covers are never in it.
  int get daysToConfirm =>
      _pastDays.values.fold(0, (sum, value) => sum + value.toConfirm);

  /// Whether the first place was shown.
  bool get started => _started;

  /// What the last move fell back from, until the next move.
  String? get notice => _notice;

  /// The subform tab shown; null for the first. It outlives a row the
  /// route cannot carry (a new shift) and goes into the route with the
  /// next selected row.
  String? get subTab => _tab;

  /// Opens [link], else the place last remembered in [store], resolved
  /// (spec 4.5). The first time it opens the first active employment's
  /// Calendar this month while one of its schedules is in use, else its
  /// Shifts this month, else the overview (addendum decision 2).
  Future<void> start() async {
    _employmentFeed = reads.watchEmployments().listen(
      (value) {
        _employments = value;
        _employmentsFailed = false;
        // Readable again: the words about it go (bead 9pk.4.4.1 item 6).
        if (_notice == WorkShellNotices.unreadable) _notice = null;
        // The open Schedules sheet follows its employment's status.
        if (_schedulesSheet case final sheet?) {
          sheet.archived =
              employment(sheet.employmentId)?.employment.status ==
              EmploymentStatus.archived;
        }
        if (_paySheet case final sheet?) {
          sheet.archived =
              employment(sheet.employmentId)?.employment.status ==
              EmploymentStatus.archived;
        }
        if (_leaveSheet case final sheet?) {
          sheet.archived =
              employment(sheet.employmentId)?.employment.status ==
              EmploymentStatus.archived;
        }
        // So does the open Shifts sheet (bead 9pk.4.14).
        if (_sheet case final sheet?) {
          sheet.archived =
              employment(sheet.employmentId)?.employment.status ==
              EmploymentStatus.archived;
        }
        _watchPastDays();
        _notify();
      },
      // The tree keeps the last list, without counts, and says why.
      onError: (Object error, StackTrace stack) {
        _employmentsFailed = true;
        _notice = WorkShellNotices.unreadable;
        _notify();
      },
    );
    final ticket = ++_moving;
    final remembered = link == null ? await store.read() : null;
    final parsed =
        link ?? (remembered == null ? null : Uri.tryParse(remembered));
    final _Resolved found;
    if (remembered != null && (parsed == null || parsed.path != '/work')) {
      // A place file this shell did not write starts as the first time
      // does, and says so (bead 9pk.4.28).
      final first = switch (await _firstPlace()) {
        final target? => await _resolve(target),
        null => _unreadable,
      };
      found = (
        place: first.place,
        notice: first.notice ?? WorkShellNotices.placeUnreadable,
        resolved: first.resolved,
      );
    } else if (parsed == null) {
      found = switch (await _firstPlace()) {
        final target? => await _resolve(target),
        null => _unreadable,
      };
    } else {
      final place = WorkLocation.parse(parsed, today: today);
      found = place.isLicences
          ? switch (await _firstPlace()) {
              final target? => await _resolve(target),
              null => _unreadable,
            }
          : await _resolve(place);
    }
    if (ticket != _moving || _disposed) return;
    _notice = found.notice;
    _resolved = found.resolved;
    _history = WorkHistory(found.place);
    await _show(found.place, ticket);
    if (ticket != _moving || _disposed) return;
    _started = true;
    _dayTimer = Timer.periodic(dayCheck, (_) => unawaited(checkDay()));
    _notify();
  }

  /// Follows the past days of every active employment, and of no other.
  void _watchPastDays() {
    final active = {
      for (final summary in _employments)
        if (summary.employment.status == EmploymentStatus.active)
          summary.employment.id,
    };
    for (final id in [..._pastFeeds.keys]) {
      if (active.contains(id)) continue;
      unawaited(_pastFeeds.remove(id)!.cancel());
      _pastDays.remove(id);
    }
    for (final id in active) {
      _pastFeeds[id] ??= work.plans
          .watchPastDays(id, today: today)
          .listen(
            (days) {
              _pastDays[id] = (
                toConfirm: days.toConfirm.length,
                withoutAgreement: days.withoutAgreement.length,
              );
              _notify();
            },
            onError: (Object error, StackTrace stack) {
              _pastDays.remove(id);
              _notice = WorkShellNotices.unreadable;
              _notify();
            },
          );
    }
  }

  /// The first place (addendum decision 2): the first active employment's
  /// Calendar this month when one of its schedules is in use today, else
  /// (or when its schedules cannot be read) its Shifts this month; the
  /// overview with no active employment; null when the employments cannot
  /// be read.
  Future<WorkLocation?> _firstPlace() async {
    final Employment? active;
    try {
      active = (await reads.employments())
          .where((value) => value.status == EmploymentStatus.active)
          .firstOrNull;
    } on Object {
      return null;
    }
    if (active == null) return const WorkLocation.overview();
    final month = today.firstOfMonth;
    try {
      final inputs = await work.plans.repository.planInputs(active.id);
      if (inputs.schedules.any((value) => value.isInUseOn(today))) {
        return WorkLocation.calendar(active.id, month: month);
      }
    } on Object {
      // Shifts shows without the schedules.
    }
    return WorkLocation.shifts(active.id, month: month);
  }

  /// Goes to [place] once the current record lets go, pushing it onto the
  /// history. Returns whether it finished showing the place without being
  /// overtaken; a place already entered remains in Back history even if a
  /// later move overtakes its asynchronous loading.
  Future<bool> go(WorkLocation place) =>
      _move(place, (resolved) => _history.push(resolved));

  /// Back, once the current record lets go.
  Future<bool> back() async {
    final previous = _history.previous;
    if (previous == null) return false;
    return _move(previous, (resolved) => _history.back(resolved));
  }

  /// Forward, once the current record lets go.
  Future<bool> forward() async {
    final next = _history.next;
    if (next == null) return false;
    return _move(next, (resolved) => _history.forward(resolved));
  }

  /// Shows the Shifts sheet from [from] to [to], keeping the filter and a
  /// selection inside the new scope (spec 4.5: it pushes a place).
  Future<bool> goScope(LocalDate from, LocalDate to) async {
    if (location.employmentId == null) return false;
    // The record lets go first: a filter set while it asks is in the
    // place the move starts from.
    if (!await coordinator.navigate(() {}) || _disposed) return false;
    final place = location;
    if (place.employmentId == null) return false;
    // Calendar and To confirm show whole months (plan 4d-2, call 1).
    if (place.daySelects) return go(place.withScope(from, to));
    if (place.sheet == WorkSheetKind.leave) {
      final date = _leaveSheet?.selectedRow?.record.date;
      return go(
        place.withScope(
          from,
          to,
          keepLeave:
              date != null &&
              date.compareTo(from) >= 0 &&
              date.compareTo(to) <= 0,
        ),
      );
    }
    if (place.sheet != WorkSheetKind.shifts) {
      return false;
    }
    // A selected stored shift stays selected when its date is inside.
    final date = switch (_sheet?.selectedRow) {
      StoredRow(:final shift) => shift.localStartDate,
      _ => null,
    };
    return go(
      place.withScope(
        from,
        to,
        keepShift:
            date != null &&
            date.compareTo(from) >= 0 &&
            date.compareTo(to) <= 0,
      ),
    );
  }

  /// Sets the Shifts filters (spec 3). It replaces the current place:
  /// nothing is left, so nothing is asked, and Back does not step through
  /// each change.
  void setFilter(ShiftsFilter filter) {
    final place = location.withFilter(filter);
    if (place == location) return;
    _history.replace(place);
    _notify();
  }

  /// Sets the Leave filters as [setFilter] does, except that a filter that
  /// would hide the selected leave selects the sheet instead once the
  /// record lets go, as the Pay filters do (bead 9pk.4.42).
  Future<bool> setLeaveFilter(ShiftsFilter filter) async {
    final sheet = _leaveSheet;
    final row = sheet?.selectedRow;
    if (sheet == null || row == null || sheet.admits(row, filter)) {
      setFilter(filter);
      return true;
    }
    return go(location.withLeave(null).withFilter(filter));
  }

  /// Steps the Shifts scope back (-1) or on (1): a whole month by a month,
  /// a pay period's dates to the neighbouring period (none past the first
  /// or last), any other range by its own length.
  Future<bool> stepScope(int direction) async {
    final place = location;
    final (from, to) = (place.from, place.to);
    if (from == null || to == null) return false;
    if (place.daySelects) {
      final month = from.firstOfMonth.addMonths(direction);
      // To confirm lists past days: no month after this one.
      if (place.sheet == WorkSheetKind.toConfirm &&
          month.compareTo(today.firstOfMonth) > 0) {
        return false;
      }
      return goScope(month, month.lastOfMonth);
    }
    if (place.sheet != WorkSheetKind.shifts &&
        place.sheet != WorkSheetKind.leave) {
      return false;
    }
    if (place.wholeMonth) {
      final month = from.addMonths(direction);
      return goScope(month, month.lastOfMonth);
    }
    final periods = this.periods;
    final index = periods.indexWhere(
      (period) => period.start == from && period.end == to,
    );
    if (index >= 0) {
      final next = index + direction;
      if (next < 0 || next >= periods.length) return false;
      return goScope(periods[next].start, periods[next].end);
    }
    final length = to.daysSince(from) + 1;
    return goScope(
      from.addDays(direction * length),
      to.addDays(direction * length),
    );
  }

  /// To confirm over All past days, from one of its months.
  Future<bool> goAllPastDays() async {
    final place = location;
    if (place.sheet != WorkSheetKind.toConfirm || place.allPastDays) {
      return false;
    }
    return go(place.withAllPastDays());
  }

  Future<bool> setPayFilter(String? status, PayPeriodId? period) {
    // Filters select the sheet rather than forcing the old selected record
    // through a filter that would hide it.
    return go(
      location
          .withPayRecord(null)
          .withPayFilter(status: status, period: period),
    );
  }

  /// Shows subform tab [tab]; the current place keeps it.
  void selectSub(String tab) {
    _tab = tab;
    _history.replace(location.withSub(tab));
    _notify();
  }

  Future<bool> _move(
    WorkLocation target,
    void Function(WorkLocation resolved) record,
  ) async {
    if (!await coordinator.navigate(() {})) return false;
    final ticket = ++_moving;
    final found = await _resolve(target);
    if (ticket != _moving || _disposed) return false;
    _notice = found.notice;
    // The Licences page is not remembered: the place before it decides.
    if (!found.place.isLicences) _resolved = found.resolved;
    record(found.place);
    await _show(found.place, ticket);
    // A later move overtook this one while it showed its place.
    if (ticket != _moving || _disposed) return false;
    _notify();
    return true;
  }

  /// [target] as it exists now (spec 4.5): a missing employment is the
  /// overview, a missing agreement or schedule its sheet, a missing shift its
  /// month with nothing selected, and a shift in another month that
  /// month. Its notice says what it fell back from. The caller takes it
  /// only while its move is the latest.
  Future<_Resolved> _resolve(WorkLocation target) async {
    final employment = target.employmentId;
    if (employment == null) {
      return (place: target, notice: null, resolved: true);
    }
    try {
      if (await reads.employment(employment) == null) {
        return (
          place: const WorkLocation.overview(),
          notice: WorkShellNotices.employmentGone,
          resolved: true,
        );
      }
      if (target.agreement case final id?) {
        if (await reads.agreement(employment, id) == null) {
          return (
            place: WorkLocation.agreements(employment),
            notice: WorkShellNotices.agreementGone,
            resolved: true,
          );
        }
      }
      if (target.schedule case final id?) {
        if (await reads.schedule(employment, id, version: target.version) ==
            null) {
          return (
            place: WorkLocation.schedules(employment),
            notice: WorkShellNotices.scheduleGone,
            resolved: true,
          );
        }
      }
      if (target.isPay) {
        if (target.periodFilter case final filter?) {
          if ((await reads.period(filter))?.employmentId != employment) {
            target = target.withPayFilter(
              status: target.payStatus,
              period: null,
            );
          }
        }
        if (target.payRecord case final id?) {
          final pay = id is PayPeriodId ? await reads.period(id) : null;
          final slip = id is PayslipId ? await reads.payslip(id) : null;
          final owner =
              pay?.employmentId ??
              (slip == null
                  ? null
                  : (await reads.period(slip.periodId))?.employmentId);
          if (owner != employment) {
            return (
              place: target.withPayRecord(null),
              notice: 'That record no longer exists in this employment; showing its sheet.',
              resolved: true,
            );
          }
          // A direct record link wins over a filter which would hide it.
          target = target.withPayFilter(
            status: _statusShowing(target.payStatus, period: pay, slip: slip),
            period:
                slip == null ||
                    target.periodFilter == null ||
                    target.periodFilter == slip.periodId
                ? target.periodFilter
                : null,
          );
        }
      }
      if (target.leave case final id?) {
        final record = await work.plans.repository.leaveById(id);
        if (record == null || record.employmentId != employment) {
          return (
            place: target.withLeave(null),
            notice: 'That leave no longer exists; showing the Leave sheet.',
            resolved: true,
          );
        }
        if ((target.filter.status == ShiftsStatusFilter.effective &&
                !record.isEffective) ||
            (target.filter.status == ShiftsStatusFilter.voided &&
                record.isEffective) ||
            (target.filter.type != null &&
                target.filter.type !=
                    (record.leaveType.name == 'sick' ? 'Sick' : 'Vacation'))) {
          target = target.withFilter(
            const ShiftsFilter(status: ShiftsStatusFilter.all),
          );
        }
        final date = record.date;
        if (date.compareTo(target.from!) < 0 ||
            date.compareTo(target.to!) > 0) {
          return (
            place: WorkLocation.leave(
              employment,
              month: date.firstOfMonth,
              leave: id,
              sub: target.sub,
              filter: target.filter,
            ),
            notice: null,
            resolved: true,
          );
        }
      }
      if (target.shift case final id?) {
        final record = await reads.shift(id);
        if (record == null || record.shift.employmentId != employment) {
          return (
            place: target.withRow(null),
            notice: WorkShellNotices.recordGone,
            resolved: true,
          );
        }
        final date = record.shift.localStartDate;
        final (first, last) = (target.from, target.to);
        if (first == null ||
            last == null ||
            date.compareTo(first) < 0 ||
            date.compareTo(last) > 0) {
          return (
            place: WorkLocation.shifts(
              employment,
              month: date.firstOfMonth,
              shift: id,
              sub: target.sub,
              filter: target.filter,
            ),
            notice: null,
            resolved: true,
          );
        }
      }
      return (place: target, notice: null, resolved: true);
    } on Object {
      return _unreadable;
    }
  }

  /// Nothing resolved: the overview, and nothing remembered.
  static const _Resolved _unreadable = (
    place: WorkLocation.overview(),
    notice: WorkShellNotices.unreadable,
    resolved: false,
  );

  /// Shows [place] for the move [ticket]: the Shifts sheet of its
  /// employment and month, reusing the open one when it is the same, with
  /// its row selected.
  Future<void> _show(WorkLocation place, int ticket) async {
    _tab = place.isPay
        ? place.sub ??
              (place.sheet == WorkSheetKind.periods
                  ? 'reconciliation'
                  : 'history')
        : place.sheet == WorkSheetKind.leave
        ? place.sub ?? 'history'
        : place.sub ?? _tab;
    _showing = ticket;
    try {
      await _showSheet(place, ticket);
    } finally {
      if (_showing == ticket) _showing = null;
    }
    // A later move shows its own place.
    if (ticket != _moving || _disposed) return;
    // The sheet may select less than asked: a day it does not plan, a
    // shift it does not list, an agreement or employment that is gone.
    if (location.isLicences) return;
    if (_employmentsSheet case final sheet?) {
      if (sheet.place != location) _history.replace(sheet.place);
    }
    if (_agreementsSheet case final sheet?) {
      if (sheet.place != location) _history.replace(sheet.place);
    }
    if (_paySheet case final sheet?) {
      final shown = location.withPayRecord(sheet.recordId).withSub(_tab);
      if (shown != location) _history.replace(shown);
    }
    if (_leaveSheet case final sheet?) {
      final shown = location.withLeave(sheet.selectedId).withSub(_tab);
      if (shown != location) _history.replace(shown);
    }
    if (_schedulesSheet case final sheet?) {
      if (sheet.place != location) _history.replace(sheet.place);
    }
    if (_sheet case final sheet?) {
      final shown = _selectionOf(sheet);
      if (shown != location) _history.replace(shown);
    }
  }

  /// The current place with [sheet]'s selection and the subform tab: a
  /// row on Shifts, a date on Calendar and To confirm.
  WorkLocation _selectionOf(ShiftsSheetController sheet) => location
      .withRow(sheet.selectedId, date: sheet.selectedRow?.date)
      .withSub(_tab);

  Future<void> _showSheet(WorkLocation place, int ticket) async {
    // The Licences page lies over the sheets, which stay as they are.
    if (place.isLicences) return;
    final employment = place.employmentId;
    final (from, to) = (place.from, place.to);
    if (employment != null && place.isPay) {
      _closeSheet();
      _closeEmployments();
      _closeAgreements();
      _closeSchedules();
      _closeLeave();
      final kind = place.sheet == WorkSheetKind.periods
          ? PayKind.periods
          : PayKind.payslips;
      var sheet = _paySheet;
      if (sheet == null ||
          sheet.employmentId != employment ||
          sheet.kind != kind) {
        _closePay();
        sheet = _paySheet = PaySheetController(
          kind: kind,
          work: work,
          reads: reads,
          employmentId: employment,
          today: today,
          coordinator: coordinator,
          confirm: _confirm,
          archived:
              this.employment(employment)?.employment.status ==
              EmploymentStatus.archived,
        )..start();
        sheet.addListener(_followPay);
        _notify();
      }
      await sheet.ready;
      if (!identical(sheet, _paySheet) || ticket != _moving) return;
      sheet.show(place.payRecord);
      return;
    }
    _closePay();
    if (employment != null && place.sheet == WorkSheetKind.leave) {
      _closeSheet();
      _closeEmployments();
      _closeAgreements();
      _closeSchedules();
      var sheet = _leaveSheet;
      if (sheet == null ||
          sheet.employmentId != employment ||
          sheet.from != from ||
          sheet.to != to) {
        _closeLeave();
        sheet = _leaveSheet = LeaveSheetController(
          work: work,
          employmentId: employment,
          from: from!,
          to: to!,
          coordinator: coordinator,
          confirm: _confirm,
          archived:
              this.employment(employment)?.employment.status ==
              EmploymentStatus.archived,
        )..start();
        sheet.addListener(_followLeave);
        _notify();
      }
      await sheet.ready;
      if (!identical(sheet, _leaveSheet) || ticket != _moving) return;
      sheet.show(place.leave);
      return;
    }
    _closeLeave();
    if (employment != null && place.sheet == WorkSheetKind.schedules) {
      _closeSheet();
      _closeEmployments();
      _closeAgreements();
      var sheet = _schedulesSheet;
      if (sheet == null || sheet.employmentId != employment) {
        _closeSchedules();
        sheet = _schedulesSheet = SchedulesSheetController(
          work: work,
          reads: reads,
          employmentId: employment,
          today: today,
          confirm: _confirm,
          coordinator: coordinator,
          archived:
              this.employment(employment)?.employment.status ==
              EmploymentStatus.archived,
        )..start();
        sheet.addListener(_followSchedules);
        _notify();
      }
      await sheet.ready;
      if (!identical(sheet, _schedulesSheet) || ticket != _moving) return;
      // The version shown stays while the same one is asked for.
      if (sheet.place != place || sheet.session == null) {
        await sheet.show(place.schedule, version: place.version);
      }
      return;
    }
    _closeSchedules();
    if (employment != null && place.sheet == WorkSheetKind.agreements) {
      _closeSheet();
      _closeEmployments();
      var sheet = _agreementsSheet;
      if (sheet == null || sheet.employmentId != employment) {
        _closeAgreements();
        sheet = _agreementsSheet = AgreementsSheetController(
          work: work,
          reads: reads,
          employmentId: employment,
          today: today,
          confirm: _confirm,
          coordinator: coordinator,
        )..start();
        sheet.addListener(_followAgreements);
        _notify();
      }
      await sheet.ready;
      if (!identical(sheet, _agreementsSheet) || ticket != _moving) return;
      await sheet.show(place.agreement);
      return;
    }
    _closeAgreements();
    final kind = place.sheet ?? WorkSheetKind.shifts;
    if (employment != null && kind == WorkSheetKind.toConfirm) {
      _closeEmployments();
      final (first, last) = place.allPastDays
          ? await _pastRange(employment)
          : (from!, to!);
      if (ticket != _moving || _disposed) return;
      await _showShifts(place, ticket, employment, kind, first, last);
      return;
    }
    if (employment == null || from == null || to == null) {
      _closeSheet();
      final sheet = _employmentsSheet ??= EmploymentsSheetController(
        work: work,
        reads: reads,
        today: today,
        confirm: _confirm,
        coordinator: coordinator,
      )..addListener(_followEmployments);
      _notify();
      await sheet.show(employment);
      return;
    }
    _closeEmployments();
    await _showShifts(place, ticket, employment, kind, from, to);
  }

  /// All past days of [employment] (plan 4d-2, call 4): from the first
  /// day any of its schedules is in use to yesterday; yesterday alone with
  /// no schedule, or one starting later, or when it cannot be read.
  Future<(LocalDate, LocalDate)> _pastRange(EmploymentId employment) async {
    final yesterday = today.addDays(-1);
    try {
      final schedules = (await work.plans.repository.planInputs(employment))
          .schedules;
      final first = schedules
          .map((value) => value.inUseFrom)
          .fold<LocalDate?>(
            null,
            (least, date) =>
                least == null || date.compareTo(least) < 0 ? date : least,
          );
      return first == null || first.compareTo(yesterday) > 0
          ? (yesterday, yesterday)
          : (first, yesterday);
    } on Object {
      return (yesterday, yesterday);
    }
  }

  /// Shows the rows of [employment] from [from] to [to] as [kind], reusing
  /// the open sheet when it is the same, with the place's row or day
  /// selected.
  Future<void> _showShifts(
    WorkLocation place,
    int ticket,
    EmploymentId employment,
    WorkSheetKind kind,
    LocalDate from,
    LocalDate to,
  ) async {
    var sheet = _sheet;
    if (sheet == null ||
        sheet.employmentId != employment ||
        sheet.kind != kind ||
        sheet.from != from ||
        sheet.to != to) {
      _closeSheet();
      sheet = _sheet = ShiftsSheetController(
        work: work,
        reads: reads,
        employmentId: employment,
        from: from,
        to: to,
        today: today,
        timezoneId: timezoneId,
        confirm: _confirm,
        coordinator: coordinator,
        archived:
            this.employment(employment)?.employment.status ==
            EmploymentStatus.archived,
        kind: kind,
      )..start();
      sheet.addListener(_followSheet);
      _notify();
    }
    // A sheet another move made may still be loading.
    await sheet.ready;
    if (!identical(sheet, _sheet) || ticket != _moving) return;
    final day = place.day;
    await sheet.show(
      place.daySelects
          ? (day == null ? null : sheet.rowIdOn(day))
          : place.rowId,
    );
  }

  /// A row selected in the sheet replaces the current place (spec 4.5).
  void _followSheet() {
    final sheet = _sheet;
    if (sheet != null && _showing == null && !location.isLicences) {
      final place = _selectionOf(sheet);
      final moved = place != location;
      if (moved) _history.replace(place);
      // A move's notice lasts until the selection changes, a new row
      // included, which changes no place.
      if (moved || sheet.selectedId != _followed) _notice = null;
      _followed = sheet.selectedId;
    }
    _notify();
  }

  /// The employment or agreement selected on the Employments sheet
  /// replaces the current place (spec 4.5).
  void _followEmployments() {
    final sheet = _employmentsSheet;
    if (sheet != null &&
        _showing == null &&
        !location.isLicences &&
        sheet.place != location) {
      _history.replace(sheet.place);
      _notice = null;
    }
    _notify();
  }

  /// The version selected on the Agreements sheet replaces the current
  /// place (spec 4.5).
  void _followAgreements() {
    final sheet = _agreementsSheet;
    if (sheet != null &&
        _showing == null &&
        !location.isLicences &&
        sheet.place != location) {
      _history.replace(sheet.place);
      _notice = null;
    }
    _notify();
  }

  /// Extend pay agreement… over [days] of the place's employment
  /// (schedules spec 6.6); its words become the notice.
  /// Once the current record and panel let go, since the change may
  /// reach the version they hold; closing waits for it.
  Future<void> extendAgreement(List<LocalDate> days) async {
    final employment = location.employmentId;
    if (employment == null) return;
    if (!await coordinator.navigate(() {}) || _disposed) return;
    final running = commands.extendAgreement(
      work: work,
      reads: reads,
      confirm: _confirm,
      employmentId: employment,
      days: days,
    );
    _extending = running;
    final String words;
    try {
      words = await running;
    } finally {
      if (identical(_extending, running)) _extending = null;
    }
    if (_disposed || words.isEmpty) return;
    _notice = words;
    _notify();
  }

  /// Extend pay agreement… as it runs.
  Future<String>? _extending;

  /// Confirm worked days… (plan 4d-2, owner pick 2B): To confirm over
  /// All past days, then its pick mode. Returns whether the panel opened.
  Future<bool> confirmWorkedDays() async {
    final employment = location.employmentId;
    if (employment == null) return false;
    final target = WorkLocation.toConfirm(employment);
    final there =
        location.sheet == WorkSheetKind.toConfirm &&
        location.allPastDays &&
        location.filter.isNone;
    if (!there && !await go(target)) return false;
    final sheet = _sheet;
    if (sheet == null || sheet.kind != WorkSheetKind.toConfirm) return false;
    await sheet.ready;
    return sheet.openConfirmDays();
  }

  Future<bool> addPay(PayKind kind, {PayPeriodId? period}) async {
    final employment = location.employmentId;
    if (employment == null) return false;
    final sheetKind = kind == PayKind.periods
        ? WorkSheetKind.periods
        : WorkSheetKind.payslips;
    if (_paySheet?.kind != kind &&
        !await go(
          WorkLocation.pay(employment, sheet: sheetKind, periodFilter: period),
        )) {
      return false;
    }
    return _paySheet?.add(period: period) ?? false;
  }

  /// Add employment… and File › New employment… (spec 4.9): on the
  /// Employments sheet, going there first.
  Future<bool> addEmployment() async {
    if (_employmentsSheet == null && !await go(const WorkLocation.overview())) {
      return false;
    }
    return _employmentsSheet?.addEmployment() ?? Future.value(false);
  }

  /// The version selected on the Schedules sheet replaces the current
  /// place (spec 4.5).
  void _followSchedules() {
    final sheet = _schedulesSheet;
    if (sheet != null &&
        _showing == null &&
        !location.isLicences &&
        sheet.place != location) {
      _history.replace(sheet.place);
      _notice = null;
    }
    _notify();
  }

  void _followPay() {
    final sheet = _paySheet;
    if (sheet != null && _showing == null && !location.isLicences) {
      var place = location.withPayRecord(sheet.recordId);
      if (sheet.selectedId != 'new' && place != location) {
        place = place.withPayFilter(
          status: _statusShowing(
            location.payStatus,
            period: sheet.selected?.period,
            slip: sheet.selected?.payslip,
          ),
          period:
              sheet.selected?.payslip != null &&
                  location.periodFilter != sheet.selected!.payslip!.periodId
              ? null
              : location.periodFilter,
        );
        _history.replace(place);
        _notice = null;
      }
    }
    _notify();
  }

  void _closePay() {
    final sheet = _paySheet;
    if (sheet == null) return;
    sheet.removeListener(_followPay);
    sheet.dispose();
    _paySheet = null;
  }

  void _followLeave() {
    final sheet = _leaveSheet;
    if (sheet != null && _showing == null && !location.isLicences) {
      var place = location.withLeave(sheet.selectedId);
      // A successful correction must show the replacement even when the
      // old type or Void filter would hide it.
      if (location.leave != sheet.selectedId &&
          sheet.corrected == sheet.selectedId) {
        place = place.withFilter(
          const ShiftsFilter(status: ShiftsStatusFilter.effective),
        );
      }
      if (place != location) {
        _history.replace(place);
        _notice = null;
      }
    }
    _notify();
  }

  void _closeLeave() {
    final sheet = _leaveSheet;
    if (sheet == null) return;
    sheet.removeListener(_followLeave);
    sheet.dispose();
    _leaveSheet = null;
  }

  void _closeSchedules() {
    final sheet = _schedulesSheet;
    if (sheet == null) return;
    sheet.removeListener(_followSchedules);
    sheet.dispose();
    _schedulesSheet = null;
  }

  void _closeAgreements() {
    final sheet = _agreementsSheet;
    if (sheet == null) return;
    sheet.removeListener(_followAgreements);
    sheet.dispose();
    _agreementsSheet = null;
  }

  void _closeEmployments() {
    final sheet = _employmentsSheet;
    if (sheet == null) return;
    sheet.removeListener(_followEmployments);
    sheet.dispose();
    _employmentsSheet = null;
  }

  void _closeSheet() {
    final sheet = _sheet;
    if (sheet == null) return;
    sheet.removeListener(_followSheet);
    sheet.dispose();
    _sheet = null;
  }

  /// Moves on to a new local day (bead 9pk.4.25): the past days and Details
  /// at once; the sheets shown once nothing is pending (no edit, panel,
  /// decision or open editor). Until then a sheet keeps the day it was
  /// made on. The place stays as it is.
  Future<void> checkDay() async {
    if (_disposed || !_started) return;
    final now = work.timezones.localDateAt(work.clock.nowUtc(), timezoneId);
    if (now != _today) {
      _today = now;
      for (final feed in _pastFeeds.values) {
        unawaited(feed.cancel());
      }
      _pastFeeds.clear();
      _pastDays.clear();
      _watchPastDays();
      _notify();
    }
    if (_dayShown == _today || _showing != null || location.isLicences) {
      return;
    }
    if (!coordinator.settled || !editorClosed()) return;
    final ticket = ++_moving;
    _dayShown = _today;
    _closeSheet();
    _closeEmployments();
    _closeAgreements();
    _closeSchedules();
    _closeLeave();
    _closePay();
    _notify();
    await _show(location, ticket);
    _notify();
  }

  /// The native close and File › Quit (spec 4.8): waits for a record
  /// command that runs, then asks every participant.
  Future<bool> mayQuit() async {
    await _extending;
    await _employmentsSheet?.settled();
    await _sheet?.settled();
    await _agreementsSheet?.settled();
    await _schedulesSheet?.settled();
    await _leaveSheet?.settled();
    await _paySheet?.settled();
    return coordinator.quit();
  }

  /// Remembers the current place for the next start (spec 4.5): only one
  /// that resolved.
  Future<void> remember() async {
    if (!_resolved) return;
    await store.write('${_lastWork.toUri()}');
  }

  /// Help › Licences (spec 4.9), once the current record lets go.
  Future<bool> openLicences() => go(const WorkLocation.licences());

  /// The last place that is not the Licences page: what [remember] keeps.
  WorkLocation get _lastWork {
    if (!location.isLicences) return location;
    return _history.previous ?? const WorkLocation.overview();
  }

  /// The employment [id]'s summary; null when it is not listed.
  EmploymentSummary? employment(EmploymentId id) =>
      _employments.where((value) => value.employment.id == id).firstOrNull;

  void _notify() {
    if (_disposed) return;
    _followDetails();
    notifyListeners();
  }

  /// Keeps one details source, for the current place's employment and
  /// month (this month off a month sheet).
  void _followDetails() {
    final employment = location.employmentId;
    final month = location.month ?? today.firstOfMonth;
    final source = _details;
    if (source != null &&
        source.employmentId == employment &&
        source.month == month &&
        source.today == today) {
      return;
    }
    if (source?.latest case final last?) {
      _heldPeriods = (source!.employmentId, last.periods);
    }
    _detailsFeed?.cancel();
    source?.dispose();
    _details = null;
    _detailsFeed = null;
    if (employment == null) return;
    final made = _details = EmploymentDetailsSource(
      work: work,
      employmentId: employment,
      month: month,
      today: today,
    );
    _detailsFeed = made.details.listen(
      (_) => _notify(),
      // The box keeps the name only; the status bar says why.
      onError: (Object error, StackTrace stack) {
        _notice = WorkShellNotices.unreadable;
        _notify();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _dayTimer?.cancel();
    unawaited(_detailsFeed?.cancel());
    _details?.dispose();
    unawaited(_employmentFeed?.cancel());
    for (final feed in _pastFeeds.values) {
      unawaited(feed.cancel());
    }
    _pastFeeds.clear();
    _closeSheet();
    _closeEmployments();
    _closeLeave();
    _closePay();
    _closeSchedules();
    _closeAgreements();
    super.dispose();
  }
}
