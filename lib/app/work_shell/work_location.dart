import 'package:flutter/foundation.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/work_record_ref.dart';
import 'shifts_filter.dart';
import 'shifts_rows.dart';
import 'shifts_subform.dart' show ShiftsSubformTab;

/// The sheets the Work shell shows under an employment.
enum WorkSheetKind {
  shifts,
  schedules,
  agreements,
  leave,
  periods,
  payslips,

  /// The month, each day in words (plan 4d-2).
  calendar,

  /// The past days to confirm, then those without a pay agreement.
  toConfirm;

  /// Its key in the tree and its word in the route.
  String get treeKey => name;
}

/// One place in Work (database shell spec 4.5): the Work overview, an
/// employment, or an employment's Shifts for one month with its selected
/// row and subform tab. It parses and formats the route
/// `/work?employment=…&sheet=shifts&from=…&to=…&record=shift:…&sub=…`; a
/// planned day is `day=` instead of `record=`, never both. Parsing never
/// fails: what does not make a valid place is dropped, leaving the nearest
/// valid one.
@immutable
final class WorkLocation {
  /// The Work tree root: the Employments sheet.
  const WorkLocation.overview()
    : leave = null,
      employmentId = null,
      agreement = null,
      sheet = null,
      _month = null,
      _from = null,
      _to = null,
      shift = null,
      day = null,
      sub = null,
      filter = ShiftsFilter.none,
      schedule = null,
      version = null,
      payRecord = null,
      periodFilter = null,
      payStatus = null,
      isLicences = false;

  /// Help › Licences, shown in place of the columns (spec 4.9). It is a
  /// place so Back returns from it, but it is never remembered.
  const WorkLocation.licences()
    : leave = null,
      employmentId = null,
      agreement = null,
      sheet = null,
      _month = null,
      _from = null,
      _to = null,
      shift = null,
      day = null,
      sub = null,
      filter = ShiftsFilter.none,
      schedule = null,
      version = null,
      payRecord = null,
      periodFilter = null,
      payStatus = null,
      isLicences = true;

  /// An employment's properties.
  const WorkLocation.employment(EmploymentId this.employmentId)
    : leave = null,
      agreement = null,
      sheet = null,
      _month = null,
      _from = null,
      _to = null,
      shift = null,
      day = null,
      sub = null,
      filter = ShiftsFilter.none,
      schedule = null,
      version = null,
      payRecord = null,
      periodFilter = null,
      payStatus = null,
      isLicences = false;

  /// The Agreements sheet of [employmentId], with the version [agreement]
  /// selected when given.
  const WorkLocation.agreements(
    EmploymentId this.employmentId, {
    this.agreement,
  }) : leave = null,
       sheet = WorkSheetKind.agreements,
       _month = null,
       _from = null,
       _to = null,
       shift = null,
       day = null,
       sub = null,
       filter = ShiftsFilter.none,
       schedule = null,
       version = null,
       payRecord = null,
       periodFilter = null,
       payStatus = null,
       isLicences = false;

  /// The Schedules sheet of [employmentId], with version [version] of
  /// [schedule] selected when given (its latest when [version] is null).
  const WorkLocation.schedules(
    EmploymentId this.employmentId, {
    this.schedule,
    this.version,
  }) : leave = null,
       agreement = null,
       sheet = WorkSheetKind.schedules,
       _month = null,
       _from = null,
       _to = null,
       shift = null,
       day = null,
       sub = null,
       filter = ShiftsFilter.none,
       payRecord = null,
       periodFilter = null,
       payStatus = null,
       isLicences = false;

  /// The Shifts sheet of [employmentId] over the whole month of [month],
  /// or from [from] to [to], with the stored [shift] or the planned [day]
  /// selected and [filter] applied.
  const WorkLocation.shifts(
    EmploymentId this.employmentId, {
    LocalDate? month,
    LocalDate? from,
    LocalDate? to,
    this.shift,
    this.day,
    this.sub,
    this.filter = ShiftsFilter.none,
  }) : leave = null,
       agreement = null,
       sheet = WorkSheetKind.shifts,
       _month = month,
       _from = from,
       _to = to,
       schedule = null,
       version = null,
       payRecord = null,
       periodFilter = null,
       payStatus = null,
       isLicences = false,
       assert(shift == null || day == null),
       assert((month == null) != (from == null || to == null));

  /// The Calendar of [employmentId] over the month of [month], with [day]
  /// selected (plan 4d-2, call 1). Only the filter's Type applies.
  const WorkLocation.calendar(
    EmploymentId this.employmentId, {
    required this._month,
    this.day,
    this.sub,
    this.filter = ShiftsFilter.none,
  }) : leave = null,
       agreement = null,
       sheet = WorkSheetKind.calendar,
       _from = null,
       _to = null,
       shift = null,
       schedule = null,
       version = null,
       payRecord = null,
       periodFilter = null,
       payStatus = null,
       isLicences = false;

  /// To confirm of [employmentId]: All past days, or one month [from] to
  /// [to], with [day] selected (plan 4d-2, call 1). Off days do not apply.
  const WorkLocation.toConfirm(
    EmploymentId this.employmentId, {
    LocalDate? from,
    LocalDate? to,
    this.day,
    this.sub,
    this.filter = ShiftsFilter.none,
  }) : leave = null,
       agreement = null,
       sheet = WorkSheetKind.toConfirm,
       _month = null,
       _from = from,
       _to = to,
       shift = null,
       schedule = null,
       version = null,
       payRecord = null,
       periodFilter = null,
       payStatus = null,
       isLicences = false,
       assert((from == null) == (to == null));

  /// Confirmed leave in a month or typed range. Facts are read-only;
  /// corrections have their own guarded action panel.
  const WorkLocation.leave(
    EmploymentId this.employmentId, {
    LocalDate? month,
    LocalDate? from,
    LocalDate? to,
    this.leave,
    this.sub,
    this.filter = const ShiftsFilter(status: ShiftsStatusFilter.effective),
  }) : sheet = WorkSheetKind.leave,
       _month = month,
       _from = from,
       _to = to,
       agreement = null,
       schedule = null,
       version = null,
       shift = null,
       day = null,
       payRecord = null,
       periodFilter = null,
       payStatus = null,
       isLicences = false,
       assert((month == null) != (from == null || to == null));

  /// Pay sheets list all periods, or payslips in one optional period.
  const WorkLocation.pay(
    EmploymentId this.employmentId, {
    required WorkSheetKind this.sheet,
    this.payRecord,
    this.periodFilter,
    this.payStatus,
    this.sub,
  }) : leave = null,
       agreement = null,
       schedule = null,
       version = null,
       _month = null,
       _from = null,
       _to = null,
       shift = null,
       day = null,
       filter = ShiftsFilter.none,
       isLicences = false,
       assert(
         sheet == WorkSheetKind.periods || sheet == WorkSheetKind.payslips,
       ),
       assert(
         payRecord == null ||
             sheet == WorkSheetKind.periods && payRecord is PayPeriodId ||
             sheet == WorkSheetKind.payslips && payRecord is PayslipId,
       );

  final WorkRecordId? payRecord;
  final PayPeriodId? periodFilter;
  final String? payStatus;
  bool get isPay =>
      sheet == WorkSheetKind.periods || sheet == WorkSheetKind.payslips;
  WorkLocation withPayRecord(WorkRecordId? id) => !isPay
      ? this
      : WorkLocation.pay(
          employmentId!,
          sheet: sheet!,
          payRecord: id,
          sub: id == null ? null : sub,
          periodFilter: periodFilter,
          payStatus: payStatus,
        );
  WorkLocation withPayFilter({String? status, Object? period = _keep}) => !isPay
      ? this
      : WorkLocation.pay(
          employmentId!,
          sheet: sheet!,
          payRecord: payRecord,
          sub: sub,
          periodFilter: identical(period, _keep)
              ? periodFilter
              : period as PayPeriodId?,
          payStatus: status,
        );

  final LeaveRecordId? leave;

  final EmploymentId? employmentId;

  /// The pay agreement selected on the Agreements sheet.
  final AgreementId? agreement;

  /// The schedule selected on the Schedules sheet, and its version (null:
  /// the latest).
  final ScheduleId? schedule;
  final int? version;
  final WorkSheetKind? sheet;

  final LocalDate? _month;
  final LocalDate? _from;
  final LocalDate? _to;

  /// The first day the sheet shows.
  LocalDate? get from => _from ?? _month?.firstOfMonth;

  /// The last day the sheet shows.
  LocalDate? get to => _to ?? _month?.lastOfMonth;

  /// The first day of the month [from] lies in: the month a whole-month
  /// scope shows, and the month Details and the tree go by.
  LocalDate? get month => from?.firstOfMonth;

  /// Whether the scope is exactly one calendar month.
  bool get wholeMonth {
    final (first, last) = (from, to);
    return first != null &&
        last != null &&
        first == first.firstOfMonth &&
        last == first.lastOfMonth;
  }

  /// Whether this is To confirm over All past days.
  bool get allPastDays => sheet == WorkSheetKind.toConfirm && _from == null;

  /// Whether the selection is a date ([day]): Calendar and To confirm.
  bool get daySelects =>
      sheet == WorkSheetKind.calendar || sheet == WorkSheetKind.toConfirm;

  /// The Shifts filters (spec 3); none off Shifts.
  final ShiftsFilter filter;
  final ShiftId? shift;
  final LocalDate? day;

  /// The subform tab ([ShiftsSubformTab]).
  final String? sub;

  /// Whether this is the Licences page.
  final bool isLicences;

  /// The longest scope a route may name, in days.
  static const _longest = 366;

  static const _tabs = {
    ShiftsSubformTab.breaks,
    ShiftsSubformTab.history,
    ShiftsSubformTab.working,
    ShiftsSubformTab.dayPlan,
  };

  /// The selected Shifts row's id; null when none is selected.
  String? get rowId => leave != null
      ? 'leave:${leave!.value}'
      : switch ((shift, day)) {
          (final id?, _) => shiftRowId(id),
          (_, final date?) => plannedRowId(date),
          _ => null,
        };

  /// This place with the Shifts row [rowId] selected instead: a stored
  /// shift, a planned day, or none. The new row has no id a route may
  /// carry (spec 4.5), so it selects none. The subform tab stays while a
  /// row is selected.
  WorkLocation withRow(String? rowId, {LocalDate? date}) {
    if (daySelects) {
      final selected = rowId == null ? null : date;
      return _day(day: selected, sub: selected == null ? null : sub);
    }
    final employment = employmentId;
    final (first, last) = (from, to);
    if (employment == null ||
        sheet != WorkSheetKind.shifts ||
        first == null ||
        last == null) {
      return this;
    }
    final (shift, day) = _target(rowId);
    return WorkLocation.shifts(
      employment,
      from: first,
      to: last,
      shift: shift,
      day: day,
      sub: shift == null && day == null ? null : sub,
      filter: filter,
    );
  }

  /// This place with the subform tab [tab].
  WorkLocation withSub(String? tab) {
    if (isPay) {
      return WorkLocation.pay(
        employmentId!,
        sheet: sheet!,
        payRecord: payRecord,
        sub:
            payRecord != null &&
                (sheet == WorkSheetKind.periods
                        ? {'history', 'reconciliation', 'evidence', 'payslips'}
                        : {'history'})
                    .contains(tab)
            ? tab
            : null,
        periodFilter: periodFilter,
        payStatus: payStatus,
      );
    }
    if (sheet == WorkSheetKind.leave) {
      return _leave(
        sub: leave != null && {'history', 'working'}.contains(tab) ? tab : null,
      );
    }
    if (daySelects) {
      return day == null ? this : _day(sub: _tabs.contains(tab) ? tab : null);
    }
    final employment = employmentId;
    final (first, last) = (from, to);
    if (employment == null || first == null || last == null || rowId == null) {
      return this;
    }
    return WorkLocation.shifts(
      employment,
      from: first,
      to: last,
      shift: shift,
      day: day,
      sub: _tabs.contains(tab) ? tab : null,
      filter: filter,
    );
  }

  /// This Shifts place over [first] to [last], keeping its filter. A
  /// planned day stays selected only inside the new scope; a stored shift,
  /// whose date the place does not know, only when [keepShift] says it
  /// lies there.
  WorkLocation withScope(
    LocalDate first,
    LocalDate last, {
    bool keepShift = false,
    bool keepLeave = false,
  }) {
    if (sheet == WorkSheetKind.leave) {
      if (last.compareTo(first) < 0) (first, last) = (last, first);
      if (last.compareTo(first.addDays(_longest - 1)) > 0) {
        last = first.addDays(_longest - 1);
      }
      return _leave(
        from: first,
        to: last,
        leave: keepLeave ? leave : null,
        sub: keepLeave ? sub : null,
      );
    }
    if (daySelects) {
      final month = first.firstOfMonth;
      final inside = day != null && day!.firstOfMonth == month;
      return _day(
        from: month,
        to: month.lastOfMonth,
        day: inside ? day : null,
        sub: inside ? sub : null,
      );
    }
    final employment = employmentId;
    if (employment == null || sheet != WorkSheetKind.shifts) return this;
    // As a route would: a backward range swaps, a long one is cut.
    if (last.compareTo(first) < 0) (first, last) = (last, first);
    if (last.compareTo(first.addDays(_longest - 1)) > 0) {
      last = first.addDays(_longest - 1);
    }
    final dayInside =
        day != null && day!.compareTo(first) >= 0 && day!.compareTo(last) <= 0;
    final shiftKept = shift != null && keepShift;
    return WorkLocation.shifts(
      employment,
      from: first,
      to: last,
      shift: shiftKept ? shift : null,
      day: dayInside ? day : null,
      sub: dayInside || shiftKept ? sub : null,
      filter: filter,
    );
  }

  /// This Shifts place with [value] as its filter.
  WorkLocation withFilter(ShiftsFilter value) {
    if (sheet == WorkSheetKind.leave) return _leave(filter: value);
    if (daySelects) return _day(filter: value);
    final employment = employmentId;
    final (first, last) = (from, to);
    if (employment == null || first == null || last == null) return this;
    return WorkLocation.shifts(
      employment,
      from: first,
      to: last,
      shift: shift,
      day: day,
      sub: sub,
      filter: value,
    );
  }

  /// This To confirm place over All past days, keeping its selection;
  /// any other place as it is.
  WorkLocation withAllPastDays() => sheet == WorkSheetKind.toConfirm
      ? WorkLocation.toConfirm(
          employmentId!,
          day: day,
          sub: sub,
          filter: filter,
        )
      : this;

  /// This Calendar or To confirm place with the given parts replaced; its
  /// filter keeps only what the sheet applies (call 1).
  WorkLocation _day({
    LocalDate? from,
    LocalDate? to,
    Object? day = _keep,
    Object? sub = _keep,
    ShiftsFilter? filter,
  }) {
    final employment = employmentId!;
    final selected = identical(day, _keep) ? this.day : day as LocalDate?;
    final tab = identical(sub, _keep) ? this.sub : sub as String?;
    final value = filter ?? this.filter;
    if (sheet == WorkSheetKind.calendar) {
      return WorkLocation.calendar(
        employment,
        month: from ?? this.from!,
        day: selected,
        sub: tab,
        filter: ShiftsFilter(type: value.type),
      );
    }
    return WorkLocation.toConfirm(
      employment,
      from: from ?? _from,
      to: to ?? _to,
      day: selected,
      sub: tab,
      filter: value.copyWith(offDays: false),
    );
  }

  WorkLocation _leave({
    LocalDate? from,
    LocalDate? to,
    Object? leave = _keep,
    Object? sub = _keep,
    ShiftsFilter? filter,
  }) => WorkLocation.leave(
    employmentId!,
    from: from ?? this.from!,
    to: to ?? this.to!,
    leave: identical(leave, _keep) ? this.leave : leave as LeaveRecordId?,
    sub: identical(sub, _keep) ? this.sub : sub as String?,
    filter: filter ?? this.filter,
  );

  WorkLocation withLeave(LeaveRecordId? id) => sheet == WorkSheetKind.leave
      ? _leave(leave: id, sub: id == null ? null : sub)
      : this;

  static const _keep = Object();

  /// This Agreements place with the version [id] selected instead, or
  /// none; any other place as it is.
  WorkLocation withAgreement(AgreementId? id) => switch (this) {
    WorkLocation(sheet: WorkSheetKind.agreements, :final employmentId?) =>
      WorkLocation.agreements(employmentId, agreement: id),
    _ => this,
  };

  /// This Schedules place with [version] of schedule [id] selected
  /// instead, or none; any other place as it is.
  WorkLocation withSchedule(ScheduleId? id, {int? version}) => switch (this) {
    WorkLocation(sheet: WorkSheetKind.schedules, :final employmentId?) =>
      WorkLocation.schedules(
        employmentId,
        schedule: id,
        version: id == null ? null : version,
      ),
    _ => this,
  };

  static (ShiftId?, LocalDate?) _target(String? rowId) {
    if (rowId == null) return (null, null);
    if (rowId.startsWith('shift:')) {
      return (ShiftId.tryParse(rowId.substring(6)), null);
    }
    if (rowId.startsWith('day:')) {
      return (null, LocalDate.tryParse(rowId.substring(4)));
    }
    return (null, null);
  }

  /// The route of this place.
  Uri toUri() {
    if (isLicences) return Uri.parse('/work?page=licences');
    final (first, last) = (from, to);
    final query = {
      'employment': ?employmentId?.value,
      if (sheet case final kind?) 'sheet': kind.treeKey,
      if ((first, last) case (final first?, final last?)) ...{
        'from': '$first',
        'to': '$last',
      },
      if (shift case final id?) 'record': 'shift:${id.value}',
      if (leave case final id?) 'record': 'leave:${id.value}',
      if (payRecord case final id?)
        'record': '${id is PayPeriodId ? 'payPeriod' : 'payslip'}:${id.value}',
      'period': ?periodFilter?.value,
      'payStatus': ?payStatus,
      if (agreement case final id?) 'record': 'agreement:${id.value}',
      if (schedule case final id?) 'record': 'schedule:${id.value}',
      if (schedule != null && version != null) 'version': '$version',
      if (day case final date?) 'day': '$date',
      'sub': ?sub,
      'status':
          ?(sheet == WorkSheetKind.leave &&
              filter.status == ShiftsStatusFilter.all
          ? 'all'
          : filter.status.routeWord),
      if (filter.type case final type?) 'type': Uri.encodeQueryComponent(type),
      if (filter.offDays) 'off': '1',
    };
    // Every value is an id, a date or a fixed word, so the route stays
    // readable: `record=shift:…` keeps its colon.
    return Uri.parse(
      query.isEmpty
          ? '/work'
          : '/work?${[for (final MapEntry(:key, :value) in query.entries) '$key=$value'].join('&')}',
    );
  }

  /// The place [uri] names, normalised (spec 4.5): `/today`, `/journal` and
  /// unknown paths are the overview; `mode=` and `add=` are ignored; a
  /// range that is not one whole month is the month of `from`, and none is
  /// the month of [today]; a `day=` outside the range moves the month to
  /// it; `record=` wins over `day=`; a sheet Phase 3 does not show falls
  /// back to its employment; an old link naming a shift or a day without
  /// a sheet opens Shifts.
  static WorkLocation parse(Uri uri, {required LocalDate today}) {
    if (uri.path != '/work') return const WorkLocation.overview();
    final Map<String, String> query;
    try {
      query = uri.queryParameters;
    } on FormatException {
      // A malformed percent sequence in a remembered route is not a place.
      return const WorkLocation.overview();
    }
    if (query['page'] == 'licences') return const WorkLocation.licences();
    final record = WorkRecordRef.tryParse(query['record']);
    final employment =
        EmploymentId.tryParse(query['employment']) ??
        switch (record) {
          WorkRecordRef(kind: WorkRecordKind.employment, :final id) =>
            id as EmploymentId,
          _ => null,
        };
    if (employment == null) return const WorkLocation.overview();
    // Old links name an agreement, a shift or a day without the sheet.
    if (query['sheet'] == 'agreements' ||
        (query['sheet'] == null && record?.kind == WorkRecordKind.agreement)) {
      return WorkLocation.agreements(
        employment,
        agreement: switch (record) {
          WorkRecordRef(kind: WorkRecordKind.agreement, :final id) =>
            id as AgreementId,
          _ => null,
        },
      );
    }
    if (query['sheet'] == 'schedules' ||
        (query['sheet'] == null && record?.kind == WorkRecordKind.schedule)) {
      final schedule = switch (record) {
        WorkRecordRef(kind: WorkRecordKind.schedule, :final id) =>
          id as ScheduleId,
        _ => null,
      };
      final version = int.tryParse(query['version'] ?? '');
      return WorkLocation.schedules(
        employment,
        schedule: schedule,
        version: schedule != null && version != null && version > 0
            ? version
            : null,
      );
    }
    if (query['sheet'] == 'periods' ||
        query['sheet'] == 'payslips' ||
        query['sheet'] == null &&
            (record?.kind == WorkRecordKind.payPeriod ||
                record?.kind == WorkRecordKind.payslip)) {
      final periods =
          query['sheet'] == 'periods' ||
          query['sheet'] == null && record?.kind == WorkRecordKind.payPeriod;
      final id = record?.id;
      final selected = periods
          ? (id is PayPeriodId ? id : null)
          : (id is PayslipId ? id : null);
      final status = query['payStatus'];
      return WorkLocation.pay(
        employment,
        sheet: periods ? WorkSheetKind.periods : WorkSheetKind.payslips,
        payRecord: selected,
        periodFilter: periods ? null : PayPeriodId.tryParse(query['period']),
        payStatus:
            (periods ? {'open', 'reviewed'} : {'all', 'void'}).contains(status)
            ? status
            : null,
        sub:
            selected != null &&
                (periods
                        ? {'history', 'reconciliation', 'evidence', 'payslips'}
                        : {'history'})
                    .contains(query['sub'])
            ? query['sub']
            : null,
      );
    }
    if (query['sheet'] == 'leave' ||
        (query['sheet'] == null && record?.kind == WorkRecordKind.leave)) {
      var first = LocalDate.tryParse(query['from'] ?? '');
      var last = LocalDate.tryParse(query['to'] ?? '');
      if (first == null || last == null) {
        first = (first ?? today).firstOfMonth;
        last = first.lastOfMonth;
      }
      if (last.compareTo(first) < 0) (first, last) = (last, first);
      if (last.compareTo(first.addDays(_longest - 1)) > 0) {
        last = first.addDays(_longest - 1);
      }
      final id = switch (record) {
        WorkRecordRef(kind: WorkRecordKind.leave, :final id) =>
          id as LeaveRecordId,
        _ => null,
      };
      return WorkLocation.leave(
        employment,
        from: first,
        to: last,
        leave: id,
        sub: id != null && {'history', 'working'}.contains(query['sub'])
            ? query['sub']
            : null,
        filter: ShiftsFilter(
          status: switch (query['status']) {
            'all' => ShiftsStatusFilter.all,
            'void' => ShiftsStatusFilter.voided,
            _ => ShiftsStatusFilter.effective,
          },
          type: {'Vacation', 'Sick'}.contains(query['type'])
              ? query['type']
              : null,
        ),
      );
    }
    if (query['sheet'] == 'calendar' || query['sheet'] == 'toConfirm') {
      return _parseDaySheet(employment, query, today);
    }
    final shifts =
        query['sheet'] == 'shifts' ||
        (query['sheet'] == null &&
            (record?.kind == WorkRecordKind.shift || query['day'] != null));
    if (!shifts) return WorkLocation.employment(employment);
    final shift = switch (record) {
      WorkRecordRef(kind: WorkRecordKind.shift, :final id) => id as ShiftId,
      _ => null,
    };
    final day = shift == null ? LocalDate.tryParse(query['day'] ?? '') : null;
    var first = LocalDate.tryParse(query['from'] ?? '');
    var last = LocalDate.tryParse(query['to'] ?? '');
    if (first == null || last == null) {
      // No whole range: the month of `from`, else of today.
      final month = (first ?? today).firstOfMonth;
      (first, last) = (month, month.lastOfMonth);
    }
    if (last.compareTo(first) < 0) (first, last) = (last, first);
    if (last.compareTo(first.addDays(_longest - 1)) > 0) {
      last = first.addDays(_longest - 1);
    }
    if (day != null && (day.compareTo(first) < 0 || day.compareTo(last) > 0)) {
      // A day outside the range shows its own month.
      (first, last) = (day.firstOfMonth, day.lastOfMonth);
    }
    final sub = query['sub'];
    return WorkLocation.shifts(
      employment,
      from: first,
      to: last,
      shift: shift,
      day: day,
      sub: (shift != null || day != null) && _tabs.contains(sub) ? sub : null,
      filter: ShiftsFilter(
        status: ShiftsStatusFilter.fromRoute(query['status']),
        type: switch (query['type']?.trim()) {
          final type? when type.isNotEmpty => type,
          _ => null,
        },
        offDays: query['off'] == '1',
      ),
    );
  }

  /// A Calendar or To confirm route (call 1): Calendar is always a whole
  /// month, of `from`, else of `day`, else of [today]; To confirm is the
  /// whole month `from`..`to` names, else All past days. A `day` outside
  /// the month moves Calendar to it and is dropped by To confirm.
  static WorkLocation _parseDaySheet(
    EmploymentId employment,
    Map<String, String> query,
    LocalDate today,
  ) {
    var first = LocalDate.tryParse(query['from'] ?? '');
    var last = LocalDate.tryParse(query['to'] ?? '');
    var day = LocalDate.tryParse(query['day'] ?? '');
    final status = ShiftsStatusFilter.fromRoute(query['status']);
    final type = switch (query['type']?.trim()) {
      final type? when type.isNotEmpty => type,
      _ => null,
    };
    final sub = query['sub'];
    String? tab() => day != null && _tabs.contains(sub) ? sub : null;
    if (query['sheet'] == 'calendar') {
      var month = (first ?? day ?? today).firstOfMonth;
      if (day != null && day.firstOfMonth != month) month = day.firstOfMonth;
      return WorkLocation.calendar(
        employment,
        month: month,
        day: day,
        sub: tab(),
        filter: ShiftsFilter(type: type),
      );
    }
    final whole =
        first != null &&
        last != null &&
        first == first.firstOfMonth &&
        last == first.lastOfMonth;
    // To confirm lists past days: no month after this one.
    if (whole && first.compareTo(today.firstOfMonth) > 0) {
      (first, last) = (today.firstOfMonth, today.lastOfMonth);
    }
    if (whole && day != null && day.firstOfMonth != first) day = null;
    return WorkLocation.toConfirm(
      employment,
      from: whole ? first : null,
      to: whole ? last : null,
      day: day,
      sub: tab(),
      filter: ShiftsFilter(status: status, type: type),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkLocation &&
      other.employmentId == employmentId &&
      other.agreement == agreement &&
      other.leave == leave &&
      other.payRecord == payRecord &&
      other.periodFilter == periodFilter &&
      other.payStatus == payStatus &&
      other.schedule == schedule &&
      other.version == version &&
      other.sheet == sheet &&
      other.from == from &&
      other.to == to &&
      other.filter == filter &&
      other.shift == shift &&
      other.day == day &&
      other.sub == sub &&
      other.isLicences == isLicences;

  @override
  int get hashCode => Object.hash(
    employmentId,
    agreement,
    leave,
    payRecord,
    periodFilter,
    payStatus,
    schedule,
    version,
    sheet,
    from,
    to,
    filter,
    shift,
    day,
    sub,
    isLicences,
  );

  @override
  String toString() => '${toUri()}';
}
