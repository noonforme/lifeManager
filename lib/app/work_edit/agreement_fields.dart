import '../../core/time/local_date.dart';
import '../../core/time/local_time.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/work_formats.dart';
import 'agreement_edit.dart';

/// A pay agreement's field keys, as `AgreementAdapter` names its problems
/// and the property column and grid name their values.
abstract final class AgreementField {
  static const effectiveStart = 'effectiveStart';
  static const effectiveEnd = 'effectiveEnd';
  static const hourlyRate = 'hourlyRate';
  static const basis = 'basis';
  static const label = 'label';
  static const note = 'note';
  static const overtimeHours = 'overtimeHours';
  static const overtimeMultiplier = 'overtimeMultiplier';
  static const nightEnabled = 'nightEnabled';
  static const nightStart = 'nightStart';
  static const nightEnd = 'nightEnd';
  static const nightMultiplier = 'nightMultiplier';
  static const holidays = 'holidays';
  static const holidayMultiplier = 'holidayMultiplier';
  static const stacking = 'stacking';
  static const vacationPercent = 'vacationPercent';
  static const sickPercent = 'sickPercent';
  static const sickDays = 'sickDays';
}

/// New terms, or why the value given is not one.
typedef AgreementFieldResult = ({AgreementTerms? terms, String? problem});

/// [terms] with [field] set to [value] as its editor hands it over: a
/// date, a time, a choice's value, or typed text. Exactly one of the
/// result's two is non-null.
AgreementFieldResult withAgreementField(
  AgreementTerms terms,
  String field,
  Object? value,
) {
  AgreementFieldResult ok(AgreementTerms next) => (terms: next, problem: null);
  AgreementFieldResult no(String problem) => (terms: null, problem: problem);
  final text = '${value ?? ''}';
  String? optional() {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  AgreementFieldResult multiplier(
    AgreementTerms Function(RationalMultiplier value) set,
  ) => switch (parseMultiplier(text)) {
    final value? => ok(set(value)),
    null => no(AgreementProblems.multiplier),
  };
  AgreementFieldResult percent(
    AgreementTerms Function(RationalMultiplier value) set,
  ) => switch (parsePercent(text)) {
    final value? => ok(set(value)),
    null => no(AgreementProblems.percent),
  };

  return switch (field) {
    AgreementField.effectiveStart => switch (value) {
      final LocalDate date => ok(terms.change(effectiveStart: date)),
      _ => no(AgreementProblems.startRequired),
    },
    AgreementField.effectiveEnd => switch (value) {
      null => ok(terms.change(effectiveEnd: () => null)),
      final LocalDate date => ok(terms.change(effectiveEnd: () => date)),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.hourlyRate => switch (parseHourlyRate(text)) {
      final rate? when rate > 0 => ok(terms.change(hourlyRateMicroEur: rate)),
      _ => no(AgreementProblems.rate),
    },
    AgreementField.basis => switch (value) {
      final RateBasis basis => ok(terms.change(basis: basis)),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.label => ok(terms.change(label: optional)),
    AgreementField.note => ok(terms.change(note: optional)),
    AgreementField.overtimeHours => switch (parseHoursAsMinutes(text)) {
      final minutes? => ok(terms.change(overtimeThresholdMinutes: minutes)),
      null => no(AgreementProblems.hours),
    },
    AgreementField.overtimeMultiplier => multiplier(
      (value) => terms.change(overtimeMultiplier: value),
    ),
    AgreementField.nightEnabled => switch (value) {
      final bool on => ok(terms.change(nightEnabled: on)),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.nightStart => switch (value) {
      final LocalTime time => ok(
        terms.change(nightStartMinute: time.hour * 60 + time.minute),
      ),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.nightEnd => switch (value) {
      final LocalTime time => ok(
        terms.change(nightEndMinute: time.hour * 60 + time.minute),
      ),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.nightMultiplier => multiplier(
      (value) => terms.change(nightMultiplier: value),
    ),
    AgreementField.holidays => switch (value) {
      final HolidayCalendar calendar => ok(
        terms.change(holidayCalendar: calendar),
      ),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.holidayMultiplier => multiplier(
      (value) => terms.change(holidayMultiplier: value),
    ),
    AgreementField.stacking => switch (value) {
      final PremiumStacking stacking => ok(
        terms.change(premiumStacking: stacking),
      ),
      _ => no(AgreementProblems.notEditable),
    },
    AgreementField.vacationPercent => percent(
      (value) => terms.change(vacationPay: value),
    ),
    AgreementField.sickPercent => percent(
      (value) => terms.change(sickPay: value),
    ),
    AgreementField.sickDays => switch (int.tryParse(text.trim())) {
      final days? when days >= 0 && days <= 30 => ok(
        terms.change(sickEmployerDays: days),
      ),
      _ => no(AgreementProblems.sickDays),
    },
    _ => no(AgreementProblems.notEditable),
  };
}

/// Agreement terms with some of their values replaced; a nullable value
/// is replaced by what its function returns.
extension AgreementTermsChange on AgreementTerms {
  AgreementTerms change({
    LocalDate? effectiveStart,
    LocalDate? Function()? effectiveEnd,
    int? hourlyRateMicroEur,
    RateBasis? basis,
    String? Function()? label,
    String? Function()? note,
    int? overtimeThresholdMinutes,
    RationalMultiplier? overtimeMultiplier,
    bool? nightEnabled,
    int? nightStartMinute,
    int? nightEndMinute,
    RationalMultiplier? nightMultiplier,
    HolidayCalendar? holidayCalendar,
    RationalMultiplier? holidayMultiplier,
    PremiumStacking? premiumStacking,
    RationalMultiplier? vacationPay,
    RationalMultiplier? sickPay,
    int? sickEmployerDays,
  }) => AgreementTerms(
    effectiveStart: effectiveStart ?? this.effectiveStart,
    effectiveEnd: effectiveEnd == null ? this.effectiveEnd : effectiveEnd(),
    hourlyRateMicroEur: hourlyRateMicroEur ?? this.hourlyRateMicroEur,
    basis: basis ?? this.basis,
    label: label == null ? this.label : label(),
    note: note == null ? this.note : note(),
    overtimeThresholdMinutes:
        overtimeThresholdMinutes ?? this.overtimeThresholdMinutes,
    overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
    nightEnabled: nightEnabled ?? this.nightEnabled,
    nightStartMinute: nightStartMinute ?? this.nightStartMinute,
    nightEndMinute: nightEndMinute ?? this.nightEndMinute,
    nightMultiplier: nightMultiplier ?? this.nightMultiplier,
    holidayCalendar: holidayCalendar ?? this.holidayCalendar,
    holidayMultiplier: holidayMultiplier ?? this.holidayMultiplier,
    premiumStacking: premiumStacking ?? this.premiumStacking,
    vacationPay: vacationPay ?? this.vacationPay,
    sickPay: sickPay ?? this.sickPay,
    sickEmployerDays: sickEmployerDays ?? this.sickEmployerDays,
  );
}
