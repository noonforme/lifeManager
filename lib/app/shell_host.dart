import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/work/data/projections/work_register_projection.dart';
import '../features/work/domain/employment.dart';
import '../features/work/domain/ids.dart';
import '../features/work/presentation/work_controller.dart';
import '../features/work/presentation/work_route_state.dart';
import '../shared/shell/book_tree.dart';
import '../shared/shell/menu_bar.dart';
import '../shared/shell/quick_add.dart';
import '../shared/shell/shell_frame.dart';
import '../shared/shell/status_line.dart';
import '../shared/workbench/lifeos_tokens.dart';

/// Closes the application window; provided by the app root.
final class AppQuit extends InheritedWidget {
  const AppQuit({required this.onQuit, required super.child, super.key});

  final VoidCallback? onQuit;

  static VoidCallback? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppQuit>()?.onQuit;

  @override
  bool updateShouldNotify(AppQuit oldWidget) => onQuit != oldWidget.onQuit;
}

/// Active employments for the book tree, read from the Work projection.
final shellEmploymentsProvider = StreamProvider.autoDispose<List<Employment>>(
  (ref) => ref
      .watch(workQueryRepositoryProvider)
      .watchRegister(const WorkScope(employmentId: null, temporal: null))
      .map((projection) => projection.availableEmployments),
);

/// Supplies the menu bar, book tree, status line and title to the surface
/// shown at [location].
final class ShellChromeHost extends ConsumerWidget {
  const ShellChromeHost({
    required this.location,
    required this.child,
    super.key,
  });

  final Uri location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employments = switch (ref.watch(shellEmploymentsProvider)) {
      AsyncData(:final value) => value,
      _ => const <Employment>[],
    };
    final active = switch (ref.watch(workActiveShiftProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final employmentId = location.path == '/work'
        ? location.queryParameters['employment']
        : null;

    String employmentRoute(Employment value) => workRouteUri(
      WorkRouteState(
        employmentId: value.id,
        scope: null,
        record: null,
        mode: WorkInspectorMode.inspect,
      ),
    ).toString();

    final nodes = <TreeNode>[
      const TreeSheet(label: 'Today', route: '/today'),
      const TreeSheet(label: 'Journal', route: '/journal'),
      TreeArea(
        area: LifeOSArea.work,
        route: '/work',
        built: true,
        children: [
          for (final employment in employments)
            TreeSheet(
              label: employment.name,
              route: employmentRoute(employment),
              liveValue: active?.shift.employmentId == employment.id
                  ? 'running'
                  : null,
              liveValueIsActive: active?.shift.employmentId == employment.id,
            ),
        ],
      ),
      const TreeArea(area: LifeOSArea.finance, route: '/finance', built: false),
      const TreeArea(
        area: LifeOSArea.tracking,
        route: '/tracking',
        built: false,
      ),
      const TreeArea(
        area: LifeOSArea.knowledge,
        route: '/knowledge',
        built: false,
      ),
    ];

    final selected = switch (location.path) {
      '/work' when employmentId != null =>
        employments
            .where((value) => value.id.value == employmentId)
            .map(employmentRoute)
            .firstOrNull,
      final path => path,
    };

    RunningShiftStatus? running;
    if (active != null) {
      final zones = ref.read(timezoneServiceProvider);
      final start = zones.localTimeAt(
        active.shift.startUtc,
        active.shift.timezoneId,
      );
      final hhmm = start.toString().substring(0, 5);
      running = RunningShiftStatus(
        label: 'Shift running since $hhmm',
        onOpen: () => context.go(
          workRouteUri(
            WorkRouteState(
              employmentId: active.shift.employmentId,
              scope: null,
              record: WorkRecordRef(
                kind: WorkRecordKind.shift,
                id: active.shift.id,
              ),
              mode: WorkInspectorMode.inspect,
            ),
          ).toString(),
        ),
      );
    }

    final employmentName = employmentId == null
        ? null
        : employments
              .where((value) => value.id.value == employmentId)
              .map((value) => value.name)
              .firstOrNull;

    return ShellChrome(
      menuBar: LifeOSMenuBar(
        onNavigate: context.go,
        onQuit: AppQuit.maybeOf(context),
      ),
      tree: (onOpened) => BookTree(
        nodes: nodes,
        footer: const [
          TreeSheet(label: 'Backup and export', route: '/system/files'),
        ],
        selectedRoute: selected,
        onOpen: (route) {
          onOpened();
          context.go(route);
        },
      ),
      status: StatusLine(snapshot: StatusSnapshot(runningShift: running)),
      title: _title(location.path, employmentName),
      onNavigate: context.go,
      quickAdd: _quickAdd(context, employments, employmentId),
      fromLastTime: _fromLastTime(context, ref, employments, employmentId),
      child: child,
    );
  }

  /// The employment + Add files records under: the open one, otherwise the
  /// first active one.
  static EmploymentId? _target(
    List<Employment> employments,
    String? employmentId,
  ) =>
      employments
          .where((value) => value.id.value == employmentId)
          .map((value) => value.id)
          .firstOrNull ??
      employments.map((value) => value.id).firstOrNull;

  List<QuickAddEntry> _quickAdd(
    BuildContext context,
    List<Employment> employments,
    String? employmentId,
  ) {
    final target = _target(employments, employmentId);
    final period = location.path == '/work'
        ? location.queryParameters['period']
        : null;
    VoidCallback? go(
      WorkInspectorMode mode, {
      WorkAddKind? adding,
      bool needsEmployment = true,
    }) {
      if (needsEmployment && target == null) return null;
      return () => context.go(
        workRouteUri(
          WorkRouteState(
            employmentId: needsEmployment ? target : null,
            scope: adding == WorkAddKind.payslip && period != null
                ? PayPeriodScope(PayPeriodId(period))
                : null,
            record: null,
            mode: mode,
            adding: adding,
          ),
        ).toString(),
      );
    }

    return [
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Start shift',
        open: go(WorkInspectorMode.create),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Manual shift',
        open: go(WorkInspectorMode.edit),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Pay period',
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.payPeriod),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Payslip',
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.payslip),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Employment',
        open: go(WorkInspectorMode.create, needsEmployment: false),
      ),
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Agreement',
        open: go(WorkInspectorMode.inspect, adding: WorkAddKind.agreement),
      ),
    ];
  }

  /// "From last time" buttons: a manual shift shaped like the last one,
  /// shown only when there is a last one.
  List<QuickAddEntry> _fromLastTime(
    BuildContext context,
    WidgetRef ref,
    List<Employment> employments,
    String? employmentId,
  ) {
    final target = _target(employments, employmentId);
    if (target == null) return const [];
    final template = switch (ref.watch(lastShiftTemplateProvider(target))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (template == null) return const [];
    return [
      QuickAddEntry(
        area: LifeOSArea.work,
        label: 'Manual shift from last time',
        open: () => context.go(
          workRouteUri(
            WorkRouteState(
              employmentId: target,
              scope: null,
              record: null,
              mode: WorkInspectorMode.edit,
              fromLast: true,
            ),
          ).toString(),
        ),
      ),
    ];
  }

  static String _title(String path, String? employmentName) => switch (path) {
    '/work' when employmentName != null => 'Work › $employmentName',
    '/work' => 'Work',
    '/journal' => 'Journal',
    '/finance' => 'Finance',
    '/tracking' => 'Tracking',
    '/knowledge' => 'Knowledge',
    '/system/files' => 'Backup and export',
    '/today' => 'Today',
    _ => 'LifeOS',
  };
}
