import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/features/work/presentation/work_screen.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    AsyncValue<WorkViewState> state,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_TestScreen(state: state));
  }

  testWidgets('screen keeps frame mounted while Work is loading', (
    tester,
  ) async {
    await pumpScreen(tester, const AsyncLoading());

    expect(find.bySemanticsLabel('System navigation'), findsOneWidget);
    expect(find.text('Loading Work records'), findsOneWidget);
  });

  testWidgets('screen renders invalid scope without substituting a register', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const AsyncData(WorkInvalidScope(WorkRouteProblem.malformedScope)),
    );

    expect(find.text('Invalid Work scope'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing);
  });

  testWidgets('missing selected record remains unavailable in the inspector', (
    tester,
  ) async {
    final route = WorkRouteState(
      employmentId: _employmentId,
      scope: null,
      record: const WorkRecordRef(kind: WorkRecordKind.shift, id: _shiftId),
      mode: WorkInspectorMode.inspect,
    );
    final ready = WorkReady(
      register: WorkRegisterProjection.empty(
        const WorkScope(employmentId: _employmentId, temporal: null),
      ),
      route: route,
      inspector: const WorkInspectorUnavailable(),
    );

    await pumpScreen(tester, AsyncData(ready));

    expect(find.text('Work record unavailable'), findsOneWidget);
    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
  });
}

final class _TestScreen extends StatelessWidget {
  const _TestScreen({required this.state});

  final AsyncValue<WorkViewState> state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: Scaffold(
        body: WorkScreen(
          state: state,
          onSelect: (_) {},
          onPrimaryAction: () {},
          onNavigate: (_) {},
        ),
      ),
    );
  }
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
