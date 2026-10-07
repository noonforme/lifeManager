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
import 'package:lifeos/features/work/domain/agreement.dart';
import 'package:lifeos/features/work/domain/employment.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/presentation/employment_agreement_forms.dart';
import 'package:lifeos/features/work/presentation/work_controller.dart';
import 'package:lifeos/features/work/presentation/work_route_state.dart';
import 'package:lifeos/shared/workbench/era_time_field.dart';
import 'package:lifeos/shared/workbench/lifeos_skin.dart';
import 'package:lifeos/shared/workbench/lifeos_theme.dart';
import 'package:lifeos/shared/workbench/office_controls.dart';
import 'package:lifeos/shared/workbench/property_sheet.dart';

import '../../../support/era_pickers.dart';

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

  // The agreement's tabs (XP-authentic shell spec 4.4) and the fields on
  // the tabs other than Rate.
  const tabOf = {
    'agreement-overtime-hours': 'Premiums',
    'agreement-overtime-multiplier': 'Premiums',
    'agreement-night-enabled': 'Premiums',
    'agreement-night-start': 'Premiums',
    'agreement-night-end': 'Premiums',
    'agreement-night-multiplier': 'Premiums',
    'agreement-holidays-enabled': 'Premiums',
    'agreement-holiday-multiplier': 'Premiums',
    'agreement-vacation-percent': 'Leave',
    'agreement-sick-percent': 'Leave',
    'agreement-sick-days': 'Leave',
  };

  Future<void> openTab(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PropertySheetTabs),
        matching: find.text(tab),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTabFor(WidgetTester tester, String key) =>
      openTab(tester, tabOf[key] ?? 'Rate');

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await openTabFor(tester, key);
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
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      _TestApp(
        textScale: textScale,
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

      expect(find.text('Name:'), findsOneWidget);
      expect(
        find.text('What you call this job, e.g. Warehouse'),
        findsOneWidget,
      );
      expect(find.text('Legal name (optional):'), findsOneWidget);
      expect(
        find.text('Employer name as it appears on payslips'),
        findsOneWidget,
      );
    });

    testWidgets('on its property sheet the form edits an employment', (
      tester,
    ) async {
      EmploymentDraft? submitted;
      final sheet = PropertySheetController();
      addTearDown(sheet.dispose);
      await tester.pumpWidget(
        _TestApp(
          child: PropertySheetScope(
            controller: sheet,
            child: EmploymentForm(
              initial: _employment,
              onSubmit: (draft) async {
                submitted = draft;
                return Committed(_employment);
              },
            ),
          ),
        ),
      );

      expect(find.text('Save employment'), findsNothing);
      expect(sheet.dirty, isFalse);
      await tester.enterText(
        find.byKey(const ValueKey('employment-name')),
        'Warehouse',
      );
      expect(sheet.dirty, isTrue);
      expect(await sheet.apply(), isTrue);
      expect(submitted?.name, 'Warehouse');
    });

    testWidgets('a stale save says to reload and keeps the sheet open', (
      tester,
    ) async {
      final sheet = PropertySheetController();
      addTearDown(sheet.dispose);
      await tester.pumpWidget(
        _TestApp(
          child: PropertySheetScope(
            controller: sheet,
            child: EmploymentForm(
              initial: _employment,
              onSubmit: (_) async => const Stale<Employment>(),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('employment-name')),
        'Warehouse',
      );
      expect(await sheet.apply(), isFalse);
      await tester.pump();
      expect(find.text(staleMessage), findsOneWidget);
    });
  });

  group('agreement form', () {
    testWidgets('defaults are filled in, so a rate alone is enough', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      expect(
        dateIn(tester, 'agreement-effective-start'),
        const LocalDate(2026, 10, 1),
      );
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

    testWidgets('leave pay has its own group box and exact fractions', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await enter(tester, 'agreement-sick-percent', '70');
      // The form scrolls lazily; the box is built once its field is shown.
      expect(find.text('Leave pay'), findsOneWidget);
      await submitAgreement(tester);

      final terms = submitted!.terms;
      expect(terms.vacationPay, _r(1, 1));
      expect(terms.sickPay, _r(7, 10));
      expect(terms.sickEmployerDays, 2);
    });

    testWidgets('leave pay defaults are 100 %, 62.06 % and 2 days', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await submitAgreement(tester);

      expect(submitted!.terms.sickPay, _r(3103, 5000));
    });

    testWidgets('decimals become exact fractions and minutes', (tester) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await enter(tester, 'agreement-overtime-hours', '7.5');
      await enter(tester, 'agreement-overtime-multiplier', '1.25');
      await enter(tester, 'agreement-night-multiplier', '1.333');
      await openTab(tester, 'Premiums');
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

    testWidgets('dates and the night window are picked with defaults', (
      tester,
    ) async {
      AgreementDraft? submitted;
      await pumpAgreementForm(tester, onSubmit: (draft) => submitted = draft);

      expect(
        dateIn(tester, 'agreement-effective-start'),
        const LocalDate(2026, 10, 1),
      );
      expect(dateIn(tester, 'agreement-effective-end'), isNull);
      await openTab(tester, 'Premiums');
      expect(timeIn(tester, 'agreement-night-start'), const LocalTime(22, 0));
      expect(timeIn(tester, 'agreement-night-end'), const LocalTime(6, 0));

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await pickDate(
        tester,
        'agreement-effective-end',
        const LocalDate(2026, 12, 31),
      );
      await openTab(tester, 'Premiums');
      await setTime(tester, 'agreement-night-start', const LocalTime(21, 30));
      await submitAgreement(tester);

      expect(submitted!.terms.effectiveStart, const LocalDate(2026, 10, 1));
      expect(submitted!.terms.effectiveEnd, const LocalDate(2026, 12, 31));
      expect(submitted!.terms.nightStartMinute, 21 * 60 + 30);
      expect(submitted!.terms.nightEndMinute, 6 * 60);
    });

    testWidgets('an end before the start is refused', (tester) async {
      var submitted = false;
      await pumpAgreementForm(tester, onSubmit: (_) => submitted = true);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await pickDate(
        tester,
        'agreement-effective-end',
        const LocalDate(2026, 9, 30),
      );
      await submitAgreement(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(find.text(agreementRangeMessage), findsOneWidget);
    });

    testWidgets('the night boxes are disabled with night pay off', (
      tester,
    ) async {
      await pumpAgreementForm(tester);
      await openTab(tester, 'Premiums');
      final night = find.byKey(const ValueKey('agreement-night-enabled'));
      await tester.ensureVisible(night);
      await tester.pumpAndSettle();
      await tester.tap(night);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('agreement-night-start')),
        ),
        isSemantics(label: 'Night pay starts, 22:00', isEnabled: false),
      );
    });

    testWidgets('the night times stay on one row at 200 % text', (
      tester,
    ) async {
      await pumpAgreementForm(tester, textScale: 2);
      await openTab(tester, 'Premiums');
      for (final key in ['agreement-night-start', 'agreement-night-end']) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        final box = find.ancestor(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(EraTimeField),
        );
        await tester.ensureVisible(box);
        await tester.pumpAndSettle();
        Rect part(String name) => tester.getRect(
          find.descendant(
            of: box,
            matching: find.byKey(ValueKey('era-time-$name')),
          ),
        );
        expect(
          part('minute').top,
          moreOrLessEquals(part('hour').top, epsilon: 0.5),
          reason: '$key splits its hours and minutes',
        );
        expect(part('minute').left, greaterThan(part('hour').right));
        expect(
          tester.getRect(find.byKey(ValueKey(key))).right,
          greaterThanOrEqualTo(part('minute').right),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a storage overlap brings the Rate tab forward', (
      tester,
    ) async {
      await pumpAgreementForm(
        tester,
        outcome: const Invalid<PayAgreement>({'effectiveRange': []}),
      );
      await enter(tester, 'agreement-hourly-rate', '18.40');
      await openTab(tester, 'Notes');
      await submitAgreement(tester);
      expect(
        find.text('These dates overlap another agreement.'),
        findsOneWidget,
      );
    });

    testWidgets('night start equal to its end is refused', (tester) async {
      await pumpAgreementForm(tester);

      await enter(tester, 'agreement-hourly-rate', '18.40');
      await openTab(tester, 'Premiums');
      await setTime(tester, 'agreement-night-start', const LocalTime(6, 0));
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
      await openTab(tester, 'Premiums');
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

    Future<PropertySheetController> pumpSheet(
      WidgetTester tester, {
      MutationOutcome<PayAgreement>? outcome,
      void Function(AgreementDraft draft)? onSubmit,
    }) async {
      final sheet = PropertySheetController();
      addTearDown(sheet.dispose);
      await tester.pumpWidget(
        _TestApp(
          child: PropertySheetScope(
            controller: sheet,
            child: AgreementForm(
              employmentId: _employmentId,
              initial: _agreement,
              today: const LocalDate(2026, 10, 1),
              onSubmit: (draft) async {
                onSubmit?.call(draft);
                return outcome ?? Committed(_agreement);
              },
            ),
          ),
        ),
      );
      return sheet;
    }

    testWidgets('on its sheet an unused agreement saves through the sheet', (
      tester,
    ) async {
      AgreementDraft? submitted;
      final sheet = await pumpSheet(
        tester,
        onSubmit: (draft) => submitted = draft,
      );

      expect(find.byKey(const ValueKey('save-agreement')), findsNothing);
      expect(find.text('25.50'), findsOneWidget);
      expect(sheet.dirty, isFalse);
      await enter(tester, 'agreement-hourly-rate', '26.00');
      expect(sheet.dirty, isTrue);
      expect(await sheet.apply(), isTrue);
      expect(submitted?.terms.hourlyRateMicroEur, 26000000);
      expect(submitted?.terms.effectiveStart, const LocalDate(2026, 10, 1));
    });

    testWidgets('a refused sheet save stays open on the problem tab', (
      tester,
    ) async {
      final sheet = await pumpSheet(tester);
      await enter(tester, 'agreement-hourly-rate', '0');
      await openTab(tester, 'Leave');
      expect(await sheet.apply(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Enter a rate above zero.'), findsOneWidget);
      expect(sheet.dirty, isTrue);
    });

    testWidgets('in-use and stale outcomes use the section 9 copy', (
      tester,
    ) async {
      var sheet = await pumpSheet(
        tester,
        outcome: const Invalid<PayAgreement>({
          'agreement.inUse': [FieldIssue(FieldIssueCode.conflict)],
        }),
      );
      await enter(tester, 'agreement-hourly-rate', '26.00');
      expect(await sheet.apply(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(agreementInUseMessage), findsOneWidget);

      sheet = await pumpSheet(tester, outcome: const Stale<PayAgreement>());
      await enter(tester, 'agreement-hourly-rate', '27.00');
      expect(await sheet.apply(), isFalse);
      await tester.pumpAndSettle();
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

  group('read-only agreement', () {
    testWidgets('an agreement in use shows its terms greyed and says why', (
      tester,
    ) async {
      var submitted = false;
      final sheet = PropertySheetController();
      addTearDown(sheet.dispose);
      await tester.pumpWidget(
        _TestApp(
          child: PropertySheetScope(
            controller: sheet,
            child: AgreementForm(
              employmentId: _employmentId,
              initial: _agreement,
              readOnly: true,
              lockedReason:
                  'Used by 3 finished shifts, so these terms can '
                  'no longer change.',
              onSubmit: (_) async {
                submitted = true;
                return Committed(_agreement);
              },
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Used by 3 finished shifts, so these terms can no longer change.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('agreement-hourly-rate')),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Net'));
      await tester.pump();
      expect(sheet.dirty, isFalse);
      expect(await sheet.apply(), isTrue);
      expect(submitted, isFalse);
    });
  });

  group('employment sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      bool canDelete = true,
      bool inUse = false,
      Future<MutationOutcome<Employment>> Function(Employment)? onDelete,
    }) => tester.pumpWidget(
      _TestApp(
        child: EmploymentSheet(
          employment: _employment,
          onSubmit: (_) async => Committed(_employment),
          canDelete: canDelete,
          agreementInUse: inUse,
          onDelete: onDelete ?? (_) async => Committed(_employment),
          onViewAgreement: () {},
        ),
      ),
    );

    testWidgets('shows the name to edit, the agreement and Delete', (
      tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text('Studio'), findsWidgets);
      expect(find.byKey(const ValueKey('employment-name')), findsOneWidget);
      expect(find.text('Agreement…'), findsOneWidget);
      expect(find.text('Delete…'), findsOneWidget);
    });

    testWidgets('history hides Delete', (tester) async {
      await pumpSheet(tester, canDelete: false, inUse: true);

      expect(find.text('Delete…'), findsNothing);
      expect(find.text('Agreement…'), findsOneWidget);
    });

    testWidgets('delete confirms inline before it runs', (tester) async {
      var deleted = false;
      await pumpSheet(
        tester,
        onDelete: (_) async {
          deleted = true;
          return Committed(_employment);
        },
      );

      await tester.tap(find.text('Delete…'));
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
      expect(find.text('Delete…'), findsOneWidget);

      await tester.tap(find.text('Delete…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-employment')));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });

    testWidgets('a rejected delete explains the history', (tester) async {
      await pumpSheet(
        tester,
        onDelete: (_) async => const Invalid<Employment>({
          'employment.hasHistory': [FieldIssue(FieldIssueCode.conflict)],
        }),
      );
      await tester.tap(find.text('Delete…'));
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

  test(
    'agreement commands carry the revision, the date and the route',
    () async {
      UpdateAgreementCommand? widen;
      ChangeAgreementTermsCommand? change;
      CloseAgreementCommand? end;
      DeleteAgreementCommand? remove;
      final routes = <WorkRouteState>[];
      final container = ProviderContainer(
        overrides: [
          workQueryRepositoryProvider.overrideWithValue(_QueryRepository()),
          workRouteProvider.overrideWithValue(
            const ValidWorkRoute(
              WorkRouteState(
                employmentId: _employmentId,
                scope: null,
                record: WorkRecordRef(
                  kind: WorkRecordKind.agreement,
                  id: _agreementId,
                ),
                mode: WorkInspectorMode.properties,
              ),
            ),
          ),
          replaceWorkRouteProvider.overrideWithValue(routes.add),
          updateAgreementProvider.overrideWithValue((command) async {
            widen = command;
            return Committed(_agreement);
          }),
          changeAgreementTermsProvider.overrideWithValue((command) async {
            change = command;
            return Committed(_agreement);
          }),
          endAgreementProvider.overrideWithValue((command) async {
            end = command;
            return Committed(_agreement);
          }),
          removeAgreementProvider.overrideWithValue((command) async {
            remove = command;
            return Committed(_agreement);
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(workControllerProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(workControllerProvider.future);
      final controller = container.read(workControllerProvider.notifier);

      // A day before the agreement moves only its start, terms unchanged.
      await controller.widenAgreementToCover(
        _agreement,
        const LocalDate(2026, 9, 20),
      );
      expect(widen?.terms.effectiveStart, const LocalDate(2026, 9, 20));
      expect(widen?.terms.effectiveEnd, isNull);
      expect(widen?.terms.hourlyRateMicroEur, _agreement.hourlyRateMicroEur);
      expect(widen?.expectedRevision, _agreement.revision);

      await controller.changeAgreementTerms(
        _agreement,
        const AgreementDraft(
          employmentId: _employmentId,
          terms: AgreementTerms(
            effectiveStart: LocalDate(2026, 11, 1),
            effectiveEnd: null,
            hourlyRateMicroEur: 27000000,
            basis: GrossBasis(),
            label: null,
            note: null,
          ),
        ),
      );
      expect(change?.from, const LocalDate(2026, 11, 1));
      expect(change?.terms.hourlyRateMicroEur, 27000000);

      await controller.endAgreement(_agreement, const LocalDate(2026, 12, 31));
      expect(end?.end, const LocalDate(2026, 12, 31));
      expect(routes, isEmpty);

      // Removing the open agreement leaves the employment's register.
      await controller.removeAgreement(_agreement);
      expect(remove?.agreementId, _agreementId);
      expect(routes.single.record, isNull);
      expect(routes.single.mode, WorkInspectorMode.inspect);
    },
  );
}

RationalMultiplier _r(int numerator, int denominator) =>
    RationalMultiplier(numerator: numerator, denominator: denominator);

final class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.textScale = 1});

  final Widget child;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLifeOSTheme(),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: LifeOSSkinScope(
        child: Scaffold(body: SizedBox(width: 520, child: child)),
      ),
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
