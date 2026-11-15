import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/time/local_date.dart';
import '../../features/work/domain/employment.dart';
import '../../features/work/domain/ids.dart';
import '../../ui/ui.dart';
import '../edit_session/confirm.dart';
import '../edit_session/window_close_guard.dart';
import '../production_work_providers.dart';
import '../work_edit/work_records.dart';
import 'agreements_sheet_controller.dart';
import 'agreements_sheet_part.dart';
import 'confirm_in_window.dart';
import 'employments_sheet_controller.dart';
import 'employments_sheet_part.dart';
import 'leave_sheet_controller.dart';
import 'leave_sheet_part.dart';
import 'location_store.dart';
import 'pay_sheet_part.dart';
import 'schedules_sheet_part.dart';
import 'shifts_edit.dart' show ShiftsField;
import 'shifts_filter.dart';
import 'shifts_filter_strip.dart';
import 'shifts_lines.dart';
import 'shifts_sheet_controller.dart';
import 'shifts_sheet_part.dart';
import 'shifts_subform.dart';
import 'work_details.dart';
import 'work_location.dart';
import 'work_menus.dart';
import 'work_shell_controller.dart';
import 'work_tree.dart';

export 'work_tree.dart' show employmentSheets, treeIdOf;

/// The words of the Work shell's own parts.
abstract final class WorkShellWords {
  static const noEmployment = 'No employment yet.';
  static const back = 'Back';
  static const forward = 'Forward';
  static const quit = 'Quit';
  static const newEmployment = 'New employment…';
  static const notBuilt = 'Not built yet';
  static const calendarOrder = 'The calendar is in date order.';
  static const oldestFirst = 'This sheet lists days oldest first.';
}

/// The window's title at [place] (as the old shell had it): the sheet,
/// the employment named [employmentName], or Work, then LifeOS.
String workWindowTitle(WorkLocation place, {String? employmentName}) {
  final name = switch (place) {
    WorkLocation(isLicences: true) => 'Licences',
    WorkLocation(employmentId: null) => 'Work',
    WorkLocation(sheet: final kind?) =>
      employmentSheets.firstWhere((sheet) => sheet.$4 == kind).$2,
    _ => employmentName ?? 'Work',
  };
  return '$name - LifeOS';
}

/// Runs [command] once the open editor's value is taken; nothing when the
/// editor refuses it. A command that throws is reported, never lost.
void runCommand(
  EditorSessionController editors,
  Future<Object?> Function() command,
) {
  if (!editors.flush().isAccepted) return;
  unawaited(
    command().then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) => FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'work shell',
        ),
      ),
    ),
  );
}

/// The new shell's Work area on AppFrame (spec 3, 4.5, 4.9): the object
/// tree of employments and their sheets, Back and Forward, the sheet of
/// the current place in the middle and property columns, and the status
/// bar, over a [WorkShellController]. Since Phase 4g it is the production
/// Work area, built by the app's one `/work` route on LifeOS's database.
final class WorkShell extends StatefulWidget {
  const WorkShell({
    required this.work,
    required this.reads,
    required this.today,
    required this.timezoneId,
    required this.store,
    this.closeApi,
    this.release,
    this.link,
    this.onTitle,
    super.key,
  });

  final ProductionWorkProviders work;
  final WorkReads reads;

  /// The day the shell starts on; it moves on at midnight
  /// ([WorkShellController.checkDay]).
  final LocalDate today;
  final String timezoneId;
  final LocationStore store;

  /// The window's close button. The shell guards it and File › Quit the
  /// same way (spec 4.8); null greys Quit.
  final WindowCloseApi? closeApi;

  /// Releases the database once the window may close and the place is
  /// remembered (spec 4.8).
  final Future<void> Function()? release;

  /// A `/work` link with a query to open instead of the remembered place.
  final Uri? link;

  /// Sets the window's title, "Shifts - LifeOS", as the place changes.
  final ValueChanged<String>? onTitle;

  @override
  State<WorkShell> createState() => WorkShellState();
}

final class WorkShellState extends State<WorkShell> {
  late final WorkShellController shell = WorkShellController(
    work: widget.work,
    reads: widget.reads,
    today: widget.today,
    timezoneId: widget.timezoneId,
    confirm: _confirm,
    store: widget.store,
    link: widget.link,
  );
  final editors = EditorSessionController();
  final Map<String, AppFramePanes> _panes = {};
  final _frame = GlobalKey<AppFrameState>();
  final _addMenu = GlobalKey<EraContextMenuState>();
  final _addAnchor = GlobalKey(debugLabel: 'Add key');

  /// The Agreements sheet's subform tab: History, or the docked
  /// properties on a narrow window.
  String _agreementsTab = 'history';
  String _schedulesTab = SchedulesSubformTab.cycle;
  String _leaveTab = 'history';

  /// Date range… was chosen: From and To show even over a whole month.
  bool _rangeOpen = false;

  /// The range boxes' dates until Apply or Enter.
  LocalDate? _draftFrom;
  final _fromFocus = FocusNode(debugLabel: 'Range From');
  final _toFocus = FocusNode(debugLabel: 'Range To');
  LocalDate? _draftTo;

  /// The toolbar's Find box; its text filters the Shifts lines as typed.
  final _find = TextEditingController();
  ShiftsSheetPart? _part;

  /// What a sheet says when it has nothing to tell: the last move's notice
  /// shows instead.
  static const _quiet = [
    ShiftsNotices.ready,
    ShiftsNotices.loading,
    EmploymentsNotices.ready,
    EmploymentsNotices.empty,
    EmploymentsNotices.onlyEnded,
    EmploymentsNotices.noAgreement,
    AgreementsNotices.ready,
    AgreementsNotices.loading,
    LeaveSheetWords.loading,
    LeaveSheetWords.ready,
    LeaveSheetWords.readOnlyStatus,
    LeaveSheetWords.voidedStatus,
  ];

  /// Closes the window once every record and panel lets go, remembering
  /// the place first (spec 4.5, 4.8).
  late final WindowCloseGuard? closeGuard = switch (widget.closeApi) {
    final api? => WindowCloseGuard(
      api: api,
      mayClose: () async {
        // The open editor's value goes into its record first.
        if (!editors.flush().isAccepted) return false;
        return shell.mayQuit();
      },
      beforeClose: () async {
        try {
          await shell.remember();
        } finally {
          // The database is released even when remembering fails; the
          // failure still reaches the guard.
          await widget.release?.call();
        }
      },
    ),
    null => null,
  };

  @override
  void initState() {
    super.initState();
    // A new day waits for a typed value to be taken or dropped.
    shell.editorClosed = () => editors.session == null;
    shell.addListener(_syncPart);
    _find.addListener(() {
      if (_part case final part? when part.find != _find.text) {
        part.find = _find.text;
        _redraw();
      }
    });
    shell.addListener(_syncTitle);
    unawaited(shell.start());
    if (closeGuard case final guard?) unawaited(guard.attach());
  }

  @override
  void dispose() {
    // The window may outlive the shell: its close button no longer asks
    // what is disposed here.
    if (closeGuard case final guard?) unawaited(guard.detach());
    shell.removeListener(_syncPart);
    _find.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _part?.dispose();
    shell.dispose();
    editors.dispose();
    super.dispose();
  }

  Future<ConfirmAnswer> _confirm(ConfirmRequest request) async =>
      mounted ? confirmInWindow(context, request) : ConfirmAnswer.cancel;

  /// Runs [command] once the open editor's value is taken.
  void _command(Future<Object?> Function() command) =>
      runCommand(editors, command);

  /// Makes the Shifts part again when the shell's sheet changes; never
  /// during a build.
  void _syncPart() {
    final sheet = shell.sheet;
    final part = _part;
    if (part != null && identical(part.sheet, sheet)) return;
    part?.dispose();
    // Another sheet (a move of any kind) spends the range boxes' draft.
    if (_rangeOpen || _draftFrom != null || _draftTo != null) _forgetRange();
    final made = _part = sheet == null
        ? null
        : ShiftsSheetPart(
            sheet: sheet,
            editors: editors,
            work: widget.work,
            today: shell.today,
            followShift: (id) => _command(
              () => shell.go(shell.location.withRow('shift:${id.value}')),
            ),
            followLeave: (id) => _command(
              () => shell.go(
                WorkLocation.leave(
                  sheet.employmentId,
                  month: sheet.month,
                  leave: id,
                ),
              ),
            ),
            extendAgreement: (date) =>
                _command(() => shell.extendAgreement([date])),
            extendAgreementOver: (days) =>
                _command(() => shell.extendAgreement(days)),
            pendingDays: () =>
                shell.pastDays[sheet.employmentId]?.toConfirm ?? 0,
            confirmWorkedDays: () => _command(shell.confirmWorkedDays),
          );
    // A move within the same sheet of the same employment keeps its sort.
    if (made != null &&
        part != null &&
        part.sheet.kind == made.sheet.kind &&
        part.sheet.employmentId == made.sheet.employmentId) {
      made
        ..sortColumn = part.sortColumn
        ..sortDescending = part.sortDescending;
    }
    // The part's own changes (the selected break) redraw the frame.
    made?.find = _find.text;
    made?.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  String? _title;

  /// Names the place in the window's title once the first place shows.
  void _syncTitle() {
    final onTitle = widget.onTitle;
    if (onTitle == null || !shell.started) return;
    final place = shell.location;
    final title = workWindowTitle(
      place,
      employmentName: switch (place.employmentId) {
        final id? => shell.employment(id)?.employment.name,
        null => null,
      },
    );
    if (title == _title) return;
    _title = title;
    onTitle(title);
  }

  /// The mouse's back and forward buttons walk the history as the orbs do.
  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons & kBackMouseButton != 0 && shell.canBack) {
      _command(shell.back);
    } else if (event.buttons & kForwardMouseButton != 0 && shell.canForward) {
      _command(shell.forward);
    }
  }

  void _selectNode(String id) {
    final parts = id.split(':');
    final employment = parts.length > 1 ? EmploymentId(parts[1]) : null;
    switch (parts.first) {
      case 'work':
        _command(() => shell.go(const WorkLocation.overview()));
      case 'employment':
        _command(() => shell.go(WorkLocation.employment(employment!)));
      case 'shifts':
        // The same employment keeps its scope and filter.
        final current = shell.location;
        final (from, to) = (current.from, current.to);
        _command(
          () => shell.go(
            current.employmentId == employment && from != null && to != null
                ? WorkLocation.shifts(
                    employment!,
                    from: from,
                    to: to,
                    filter: current.sheet == WorkSheetKind.leave
                        ? ShiftsFilter.none
                        : current.filter,
                  )
                : WorkLocation.shifts(
                    employment!,
                    month: shell.today.firstOfMonth,
                  ),
          ),
        );
      case 'calendar':
        // A month sheet of the same employment keeps its month and Type.
        final current = shell.location;
        if (current.employmentId == employment &&
            current.sheet == WorkSheetKind.calendar) {
          return;
        }
        final month = current.employmentId == employment && current.wholeMonth
            ? current.month!
            : shell.today.firstOfMonth;
        _command(
          () => shell.go(
            WorkLocation.calendar(
              employment!,
              month: month,
              filter:
                  current.employmentId == employment &&
                      current.sheet != WorkSheetKind.leave
                  ? ShiftsFilter(type: current.filter.type)
                  : ShiftsFilter.none,
            ),
          ),
        );
      case 'leave':
        final current = shell.location;
        if (current.employmentId == employment &&
            current.sheet == WorkSheetKind.leave) {
          return;
        }
        _command(
          () => shell.go(
            current.employmentId == employment &&
                    current.from != null &&
                    current.to != null
                ? WorkLocation.leave(
                    employment!,
                    from: current.from,
                    to: current.to,
                  )
                : WorkLocation.leave(
                    employment!,
                    month: shell.today.firstOfMonth,
                  ),
          ),
        );
      case 'toConfirm':
        final current = shell.location;
        if (current.employmentId == employment &&
            current.sheet == WorkSheetKind.toConfirm) {
          return;
        }
        _command(() => shell.go(WorkLocation.toConfirm(employment!)));
      case 'agreements' || 'schedules':
        // The sheet shown keeps its selection; another opens with none.
        final current = shell.location;
        final kind = parts.first == 'agreements'
            ? WorkSheetKind.agreements
            : WorkSheetKind.schedules;
        if (current.employmentId == employment && current.sheet == kind) {
          return;
        }
        _command(
          () => shell.go(
            kind == WorkSheetKind.agreements
                ? WorkLocation.agreements(employment!)
                : WorkLocation.schedules(employment!),
          ),
        );
      case 'periods' || 'payslips':
        final kind = parts.first == 'periods'
            ? WorkSheetKind.periods
            : WorkSheetKind.payslips;
        if (shell.location.employmentId == employment &&
            shell.location.sheet == kind) {
          return;
        }
        _command(() => shell.go(WorkLocation.pay(employment!, sheet: kind)));
    }
  }

  ToolbarItem _orbKey(
    String label,
    OrbGlyph glyph,
    Future<bool> Function()? go,
  ) => ToolbarItem(
    label: label,
    leading: Orb(
      glyph: glyph,
      tone: go == null ? OrbTone.grey : OrbTone.green,
      size: 18,
    ),
    onPressed: go == null ? null : () => _command(go),
  );

  /// The Employments part of the overview or an employment.
  EmploymentsSheetPart? _employmentsPart() => switch (shell.employmentsSheet) {
    final sheet? => EmploymentsSheetPart(
      sheet: sheet,
      editors: editors,
      today: shell.today,
      employments: shell.employments,
      unreadable: shell.employmentsFailed,
      daysToConfirm: switch (sheet.selected) {
        final id? => shell.pastDays[id]?.toConfirm ?? 0,
        null => 0,
      },
      openAgreement: (id) => _command(
        () => shell.go(WorkLocation.agreements(sheet.selected!, agreement: id)),
      ),
      openSchedules: () => _command(() async {
        final employment = sheet.selected!;
        final hasOne =
            (shell.employment(employment)?.counts.schedules ?? 0) > 0;
        if (!await shell.go(WorkLocation.schedules(employment))) return false;
        return hasOne || (await shell.schedulesSheet?.addSchedule() ?? false);
      }),
    ),
    null => null,
  };

  /// The Agreements part of an employment's Agreements place.
  AgreementsSheetPart? _agreementsPart() => switch (shell.agreementsSheet) {
    final sheet? => AgreementsSheetPart(
      sheet: sheet,
      editors: editors,
      work: widget.work,
      today: shell.today,
      employmentName:
          shell.employment(sheet.employmentId)?.employment.name ?? '',
      onEmployment: () =>
          unawaited(shell.go(WorkLocation.employment(sheet.employmentId))),
    ),
    null => null,
  };

  /// The Schedules part of an employment's Schedules place.
  SchedulesSheetPart? _schedulesPart() => switch (shell.schedulesSheet) {
    final sheet? => SchedulesSheetPart(
      sheet: sheet,
      editors: editors,
      work: widget.work,
      today: shell.today,
      employmentName:
          shell.employment(sheet.employmentId)?.employment.name ?? '',
      onEmployment: () =>
          unawaited(shell.go(WorkLocation.employment(sheet.employmentId))),
    ),
    null => null,
  };

  LeaveSheetPart? _leavePart() => switch (shell.leaveSheet) {
    final sheet? => LeaveSheetPart(
      sheet: sheet,
      editors: editors,
      today: shell.today,
      filter: shell.location.filter,
      employmentName:
          shell.employment(sheet.employmentId)?.employment.name ?? '',
      onEmployment: () =>
          _command(() => shell.go(WorkLocation.employment(sheet.employmentId))),
      onAgreement: (id) => _command(
        () => shell.go(
          WorkLocation.agreements(sheet.employmentId, agreement: id),
        ),
      ),
      onSchedule: (id, version) => _command(
        () => shell.go(
          WorkLocation.schedules(
            sheet.employmentId,
            schedule: id,
            version: version,
          ),
        ),
      ),
      onLeave: (id) => _command(
        () => shell.go(
          shell.location
              .withLeave(id)
              .withFilter(const ShiftsFilter(status: ShiftsStatusFilter.all)),
        ),
      ),
    ),
    null => null,
  };

  PaySheetPart? _payPart() => switch (shell.paySheet) {
    final sheet? => PaySheetPart(
      sheet: sheet,
      editors: editors,
      place: shell.location,
      today: shell.today,
      employmentName:
          shell.employment(sheet.employmentId)?.employment.name ?? '',
      go: (place) => _command(() => shell.go(place)),
      addPay: (kind, period) =>
          _command(() => shell.addPay(kind, period: period)),
      setFilter: (status, period) =>
          _command(() => shell.setPayFilter(status, period)),
    ),
    null => null,
  };

  Widget _toolbar(
    ToolbarItem? tree,
    ShiftsSheetPart? part,
    EmploymentsSheetPart? employments,
    AgreementsSheetPart? agreements, [
    SchedulesSheetPart? schedules,
    LeaveSheetPart? leave,
    PaySheetPart? pay,
  ]) => BandedToolbar(
    // Two rows on every sheet: the record's keys and Find on the first, the
    // sheet's own commands on the second, so the panes never move.
    rows: 2,
    trailingWidth: 230,
    trailing: _findBox(enabled: part != null),
    bands: [
      if (tree != null) ToolbarBand(items: [tree]),
      ToolbarBand(
        items: [
          _orbKey(
            WorkShellWords.back,
            OrbGlyph.back,
            shell.canBack ? shell.back : null,
          ),
          _orbKey(
            WorkShellWords.forward,
            OrbGlyph.forward,
            shell.canForward ? shell.forward : null,
          ),
        ],
      ),
      ToolbarBand(
        items: [
          ToolbarItem(
            label: 'Add',
            leading: KeyedSubtree(
              key: _addAnchor,
              child: const Orb(
                glyph: OrbGlyph.add,
                tone: OrbTone.orange,
                size: 18,
              ),
            ),
            dropArrow: true,
            onPressed: () => _openAdd(part, agreements, schedules, pay),
          ),
        ],
      ),
      ...?part?.bands(),
      if (part != null) _dataBand(part),
      ...?employments?.bands(),
      ...?agreements?.bands(),
      ...?schedules?.bands(),
      ...?leave?.bands(),
      ...?pay?.bands(),
    ],
  );

  /// The toolbar's Find box, "Find:" beside it as on the era's toolbars. It
  /// filters the Calendar, Shifts and To confirm sheets and rests, greyed in
  /// place, on every other sheet.
  Widget _findBox({required bool enabled}) {
    final skin = LifeOSSkinScope.of(context);
    final on = enabled && EraFormScope.enabledOf(context);
    return Row(
      children: [
        ExcludeSemantics(
          child: Text(
            'Find:',
            style: skin.typography.body.copyWith(
              color: on ? skin.tokens.ink : skin.tokens.muted,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: EraFormScope(
            enabled: on,
            // Data entry (spec 4.6): Esc drops the typed text; Enter and Tab
            // stay in the box, so no key reaches the sheet's chrome.
            child: EraEditorHostScope(
              bare: true,
              onKey: (key) {
                if (key == EraEditorKey.escape) _find.clear();
              },
              child: EraField(
                key: const ValueKey('work-find'),
                controller: _find,
                label: 'Find',
                semanticLabel: 'Find in the sheet',
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<AppMenu> _menus(
    ShiftsSheetPart? part,
    EmploymentsSheetPart? employments,
    AgreementsSheetPart? agreements,
    SchedulesSheetPart? schedules,
    String paneKey,
    LeaveSheetPart? leave,
    PaySheetPart? pay, {
    required bool treeFolded,
  }) {
    return workMenus(
      place: shell.location,
      onNewEmployment: shell.employmentsFailed
          ? null
          : () => _command(shell.addEmployment),
      newEmploymentBlocked: EmploymentsWords.unreadable,
      onQuit: switch (closeGuard) {
        final guard? => () => unawaited(guard.requestClose()),
        null => null,
      },
      edit: _resting(
        part?.editMenu() ??
            employments?.editMenu() ??
            agreements?.editMenu() ??
            schedules?.editMenu() ??
            leave?.editMenu() ??
            pay?.editMenu() ??
            const [],
      ),
      onBack: shell.canBack ? () => _command(shell.back) : null,
      onForward: shell.canForward ? () => _command(shell.forward) : null,
      onSheet: (key) =>
          _selectNode('$key:${shell.location.employmentId!.value}'),
      record: _resting(
        part?.recordMenu() ??
            employments?.recordMenu() ??
            agreements?.recordMenu() ??
            schedules?.recordMenu() ??
            leave?.recordMenu() ??
            pay?.recordMenu() ??
            const [],
      ),
      onTree: treeFolded && !shell.location.isLicences
          ? () => _frame.currentState?.openTree()
          : null,
      treeBlocked: shell.location.isLicences ? WorkMenuWords.onLicences : null,
      onRestorePanes: () =>
          setState(() => _panes[paneKey] = AppFramePanes.baseline),
      onLicences: () => _command(shell.openLicences),
    );
  }

  /// [items] as they are on a sheet, greyed while Licences shows.
  List<EraMenuItem> _resting(List<EraMenuItem> items) => [
    for (final item in items)
      if (item.separator || !shell.location.isLicences)
        item
      else
        EraMenuItem(
          item.label,
          null,
          icon: item.icon,
          disabledReason: WorkMenuWords.onLicences,
        ),
  ];

  /// [grid] at least AppFrame's grid minimum tall. The frame keeps the
  /// middle that tall, but for the one frame in which the filter strip
  /// grows (Date range… opens) it is shorter: the grid then scrolls into
  /// view rather than overflow.
  Widget _atLeastGrid(Widget grid) => LayoutBuilder(
    builder: (context, constraints) {
      final least =
          AppFrame.minGrid * MediaQuery.textScalerOf(context).scale(1);
      if (constraints.maxHeight >= least) return grid;
      return SingleChildScrollView(
        child: SizedBox(height: least, child: grid),
      );
    },
  );

  /// The toolbar's Data band (spec 3): Filter by selection, Remove filter
  /// and Sort.
  ToolbarBand _dataBand(ShiftsSheetPart part) {
    final selection = part.selectionFilter;
    final clear = _clearOf(part, shell.location);
    final sorted = part.sortColumn == ShiftsField.date
        ? 'Date'
        : part.sortColumn[0].toUpperCase() + part.sortColumn.substring(1);
    return ToolbarBand(
      row: 1,
      items: [
        ToolbarItem(
          label: 'Filter by selection',
          tooltip: selection == null ? 'Select a row first.' : null,
          onPressed: selection == null
              ? null
              : () => shell.setFilter(selection),
        ),
        ToolbarItem(
          label: 'Remove filter',
          tooltip: clear == null ? 'No filter is set.' : null,
          onPressed: clear,
        ),
        ToolbarItem(
          label: 'Sort',
          tooltip: switch (part.sheet.kind) {
            WorkSheetKind.calendar => WorkShellWords.calendarOrder,
            WorkSheetKind.toConfirm => WorkShellWords.oldestFirst,
            _ => 'Sorts by $sorted the other way.',
          },
          // The open cell's value goes in first, as a header click's does
          // (bead 9pk.4.46); a rejected value stops the sort.
          onPressed: part.sheet.kind == WorkSheetKind.shifts
              ? () => _command(() async => part.reverseSort())
              : null,
        ),
      ],
    );
  }

  /// Clear and Remove filter: every filter and Find back to none; null
  /// while none is set.
  VoidCallback? _clearOf(ShiftsSheetPart part, WorkLocation place) =>
      place.filter.isNone && part.find.trim().isEmpty
      ? null
      : () {
          _find.clear();
          shell.setFilter(ShiftsFilter.none);
        };

  /// Moves the Shifts scope; the range boxes' draft is spent.
  void _goScope(LocalDate from, LocalDate to) {
    _forgetRange();
    _command(() => shell.goScope(from, to));
  }

  void _forgetRange() => setState(() {
    _rangeOpen = false;
    _draftFrom = null;
    _draftTo = null;
  });

  /// The Shifts sheet's filter strip over its grid (spec 3).
  Widget _filterStrip(ShiftsSheetPart part, WorkLocation place) =>
      shiftsFilterStrip(
        // Under the Licences page the hidden sheet keeps its own scope.
        place: place.isLicences
            ? WorkLocation.shifts(
                part.sheet.employmentId,
                from: part.sheet.from,
                to: part.sheet.to,
                filter: part.filter,
              )
            : place,
        types: {for (final line in part.allLines) ?line.type}.toList(),
        periods: shell.periods,
        today: shell.today,
        rangeOpen: _rangeOpen,
        fromFocus: _fromFocus,
        toFocus: _toFocus,
        onScope: _goScope,
        draftFrom: _draftFrom,
        draftTo: _draftTo,
        onDraft: (from, to) => setState(() {
          _draftFrom = from;
          _draftTo = to;
        }),
        onApply: () {
          final (from, to) = (place.from, place.to);
          if (from == null || to == null) return;
          // A backward or overlong range is swapped or cut on the way.
          _goScope(_draftFrom ?? from, _draftTo ?? to);
        },
        onStep: (direction) {
          _forgetRange();
          _command(() => shell.stepScope(direction));
        },
        onFilter: shell.setFilter,
        onRange: () => setState(() => _rangeOpen = true),
        onClear: _clearOf(part, place),
      );

  Widget _leaveStrip(LeaveSheetPart part, WorkLocation place) {
    final shown = place.isLicences ? part.sheet.place : place;
    return shiftsFilterStrip(
      place: shown,
      types: const ['Vacation', 'Sick'],
      periods: shell.periods,
      today: shell.today,
      leave: true,
      rangeOpen: _rangeOpen,
      fromFocus: _fromFocus,
      toFocus: _toFocus,
      onScope: _goScope,
      draftFrom: _draftFrom,
      draftTo: _draftTo,
      onDraft: (from, to) => setState(() {
        _draftFrom = from;
        _draftTo = to;
      }),
      onApply: () => _goScope(_draftFrom ?? shown.from!, _draftTo ?? shown.to!),
      onStep: (direction) {
        _forgetRange();
        _command(() => shell.stepScope(direction));
      },
      onFilter: (filter) => _command(() => shell.setLeaveFilter(filter)),
      onRange: () => setState(() => _rangeOpen = true),
      onClear:
          shown.filter ==
              const ShiftsFilter(status: ShiftsStatusFilter.effective)
          ? null
          : () => _command(
              () => shell.setLeaveFilter(
                const ShiftsFilter(status: ShiftsStatusFilter.effective),
              ),
            ),
    );
  }

  /// The Calendar's filter strip (plan 4d-2): whole months only.
  Widget _calendarStrip(ShiftsSheetPart part, WorkLocation place) {
    final shown = place.isLicences
        ? WorkLocation.calendar(
            part.sheet.employmentId,
            month: part.sheet.month,
            filter: part.filter,
          )
        : place;
    return calendarFilterStrip(
      place: shown,
      types: part.sheet.shiftTypeNames,
      onMonth: (month) => _goScope(month, month.lastOfMonth),
      onStep: (direction) => _command(() => shell.stepScope(direction)),
      onFilter: shell.setFilter,
      onClear: _clearOf(part, shown),
    );
  }

  /// To confirm's filter strip (plan 4d-2): All past days or a month.
  Widget _toConfirmStrip(ShiftsSheetPart part, WorkLocation place) {
    final shown = place.isLicences
        ? WorkLocation.toConfirm(part.sheet.employmentId, filter: part.filter)
        : place;
    return toConfirmFilterStrip(
      place: shown,
      types: {for (final line in part.allLines) ?line.type}.toList(),
      today: shell.today,
      enabled: part.sheet.confirmDays == null,
      onMonth: (month) => month == null
          ? _command(shell.goAllPastDays)
          : _goScope(month, month.lastOfMonth),
      onStep: (direction) => _command(() => shell.stepScope(direction)),
      onFilter: shell.setFilter,
      onClear: _clearOf(part, shown),
    );
  }

  /// Opens the Add menu under its key.
  void _openAdd(
    ShiftsSheetPart? part,
    AgreementsSheetPart? agreements,
    SchedulesSheetPart? schedules,
    PaySheetPart? pay,
  ) {
    final anchor = _addAnchor.currentContext?.findRenderObject();
    if (anchor is! RenderBox) return;
    _addMenu.currentState?.show(
      anchor.localToGlobal(Offset(-4, anchor.size.height + 6)),
      workAddItems(
        onEmployment: shell.employmentsFailed
            ? null
            : () => _command(shell.addEmployment),
        employmentBlocked: EmploymentsWords.unreadable,
        onManualShift:
            part == null ||
                shell.location.isLicences ||
                part.sheet.addBlocked != null
            ? null
            : () => _command(part.sheet.addShift),
        manualShiftBlocked: shell.location.isLicences
            ? null
            : part?.sheet.addBlocked,
        sheetItems: shell.location.isLicences
            ? const []
            : part?.addItems() ??
                  agreements?.addItems() ??
                  schedules?.addItems() ??
                  pay?.addItems() ??
                  const [],
      ),
    );
  }

  /// The status line: what the sheet says about its record, else a greyed
  /// node's word, else what the last move fell back from, else the
  /// sheet's own quiet word.
  String _notice(
    ShiftsSheetPart? part,
    List<ShiftsLine> lines,
    EmploymentsSheetPart? employments,
    AgreementsSheetPart? agreements,
    SchedulesSheetPart? schedules,
    LeaveSheetPart? leave,
    PaySheetPart? pay,
  ) {
    final own =
        part?.notice(lines) ??
        employments?.notice() ??
        agreements?.notice() ??
        schedules?.notice() ??
        leave?.notice() ??
        pay?.notice() ??
        (shell.started ? ShiftsNotices.ready : ShiftsNotices.loading);
    final quiet =
        _quiet.contains(own) ||
        (part != null && own == part.sheet.readOnlyReason);
    if (!quiet) return own;
    return shell.notice ?? own;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The shell tells of every change of its sheet too.
    listenable: shell,
    builder: (context, _) {
      final part = _part?..filter = shell.location.filter;
      final employmentsPart = _employmentsPart();
      final agreementsPart = _agreementsPart();
      final schedulesPart = _schedulesPart();
      final leavePart = _leavePart();
      final payPart = _payPart();
      final schedulesTabs = schedulesPart?.subformTabs() ?? const [];
      // The view's tabs change (versions or types); the docked Properties
      // tab stays.
      final schedulesTab =
          _schedulesTab == AppFrame.propertiesTabId ||
              schedulesTabs.any((tab) => tab.id == _schedulesTab)
          ? _schedulesTab
          : schedulesTabs.firstOrNull?.id;
      final place = shell.location;
      final lines = part?.lines ?? const [];
      final selected = lines
          .where((line) => line.id == part?.sheet.selectedId)
          .firstOrNull;
      final employment = switch (place.employmentId) {
        final id? => shell.employment(id)?.employment,
        null => null,
      };
      final paneKey = part != null
          ? 'shifts'
          : agreementsPart != null
          ? 'agreements'
          : schedulesPart != null
          ? 'schedules'
          : leavePart != null
          ? 'leave'
          : payPart != null
          ? payPart.periods
                ? 'periods'
                : 'payslips'
          : 'employments';
      final panes =
          _panes[paneKey] ??
          (paneKey == 'schedules'
              ? const AppFramePanes(dock: 236)
              : AppFramePanes.baseline);
      final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        // The frame's own fold decision at its width, so Window › Tree
        // follows a resize in the same frame.
        child: LayoutBuilder(
          builder: (context, constraints) => EraContextMenu(
            key: _addMenu,
            child: AppFrame(
              key: _frame,
              page: place.isLicences
                  ? LicencesPage(onBack: () => _command(shell.back))
                  : null,
              controller: editors,
              menus: _menus(
                part,
                employmentsPart,
                agreementsPart,
                schedulesPart,
                paneKey,
                leavePart,
                payPart,
                treeFolded: AppFrameLayout.resolve(
                  width: constraints.maxWidth,
                  scale: scale,
                  panes: panes,
                ).treeFolded,
              ),
              // While Licences shows, the hidden sheet's commands rest.
              toolbarBuilder: (context, tree) => place.isLicences
                  ? _toolbar(tree, null, null, null)
                  : _toolbar(
                      tree,
                      part,
                      employmentsPart,
                      agreementsPart,
                      schedulesPart,
                      leavePart,
                      payPart,
                    ),
              areas: const [
                TabItem(id: 'work', label: 'Work', icon: EraIconKind.work),
                TabItem(
                  id: 'finance',
                  label: 'Finance',
                  icon: EraIconKind.finance,
                  enabled: false,
                  disabledReason: WorkShellWords.notBuilt,
                ),
                TabItem(
                  id: 'tracking',
                  label: 'Tracking',
                  icon: EraIconKind.tracking,
                  enabled: false,
                  disabledReason: WorkShellWords.notBuilt,
                ),
                TabItem(
                  id: 'knowledge',
                  label: 'Knowledge',
                  icon: EraIconKind.knowledge,
                  enabled: false,
                  disabledReason: WorkShellWords.notBuilt,
                ),
              ],
              areaId: 'work',
              onAreaSelect: (_) {},
              treeTitle: 'Work',
              tree: TreeView(
                label: 'Object tree',
                nodes: workTreeNodes(
                  employments: shell.employments,
                  pastDays: shell.pastDays,
                  place: place,
                  countsKnown: !shell.employmentsFailed,
                ),
                selectedId: treeIdOf(place),
                onSelect: _selectNode,
                // Pick mode holds the tree until the panel closes (umbrella
                // 4.4).
                enabled: part?.sheet.confirmDays == null,
              ),
              details: DetailsBox(
                caption: 'Details',
                sections: workDetailsSections(
                  details: shell.details,
                  employmentName: employment?.name,
                  employmentCount: shell.employments.length,
                  onAgreement: (id) => _command(
                    () => shell.go(
                      WorkLocation.agreements(
                        place.employmentId!,
                        agreement: id,
                      ),
                    ),
                  ),
                  onSchedule: (id) => _command(
                    () => shell.go(
                      WorkLocation.schedules(place.employmentId!, schedule: id),
                    ),
                  ),
                  onPeriod: (id) => _command(
                    () => shell.go(
                      WorkLocation.pay(
                        place.employmentId!,
                        sheet: WorkSheetKind.periods,
                        payRecord: id,
                      ),
                    ),
                  ),
                  onPayslip: (id) => _command(
                    () => shell.go(
                      WorkLocation.pay(
                        place.employmentId!,
                        sheet: WorkSheetKind.payslips,
                        payRecord: id,
                      ),
                    ),
                  ),
                  onExtend: employment?.status == EmploymentStatus.archived
                      ? null
                      : (days) => _command(() => shell.extendAgreement(days)),
                  onToConfirm: place.employmentId == null
                      ? null
                      : () => _selectNode(
                          'toConfirm:${place.employmentId!.value}',
                        ),
                ),
              ),
              middleHeader: part == null
                  ? leavePart != null
                        ? _leaveStrip(leavePart, place)
                        : payPart?.filterStrip() ??
                              schedulesPart?.middleHeader() ??
                              employmentsPart?.middleHeader()
                  : switch (part.sheet.kind) {
                      WorkSheetKind.calendar => _calendarStrip(part, place),
                      WorkSheetKind.toConfirm => _toConfirmStrip(part, place),
                      _ => _filterStrip(part, place),
                    },
              middle: switch (part) {
                final part? when part.sheet.kind == WorkSheetKind.calendar =>
                  _atLeastGrid(part.calendar()),
                final part? when part.sheet.kind == WorkSheetKind.toConfirm =>
                  _atLeastGrid(part.toConfirmGrid(lines)),
                final part? => _atLeastGrid(part.grid(lines)),
                null =>
                  (leavePart == null
                          ? null
                          : _atLeastGrid(leavePart.middle())) ??
                      (payPart == null
                          ? null
                          : _atLeastGrid(payPart.middle())) ??
                      agreementsPart?.middle() ??
                      schedulesPart?.middle() ??
                      employmentsPart?.middle() ??
                      const SizedBox(),
              },
              subformTabs:
                  part?.subformTabs(selected) ??
                  leavePart?.subformTabs() ??
                  payPart?.subformTabs() ??
                  agreementsPart?.subformTabs() ??
                  (schedulesPart == null ? null : schedulesTabs) ??
                  const [],
              // The Employments sheet has no subform: when the property column
              // docks, its tab is the only one, so it is always shown.
              subformSelectedId: payPart != null
                  ? shell.subTab ??
                        (payPart.periods ? 'reconciliation' : 'history')
                  : leavePart != null
                  ? shell.subTab ?? _leaveTab
                  : part != null
                  ? shell.subTab ?? ShiftsSubformTab.breaks
                  : agreementsPart != null
                  ? _agreementsTab
                  : schedulesPart != null
                  ? schedulesTab
                  : AppFrame.propertiesTabId,
              onSubformSelect: payPart != null
                  ? shell.selectSub
                  : leavePart != null
                  ? (tab) {
                      _leaveTab = tab;
                      shell.selectSub(tab);
                    }
                  : part != null
                  ? shell.selectSub
                  : agreementsPart != null
                  ? (tab) => setState(() => _agreementsTab = tab)
                  : schedulesPart != null
                  ? (tab) => setState(() => _schedulesTab = tab)
                  : (_) {},
              subformLabel: payPart != null
                  ? 'Pay details'
                  : leavePart != null
                  ? 'Leave details'
                  : part != null
                  ? 'Shift details'
                  : agreementsPart != null
                  ? 'Agreement details'
                  : schedulesPart != null
                  ? 'Schedule details'
                  : 'Details',
              subformTrailing:
                  part?.subformTrailing(selected) ??
                  agreementsPart?.subformTrailing() ??
                  schedulesPart?.subformTrailing(),
              properties:
                  payPart?.properties() ??
                  leavePart?.properties() ??
                  part?.propertyColumn(lines) ??
                  agreementsPart?.properties() ??
                  schedulesPart?.properties() ??
                  employmentsPart?.properties() ??
                  PropertyGrid(
                    record: 'none',
                    controller: editors,
                    items: const [],
                    onCommit: (_, _) => const EditResult.accepted(),
                    today: shell.today,
                  ),
              status: StatusBar(
                notice: _notice(
                  part,
                  lines,
                  employmentsPart,
                  agreementsPart,
                  schedulesPart,
                  leavePart,
                  payPart,
                ),
                warning: switch (shell.daysToConfirm) {
                  0 => null,
                  1 => '1 day to confirm',
                  final days => '$days days to confirm',
                },
                panels: [
                  if (part != null)
                    StatusPanel(switch (part.sheet.kind) {
                      WorkSheetKind.calendar => '${part.sheet.to.day} days',
                      WorkSheetKind.toConfirm => switch (lines.length) {
                        1 => '1 day',
                        final n => '$n days',
                      },
                      // The lines the grid shows, not the rows filters
                      // hide (bead 9pk.4.33).
                      _ => switch (lines.length) {
                        1 => '1 row',
                        final n => '$n rows',
                      },
                    }),
                  if (agreementsPart != null)
                    StatusPanel(switch (agreementsPart.sheet.rows.length) {
                      1 => '1 version',
                      final n => '$n versions',
                    }),
                  if (schedulesPart != null)
                    StatusPanel(schedulesPart.statusPanel()),
                  if (leavePart != null)
                    StatusPanel(
                      leavePart.rows.length == 1
                          ? '1 leave record'
                          : '${leavePart.rows.length} leave records',
                    ),
                  if (payPart != null)
                    StatusPanel(switch ((
                      payPart.lines.length,
                      payPart.periods,
                    )) {
                      (1, true) => '1 period',
                      (final n, true) => '$n periods',
                      (1, false) => '1 payslip',
                      (final n, false) => '$n payslips',
                    }),
                  const StatusPanel('Local database'),
                ],
              ),
              // The Schedules sheet's Cycle and Preview need a taller subform.
              panes: panes,
              onPanesChanged: (value) =>
                  setState(() => _panes[paneKey] = value),
            ),
          ),
        ),
      );
    },
  );
}
