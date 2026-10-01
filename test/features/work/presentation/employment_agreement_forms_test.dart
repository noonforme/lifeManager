import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/core/time/local_date.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/application/work_query_service.dart';
import 'package:lifeos/features/work/data/projections/work_record_projection.dart';
import 'package:lifeos/features/work/data/projections/work_register_projection.dart';
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/employment_agreement_forms.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_inspector.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> submitAgreement(WidgetTester tester) async {
    final action = find.byKey(const ValueKey('save-agreement'));
    await tester.scrollUntilVisible(
      action,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets('empty Work explains setup and opens employment creation', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: WorkInspector(
          onCreateEmployment: (_) async => Committed(_employment),
          onCreateAgreement: (_) async => Committed(_agreement),
        ),
      ),
    );

    expect(
      find.text(
        'Create an employment and an agreement before recording paid work.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Create employment'));
    await tester.pump();

    expect(find.bySemanticsLabel('Create employment'), findsOneWidget);
  });

  testWidgets('invalid agreement keeps field values and associates errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: AgreementForm(
          employmentId: _employmentId,
          onSubmit: (_) async => const Invalid<PayAgreement>({
            'hourlyRate': [FieldIssue(FieldIssueCode.outOfRange)],
          }),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agreement-effective-start')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '25.50',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-threshold')),
      '480',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-multiplier-numerator')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-multiplier-denominator')),
      '2',
    );
    await submitAgreement(tester);

    expect(find.text('Enter a rate above zero.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Hourly rate, Enter a rate above zero.'),
      findsOneWidget,
    );
    expect(find.text('25.50'), findsOneWidget);
  });

  testWidgets(
    'shift actions appear only after employment and agreement commit',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: WorkInspector(
            onCreateEmployment: (_) async => Committed(_employment),
            onCreateAgreement: (_) async => Committed(_agreement),
          ),
        ),
      );

      expect(find.text('Start shift'), findsNothing);
      expect(find.text('Add manual shift'), findsNothing);
      await tester.tap(find.text('Create employment'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('employment-name')),
        'Studio',
      );
      await tester.tap(find.text('Save employment'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Create agreement'), findsOneWidget);
      expect(find.text('Start shift'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('agreement-effective-start')),
        '2026-10-01',
      );
      await tester.enterText(
        find.byKey(const ValueKey('agreement-hourly-rate')),
        '25.50',
      );
      await tester.enterText(
        find.byKey(const ValueKey('agreement-threshold')),
        '480',
      );
      await tester.enterText(
        find.byKey(const ValueKey('agreement-multiplier-numerator')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('agreement-multiplier-denominator')),
        '2',
      );
      await submitAgreement(tester);

      expect(find.text('Start shift'), findsOneWidget);
      expect(find.text('Add manual shift'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
    },
  );

  test('controller actions adapt drafts to typed commands', () async {
    CreateEmploymentCommand? employmentCommand;
    CreateAgreementCommand? agreementCommand;
    final container = ProviderContainer(
      overrides: [
        workQueryRepositoryProvider.overrideWithValue(_QueryRepository()),
        workRouteProvider.overrideWithValue(
          const ValidWorkRoute(
            WorkRouteState(
              employmentId: _employmentId,
              scope: null,
              record: null,
              mode: WorkInspectorMode.inspect,
            ),
          ),
        ),
        createEmploymentProvider.overrideWithValue((command) async {
          employmentCommand = command;
          return Committed(_employment);
        }),
        createAgreementProvider.overrideWithValue((command) async {
          agreementCommand = command;
          return Committed(_agreement);
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(workControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(workControllerProvider.future);
    final controller = container.read(workControllerProvider.notifier);

    await controller.submitEmployment(
      const EmploymentDraft(name: '  Studio  ', legalLabel: '  Legal  '),
    );
    await controller.submitAgreement(
      const AgreementDraft(
        employmentId: _employmentId,
        effectiveStart: LocalDate(2026, 10, 1),
        effectiveEnd: null,
        hourlyRateMicroEur: 25500000,
        basis: GrossBasis(),
        overtimeThresholdMinutes: 480,
        multiplierNumerator: 3,
        multiplierDenominator: 2,
        label: '  Standard  ',
        note: '  Initial  ',
      ),
    );

    expect(employmentCommand?.name, 'Studio');
    expect(employmentCommand?.legalLabel, 'Legal');
    expect(agreementCommand?.hourlyRateMicroEur, 25500000);
    expect(agreementCommand?.overtimeMultiplierNumerator, 3);
    expect(agreementCommand?.overtimeMultiplierDenominator, 2);
    expect(agreementCommand?.label, 'Standard');
    expect(agreementCommand?.note, 'Initial');
  });

  testWidgets('agreement form converts decimal EUR to integer micro-euros', (
    tester,
  ) async {
    AgreementDraft? submitted;
    await tester.pumpWidget(
      _TestApp(
        child: AgreementForm(
          employmentId: _employmentId,
          onSubmit: (draft) async {
            submitted = draft;
            return Committed(_agreement);
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('agreement-effective-start')),
      '2026-10-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-hourly-rate')),
      '25.50',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-threshold')),
      '480',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-multiplier-numerator')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('agreement-multiplier-denominator')),
      '2',
    );
    await submitAgreement(tester);

    expect(submitted?.hourlyRateMicroEur, 25500000);
    expect(submitted?.basis, isA<GrossBasis>());
  });
}

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(highContrast: false),
      home: Scaffold(body: SizedBox(width: 520, child: child)),
    );
  }
}

const _employmentId = EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11');
const _agreementId = AgreementId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c21');
final _employment = Employment(
  id: _employmentId,
  name: 'Studio',
  legalLabel: null,
  status: EmploymentStatus.active,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  updatedAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(0),
);

final class _QueryRepository implements WorkQueryRepository {
  @override
  Stream<WorkRegisterProjection> watchRegister(WorkScope scope) =>
      Stream.value(WorkRegisterProjection.empty(scope));

  @override
  Stream<WorkRecordProjection?> watchRecord(WorkRecordId id) =>
      Stream.value(null);
}

final _agreement = PayAgreement(
  id: _agreementId,
  employmentId: _employmentId,
  version: 1,
  effectiveStart: const LocalDate(2026, 10, 1),
  effectiveEnd: null,
  hourlyRateMicroEur: 25500000,
  basis: const GrossBasis(),
  overtimeThresholdMinutes: 480,
  overtimeMultiplier: const RationalMultiplier(numerator: 3, denominator: 2),
  label: null,
  note: null,
  createdAtUtc: DateTime.utc(2026, 10, 1),
  revision: const Revision(0),
  usedByFinalizedShift: false,
);
