import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/app/app_router.dart';
import 'package:lifeos/app/lifeos_app.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/core/time/local_time.dart';
import 'package:lifeos/core/time/timezone_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/daos/shift_dao.dart';
import 'package:lifeos/features/work/data/projections/reconciliation_projection.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/pay.dart';
import 'package:lifeos/features/work/domain/pay_period.dart';
import 'package:lifeos/features/work/domain/payslip.dart';
import 'package:lifeos/features/work/domain/reconciliation.dart';
import 'package:lifeos/features/work/domain/shift.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';

import '../support/era_pickers.dart';
import '../support/work_dialogs.dart';

void main() {
  test(
    'invalid record UUID remains unavailable instead of selecting a row',
    () {
      final result = parseWorkRoute(Uri.parse('/work?record=shift:not-a-uuid'));

      expect(result, isA<InvalidWorkRoute>());
      expect((result as InvalidWorkRoute).reason, WorkRouteProblem.malformedId);
    },
  );

  test('serializes only safe structural Work route state', () {
    final uri = workRouteUri(
      WorkRouteState(
        employmentId: _employmentId,
        scope: null,
        record: const WorkRecordRef(kind: WorkRecordKind.shift, id: _shiftId),
        mode: WorkInspectorMode.inspect,
      ),
    );

    expect(
      uri.toString(),
      '/work?employment=${_employmentId.value}'
      '&record=shift:${_shiftId.value}&mode=inspect',
    );
  });

  test('route parser rejects malformed and conflicting temporal scopes', () {
    expect(
      parseWorkRoute(Uri.parse('/work?period=not-a-uuid')),
      isA<InvalidWorkRoute>().having(
        (value) => value.reason,
        'reason',
        WorkRouteProblem.malformedScope,
      ),
    );
    expect(
      parseWorkRoute(
        Uri.parse(
          '/work?period=018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51'
          '&from=2026-09-01&to=2026-09-30',
        ),
      ),
      isA<InvalidWorkRoute>().having(
        (value) => value.reason,
        'reason',
        WorkRouteProblem.malformedScope,
      ),
    );
  });

  testWidgets('valid Work route renders the provider-backed workbench', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: '/work');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _EmptyWorkQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Task pane'), findsOneWidget);
    expect(find.bySemanticsLabel('Work register'), findsOneWidget);
    expect(find.bySemanticsLabel('Record inspector'), findsNothing);
    expect(
      find.text(
        'Track shifts, see what you should be paid, and compare it with your payslips. Start by adding where you work.',
      ),
      findsOneWidget,
    );
    expect(find.text('Work records will appear here.'), findsNothing);
  });

  testWidgets(
    'empty Work primary action opens setup through safe route state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 760);
      addTearDown(tester.view.reset);
      final router = createAppRouter(initialLocation: '/work');
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workQueryRepositoryProvider.overrideWithValue(
              _EmptyWorkQueryRepository(),
            ),
            createEmploymentProvider.overrideWithValue(
              (_) async => Committed(_employment),
            ),
          ],
          child: LifeOsApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create employment'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/work?mode=create',
      );
      await tester.enterText(
        find.byKey(const ValueKey('employment-name')),
        'Synthetic studio',
      );
      await tester.tap(find.text('Save employment'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/work?employment=${_employmentId.value}&mode=create',
      );
    },
  );

  testWidgets('selecting a Work row writes only safe structural route state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final repository = _ShiftWorkQueryRepository();
    final initialLocation = '/work?employment=${_employmentId.value}';
    final parsed = parseWorkRoute(Uri.parse(initialLocation));
    expect(parsed, isA<ValidWorkRoute>());
    expect((parsed as ValidWorkRoute).state.employmentId, _employmentId);
    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workQueryRepositoryProvider.overrideWithValue(repository)],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    // The book tree also watches the unscoped employment list, and
    // "from last time" watches the employment's records.
    expect(
      repository.requestedScopes
          .where((scope) => scope.employmentId != null)
          .map((scope) => scope.employmentId)
          .toSet(),
      {_employmentId},
    );

    await tester.tap(find.text('2026-09-29'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}'
      '&record=shift:${_shiftId.value}&mode=inspect',
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      isNot(contains('Synthetic private note')),
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      isNot(contains('12345')),
    );
  });

  testWidgets('stale lifecycle outcome stays on route and explains reload', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final repository = _LiveShiftQueryRepository(
      ShiftRecordProjection(
        _liveShift(
          ShiftState.draft,
          const Revision(0),
          endUtc: DateTime.utc(2026, 9, 29, 16),
        ),
        breaks: const [],
      ),
    );
    addTearDown(repository.close);
    final initialLocation =
        '/work?employment=${_employmentId.value}'
        '&record=shift:${_shiftId.value}&mode=properties';
    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(repository),
          finalizeShiftProvider.overrideWithValue(
            (_) async => const Stale<WorkShift>(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tapInDialog(tester, find.widgetWithText(KeyButton, 'Finalize shift'));

    expect(
      router.routeInformationProvider.value.uri.toString(),
      initialLocation,
    );
    expect(
      find.text(
        'Your record is out of date. Reload and review before trying again.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ended shift finalizes from the inspector', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final ended = _liveShift(
      ShiftState.draft,
      const Revision(3),
      endUtc: DateTime.utc(2026, 9, 29, 16),
    );
    final repository = _LiveShiftQueryRepository(
      ShiftRecordProjection(ended, breaks: [_closedBreak]),
    );
    addTearDown(repository.close);
    FinalizeShiftCommand? issued;
    final router = createAppRouter(
      initialLocation:
          '/work?employment=${_employmentId.value}'
          '&record=shift:${_shiftId.value}&mode=properties',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(repository),
          finalizeShiftProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(
              _liveShift(
                ShiftState.finalized,
                const Revision(4),
                endUtc: DateTime.utc(2026, 9, 29, 16),
              ),
            );
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Finalize shift'), findsWidgets);
    await tapInDialog(tester, find.widgetWithText(KeyButton, 'Finalize shift'));

    expect(issued?.id, _shiftId);
    expect(issued?.expectedRevision, const Revision(3));
  });

  testWidgets('manual shift opens through edit route and saves', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.reset);
    CreateManualShiftCommand? issued;
    final router = createAppRouter(
      initialLocation: '/work?employment=${_employmentId.value}&mode=create',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _EmptyWorkQueryRepository(),
          ),
          currentTimezoneIdProvider.overrideWithValue(() => 'Europe/Amsterdam'),
          saveManualShiftProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(
              _liveShift(
                ShiftState.finalized,
                const Revision(0),
                endUtc: DateTime.utc(2026, 9, 29, 16),
              ),
            );
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add manual shift'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}&mode=edit',
    );
    expect(find.text('Europe/Amsterdam'), findsOneWidget);

    await pickDate(tester, 'shift-start-date', const LocalDate(2026, 9, 29));
    await setTime(tester, 'shift-start-time', const LocalTime(10, 0));
    await pickDate(tester, 'shift-end-date', const LocalDate(2026, 9, 29));
    await setTime(tester, 'shift-end-time', const LocalTime(18, 0));
    await tester.tap(find.text('Save manual shift'));
    await tester.pumpAndSettle();

    expect(issued?.employmentId, _employmentId);
    expect(issued?.timezoneId, 'Europe/Amsterdam');
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}'
      '&from=2026-09-29&to=2026-09-29'
      '&record=shift:${_shiftId.value}&mode=inspect',
    );
  });

  testWidgets('selecting a pay period row scopes the register to it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 760);
    addTearDown(tester.view.reset);
    final router = createAppRouter(
      initialLocation: '/work?employment=${_employmentId.value}&sheet=periods',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PeriodQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsLabel('Pay period 2026-09-01 – 2026-09-30'),
    );
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}&period=${_periodId.value}'
      '&sheet=periods&record=payPeriod:${_periodId.value}&mode=inspect',
    );
  });

  testWidgets('new pay period form creates and selects the period', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    CreatePayPeriodCommand? issued;
    final router = createAppRouter(
      initialLocation: '/work?employment=${_employmentId.value}',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PeriodQueryRepository(),
          ),
          createPayPeriodProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(_openPeriod);
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New pay period'));
    await tester.pumpAndSettle();
    await pickDate(tester, 'period-start', const LocalDate(2026, 9, 1));
    await pickDate(tester, 'period-end', const LocalDate(2026, 9, 30));
    await tester.tap(find.text('Create period'));
    await tester.pumpAndSettle();

    expect(issued?.employmentId, _employmentId);
    expect(issued?.start, const LocalDate(2026, 9, 1));
    expect(issued?.end, const LocalDate(2026, 9, 30));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}&period=${_periodId.value}'
      '&record=payPeriod:${_periodId.value}&mode=inspect',
    );
  });

  testWidgets('selected period is marked reviewed through the controller', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    SetPayPeriodStateCommand? issued;
    final router = createAppRouter(initialLocation: _periodLocation);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PeriodQueryRepository(),
          ),
          setPayPeriodStateProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(_openPeriod);
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();

    expect(issued?.id, _periodId);
    expect(issued?.state, PayPeriodState.reviewed);
    expect(issued?.expectedRevision, _openPeriod.revision);
  });

  testWidgets('stale period review explains reload and keeps the route', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: _periodLocation);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PeriodQueryRepository(),
          ),
          setPayPeriodStateProvider.overrideWithValue(
            (command) async => const Stale(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your record is out of date. Reload and review before trying again.',
      ),
      findsOneWidget,
    );
    expect(
      router.routeInformationProvider.value.uri.toString(),
      _periodLocation,
    );
  });

  testWidgets('selected period records a payslip and selects it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.reset);
    RecordPayslipCommand? issued;
    final router = createAppRouter(initialLocation: _periodLocation);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PeriodQueryRepository(),
          ),
          recordPayslipProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(_payslip);
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(KeyButton, 'Record payslip'));
    await tester.pumpAndSettle();
    await pickDate(tester, 'payslip-issued-date', const LocalDate(2026, 9, 30));
    await tester.enterText(
      find.byKey(const ValueKey('payslip-amount')),
      '950.00',
    );
    await tapInDialog(tester, find.text('Save payslip'));

    expect(issued?.periodId, _periodId);
    expect(issued?.amountMinorUnits, 95000);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}&period=${_periodId.value}'
      '&record=payslip:${_payslipId.value}&mode=inspect',
    );
  });

  testWidgets('selected period explains its reconciliation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: _periodLocation);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PeriodQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Paid evidence differs from the recorded agreement.'),
      findsOneWidget,
    );
  });

  testWidgets('finalized shift correction voids and selects the replacement', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final repository = _LiveShiftQueryRepository(
      ShiftRecordProjection(_finalizedShift, breaks: const []),
    );
    addTearDown(repository.close);
    CorrectShiftCommand? issued;
    final router = createAppRouter(initialLocation: _finalizedProperties);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(repository),
          nextReplacementShiftIdProvider.overrideWithValue(
            () => _replacementShiftId,
          ),
          correctShiftProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(_replacementDraft);
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tapInDialog(tester, find.text('Correct shift'));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      _finalizedLocation.replaceFirst('mode=inspect', 'mode=correct'),
    );
    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      '  Wrong end time  ',
    );
    await tester.tap(find.text('Void original and create replacement'));
    await tester.pumpAndSettle();

    expect(issued?.originalId, _shiftId);
    expect(issued?.replacementId, _replacementShiftId);
    expect(issued?.expectedRevision, const Revision(3));
    expect(issued?.voidReason, 'Wrong end time');
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}'
      '&from=2026-09-29&to=2026-09-29'
      '&record=shift:${_replacementShiftId.value}&mode=properties',
    );
  });

  testWidgets('canceling a correction returns to inspect without mutation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final repository = _LiveShiftQueryRepository(
      ShiftRecordProjection(_finalizedShift, breaks: const []),
    );
    addTearDown(repository.close);
    var issued = false;
    final router = createAppRouter(
      initialLocation: _finalizedLocation.replaceFirst(
        'mode=inspect',
        'mode=correct',
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(repository),
          correctShiftProvider.overrideWithValue((command) async {
            issued = true;
            return Committed(_replacementDraft);
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Correct shift'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(issued, isFalse);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      _finalizedLocation,
    );
  });

  testWidgets('stale correction keeps the correction route and explains', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    final repository = _LiveShiftQueryRepository(
      ShiftRecordProjection(_finalizedShift, breaks: const []),
    );
    addTearDown(repository.close);
    final location = _finalizedLocation.replaceFirst(
      'mode=inspect',
      'mode=correct',
    );
    final router = createAppRouter(initialLocation: location);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(repository),
          nextReplacementShiftIdProvider.overrideWithValue(
            () => _replacementShiftId,
          ),
          correctShiftProvider.overrideWithValue(
            (command) async => const Stale<WorkShift>(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'Wrong end time',
    );
    await tester.tap(find.text('Void original and create replacement'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your record is out of date. Reload and review before trying again.',
      ),
      findsOneWidget,
    );
    expect(router.routeInformationProvider.value.uri.toString(), location);
  });

  testWidgets('effective payslip correction selects the replacement', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);
    CorrectPayslipCommand? issued;
    final location =
        '/work?employment=${_employmentId.value}&period=${_periodId.value}'
        '&record=payslip:${_payslipId.value}&mode=properties';
    final router = createAppRouter(initialLocation: location);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _PayslipQueryRepository(),
          ),
          nextReplacementPayslipIdProvider.overrideWithValue(
            () => _replacementPayslipId,
          ),
          correctPayslipProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(
              _payslip.replacement(
                replacementId: _replacementPayslipId,
                nowUtc: DateTime.utc(2026, 10, 1),
              ),
            );
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Correct payslip'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('correction-reason')),
      'Amount misread',
    );
    await tester.tap(find.text('Void original and create replacement'));
    await tester.pumpAndSettle();

    expect(issued?.originalId, _payslipId);
    expect(issued?.replacementId, _replacementPayslipId);
    expect(issued?.voidReason, 'Amount misread');
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/work?employment=${_employmentId.value}&period=${_periodId.value}'
      '&record=payslip:${_replacementPayslipId.value}&mode=inspect',
    );
  });

  testWidgets('safe top-level navigation remains available from Work', (
    tester,
  ) async {
    final router = createAppRouter(initialLocation: '/work');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _EmptyWorkQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/finance');
    await tester.pumpAndSettle();

    expect(find.text('Finance is not built yet.'), findsOneWidget);
  });

  testWidgets('invalid Work date scope is explicit and not replaced', (
    tester,
  ) async {
    final router = createAppRouter(
      initialLocation: '/work?from=2026-09-31&to=2026-10-01',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _EmptyWorkQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invalid Work scope'), findsOneWidget);
    expect(find.textContaining('today'), findsNothing);
  });

  testWidgets('routes never render unknown query content', (tester) async {
    final router = createAppRouter(
      initialLocation: '/work?note=private-marker&mode=inspect',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _EmptyWorkQueryRepository(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('private-marker'), findsNothing);
  });

  testWidgets('an old edit link to a record opens its property sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: _replacementEditLocation);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _DraftQueryRepository(),
          ),
          timezoneServiceProvider.overrideWithValue(IanaTimezoneService()),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General'), findsOneWidget);
    expect(find.widgetWithText(KeyButton, 'Apply'), findsOneWidget);
    expect(find.text('Revise replacement shift'), findsNothing);
  });

  testWidgets('a replacement draft opens as a property sheet; OK revises it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.reset);
    ReviseShiftDraftCommand? issued;
    final router = createAppRouter(
      initialLocation: _replacementEditLocation.replaceFirst(
        'mode=edit',
        'mode=properties',
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _DraftQueryRepository(),
          ),
          timezoneServiceProvider.overrideWithValue(IanaTimezoneService()),
          reviseShiftDraftProvider.overrideWithValue((command) async {
            issued = command;
            return Committed(_revisedFinalized);
          }),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-manual-shift')), findsNothing);
    expect(timeIn(tester, 'shift-start-time'), const LocalTime(10, 0));
    expect(timeIn(tester, 'shift-end-time'), const LocalTime(18, 0));
    await setTime(tester, 'shift-end-time', const LocalTime(17, 0));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(issued?.id, _replacementShiftId);
    expect(issued?.expectedRevision, const Revision(0));
    expect(issued?.localEndTime, const LocalTime(17, 0));
    expect(issued?.timezoneId, 'Europe/Amsterdam');
    expect(find.text('General'), findsNothing);
  });

  testWidgets('a stale revision keeps the sheet open and explains', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1400);
    addTearDown(tester.view.reset);
    final router = createAppRouter(initialLocation: _replacementEditLocation);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(
            _DraftQueryRepository(),
          ),
          timezoneServiceProvider.overrideWithValue(IanaTimezoneService()),
          reviseShiftDraftProvider.overrideWithValue(
            (_) async => const Stale<WorkShift>(),
          ),
        ],
        child: LifeOsApp(router: router),
      ),
    );
    await tester.pumpAndSettle();

    // What the owner typed survives the stale outcome.
    await setTime(tester, 'shift-end-time', const LocalTime(17, 0));
    await tapInDialog(tester, find.text('OK'));

    expect(find.text('General'), findsOneWidget);
    expect(timeIn(tester, 'shift-end-time'), const LocalTime(17, 0));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      _replacementEditLocation,
    );
    expect(find.text('Reload record'), findsOneWidget);
  });
}

final class _EmptyWorkQueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

final class _ShiftWorkQueryRepository implements WorkQueryRepository {
  final requestedScopes = <WorkScope>[];

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) {
    requestedScopes.add(scope);
    return Stream.value(
      WorkRegisterProjection(
        scope: scope,
        period: null,
        shiftRows: [
          ShiftRegisterRow(
            id: _shiftId,
            localStartDate: '2026-09-29',
            startUtc: DateTime.utc(2026, 9, 29, 8),
            endUtc: DateTime.utc(2026, 9, 29, 16),
            state: ShiftState.finalized,
          ),
        ],
        payslipRows: const [],
        paid: const Money(minorUnits: 12345),
        reconciliation: null,
        shiftSheet: [
          ShiftSheetRow(
            shift: _liveShift(
              ShiftState.finalized,
              const Revision(2),
              endUtc: DateTime.utc(2026, 9, 29, 16),
            ),
            breakSeconds: 0,
            paidSeconds: 8 * 3600,
            period: null,
          ),
        ],
      ),
    );
  }

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _shiftId = ShiftId('00000000-0000-7000-8000-000000000001');
final _employment = Employment(
  id: _employmentId,
  name: 'Synthetic studio',
  legalLabel: null,
  status: EmploymentStatus.active,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(0),
);

final class _LiveShiftQueryRepository implements WorkQueryRepository {
  _LiveShiftQueryRepository(this._current);

  WorkRecordProjection? _current;
  final _changes = StreamController<WorkRecordProjection?>.broadcast();

  void emit(WorkRecordProjection value) {
    _current = value;
    _changes.add(value);
  }

  Future<void> close() => _changes.close();

  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) async* {
    yield id == _shiftId ? _current : null;
    yield* _changes.stream.where((value) => value?.id == id);
  }
}

const _agreementId = AgreementId('00000000-0000-7000-8000-000000000003');
const _breakId = ShiftBreakId('00000000-0000-7000-8000-000000000002');

WorkShift _liveShift(ShiftState state, Revision revision, {DateTime? endUtc}) =>
    WorkShift(
      id: _shiftId,
      employmentId: _employmentId,
      agreementId: state == ShiftState.finalized ? _agreementId : null,
      state: state,
      startUtc: DateTime.utc(2026, 9, 29, 8),
      endUtc: endUtc,
      timezoneId: 'Europe/Amsterdam',
      localStartDate: const LocalDate(2026, 9, 29),
      note: null,
      voidReason: null,
      replacementShiftId: null,
      replacedShiftId: null,
      createdAtUtc: DateTime.utc(2026, 9, 29, 8),
      updatedAtUtc: DateTime.utc(2026, 9, 29, 12),
      revision: revision,
    );

final _closedBreak = ShiftBreak(
  id: _breakId,
  shiftId: _shiftId,
  startUtc: DateTime.utc(2026, 9, 29, 12),
  endUtc: DateTime.utc(2026, 9, 29, 12, 30),
  createdAtUtc: DateTime.utc(2026, 9, 29, 12),
  updatedAtUtc: DateTime.utc(2026, 9, 29, 12, 30),
  revision: const Revision(1),
);

const _periodId = PayPeriodId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c51');
const _payslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c61');
final _periodLocation =
    '/work?employment=${_employmentId.value}&period=${_periodId.value}'
    '&record=payPeriod:${_periodId.value}&mode=properties';

final _openPeriod = PayPeriod.create(
  id: _periodId,
  employmentId: _employmentId,
  start: const LocalDate(2026, 9, 1),
  end: const LocalDate(2026, 9, 30),
  label: null,
  nowUtc: DateTime.utc(2026, 9, 1),
);

final _payslip = Payslip(
  id: _payslipId,
  periodId: _periodId,
  issuedDate: const LocalDate(2026, 9, 30),
  paidDate: null,
  amount: const Money(minorUnits: 95000),
  basis: const GrossBasis(),
  grossMinorUnits: null,
  netMinorUnits: null,
  deductionMinorUnits: null,
  reference: null,
  note: null,
  state: PayslipState.effective,
  voidReason: null,
  replacementPayslipId: null,
  replacedPayslipId: null,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(0),
);

final class _PeriodQueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) {
    if (scope.temporal == null) {
      return Stream.value(
        WorkRegisterProjection(
          scope: scope,
          period: null,
          shiftRows: const [],
          payslipRows: const [],
          paid: const Money(minorUnits: 0),
          reconciliation: null,
          periodRows: [_openPeriod],
          periodSheet: [
            PeriodSheetRow(period: _openPeriod, shiftCount: 0, groups: []),
          ],
        ),
      );
    }
    return Stream.value(
      WorkRegisterProjection(
        scope: scope,
        period: _openPeriod,
        shiftRows: const [],
        payslipRows: const [],
        paid: const Money(minorUnits: 9500),
        reconciliation: ReconciliationProjection(
          period: _openPeriod,
          shiftFacts: const [],
          payslipEvidence: const [],
          groups: [
            ReconciliationGroup(
              employmentId: _employmentId,
              periodId: _periodId,
              currency: const CurrencyCode.eur(),
              basis: const GrossBasis(),
              regularPaidSeconds: 0,
              overtimePaidSeconds: 0,
              expected: const Money(minorUnits: 10000),
              paid: const Money(minorUnits: 9500),
              difference: const Money(minorUnits: -500),
              shiftIds: const [],
              payslipIds: const [],
              status: const Difference(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) => Stream.value(
    id == _periodId ? PayPeriodRecordProjection(_openPeriod) : null,
  );
}

const _replacementShiftId = ShiftId('00000000-0000-7000-8000-000000000009');
const _replacementPayslipId = PayslipId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c69');
final _finalizedShift = _liveShift(
  ShiftState.finalized,
  const Revision(3),
  endUtc: DateTime.utc(2026, 9, 29, 16),
);
final _replacementDraft = _finalizedShift.replacementDraft(
  replacementId: _replacementShiftId,
  nowUtc: DateTime.utc(2026, 10, 1),
);
final _finalizedLocation =
    '/work?employment=${_employmentId.value}'
    '&from=2026-09-29&to=2026-09-29'
    '&record=shift:${_shiftId.value}&mode=inspect';
final _finalizedProperties = _finalizedLocation.replaceFirst(
  'mode=inspect',
  'mode=properties',
);

final class _PayslipQueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(id == _payslipId ? PayslipRecordProjection(_payslip) : null);
}

final _replacementEditLocation =
    '/work?employment=${_employmentId.value}'
    '&from=2026-09-29&to=2026-09-29'
    '&record=shift:${_replacementShiftId.value}&mode=edit';
final _revisedFinalized = WorkShift(
  id: _replacementShiftId,
  employmentId: _employmentId,
  agreementId: _agreementId,
  state: ShiftState.finalized,
  startUtc: DateTime.utc(2026, 9, 29, 8),
  endUtc: DateTime.utc(2026, 9, 29, 15),
  timezoneId: 'Europe/Amsterdam',
  localStartDate: const LocalDate(2026, 9, 29),
  note: null,
  voidReason: null,
  replacementShiftId: null,
  replacedShiftId: _shiftId,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(1),
);

final class _DraftQueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) => Stream.value(
    id == _replacementShiftId
        ? ShiftRecordProjection(_replacementDraft, breaks: const [])
        : null,
  );
}
