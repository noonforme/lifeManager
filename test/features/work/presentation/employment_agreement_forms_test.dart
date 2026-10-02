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
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';

void main() {
  Future<void> submitAgreement(WidgetTester tester) async {
    // A focused field scrolls itself back into view; release it first.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final action = find.byKey(const ValueKey('save-agreement'));
    await tester.scrollUntilVisible(
      action,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    // Built is not on screen; bring it into view before tapping.
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      field,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(field, text);
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<AgreementDraft?> pumpAgreementForm(
    WidgetTester tester, {
    PayAgreement? initial,
    MutationOutcome<PayAgreement>? outcome,
    void Function(AgreementDraft draft)? onSubmit,
  }) async {
    await tester.pumpWidget(
      _TestApp(
        child: AgreementForm(
          employmentId: _employmentId,
          initial: initial,
          today: const LocalDate(2026, 10, 1),
          onSubmit: (draft) async {
            onSubmit?.call(draft);
            return outcome ?? Committed(_agreement);
          },
        ),
      ),
    );
    return null;
  }

  group('employment form', () {
    testWidgets('names its fields with hints', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: EmploymentForm(onSubmit: (_) async => Committed(_employment)),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(
        find.text('What you call this job, e.g. Warehouse'),
        findsOneWidget,
      );
      expect(find.text('Legal name (optional)'), findsOneWidget);
      expect(
        find.text('Employer name as it appears on payslips'),
        findsOneWidget,
      );
    });

    testWidgets('the same form edits an employment', (tester) async {
      EmploymentDraft? submitted;
      await tester.pumpWidget(
        _TestApp(
          child: EmploymentForm(
            initial: _employment,
            onSubmit: (draft) async {
              submitted = draft;
              return Committed(_employment);
            },
          ),
        ),
      );

      expect(find.text('Edit employment'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('employment-name')),
        'Warehouse',
      );
      await tester.tap(find.text('Save employment'));
      await tester.pumpAndSettle();
      expect(submitted?.name, 'Warehouse');
    });

    testWidgets('a stale save says to reload', (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: EmploymentForm(
            initial: _employment,
            onSubmit: (_) async => const Stale<Employment>(),
          ),
        ),
      );
      await tester.tap(find.text('Save employment'));
      await tester.pumpAndSettle();
      expect(find.text(staleMessage), findsOneWidget);
    });
  });

  group('agreement form', () {
    testWidgets('defaults are filled in, so a rate alone is enough', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      expect(find.text('2026-10-01'), findsOneWidget);
      await enter(tester, 'agreement-hourly-rate', '18.40');
      await submitAgreement(tester);

      final terms = submitted!.terms;
      expect(terms.effectiveStart, const LocalDate(2026, 10, 1));
      expect(terms.hourlyRateMicroEur, 18400000);
      expect(terms.basis, isA<GrossBasis>());
      expect(terms.overtimeThresholdMinutes, 480);
      expect(terms.overtimeMultiplier, _r(3, 2));
      expect(terms.nightEnabled, isTrue);
      expect(terms.nightStartMinute, 22 * 60);
      expect(terms.nightEndMinute, 6 * 60);
      expect(terms.nightMultiplier, _r(3, 2));
      expect(terms.holidayCalendar, HolidayCalendar.lithuania);
      expect(terms.holidayMultiplier, _r(2, 1));
      expect(terms.premiumStacking, PremiumStacking.highest);
    });

    testWidgets('decimals become exact fractions and minutes', (tester) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await enter(tester, 'agreement-overtime-hours', '7.5');
      await enter(tester, 'agreement-overtime-multiplier', '1.25');
      await enter(tester, 'agreement-night-multiplier', '1.333');
      await tapVisible(tester, find.text('Add the extras'));
      await submitAgreement(tester);

      final terms = submitted!.terms;
      expect(terms.overtimeThresholdMinutes, 450);
      expect(terms.overtimeMultiplier, _r(5, 4));
      expect(terms.nightMultiplier, _r(1333, 1000));
      expect(terms.premiumStacking, PremiumStacking.additive);
    });

    testWidgets('a multiplier below 1 or unparseable is refused', (
      tester,
    ) async {
      var submitted = false;
      await pumpAgreementForm(tester, onSubmit: (_) => submitted = true);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await enter(tester, 'agreement-night-multiplier', '0.5');
      await enter(tester, 'agreement-holiday-multiplier', 'double');
      await submitAgreement(tester);

      expect(submitted, isFalse);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.text(multiplierMessage), findsNWidgets(2));
    });

    testWidgets('night start equal to its end is refused', (tester) async {
      await pumpAgreementForm(tester);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await enter(tester, 'agreement-night-start', '06:00');
      await submitAgreement(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(find.text(nightWindowMessage), findsOneWidget);
    });

    testWidgets('switching premiums off keeps the night window', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('agreement-night-enabled')),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('agreement-holidays-enabled')),
      );
      await submitAgreement(tester);

      final terms = submitted!.terms;
      expect(terms.nightEnabled, isFalse);
      expect(terms.nightStartMinute, 22 * 60);
      expect(terms.holidayCalendar, HolidayCalendar.none);
    });

    testWidgets('the same form edits an unused agreement', (tester) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(
        tester,
        initial: _agreement,
        onSubmit: (draft) => submitted = draft,
      );

      expect(find.text('Edit agreement'), findsOneWidget);
      expect(find.text('25.50'), findsOneWidget);
      await submitAgreement(tester);
      expect(submitted?.terms.hourlyRateMicroEur, 25500000);
      expect(submitted?.terms.effectiveStart, const LocalDate(2026, 10, 1));
    });

    testWidgets('in-use and stale outcomes use the section 9 copy', (
      tester,
    ) async {
      await pumpAgreementForm(
        tester,
        initial: _agreement,
        outcome: const Invalid<PayAgreement>({
          'agreement.inUse': [FieldIssue(FieldIssueCode.conflict)],
        }),
      );
      await submitAgreement(tester);
      expect(find.text(agreementInUseMessage), findsOneWidget);

      await pumpAgreementForm(
        tester,
        initial: _agreement,
        outcome: const Stale<PayAgreement>(),
      );
      await submitAgreement(tester);
      expect(find.text(staleMessage), findsOneWidget);
    });

    testWidgets('an invalid rate keeps field values and associates errors', (
      tester,
    ) async {
      await pumpAgreementForm(tester);

      await enter(tester, 'agreement-hourly-rate', '0');
      await submitAgreement(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('agreement-hourly-rate')),
        -240,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.bySemanticsLabel('Hourly rate, Enter a rate above zero.'),
        findsOneWidget,
      );
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('agreement view', () {
    testWidgets('an agreement in use is read-only and says why', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AgreementView(
            agreement: _agreement,
            finishedShifts: 3,
            onEdit: () {},
          ),
        ),
      );

      expect(
        find.text(
          'Used by 3 finished shifts. New versions arrive in a later update.',
        ),
        findsOneWidget,
      );
      expect(find.text('Edit agreement'), findsNothing);
      expect(find.text('22:00 to 06:00, ×1.5'), findsOneWidget);
    });
  });

  group('employment header', () {
    Future<void> pumpHeader(
      WidgetTester tester, {
      bool canDelete = true,
      bool inUse = false,
      Future<MutationOutcome<Employment>> Function(Employment)? onDelete,
    }) => tester.pumpWidget(
      _TestApp(
        child: EmploymentHeader(
          employment: _employment,
          canDelete: canDelete,
          agreementInUse: inUse,
          onEdit: () {},
          onDelete: onDelete ?? (_) async => Committed(_employment),
          onEditAgreement: () {},
          onViewAgreement: () {},
        ),
      ),
    );

    testWidgets('offers edit, agreement edit and delete without history', (
      tester,
    ) async {
      await pumpHeader(tester);

      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Edit agreement'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('history hides delete and an agreement in use is view-only', (
      tester,
    ) async {
      await pumpHeader(tester, canDelete: false, inUse: true);

      expect(find.text('Delete'), findsNothing);
      expect(find.text('Edit agreement'), findsNothing);
      expect(find.text('View agreement'), findsOneWidget);
      expect(
        find.text('Has work history — archiving arrives in a later update.'),
        findsOneWidget,
      );
    });

    testWidgets('delete confirms inline before it runs', (tester) async {
      var deleted = false;
      await pumpHeader(
        tester,
        onDelete: (_) async {
          deleted = true;
          return Committed(_employment);
        },
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Delete Studio? Its unused agreement is removed too. This can't "
          'be undone.',
        ),
        findsOneWidget,
      );
      expect(deleted, isFalse);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-employment')));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('a rejected delete explains the history', (tester) async {
      await pumpHeader(
        tester,
        onDelete: (_) async => const Invalid<Employment>({
          'employment.hasHistory': [FieldIssue(FieldIssueCode.conflict)],
        }),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-employment')));
      await tester.pumpAndSettle();
      expect(find.text(employmentHistoryMessage), findsOneWidget);
    });
  });

  test('controller actions adapt drafts to typed commands', () async {
    CreateEmploymentCommand? employmentCommand;
    CreateAgreementCommand? agreementCommand;
    UpdateEmploymentCommand? renameCommand;
    DeleteEmploymentCommand? deleteCommand;
    UpdateAgreementCommand? updateCommand;
    final routes = <WorkRouteState>[];
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
        replaceWorkRouteProvider.overrideWithValue(routes.add),
        createEmploymentProvider.overrideWithValue((command) async {
          employmentCommand = command;
          return Committed(_employment);
        }),
        createAgreementProvider.overrideWithValue((command) async {
          agreementCommand = command;
          return Committed(_agreement);
        }),
        updateEmploymentProvider.overrideWithValue((command) async {
          renameCommand = command;
          return Committed(_employment);
        }),
        deleteEmploymentProvider.overrideWithValue((command) async {
          deleteCommand = command;
          return Committed(_employment);
        }),
        updateAgreementProvider.overrideWithValue((command) async {
          updateCommand = command;
          return Committed(_agreement);
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(workControllerProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(workControllerProvider.future);
    final controller = container.read(workControllerProvider.notifier);
    const terms = AgreementTerms(
      effectiveStart: LocalDate(2026, 10, 1),
      effectiveEnd: null,
      hourlyRateMicroEur: 25500000,
      basis: GrossBasis(),
      label: 'Standard',
      note: null,
    );

    await controller.submitEmployment(
      const EmploymentDraft(name: '  Studio  ', legalLabel: '  Legal  '),
    );
    await controller.submitAgreement(
      const AgreementDraft(employmentId: _employmentId, terms: terms),
    );
    await controller.updateEmployment(
      _employment,
      const EmploymentDraft(name: ' Warehouse ', legalLabel: ' '),
    );
    await controller.updateAgreement(
      _agreement,
      const AgreementDraft(employmentId: _employmentId, terms: terms),
    );
    await controller.deleteEmployment(_employment);

    expect(employmentCommand?.name, 'Studio');
    expect(employmentCommand?.legalLabel, 'Legal');
    expect(agreementCommand?.terms.hourlyRateMicroEur, 25500000);
    expect(renameCommand?.name, 'Warehouse');
    expect(renameCommand?.legalLabel, isNull);
    expect(renameCommand?.expectedRevision, _employment.revision);
    expect(updateCommand?.agreementId, _agreementId);
    expect(updateCommand?.terms.label, 'Standard');
    expect(deleteCommand?.employmentId, _employmentId);
    expect(routes.last.employmentId, isNull);
  });
}

RationalMultiplier _r(int numerator, int denominator) =>
    RationalMultiplier(numerator: numerator, denominator: denominator);

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

  @override
  Stream<ShiftRecordProjection?> watchActiveShift() => Stream.value(null);
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
