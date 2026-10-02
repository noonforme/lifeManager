import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/desks/desks.dart';
import '../core/desks/saved_views.dart';
import '../core/outcomes/mutation_outcome.dart';
import '../core/time/local_date.dart';
import '../features/journal/journal_controller.dart';
import '../features/journal/journal_sheet.dart';
import '../features/work/data/projections/work_register_projection.dart';
import '../features/work/domain/employment.dart';
import '../features/work/presentation/work_controller.dart';
import '../features/work/presentation/work_desk_tiles.dart';
import '../features/work/presentation/work_formats.dart';
import '../features/work/presentation/work_route_state.dart';
import '../features/work/presentation/work_sheets.dart';
import '../features/work/presentation/work_views.dart';
import '../shared/shell/desk_view.dart';
import '../shared/shell/name_dialog.dart';
import '../shared/shell/shell_frame.dart';
import '../shared/workbench/lifeos_tokens.dart';
import '../shared/workbench/operational_state.dart';
import 'desk_providers.dart';
import 'shell_host.dart';

const _sheetNames = {
  DeskSheets.journalRecent: 'Journal, today and yesterday',
  DeskSheets.needsYou: 'Needs you',
  DeskSheets.workThisPeriod: 'Work this period',
  DeskSheets.shiftsThisWeek: 'Shifts, last 7 days',
  DeskSheets.payPeriods: 'Pay periods',
  DeskSheets.monthPeriods: 'Pay periods this month',
  DeskSheets.monthChecklist: 'Month close checklist',
};

/// The desk at `/today?desk=<id>`, the first desk by default.
final class DeskHost extends ConsumerWidget {
  const DeskHost({required this.uri, super.key});

  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desks = switch (ref.watch(desksProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final Widget desk;
    if (desks == null) {
      desk = const OperationalState(
        kind: OperationalStateKind.loading,
        title: 'Opening Today',
        message: 'Reading your desks.',
      );
    } else if (desks.isEmpty) {
      desk = const OperationalState(
        kind: OperationalStateKind.unavailable,
        title: 'Desks unavailable',
        message: 'Reload LifeOS to open your desks.',
      );
    } else {
      final selected =
          desks
              .where((value) => value.id == uri.queryParameters['desk'])
              .firstOrNull ??
          desks.first;
      desk = _desk(context, ref, desks, selected);
    }
    return ShellFrame(inspectorOpen: false, onBackToDesk: () {}, desk: desk);
  }

  Widget _desk(
    BuildContext context,
    WidgetRef ref,
    List<Desk> desks,
    Desk selected,
  ) {
    final repository = ref.read(deskRepositoryProvider)!;
    void go(String route) => context.go(route);
    void select(Desk desk) => go('/today?desk=${desk.id}');
    Future<void> apply(Future<MutationOutcome<Desk>> change) async {
      final outcome = await change;
      if (outcome case Committed<Desk>(:final value)) select(value);
    }

    final views = switch (ref.watch(savedViewsProvider)) {
      AsyncData(:final value) => value,
      _ => const <SavedView>[],
    };
    return DeskView(
      desks: desks,
      selected: selected,
      sheetNames: _sheetNames,
      views: {
        for (final view in views)
          if (workViewState(view.shape) != null) view.id: view.name,
      },
      onAddView: (viewId) => apply(
        repository.addView(
          selected.id,
          expected: selected.revision,
          viewId: viewId,
        ),
      ),
      tile: (tile) => switch (tile.viewId) {
        null => _tile(ref, tile.sheetRef, go),
        final viewId => _viewTile(
          ref,
          views.where((view) => view.id == viewId).firstOrNull,
          go,
        ),
      },
      onSelectDesk: select,
      onNewDesk: () => apply(repository.createDesk('Desk ${desks.length + 1}')),
      onRemoveTile: (tile) => apply(
        repository.removeTile(
          selected.id,
          expected: selected.revision,
          tileId: tile.id,
        ),
      ),
      onReplaceTile: (tile, sheet) => apply(
        repository.addSheet(
          selected.id,
          expected: selected.revision,
          sheetRef: sheet,
          focusedTileId: tile.id,
        ),
      ),
      onAddSheet: (sheet) => apply(
        repository.addSheet(
          selected.id,
          expected: selected.revision,
          sheetRef: sheet,
        ),
      ),
      onLayout: (layout) => apply(
        repository.setLayout(
          selected.id,
          expected: selected.revision,
          layout: layout,
        ),
      ),
      onRename: () async {
        final name = await askForName(
          context,
          title: 'Rename desk',
          action: 'Rename',
          initial: selected.name,
        );
        if (name != null) {
          await apply(
            repository.rename(
              selected.id,
              expected: selected.revision,
              name: name,
            ),
          );
        }
      },
      onReset: selected.starter == null
          ? null
          : () => apply(
              repository.resetStarter(selected.id, expected: selected.revision),
            ),
      onDelete: selected.canDelete
          ? () async {
              final outcome = await repository.deleteDesk(
                selected.id,
                expected: selected.revision,
              );
              if (outcome is Committed<Desk>) go('/today');
            }
          : null,
      onOpen: go,
    );
  }

  DeskTileContent _tile(WidgetRef ref, String sheet, ValueChanged<String> go) {
    final today = ref.read(todayProvider)();
    final employments = switch (ref.watch(shellEmploymentsProvider)) {
      AsyncData(:final value) => value,
      _ => const <Employment>[],
    };
    final registers = [
      for (final employment in employments)
        if (ref.watch(employmentRegisterProvider(employment.id)) case AsyncData(
          :final value,
        ))
          value,
    ];
    final title = _sheetNames[sheet] ?? sheet;
    final firstEmployment = employments.firstOrNull?.id;
    String workRoute({WorkSheet sheet = WorkSheet.shifts}) => workRouteUri(
      WorkRouteState(
        employmentId: firstEmployment,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
        sheet: sheet,
      ),
    ).toString();
    final month = (
      start: LocalDate(today.year, today.month, 1),
      end: _lastDayOfMonth(today),
    );
    final noEmployment = employments.isEmpty;

    switch (sheet) {
      case DeskSheets.journalRecent:
        final range = JournalRange(from: _addDays(today, -1), to: today);
        return (
          title: title,
          area: null,
          fullSizeRoute: range.uri.toString(),
          body: JournalSheet(
            range: range,
            entries: switch (ref.watch(journalEntriesProvider(range))) {
              AsyncData(:final value) => value,
              _ => null,
            },
            timezones: ref.read(timezoneServiceProvider),
            onRange: (next) => go(next.uri.toString()),
            onOpen: (entry) => go(
              workRouteUri(
                WorkRouteState(
                  employmentId: entry.employmentId,
                  scope: null,
                  record: entry.record,
                  mode: WorkInspectorMode.inspect,
                ),
              ).toString(),
            ),
          ),
        );
      case DeskSheets.needsYou:
        final active = switch (ref.watch(workActiveShiftProvider)) {
          AsyncData(:final value) => value,
          _ => null,
        };
        final zones = ref.read(timezoneServiceProvider);
        final items = needsYou(
          active: active,
          activeLabel: (active) =>
              'Shift running since '
              '${zones.localTimeAt(active.shift.startUtc, active.shift.timezoneId).toString().substring(0, 5)}',
          registers: registers,
        );
        return (
          title: title,
          area: null,
          fullSizeRoute: null,
          body: TileList(
            lines: [
              for (final item in items)
                (text: item.text, detail: null, route: item.route, done: null),
            ],
            empty: noEmployment
                ? 'Nothing waiting. Work is ready when you add an employment.'
                : 'Nothing waiting.',
            onOpen: go,
            action: noEmployment
                ? (
                    label: 'Add employment',
                    route: workRouteUri(
                      const WorkRouteState(
                        employmentId: null,
                        scope: null,
                        record: null,
                        mode: WorkInspectorMode.create,
                      ),
                    ).toString(),
                  )
                : null,
          ),
        );
      case DeskSheets.workThisPeriod:
        final rows = workThisPeriod(registers, today);
        return (
          title: title,
          area: LifeOSArea.work,
          fullSizeRoute: firstEmployment == null ? null : workRoute(),
          body: TileList(
            lines: [
              for (final row in rows)
                (
                  text:
                      '${row.employment}: ${formatDuration(row.paidSeconds)} '
                      'paid, ${formatMoney(row.expected)} expected so far',
                  detail: periodName(row.period),
                  route: null,
                  done: null,
                ),
            ],
            empty: noEmployment
                ? 'Add an employment to see this period.'
                : 'No pay period covers today.',
          ),
        );
      case DeskSheets.shiftsThisWeek:
        final from = _addDays(today, -6);
        return (
          title: title,
          area: LifeOSArea.work,
          fullSizeRoute: firstEmployment == null ? null : workRoute(),
          body: ShiftsSheet(
            rows: [
              for (final register in registers)
                for (final row in register.shiftSheet)
                  if (row.shift.localStartDate.compareTo(from) >= 0 &&
                      row.shift.localStartDate.compareTo(today) <= 0)
                    row,
            ]..sort((a, b) => a.shift.startUtc.compareTo(b.shift.startUtc)),
            timezones: ref.read(timezoneServiceProvider),
            selectedId: null,
            onOpen: (record) => go(_recordRoute(registers, record)),
            showVoid: false,
          ),
        );
      case DeskSheets.payPeriods || DeskSheets.monthPeriods:
        final onlyMonth = sheet == DeskSheets.monthPeriods;
        return (
          title: title,
          area: LifeOSArea.work,
          fullSizeRoute: firstEmployment == null
              ? null
              : workRoute(sheet: WorkSheet.periods),
          body: PeriodsSheet(
            rows: [
              for (final register in registers)
                for (final row in register.periodSheet)
                  if (!onlyMonth ||
                      (row.period.start.compareTo(month.end) <= 0 &&
                          row.period.end.compareTo(month.start) >= 0))
                    row,
            ],
            selectedId: null,
            onOpen: (record) => go(_recordRoute(registers, record)),
          ),
        );
      case DeskSheets.monthChecklist:
        final checks = monthChecklist(registers, month);
        return (
          title: title,
          area: null,
          fullSizeRoute: null,
          body: TileList(
            lines: [
              for (final check in checks)
                (
                  text: check.label,
                  detail: check.detail,
                  route: null,
                  done: check.done,
                ),
            ],
            empty: '',
          ),
        );
    }
    return (
      title: title,
      area: null,
      fullSizeRoute: null,
      body: const SizedBox.shrink(),
    );
  }
}

/// A saved view's sheet, filtered as the view says.
DeskTileContent _viewTile(
  WidgetRef ref,
  SavedView? view,
  ValueChanged<String> go,
) {
  final state = view == null ? null : workViewState(view.shape);
  if (view == null || state == null) {
    return (
      title: view?.name ?? 'View',
      area: null,
      fullSizeRoute: null,
      body: const TileList(lines: [], empty: 'This view is not available.'),
    );
  }
  final route = workRouteUri(state).toString();
  final register = switch (ref.watch(workRouteRegisterProvider(route))) {
    AsyncData(:final value) => value,
    _ => null,
  };
  void open(WorkRecordRef record) => go(
    workRouteUri(
      state.copyWith(record: () => record, mode: WorkInspectorMode.inspect),
    ).toString(),
  );
  final Widget body = switch (register) {
    null => const TileList(lines: [], empty: 'Reading records.'),
    final register => switch (state.sheet) {
      WorkSheet.shifts => ShiftsSheet(
        rows: register.shiftSheet,
        timezones: ref.read(timezoneServiceProvider),
        selectedId: null,
        onOpen: open,
        showVoid: state.showVoid,
      ),
      WorkSheet.periods => PeriodsSheet(
        rows: register.periodSheet,
        selectedId: null,
        onOpen: open,
      ),
      WorkSheet.payslips => PayslipsSheet(
        payslips: register.payslipSheet,
        periods: register.periodSheet,
        selectedId: null,
        onOpen: open,
        showVoid: state.showVoid,
      ),
      WorkSheet.agreements => AgreementsSheet(
        rows: register.agreementSheet,
        employmentName: register.employment?.name ?? 'Employment',
        selectedId: null,
        onOpen: open,
      ),
    },
  };
  return (
    title: view.name,
    area: LifeOSArea.work,
    fullSizeRoute: route,
    body: body,
  );
}

/// A record's Work route, under the employment whose sheet holds it.
String _recordRoute(
  List<WorkRegisterProjection> registers,
  WorkRecordRef record,
) {
  final owner = registers.where(
    (register) =>
        register.shiftSheet.any((row) => row.shift.id == record.id) ||
        register.periodSheet.any((row) => row.period.id == record.id),
  );
  return workRouteUri(
    WorkRouteState(
      employmentId: owner.firstOrNull?.scope.employmentId,
      scope: null,
      record: record,
      mode: WorkInspectorMode.inspect,
    ),
  ).toString();
}

LocalDate _addDays(LocalDate date, int days) {
  final value = DateTime.utc(date.year, date.month, date.day + days);
  return LocalDate(value.year, value.month, value.day);
}

LocalDate _lastDayOfMonth(LocalDate date) {
  final value = DateTime.utc(date.year, date.month + 1, 0);
  return LocalDate(value.year, value.month, value.day);
}
