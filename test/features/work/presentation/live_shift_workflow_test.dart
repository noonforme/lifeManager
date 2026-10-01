import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/shift_forms.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_inspector.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  testWidgets(
    'end shift presents suggestion and requires owner overtime confirmation',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: OvertimeConfirmationInspector(
            shift: endedShift,
            suggestedOvertimeMinutes: 42,
            enteredOvertimeMinutes: 0,
            onFinalize: (_) async => Committed(finalizedShift),
          ),
        ),
      );

      expect(
        find.text('Suggested from the agreement threshold: 42 minutes.'),
        findsOneWidget,
      );
      expect(find.text('Confirm finalization'), findsOneWidget);
    },
  );

  testWidgets('restart restores on-break state from projection', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: WorkInspector.fromProjection(
          projection: ShiftRecordProjection(onBreakShift, breaks: [openBreak]),
          onStartBreak: (_) async => Committed(onBreakShift),
          onEndBreak: (_) async => Committed(runningAfterBreak),
          onEndShift: (_) async => Committed(endedShift),
          onFinalize: (_) async => Committed(finalizedShift),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Shift on break'), findsOneWidget);
    expect(find.text('End break'), findsOneWidget);
  });

  testWidgets('live shift exposes lifecycle actions in committed order', (
    tester,
  ) async {
    var projection = ShiftRecordProjection(runningShift, breaks: const []);
    late StateSetter update;
    await tester.pumpWidget(
      _TestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return WorkInspector.fromProjection(
              projection: projection,
              onStartBreak: (_) async {
                update(() {
                  projection = ShiftRecordProjection(
                    onBreakShift,
                    breaks: [openBreak],
                  );
                });
                return Committed(onBreakShift);
              },
              onEndBreak: (_) async {
                update(() {
                  projection = ShiftRecordProjection(
                    runningAfterBreak,
                    breaks: [closedBreak],
                  );
                });
                return Committed(runningAfterBreak);
              },
              onEndShift: (_) async {
                update(() {
                  projection = ShiftRecordProjection(
                    endedShift,
                    breaks: [closedBreak],
                  );
                });
                return Committed(endedShift);
              },
              suggestedOvertimeMinutes: 0,
              onFinalize: (_) async {
                update(() {
                  projection = ShiftRecordProjection(
                    finalizedShift,
                    breaks: [closedBreak],
                  );
                });
                return Committed(finalizedShift);
              },
            );
          },
        ),
      ),
    );

    expect(find.text('Start break'), findsOneWidget);
    await tester.tap(find.text('Start break'));
    await tester.pumpAndSettle();
    expect(find.text('End break'), findsOneWidget);
    await tester.tap(find.text('End break'));
    await tester.pumpAndSettle();
    expect(find.text('End shift'), findsOneWidget);
    await tester.tap(find.text('End shift'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm finalization'), findsOneWidget);
    await tester.tap(find.text('Confirm finalization'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Finalized shift'), findsOneWidget);
  });

  test('committed shift route uses its captured local date and safe ID', () {
    final route = routeForCommittedShift(finalizedShift);

    expect(route.employmentId, employmentId);
    expect(route.record?.kind, WorkRecordKind.shift);
    expect(route.record?.id, shiftId);
    expect(route.scope, isA<DateRangeScope>());
    final scope = route.scope! as DateRangeScope;
    expect(scope.start, const LocalDate(2026, 10, 1));
    expect(scope.end, const LocalDate(2026, 10, 1));
    expect(route.mode, WorkInspectorMode.inspect);
  });

  test(
    'controller adapts lifecycle drafts and replaces route after commit',
    () async {
      StartShiftCommand? start;
      StartBreakCommand? startBreak;
      EndBreakCommand? endBreak;
      EndShiftCommand? end;
      FinalizeShiftCommand? finalize;
      CreateManualShiftCommand? manual;
      final replaced = <WorkRouteState>[];
      final container = ProviderContainer(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(_QueryRepository()),
          workRouteProvider.overrideWithValue(
            ValidWorkRoute(
              WorkRouteState(
                employmentId: employmentId,
                scope: null,
                record: null,
                mode: WorkInspectorMode.inspect,
              ),
            ),
          ),
          replaceWorkRouteProvider.overrideWithValue(replaced.add),
          startShiftProvider.overrideWithValue((command) async {
            start = command;
            return Committed(runningShift);
          }),
          startBreakProvider.overrideWithValue((command) async {
            startBreak = command;
            return Committed(onBreakShift);
          }),
          endBreakProvider.overrideWithValue((command) async {
            endBreak = command;
            return Committed(runningAfterBreak);
          }),
          endShiftProvider.overrideWithValue((command) async {
            end = command;
            return Committed(endedShift);
          }),
          finalizeShiftProvider.overrideWithValue((command) async {
            finalize = command;
            return Committed(finalizedShift);
          }),
          saveManualShiftProvider.overrideWithValue((command) async {
            manual = command;
            return Committed(finalizedShift);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(workControllerProvider.future);
      final controller = container.read(workControllerProvider.notifier);

      await controller.startShift(
        employmentId: employmentId,
        timezoneId: ' Europe/Amsterdam ',
        note: ' note ',
      );
      await controller.startBreak(runningShift);
      await controller.endBreak(onBreakShift, openBreak);
      await controller.endShift(runningAfterBreak);
      await controller.finalizeShift(endedShift, overtimeMinutes: 15);
      await controller.saveManualShift(
        const ManualShiftDraft(
          employmentId: employmentId,
          localStartDate: LocalDate(2026, 10, 1),
          localStartTime: LocalTime(22, 30),
          localEndDate: LocalDate(2026, 10, 2),
          localEndTime: LocalTime(6, 15),
          timezoneId: 'Europe/Amsterdam',
          startFold: null,
          endFold: null,
          breaks: [
            ManualBreakDraft(
              startDate: LocalDate(2026, 10, 2),
              start: LocalTime(1, 0),
              endDate: LocalDate(2026, 10, 2),
              end: LocalTime(1, 20),
            ),
          ],
          overtimeMinutes: 30,
          note: ' night ',
        ),
      );

      expect(start?.timezoneId, 'Europe/Amsterdam');
      expect(start?.note, 'note');
      expect(startBreak?.expectedShiftRevision, runningShift.revision);
      expect(endBreak?.breakId, breakId);
      expect(endBreak?.expectedBreakRevision, openBreak.revision);
      expect(end?.expectedRevision, runningAfterBreak.revision);
      expect(finalize?.overtimeMinutes, 15);
      expect(finalize?.expectedRevision, endedShift.revision);
      expect(manual?.localEndDate, const LocalDate(2026, 10, 2));
      expect(manual?.breaks, hasLength(1));
      expect(
        manual?.breaks.single.localStartDate,
        const LocalDate(2026, 10, 2),
      );
      expect(manual?.breaks.single.localEndTime, const LocalTime(1, 20));
      expect(manual?.note, 'night');
      expect(replaced, hasLength(6));
      expect(replaced.last.record?.id, shiftId);
      expect(
        (replaced.last.scope! as DateRangeScope).start,
        const LocalDate(2026, 10, 1),
      );
    },
  );
}

final class _QueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildLifeOSTheme(highContrast: false),
    home: Scaffold(body: SizedBox(width: 520, height: 760, child: child)),
  );
}

const employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const shiftId = ShiftId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c31');
const breakId = ShiftBreakId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c32');
const agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');

WorkShift shift({
  required ShiftState state,
  required Revision revision,
  DateTime? endUtc,
  AgreementId? agreement,
  int overtimeMinutes = 0,
}) => WorkShift(
  id: shiftId,
  employmentId: employmentId,
  agreementId: agreement,
  state: state,
  startUtc: DateTime.utc(2026, 10, 1, 8),
  endUtc: endUtc,
  timezoneId: 'Europe/Amsterdam',
  localStartDate: const LocalDate(2026, 10, 1),
  overtimeMinutes: overtimeMinutes,
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: null,
  createdAtUtc: DateTime.utc(2026, 10, 1, 8),
  updatedAtUtc: DateTime.utc(2026, 10, 1, 16),
  revision: revision,
);

final runningShift = shift(
  state: ShiftState.running,
  revision: const Revision(0),
);
final onBreakShift = shift(
  state: ShiftState.onBreak,
  revision: const Revision(1),
);
final runningAfterBreak = shift(
  state: ShiftState.running,
  revision: const Revision(2),
);
final endedShift = shift(
  state: ShiftState.draft,
  endUtc: DateTime.utc(2026, 10, 1, 16),
  revision: const Revision(3),
);
final finalizedShift = shift(
  state: ShiftState.finalized,
  endUtc: DateTime.utc(2026, 10, 1, 16),
  agreement: agreementId,
  overtimeMinutes: 15,
  revision: const Revision(4),
);
final openBreak = ShiftBreak(
  id: breakId,
  shiftId: shiftId,
  startUtc: DateTime.utc(2026, 10, 1, 12),
  endUtc: null,
  createdAtUtc: DateTime.utc(2026, 10, 1, 12),
  updatedAtUtc: DateTime.utc(2026, 10, 1, 12),
  revision: const Revision(0),
);
final closedBreak = ShiftBreak(
  id: breakId,
  shiftId: shiftId,
  startUtc: DateTime.utc(2026, 10, 1, 12),
  endUtc: DateTime.utc(2026, 10, 1, 12, 30),
  createdAtUtc: DateTime.utc(2026, 10, 1, 12),
  updatedAtUtc: DateTime.utc(2026, 10, 1, 12, 30),
  revision: const Revision(1),
);
