import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/work/data/projections/work_register_projection.dart';
import '../features/work/domain/ids.dart';
import '../features/work/presentation/work_controller.dart';
import '../features/work/presentation/work_route_state.dart';
import '../features/work/presentation/work_screen.dart';
import '../shared/shell/shell_frame.dart';
import '../shared/workbench/lifeos_skin.dart';
import 'shell_host.dart';

GoRouter createAppRouter({String initialLocation = '/work'}) {
  GoRoute unavailable(String path, String title, String message) => GoRoute(
    path: path,
    builder: (_, state) => ShellChromeHost(
      location: state.uri,
      child: _UnavailableSurface(title: title, message: message),
    ),
  );

  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      unavailable(
        '/today',
        'Today',
        'Today is not built yet. It arrives with desks in a later update.',
      ),
      GoRoute(
        path: '/work',
        builder: (context, state) => _workSurface(context, state.uri),
      ),
      unavailable(
        '/journal',
        'Journal',
        'The Journal is not built yet. It arrives in a later update.',
      ),
      unavailable(
        '/finance',
        'Finance',
        'Finance is not built yet. It arrives in a later update.',
      ),
      unavailable(
        '/tracking',
        'Tracking',
        'Tracking is not built yet. It arrives in a later update.',
      ),
      unavailable(
        '/knowledge',
        'Knowledge',
        'Knowledge is not built yet. It arrives in a later update.',
      ),
      unavailable(
        '/system/files',
        'Backup and export',
        'File tools are not available yet.',
      ),
    ],
    redirect: (_, state) => switch (state.uri.path) {
      '/' => '/work',
      // Money and Habits were renamed Finance and Tracking.
      '/money' => '/finance',
      '/habits' => '/tracking',
      _ => null,
    },
  );
}

Widget _workSurface(BuildContext routerContext, Uri uri) {
  final route = parseWorkRoute(uri);
  if (route is InvalidWorkRoute) {
    return ShellChromeHost(
      location: uri,
      child: _UnavailableSurface(
        title: switch (route.reason) {
          WorkRouteProblem.malformedId => 'Work record unavailable',
          WorkRouteProblem.malformedScope => 'Invalid Work scope',
          WorkRouteProblem.invalidMode => 'Invalid Work mode',
        },
        message: switch (route.reason) {
          WorkRouteProblem.malformedId =>
            'The requested Work record identifier is invalid.',
          WorkRouteProblem.malformedScope =>
            'Choose a valid period or date range to inspect Work records.',
          WorkRouteProblem.invalidMode =>
            'Choose a valid inspector mode to continue.',
        },
      ),
    );
  }
  return ProviderScope(
    overrides: [
      workRouteProvider.overrideWithValue(route),
      replaceWorkRouteProvider.overrideWithValue(
        (route) => routerContext.go(workRouteUri(route).toString()),
      ),
    ],
    child: ShellChromeHost(location: uri, child: const _WorkRouteHost()),
  );
}

final class _WorkRouteHost extends ConsumerWidget {
  const _WorkRouteHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: WorkScreen(
        state: ref.watch(workControllerProvider),
        onSelect: (record) {
          final parsed = ref.read(workRouteProvider);
          if (parsed case ValidWorkRoute(:final state)) {
            ref.read(replaceWorkRouteProvider)(
              WorkRouteState(
                employmentId: state.employmentId,
                scope: record.kind == WorkRecordKind.payPeriod
                    ? PayPeriodScope(record.id as PayPeriodId)
                    : state.scope,
                record: record,
                mode: WorkInspectorMode.inspect,
              ),
            );
          }
        },
        onPrimaryAction: () {
          final parsed = ref.read(workRouteProvider);
          if (parsed case ValidWorkRoute(:final state)) {
            ref.read(replaceWorkRouteProvider)(
              WorkRouteState(
                employmentId: state.employmentId,
                scope: state.scope,
                record: null,
                mode: WorkInspectorMode.create,
              ),
            );
          }
        },
        onCreateEmployment: ref
            .read(workControllerProvider.notifier)
            .submitEmployment,
        onCreateAgreement: ref
            .read(workControllerProvider.notifier)
            .submitAgreement,
        onNavigate: context.go,
        onStartBreak: ref.read(workControllerProvider.notifier).startBreak,
        onEndBreak: ref.read(workControllerProvider.notifier).endBreak,
        onEndShift: ref.read(workControllerProvider.notifier).endShift,
        onFinalize: ref.read(workControllerProvider.notifier).finalizeShift,
        onStartShift: ref
            .read(workControllerProvider.notifier)
            .startShiftInSystemZone,
        onOpenManualShift: (employment) {
          final parsed = ref.read(workRouteProvider);
          if (parsed case ValidWorkRoute(:final state)) {
            ref.read(replaceWorkRouteProvider)(
              WorkRouteState(
                employmentId: employment,
                scope: state.scope,
                record: null,
                mode: WorkInspectorMode.edit,
              ),
            );
          }
        },
        onSaveManualShift: ref
            .read(workControllerProvider.notifier)
            .saveManualShift,
        systemTimezoneId: ref.read(currentTimezoneIdProvider)(),
        onCreatePayPeriod: ref
            .read(workControllerProvider.notifier)
            .createPayPeriod,
        onSetPeriodState: ref
            .read(workControllerProvider.notifier)
            .setPayPeriodState,
        onRecordPayslip: ref
            .read(workControllerProvider.notifier)
            .recordPayslip,
        onOpenCorrection: () => _replaceMode(ref, WorkInspectorMode.correct),
        onCancelCorrection: () => _replaceMode(ref, WorkInspectorMode.inspect),
        onCorrectShift: ref
            .read(workControllerProvider.notifier)
            .correctShiftWithReason,
        onCorrectPayslip: ref
            .read(workControllerProvider.notifier)
            .correctPayslipWithReason,
        onReviseDraft: ref
            .read(workControllerProvider.notifier)
            .reviseDraftShift,
        timezones: ref.read(timezoneServiceProvider),
        onUpdateEmployment: ref
            .read(workControllerProvider.notifier)
            .updateEmployment,
        onDeleteEmployment: ref
            .read(workControllerProvider.notifier)
            .deleteEmployment,
        onUpdateAgreement: ref
            .read(workControllerProvider.notifier)
            .updateAgreement,
      ),
    );
  }
}

/// Switches the selected record's inspector mode, keeping scope and record.
void _replaceMode(WidgetRef ref, WorkInspectorMode mode) {
  final parsed = ref.read(workRouteProvider);
  if (parsed case ValidWorkRoute(:final state)) {
    ref.read(replaceWorkRouteProvider)(
      WorkRouteState(
        employmentId: state.employmentId,
        scope: state.scope,
        record: state.record,
        mode: mode,
      ),
    );
  }
}

/// An honest sheet for a destination that has not shipped.
final class _UnavailableSurface extends StatelessWidget {
  const _UnavailableSurface({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ShellFrame(
      inspectorOpen: false,
      onBackToDesk: _noop,
      inspector: const SizedBox.expand(),
      desk: Builder(
        builder: (context) {
          final skin = LifeOSSkinScope.of(context);
          return ColoredBox(
            color: skin.tokens.paper,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: skin.typography.title.copyWith(
                      color: skin.tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: skin.typography.body.copyWith(
                      color: skin.tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _noop() {}
