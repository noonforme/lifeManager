# LifeOS Native Work Domain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a Flutter- and Drift-free Work domain that represents immutable historical facts and deterministically derives agreement selection, expected compensation, and reconciliation.

**Architecture:** This phase consumes Phase 01's strict temporal values and provides only immutable Dart value objects and pure policy functions under `lib/features/work/domain/`. It deliberately has no database, Riverpod, Flutter, UUID generator, clock, route, or filesystem dependency; the next phase supplies IDs, persistence, transaction boundaries, and application use cases around these policies.

**Tech Stack:** Dart 3.13.4 from Flutter 3.47.5, `package:test`, `clock`, and Phase 01 core time and safe-outcome types.

**Spec:** `docs/superpowers/specs/2026-09-29-lifeos-native-foundation-work-design.md`

## Global Constraints

- Pin Flutter `3.47.5` and Dart `3.13.4`; do not add a package for domain modeling or arithmetic.
- Keep every file in this phase free of `package:flutter`, `drift`, `sqlite3`, Riverpod, GoRouter, filesystem, and wall-clock calls.
- Persisted money is integer minor units; hourly EUR rates are positive integer micro-euros per hour; pay calculations use `BigInt`, never `double`.
- Persisted instants are UTC and business dates are Phase 01 `LocalDate` values; duration uses elapsed UTC time and a shift retains its captured IANA zone and local start date.
- Rate basis is always explicit (`gross` or `net`); currencies and bases are never converted or combined.
- Agreement ranges and pay periods are inclusive local-date ranges; shifts use their captured local start date even when they end after midnight.
- Used agreements, finalized shifts, void shifts, effective payslips, and void payslips are historical facts; correction is void-and-replace rather than destructive mutation.
- Expected pay and reconciliation are derived projections and are never fields on factual records.
- Synthetic test data only; never add personal labels, notes, IDs, dates, amounts, screenshots, or diagnostics to test fixtures.

## Review Focus

1. A half-cent result, including overtime multiplication, must round half-up exactly once to cents — Task 3 pins positive boundary cases.
2. A DST gap or fold must use UTC elapsed seconds while retaining the captured local start date for agreement resolution — Task 4 pins both cases.
3. Adjacent agreement ranges are valid but a one-day overlap, a missing agreement, an ambiguous agreement, or an agreement from another employment must not finalize a shift — Tasks 2 and 4 pin these outcomes.
4. An open, overlapping, zero-length, or out-of-bounds break must never yield a finalized shift or a positive paid duration — Task 4 pins every condition.
5. Gross/net or currency mismatches must remain separately explained reconciliation groups rather than becoming one misleading difference — Task 5 pins mixed-basis and distinct-currency cases.

---

## Stable Interfaces Produced by This Phase

```dart
// lib/features/work/domain/ids.dart
final class EmploymentId { const EmploymentId(this.value); final String value; static EmploymentId? tryParse(String? value); }
final class AgreementId { const AgreementId(this.value); final String value; static AgreementId? tryParse(String? value); }
final class ShiftId { const ShiftId(this.value); final String value; static ShiftId? tryParse(String? value); }
final class ShiftBreakId { const ShiftBreakId(this.value); final String value; static ShiftBreakId? tryParse(String? value); }
final class PayPeriodId { const PayPeriodId(this.value); final String value; static PayPeriodId? tryParse(String? value); }
final class PayslipId { const PayslipId(this.value); final String value; static PayslipId? tryParse(String? value); }
sealed class WorkRecordId { const WorkRecordId(); String get value; }
```

```dart
// lib/features/work/domain/facts.dart
sealed class RateBasis { const RateBasis(); }
final class GrossBasis extends RateBasis { const GrossBasis(); }
final class NetBasis extends RateBasis { const NetBasis(); }
final class CurrencyCode { const CurrencyCode.eur() : value = 'EUR'; final String value; }
final class Revision { const Revision(this.value); final int value; }
final class DomainIssue { const DomainIssue(this.code, {this.field}); final String code; final String? field; }
final class DomainValidation { const DomainValidation(this.issues); final List<DomainIssue> issues; bool get isValid => issues.isEmpty; }
```

```dart
// lib/features/work/domain/agreement.dart
final class PayAgreement { /* immutable factual agreement fields from Task 2 */ }
sealed class AgreementResolution { const AgreementResolution(); }
final class ResolvedAgreement extends AgreementResolution { const ResolvedAgreement(this.agreement); final PayAgreement agreement; }
final class MissingAgreement extends AgreementResolution { const MissingAgreement(); }
final class AmbiguousAgreement extends AgreementResolution { const AmbiguousAgreement(); }
final class ForeignAgreement extends AgreementResolution { const ForeignAgreement(); }
AgreementResolution resolveAgreement({required EmploymentId employmentId, required LocalDate localStartDate, required Iterable<PayAgreement> agreements});
DomainValidation validateAgreementSet(Iterable<PayAgreement> agreements);
```

```dart
// lib/features/work/domain/shift.dart
final class WorkShift { /* immutable factual shift fields from Task 4 */ }
final class ShiftBreak { /* immutable factual break fields from Task 4 */ }
final class FinalizationFacts { const FinalizationFacts({required this.shift, required this.breaks, required this.agreement}); final WorkShift shift; final List<ShiftBreak> breaks; final PayAgreement agreement; }
final class FinalizationValidation { const FinalizationValidation({required this.issues, this.facts}); final List<DomainIssue> issues; final FinalizationFacts? facts; bool get isValid => facts != null; }
FinalizationValidation validateFinalization({required WorkShift shift, required Iterable<ShiftBreak> breaks, required Iterable<PayAgreement> agreements});
int suggestedOvertimeMinutes({required int paidWholeMinutes, required PayAgreement agreement});
```

```dart
// lib/features/work/domain/pay.dart
final class Money { const Money({required this.minorUnits, this.currency = const CurrencyCode.eur()}); final int minorUnits; final CurrencyCode currency; }
final class ExpectedPayInput { const ExpectedPayInput({required this.paidSeconds, required this.overtimeMinutes, required this.hourlyRateMicroEur, required this.multiplier, required this.currency}); final int paidSeconds; final int overtimeMinutes; final int hourlyRateMicroEur; final RationalMultiplier multiplier; final CurrencyCode currency; }
final class ExpectedPay { const ExpectedPay({required this.regularPaidSeconds, required this.overtimePaidSeconds, required this.amount}); final int regularPaidSeconds; final int overtimePaidSeconds; final Money amount; }
ExpectedPay calculateExpectedPay(ExpectedPayInput input);
```

```dart
// lib/features/work/domain/reconciliation.dart
sealed class ReconciliationStatus { const ReconciliationStatus(); }
final class Balanced extends ReconciliationStatus { const Balanced(); }
final class Difference extends ReconciliationStatus { const Difference(); }
final class MissingPayslip extends ReconciliationStatus { const MissingPayslip(); }
final class UnmatchedPayslip extends ReconciliationStatus { const UnmatchedPayslip(); }
final class MixedBasis extends ReconciliationStatus { const MixedBasis(); }
final class UnavailableReconciliation extends ReconciliationStatus { const UnavailableReconciliation(); }
final class EmptyReconciliation extends ReconciliationStatus { const EmptyReconciliation(); }
final class ReconciliationGroup { /* Task 5 exact fields */ }
List<ReconciliationGroup> reconcilePeriod({required EmploymentId employmentId, required PayPeriod period, required Iterable<WorkShift> shifts, required Iterable<ShiftBreak> breaks, required Iterable<PayAgreement> agreements, required Iterable<Payslip> payslips});
```

### Task 1: Domain Foundations and Immutable Employment Facts

**Files:**
- Create: `lib/features/work/domain/ids.dart`
- Create: `lib/features/work/domain/facts.dart`
- Create: `lib/features/work/domain/employment.dart`
- Create: `test/features/work/domain/ids_test.dart`
- Create: `test/features/work/domain/employment_test.dart`

**Interfaces:**
- Consumes: `LocalDate` and `LocalTime` from Phase 01 core time; no other application-layer interface.
- Produces: typed Work IDs, `WorkRecordId`, `RateBasis`, `CurrencyCode`, `Revision`, `DomainIssue`, `DomainValidation`, `Employment`, and `EmploymentStatus` for all later tasks.

- [ ] **Step 1: Write failing identifier and value-object tests**

```dart
void main() {
  test('typed IDs preserve a UUIDv7 value without cross-type equality', () {
    const raw = '018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11';
    expect(const EmploymentId(raw).value, raw);
    expect(const EmploymentId(raw), isNot(const AgreementId(raw)));
  });

  test('currency is EUR and revisions are non-negative', () {
    expect(const CurrencyCode.eur().value, 'EUR');
    expect(() => Revision(-1), throwsArgumentError);
  });
}
```

- [ ] **Step 2: Write failing employment tests**

```dart
void main() {
  test('employment trims required name and preserves factual optional label', () {
    final result = Employment.create(
      id: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'),
      name: '  North Dock  ', legalLabel: '  Dock Works Ltd  ', nowUtc: DateTime.utc(2026, 9, 29),
    );
    expect(result.name, 'North Dock');
    expect(result.legalLabel, 'Dock Works Ltd');
    expect(result.status, EmploymentStatus.active);
  });

  test('employment rejects an empty trimmed name', () {
    expect(() => Employment.create(id: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'), name: '  ', legalLabel: null, nowUtc: DateTime.utc(2026)), throwsArgumentError);
  });
}
```

- [ ] **Step 3: Verify RED**

Run: `flutter test test/features/work/domain/ids_test.dart test/features/work/domain/employment_test.dart`
Expected: FAIL during compilation because `ids.dart`, `facts.dart`, and `employment.dart` do not exist.

- [ ] **Step 4: Implement immutable foundations**

```dart
sealed class WorkRecordId { const WorkRecordId(); String get value; }
final class EmploymentId extends WorkRecordId { const EmploymentId(this.value); @override final String value; }
final class AgreementId extends WorkRecordId { const AgreementId(this.value); @override final String value; }
final class ShiftId extends WorkRecordId { const ShiftId(this.value); @override final String value; }
final class ShiftBreakId extends WorkRecordId { const ShiftBreakId(this.value); @override final String value; }
final class PayPeriodId extends WorkRecordId { const PayPeriodId(this.value); @override final String value; }
final class PayslipId extends WorkRecordId { const PayslipId(this.value); @override final String value; }
```

Implement typed ID value equality/hash codes and `tryParse()` using one shared canonical UUIDv7 validator; constructors retain already-validated values for repository mapping. Implement `Employment.create()` to trim `name` and a non-null `legalLabel`, reject an empty name with `ArgumentError.value(name, 'name')`, set `createdAtUtc` and `updatedAtUtc` to the supplied UTC instant, and start at `Revision(0)`. Define `EmploymentStatus.active` and `EmploymentStatus.archived`; expose `archive({required DateTime nowUtc})` as a pure copy returning an archived record with `Revision(value + 1)`. Give `CurrencyCode`, `RateBasis`, `Revision`, and `Money` value equality so grouping and round-trip tests do not depend on object identity.

- [ ] **Step 5: Verify GREEN**

Run: `dart format --set-exit-if-changed lib/features/work/domain test/features/work/domain && flutter test test/features/work/domain/ids_test.dart test/features/work/domain/employment_test.dart`
Expected: PASS; no formatter changes and all four value/invariant cases pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/domain/ids.dart lib/features/work/domain/facts.dart lib/features/work/domain/employment.dart test/features/work/domain/ids_test.dart test/features/work/domain/employment_test.dart
git commit -m "feat: add immutable work foundations

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 2: Effective-Dated Pay Agreement Policy

**Files:**
- Create: `lib/features/work/domain/agreement.dart`
- Create: `test/features/work/domain/agreement_test.dart`

**Interfaces:**
- Consumes: Task 1 ID/value types and Phase 01 `LocalDate`.
- Produces: immutable `PayAgreement`, `RationalMultiplier`, exact agreement-resolution subtypes, and `validateAgreementSet()`.

- [ ] **Step 1: Write failing agreement range and resolution tests**

```dart
void main() {
  test('resolves the sole inclusive agreement at a shift local start date', () {
    final agreement = agreement(start: LocalDate.parse('2026-09-01'), end: LocalDate.parse('2026-09-30'));
    final result = resolveAgreement(employmentId: agreement.employmentId, localStartDate: LocalDate.parse('2026-09-30'), agreements: [agreement]);
    expect(result, isA<ResolvedAgreement>());
  });

  test('allows adjacent ranges and rejects overlapping ranges within employment', () {
    expect(validateAgreementSet([agreement(start: LocalDate.parse('2026-09-01'), end: LocalDate.parse('2026-09-15')), agreement(version: 2, start: LocalDate.parse('2026-09-16'), end: null)]).isValid, isTrue);
    expect(validateAgreementSet([agreement(start: LocalDate.parse('2026-09-01'), end: LocalDate.parse('2026-09-15')), agreement(version: 2, start: LocalDate.parse('2026-09-15'), end: null)]).issues.single.code, 'agreement.rangeOverlap');
  });

  test('does not resolve an agreement belonging to another employment', () {
    expect(resolveAgreement(employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c11'), localStartDate: LocalDate.parse('2026-09-10'), agreements: [agreement(employmentId: const EmploymentId('018f0f9a-7d03-7e6a-8b0c-3d2e1f0a4c12'))]), isA<ForeignAgreement>());
  });
}
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/work/domain/agreement_test.dart`
Expected: FAIL because `PayAgreement`, `resolveAgreement`, and `validateAgreementSet` are undefined.

- [ ] **Step 3: Implement agreement construction and resolution**

```dart
final class RationalMultiplier {
  const RationalMultiplier({required this.numerator, required this.denominator})
      : assert(numerator > 0), assert(denominator > 0);
  final int numerator;
  final int denominator;
}

AgreementResolution resolveAgreement({required EmploymentId employmentId, required LocalDate localStartDate, required Iterable<PayAgreement> agreements}) {
  final sameEmployment = agreements.where((item) => item.employmentId == employmentId).toList(growable: false);
  if (sameEmployment.isEmpty && agreements.isNotEmpty) return const ForeignAgreement();
  final matches = sameEmployment.where((item) => item.isEffectiveOn(localStartDate)).toList(growable: false);
  return switch (matches) { [] => const MissingAgreement(), [final one] => ResolvedAgreement(one), _ => const AmbiguousAgreement() };
}
```

Give `PayAgreement` these immutable fields: `id`, `employmentId`, `version`, `effectiveStart`, `effectiveEnd`, `hourlyRateMicroEur`, `basis`, `overtimeThresholdMinutes`, `overtimeMultiplier`, `label`, `note`, `createdAtUtc`, and `revision`. Constructor validation rejects a nonpositive version/rate/threshold/multiplier part and an end preceding start. `validateAgreementSet()` groups by `EmploymentId`, sorts ranges by start, and returns `DomainIssue('agreement.rangeOverlap', field: 'effectiveRange')` for every intersecting inclusive pair.

- [ ] **Step 4: Add immutable-used-agreement tests and implementation**

```dart
test('used agreement cannot be edited but unused agreement can close safely', () {
  final used = agreement(usedByFinalizedShift: true);
  expect(() => used.withRangeEnd(LocalDate.parse('2026-09-15')), throwsStateError);
  expect(agreement().withRangeEnd(LocalDate.parse('2026-09-15')).effectiveEnd, LocalDate.parse('2026-09-15'));
});
```

Add `usedByFinalizedShift` to the in-memory factual representation supplied by the data layer and make `withRangeEnd()` throw `StateError` when true; it otherwise creates a higher-revision copy and lets `validateAgreementSet()` decide overlap. The application service will provide the complete employment agreement set before accepting the copy.

- [ ] **Step 5: Verify GREEN**

Run: `flutter test test/features/work/domain/agreement_test.dart && flutter test test/features/work/domain`
Expected: PASS; inclusive endpoint, overlap, foreign employment, used immutability, and domain regression tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/domain/agreement.dart test/features/work/domain/agreement_test.dart
git commit -m "feat: add effective dated agreement policy

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 3: Exact Expected-Pay Arithmetic

**Files:**
- Create: `lib/features/work/domain/pay.dart`
- Create: `test/features/work/domain/pay_test.dart`

**Interfaces:**
- Consumes: agreement rate/multiplier fields from Task 2 and primitive paid-duration/overtime facts supplied explicitly by callers.
- Produces: `Money`, `ExpectedPayInput`, `ExpectedPay`, `roundHalfUpRatio()`, and `calculateExpectedPay()` for shift finalization, reconciliation, and data projections.

- [ ] **Step 1: Write failing rational-arithmetic tests**

```dart
void main() {
  test('rounds a positive half cent upward using integer arithmetic', () {
    expect(roundHalfUpRatio(BigInt.from(15000), BigInt.from(10000)), BigInt.two);
    expect(roundHalfUpRatio(BigInt.from(14999), BigInt.from(10000)), BigInt.one);
  });

  test('calculates regular and overtime amounts without floating point', () {
    final result = calculateExpectedPay(const ExpectedPayInput(
      hourlyRateMicroEur: 20000000,
      paidSeconds: 3600,
      overtimeMinutes: 20,
      multiplier: RationalMultiplier(numerator: 3, denominator: 2),
      currency: CurrencyCode.eur(),
    ));
    expect(result.regularPaidSeconds, 2400);
    expect(result.overtimePaidSeconds, 1200);
    expect(result.amount.minorUnits, 2333);
  });
}
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/work/domain/pay_test.dart`
Expected: FAIL because `roundHalfUpRatio` and `calculateExpectedPay` are undefined.

- [ ] **Step 3: Implement named-boundary arithmetic**

```dart
int roundHalfUpRatio(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) throw ArgumentError.value(denominator, 'denominator');
  final negative = numerator.isNegative;
  final absolute = numerator.abs();
  final rounded = (absolute + denominator ~/ BigInt.two) ~/ denominator;
  return (negative ? -rounded : rounded).toInt();
}

final class Money {
  const Money({required this.minorUnits, this.currency = const CurrencyCode.eur()});
  final int minorUnits;
  final CurrencyCode currency;
}
```

In `calculateExpectedPay()`, validate `input.paidSeconds > 0`, `input.overtimeMinutes >= 0`, and `input.overtimeMinutes * 60 <= input.paidSeconds`; set `overtimeSeconds = input.overtimeMinutes * 60`, set `regularSeconds = input.paidSeconds - overtimeSeconds`, and form one `BigInt` numerator in micro-euros: regular rate × regular seconds plus rate × overtime seconds × multiplier numerator ÷ denominator. Divide only at the named cents boundary with denominator `BigInt.from(3600 * 10000)`. Return `Money(minorUnits: ...)`. Task 4 converts validated finalization facts into this input; no calculated total is stored on `WorkShift`.

- [ ] **Step 4: Add threshold-suggestion tests and implementation**

```dart
test('suggests only whole paid minutes beyond a per-shift threshold', () {
  expect(suggestedOvertimeMinutes(paidWholeMinutes: 481, agreement: agreement(thresholdMinutes: 480)), 1);
  expect(suggestedOvertimeMinutes(paidWholeMinutes: 479, agreement: agreement(thresholdMinutes: 480)), 0);
});
```

Implement `suggestedOvertimeMinutes()` as `max(0, paidWholeMinutes - agreement.overtimeThresholdMinutes)` and keep it independent of the owner-confirmed `WorkShift.overtimeMinutes`.

- [ ] **Step 5: Verify GREEN**

Run: `dart format --set-exit-if-changed lib/features/work/domain/pay.dart test/features/work/domain/pay_test.dart && flutter test test/features/work/domain/pay_test.dart`
Expected: PASS; half-up, below-half, regular/overtime split, and threshold suggestion cases pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/domain/pay.dart test/features/work/domain/pay_test.dart
git commit -m "feat: calculate exact expected shift pay

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 4: Shift, Break, and Finalization Invariants

**Files:**
- Create: `lib/features/work/domain/shift.dart`
- Create: `test/features/work/domain/shift_test.dart`

**Interfaces:**
- Consumes: Task 1 IDs/revisions, Task 2 agreement resolution, and Task 3 pay input contract.
- Produces: `ShiftState`, `WorkShift`, `ShiftBreak`, `FinalizationFacts`, `FinalizationValidation`, `validateFinalization()`, and `FinalizationFacts.toExpectedPayInput()` for Task 3 arithmetic.

- [ ] **Step 1: Write failing shift lifecycle and break tests**

```dart
void main() {
  test('finalizes only a closed non-overlapping break set within elapsed bounds', () {
    final outcome = validateFinalization(shift: finalizedCandidate(), breaks: [closedBreak('2026-10-26T08:30:00Z', '2026-10-26T09:00:00Z')], agreements: [effectiveAgreement()]);
    expect(outcome.isValid, isTrue);
    expect(outcome.facts!.shift.state, ShiftState.finalized);
  });

  test('rejects open, zero-length, overlapping, and out-of-bounds breaks', () {
    for (final breaks in [openBreakSet(), zeroLengthBreakSet(), overlappingBreakSet(), outOfBoundsBreakSet()]) {
      expect(validateFinalization(shift: finalizedCandidate(), breaks: breaks, agreements: [effectiveAgreement()]).isValid, isFalse);
    }
  });

  test('uses UTC elapsed seconds through a daylight-saving fold and local start date for agreement', () {
    final outcome = validateFinalization(shift: dstFoldCandidate(), breaks: const [], agreements: [agreement(start: LocalDate.parse('2026-10-26'))]);
    expect(outcome.facts!.shift.elapsedSeconds, 10800);
    expect(outcome.facts!.agreement.effectiveStart, LocalDate.parse('2026-10-26'));
  });
}
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/work/domain/shift_test.dart`
Expected: FAIL because `WorkShift`, `ShiftBreak`, `ShiftState`, and `validateFinalization` are undefined.

- [ ] **Step 3: Implement factual shift and break values**

```dart
enum ShiftState { draft, running, onBreak, finalized, voided }

final class WorkShift {
  const WorkShift({required this.id, required this.employmentId, required this.agreementId, required this.state, required this.startUtc, required this.endUtc, required this.timezoneId, required this.localStartDate, required this.overtimeMinutes, required this.note, required this.voidReason, required this.replacementShiftId, required this.replacedShiftId, required this.createdAtUtc, required this.updatedAtUtc, required this.revision});
  final ShiftId id; final EmploymentId employmentId; final AgreementId? agreementId; final ShiftState state;
  final DateTime startUtc; final DateTime? endUtc; final String timezoneId; final LocalDate localStartDate;
  final int overtimeMinutes; final String? note; final String? voidReason; final ShiftId? replacementShiftId; final ShiftId? replacedShiftId;
  final DateTime createdAtUtc; final DateTime updatedAtUtc; final Revision revision;
  int get elapsedSeconds => endUtc!.difference(startUtc).inSeconds;
}
```

Reject non-UTC instants, blank `timezoneId`, negative overtime, a non-null end not after start, and state/field combinations that contradict the state: `running` has no end, `onBreak` has no end, `finalized` has an end and agreement ID, and `voided` has a void reason and replacement ID. Define `ShiftBreak` with UTC start/end, shift ID, timestamps, and revision; its constructor rejects a closed end not after start.

- [ ] **Step 4: Implement finalization validation**

```dart
FinalizationValidation validateFinalization({required WorkShift shift, required Iterable<ShiftBreak> breaks, required Iterable<PayAgreement> agreements}) {
  final issues = <DomainIssue>[];
  final ordered = [...breaks]..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  // Append precise issues before returning; do not mutate shift or breaks.
  if (issues.isNotEmpty) return FinalizationValidation(issues: List.unmodifiable(issues));
  final resolution = resolveAgreement(employmentId: shift.employmentId, localStartDate: shift.localStartDate, agreements: agreements);
  if (resolution is! ResolvedAgreement) return FinalizationValidation(issues: [DomainIssue('shift.agreement.${resolution.runtimeType}')]);
  return FinalizationValidation(issues: const [], facts: FinalizationFacts(shift: shift, breaks: List.unmodifiable(ordered), agreement: resolution.agreement));
}
```

Append these exact issue codes when applicable: `shift.endMissing`, `shift.endNotAfterStart`, `break.open`, `break.outsideShift`, `break.overlap`, `shift.paidDurationNotPositive`, `shift.overtimeNegative`, and `shift.overtimeExceedsPaidMinutes`. Treat breaks as overlapping when a later start is before the prior closed end. Require each break to be inside `[startUtc, endUtc]`; compute paid seconds as elapsed seconds minus closed-break seconds; require positive paid seconds and `overtimeMinutes <= paidSeconds ~/ 60`.

- [ ] **Step 5: Add overnight and agreement-boundary tests**

```dart
test('attributes a cross-midnight shift wholly to its captured local start date', () {
  final result = validateFinalization(shift: crossMidnightCandidate(localStart: '2026-09-30'), breaks: const [], agreements: [agreement(start: LocalDate.parse('2026-09-01'), end: LocalDate.parse('2026-09-30')), agreement(version: 2, start: LocalDate.parse('2026-10-01'))]);
  expect(result.facts!.agreement.version, 1);
});

test('rejects missing and ambiguous agreement resolution', () {
  expect(validateFinalization(shift: finalizedCandidate(), breaks: const [], agreements: const []).issues.single.code, contains('MissingAgreement'));
  expect(validateFinalization(shift: finalizedCandidate(), breaks: const [], agreements: [effectiveAgreement(), effectiveAgreement(version: 2)]).issues.single.code, contains('AmbiguousAgreement'));
});
```

- [ ] **Step 6: Verify GREEN**

Run: `flutter test test/features/work/domain/shift_test.dart && flutter test test/features/work/domain`
Expected: PASS; lifecycle combinations, all four invalid-break classes, DST elapsed duration, cross-midnight attribution, overtime limit, and agreement outcomes pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/work/domain/shift.dart test/features/work/domain/shift_test.dart
git commit -m "feat: enforce work shift finalization invariants

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 5: Pay Period, Payslip, and Reconciliation Projection

**Files:**
- Create: `lib/features/work/domain/pay_period.dart`
- Create: `lib/features/work/domain/payslip.dart`
- Create: `lib/features/work/domain/reconciliation.dart`
- Create: `test/features/work/domain/reconciliation_test.dart`

**Interfaces:**
- Consumes: Task 1 ID/fact types, Task 2 agreements, Task 3 `calculateExpectedPay`, and Task 4 finalization facts.
- Produces: `PayPeriod`, `PayPeriodState`, `Payslip`, `PayslipState`, `ReconciliationStatus`, `ReconciliationGroup`, and `reconcilePeriod()`.

- [ ] **Step 1: Write failing period and payslip invariant tests**

```dart
void main() {
  test('period range is inclusive and cannot end before it starts', () {
    expect(PayPeriod.create(id: periodId, employmentId: employmentId, start: LocalDate.parse('2026-09-01'), end: LocalDate.parse('2026-09-30'), label: null, nowUtc: DateTime.utc(2026)).contains(LocalDate.parse('2026-09-30')), isTrue);
    expect(() => PayPeriod.create(id: periodId, employmentId: employmentId, start: LocalDate.parse('2026-09-30'), end: LocalDate.parse('2026-09-01'), label: null, nowUtc: DateTime.utc(2026)), throwsArgumentError);
  });

  test('void payslips remain factual but do not contribute to paid evidence', () {
    expect(effectivePayslip().isEffective, isTrue);
    expect(voidPayslip().isEffective, isFalse);
  });
}
```

- [ ] **Step 2: Write failing reconciliation status tests**

```dart
test('keeps gross and net evidence separate instead of inventing a difference', () {
  final groups = reconcilePeriod(employmentId: employmentId, period: septemberPeriod(), shifts: [finalizedShift()], breaks: const [], agreements: [effectiveAgreement()], payslips: [effectivePayslip(basis: const NetBasis())]);
  expect(groups.single.status, isA<MixedBasis>());
  expect(groups.single.difference, isNull);
});

test('reports balanced, difference, missing, unmatched, unavailable, and empty', () {
  expect(statusFor(balancedFixture()), isA<Balanced>());
  expect(statusFor(differenceFixture()), isA<Difference>());
  expect(statusFor(missingPayslipFixture()), isA<MissingPayslip>());
  expect(statusFor(unmatchedPayslipFixture()), isA<UnmatchedPayslip>());
  expect(statusFor(unavailableFixture()), isA<UnavailableReconciliation>());
  expect(statusFor(emptyFixture()), isA<EmptyReconciliation>());
});
```

- [ ] **Step 3: Verify RED**

Run: `flutter test test/features/work/domain/reconciliation_test.dart`
Expected: FAIL because period, payslip, and reconciliation domain files do not exist.

- [ ] **Step 4: Implement factual period and payslip types**

```dart
enum PayPeriodState { open, reviewed }
enum PayslipState { effective, voided }

final class PayPeriod { /* id, employmentId, inclusive start/end, label, state, timestamps, revision */ }
final class Payslip { /* id, periodId, issued/paid dates, primary amount/basis, supplementary factual amounts, links, timestamps, revision */ }
```

Implement `PayPeriod.create()` with end-not-before-start validation, trimmed nullable label, `open` state, and revision zero. Implement `Payslip` with a positive primary `Money`, explicit `RateBasis`, optional nonnegative `grossMinorUnits`, `netMinorUnits`, and `deductionMinorUnits`, factual reference/note, and a `voided` state requiring `voidReason` and `replacementPayslipId`. Do not derive deductions or basis conversions.

- [ ] **Step 5: Implement deterministic reconciliation**

```dart
final class ReconciliationGroup {
  const ReconciliationGroup({required this.employmentId, required this.periodId, required this.currency, required this.basis, required this.regularPaidSeconds, required this.overtimePaidSeconds, required this.expected, required this.paid, required this.difference, required this.shiftIds, required this.payslipIds, required this.status});
  final EmploymentId employmentId; final PayPeriodId periodId; final CurrencyCode currency; final RateBasis? basis;
  final int regularPaidSeconds; final int overtimePaidSeconds; final Money? expected; final Money? paid; final Money? difference;
  final List<ShiftId> shiftIds; final List<PayslipId> payslipIds; final ReconciliationStatus status;
}
```

Filter to the requested employment and shifts that are `finalized`, non-void, and whose `localStartDate` is within the period. Resolve each finalized shift's retained agreement ID; a missing retained agreement or invalid finalization yields `UnavailableReconciliation`. Group expected amounts and effective payslips by `CurrencyCode.value` and exact basis type. Return `MixedBasis` with null difference if one period/currency has both gross and net evidence. Use `Balanced` when same-basis expected and paid cents match, `Difference` when both exist and differ, `MissingPayslip` for expected only, `UnmatchedPayslip` for paid only, and `EmptyReconciliation` when neither exists. Sort groups by currency then basis name and IDs lexically for stable UI streams.

- [ ] **Step 6: Verify GREEN**

Run: `flutter test test/features/work/domain/reconciliation_test.dart && flutter test test/features/work/domain`
Expected: PASS; inclusive period membership, void-payslip exclusion, all seven statuses, and no gross/net or currency combination pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/work/domain/pay_period.dart lib/features/work/domain/payslip.dart lib/features/work/domain/reconciliation.dart test/features/work/domain/reconciliation_test.dart
git commit -m "feat: derive work period reconciliation

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

### Task 6: Pure Void-and-Replace Correction Policy

**Files:**
- Create: `lib/features/work/domain/correction.dart`
- Create: `test/features/work/domain/correction_test.dart`
- Modify: `lib/features/work/domain/shift.dart`
- Modify: `lib/features/work/domain/payslip.dart`

**Interfaces:**
- Consumes: all preceding Work factual values.
- Produces: `ShiftCorrection`, `PayslipCorrection`, `prepareShiftCorrection()`, and `preparePayslipCorrection()` for Phase 03's atomic transaction services.

- [ ] **Step 1: Write failing finalized-shift correction tests**

```dart
void main() {
  test('voids a finalized original and creates a linked editable replacement draft', () {
    final correction = prepareShiftCorrection(original: finalizedShift(), replacementId: replacementShiftId, voidReason: 'Correct end time', nowUtc: DateTime.utc(2026, 9, 29));
    expect(correction.voidedOriginal.state, ShiftState.voided);
    expect(correction.voidedOriginal.replacementShiftId, replacementShiftId);
    expect(correction.replacement.state, ShiftState.draft);
    expect(correction.replacement.replacedShiftId, finalizedShift().id);
    expect(correction.replacement.agreementId, finalizedShift().agreementId);
  });

  test('rejects correction of a draft or an already voided historical shift', () {
    expect(() => prepareShiftCorrection(original: draftShift(), replacementId: replacementShiftId, voidReason: 'Reason', nowUtc: DateTime.utc(2026)), throwsStateError);
    expect(() => prepareShiftCorrection(original: voidedShift(), replacementId: replacementShiftId, voidReason: 'Reason', nowUtc: DateTime.utc(2026)), throwsStateError);
  });
}
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/work/domain/correction_test.dart`
Expected: FAIL because `correction.dart` and correction functions are undefined.

- [ ] **Step 3: Implement linked correction values**

```dart
final class ShiftCorrection {
  const ShiftCorrection({required this.voidedOriginal, required this.replacement});
  final WorkShift voidedOriginal;
  final WorkShift replacement;
}

ShiftCorrection prepareShiftCorrection({required WorkShift original, required ShiftId replacementId, required String voidReason, required DateTime nowUtc}) {
  if (original.state != ShiftState.finalized) throw StateError('Only finalized shifts can be corrected.');
  final reason = voidReason.trim();
  if (reason.isEmpty) throw ArgumentError.value(voidReason, 'voidReason');
  // Return copies with incremented original revision and new replacement revision zero.
}
```

The voided original retains its end, agreement ID, note, timezone, local start date, and all other historical fields; it gains the trimmed reason, replacement ID, `voided` state, updated timestamp, and incremented revision. The replacement has the supplied ID, `draft` state, `replacedShiftId` set to original ID, no void reason/replacement ID, `Revision(0)`, supplied timestamps, and copies original editable facts. It does not mutate the original object or original breaks. Add the parallel payslip policy with the same effective-only rule and reciprocal links.

- [ ] **Step 4: Add cancellation/history tests**

```dart
test('discarding an unfinalized replacement cannot reactivate its voided original', () {
  final correction = prepareShiftCorrection(original: finalizedShift(), replacementId: replacementShiftId, voidReason: 'Correction', nowUtc: DateTime.utc(2026));
  expect(correction.voidedOriginal.state, ShiftState.voided);
  expect(correction.replacement.state, ShiftState.draft);
  expect(correction.voidedOriginal.replacementShiftId, correction.replacement.id);
});
```

Keep cancellation outside this pure policy: Phase 03 must persist an explicit replacement-resolution action and may not alter the voided original automatically.

- [ ] **Step 5: Verify GREEN and complete the domain gate**

```bash
dart format --set-exit-if-changed lib/features/work/domain test/features/work/domain
flutter test test/features/work/domain
flutter analyze lib/features/work/domain test/features/work/domain
```

Expected: all pure Work domain tests and static analysis pass with no Flutter, Drift, database, or provider imports in `lib/features/work/domain/`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/work/domain/correction.dart lib/features/work/domain/shift.dart lib/features/work/domain/payslip.dart test/features/work/domain/correction_test.dart
git commit -m "feat: preserve work correction history

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

## Final Domain Review

- [ ] Re-read Sections 9–13 and 19.1 of the native Work specification and verify that each rule maps to Tasks 1–6: typed IDs, money/rates, agreement ranges, shift/break validation, arithmetic, periods/payslips, reconciliation, and corrections.
- [ ] Run `rg -n "package:flutter|drift|sqlite3|riverpod|go_router|DateTime\.now|double" lib/features/work/domain`; expected: no matches.
- [ ] Run the repository plan-quality scanner against this file; expected: no incomplete-step or vague-instruction findings.
- [ ] Run the final phase gate: `dart format --set-exit-if-changed lib/features/work/domain test/features/work/domain && flutter test test/features/work/domain && flutter analyze`.

Plan complete and saved to `docs/superpowers/plans/2026-09-29-lifeos-native-02-work-domain.md`. Please review the plan. Does it capture what you want?
