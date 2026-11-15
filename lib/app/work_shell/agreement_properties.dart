import 'package:flutter/foundation.dart';

import '../../core/time/local_time.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/agreement.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/work_formats.dart';
import '../../ui/ui.dart';
import '../work_edit/agreement_edit.dart';
import '../work_edit/agreement_fields.dart';
import '../work_edit/work_records.dart';

/// Words of an agreement's properties (spec 4.2: the description names a
/// value's meaning, or why it is read-only).
abstract final class AgreementPropertyWords {
  static const starts = 'The first day this agreement pays.';
  static const ends = 'The last day it pays; empty while it runs on.';
  static const rate = 'Pay per hour, such as 18.40.';
  static const basis = 'Whether the rate is before (gross) or after (net) tax.';
  static const label = 'Your own name for these terms.';
  static const note = 'Your own words about these terms.';
  static const overtimeAfter =
      'Hours in a shift after which overtime is paid, such as 8.';
  static const multiplier = 'How many times the rate, such as 1.5.';
  static const night = 'Whether night hours pay more.';
  static const nightStart = 'When night pay starts.';
  static const nightEnd = 'When night pay ends, the next morning if earlier.';
  static const holidays = 'Whether Lithuanian public holidays pay more.';
  static const stacking = 'How premiums combine when several apply.';
  static const vacation = 'Vacation pay as a percent of average pay.';
  static const sick = 'Sick pay for the days the employer pays, as a percent.';
  static const sickDays = 'Sick days the employer pays, 0 to 30.';
  static const version = 'Given when the agreement was stored.';
  static const use = 'Counted from finished shifts and confirmed leave.';
  static const employment = 'Back to the employment.';

  /// A stored agreement's terms (bead 9pk.3.6): what changing one does.
  static const corrects =
      'Changing a term corrects this agreement as if it had always said '
      'this; its history keeps the old terms. Saving asks first when it '
      'reprices finished shifts or leave, and a reviewed pay period it '
      'reprices changes its reconciliation. New terms from a date: Change '
      'terms from….';
}

/// The choices of an agreement's choice values.
const basisChoices = [
  EraComboItem<Object?>(GrossBasis(), 'Gross'),
  EraComboItem<Object?>(NetBasis(), 'Net'),
];
const _onOff = [
  EraComboItem<Object?>(true, 'On'),
  EraComboItem<Object?>(false, 'Off'),
];
const _holidayChoices = [
  EraComboItem<Object?>(HolidayCalendar.lithuania, 'Lithuania'),
  EraComboItem<Object?>(HolidayCalendar.none, 'None'),
];
const _stackingChoices = [
  EraComboItem<Object?>(PremiumStacking.highest, 'Highest wins'),
  EraComboItem<Object?>(PremiumStacking.additive, 'Add the extras'),
  EraComboItem<Object?>(PremiumStacking.multiplicative, 'Multiply'),
];

/// An hourly rate as its editor starts: "18.40".
String hourlyRateText(int microEur) =>
    formatHourlyRate(microEur).replaceFirst('/h', '');

/// A multiplier as the grid and properties show it: "×1.5".
String multiplierText(RationalMultiplier value) =>
    '×${formatMultiplier(value)}';

/// A minute of the day as a time.
LocalTime clockTime(int minute) => LocalTime(minute ~/ 60 % 24, minute % 60);

/// A pay agreement's night premium in a line: "×1.5, 22:00–06:00", or
/// "Off".
String nightText(AgreementTerms terms) => terms.nightEnabled
    ? '${multiplierText(terms.nightMultiplier)}, '
          '${formatClock(terms.nightStartMinute)}–'
          '${formatClock(terms.nightEndMinute)}'
    : 'Off';

/// The property items of an agreement's [edit] (spec 4.2): every term,
/// grouped as the old agreement form grouped them, with "(was …)" after a
/// changed one and its problem; for a stored version, what it paid
/// ([row]) and its employment ([onEmployment]). With [readOnlyReason]
/// every term is read-only for that reason.
List<PropertyItem> agreementPropertyItems({
  required AgreementSession edit,
  required AgreementRow? row,
  required String? employmentName,
  required VoidCallback? onEmployment,
  String? readOnlyReason,
}) {
  final terms = edit.draft.terms;
  final saved = edit.baseline?.value;
  final stored = saved == null ? null : AgreementTerms.of(saved);
  String describe(String own) =>
      saved == null ? own : '$own ${AgreementPropertyWords.corrects}';

  PropertyItem item(
    String key,
    String label,
    String category, {
    required Object? value,
    required Object? Function(AgreementTerms terms) of,
    required String description,
    ValueKind kind = ValueKind.text,
    String Function(Object? value)? display,
    String? text,
    List<EraComboItem<Object?>> choices = const [],
    bool optional = false,
  }) {
    String shown(Object? value) =>
        display?.call(value) ?? formatValue(kind, value, choices: choices);
    final before = stored == null ? null : of(stored);
    return PropertyItem(
      key: key,
      label: label,
      category: category,
      kind: kind,
      value: value,
      display: display == null ? null : shown(value),
      text: text,
      choices: choices,
      optional: optional,
      was: stored != null && before != of(terms) ? shown(before) : null,
      error: edit.issues[key],
      description: describe(description),
      readOnlyReason: readOnlyReason,
    );
  }

  String? multiplierOf(Object? value) =>
      value is RationalMultiplier ? multiplierText(value) : null;
  String percentOf(Object? value) =>
      value is RationalMultiplier ? '${formatPercent(value)} %' : '';

  return [
    if (saved != null)
      PropertyItem(
        key: 'version',
        label: 'Version',
        category: 'Pay agreement',
        value: 'v${saved.version}',
        readOnlyReason: AgreementPropertyWords.version,
      ),
    item(
      AgreementField.effectiveStart,
      'Starts',
      'Pay agreement',
      kind: ValueKind.date,
      value: terms.effectiveStart,
      of: (terms) => terms.effectiveStart,
      description: AgreementPropertyWords.starts,
    ),
    item(
      AgreementField.effectiveEnd,
      'Ends',
      'Pay agreement',
      kind: ValueKind.date,
      optional: true,
      value: terms.effectiveEnd,
      of: (terms) => terms.effectiveEnd,
      description: AgreementPropertyWords.ends,
    ),
    item(
      AgreementField.label,
      'Label',
      'Pay agreement',
      value: terms.label,
      of: (terms) => terms.label,
      description: AgreementPropertyWords.label,
    ),
    item(
      AgreementField.note,
      'Note',
      'Pay agreement',
      value: terms.note,
      of: (terms) => terms.note,
      description: AgreementPropertyWords.note,
    ),
    item(
      AgreementField.hourlyRate,
      'Hourly rate',
      'Rate',
      kind: ValueKind.money,
      value: terms.hourlyRateMicroEur == 0 ? null : terms.hourlyRateMicroEur,
      of: (terms) => terms.hourlyRateMicroEur,
      display: (value) =>
          value is int && value > 0 ? formatHourlyRate(value) : '',
      text: terms.hourlyRateMicroEur == 0
          ? ''
          : hourlyRateText(terms.hourlyRateMicroEur),
      description: AgreementPropertyWords.rate,
    ),
    item(
      AgreementField.basis,
      'Basis',
      'Rate',
      kind: ValueKind.choice,
      choices: basisChoices,
      value: terms.basis,
      of: (terms) => terms.basis,
      description: AgreementPropertyWords.basis,
    ),
    item(
      AgreementField.overtimeHours,
      'After',
      'Overtime',
      kind: ValueKind.number,
      value: terms.overtimeThresholdMinutes,
      of: (terms) => terms.overtimeThresholdMinutes,
      display: (value) => value is int ? '${formatHours(value)} h' : '',
      text: formatHours(terms.overtimeThresholdMinutes),
      description: AgreementPropertyWords.overtimeAfter,
    ),
    item(
      AgreementField.overtimeMultiplier,
      'Multiplier',
      'Overtime',
      kind: ValueKind.number,
      value: terms.overtimeMultiplier,
      of: (terms) => terms.overtimeMultiplier,
      display: (value) => multiplierOf(value) ?? '',
      text: formatMultiplier(terms.overtimeMultiplier),
      description: AgreementPropertyWords.multiplier,
    ),
    item(
      AgreementField.nightEnabled,
      'Night pay',
      'Night',
      kind: ValueKind.choice,
      choices: _onOff,
      value: terms.nightEnabled,
      of: (terms) => terms.nightEnabled,
      description: AgreementPropertyWords.night,
    ),
    item(
      AgreementField.nightStart,
      'Starts',
      'Night',
      kind: ValueKind.time,
      value: clockTime(terms.nightStartMinute),
      of: (terms) => clockTime(terms.nightStartMinute),
      description: AgreementPropertyWords.nightStart,
    ),
    item(
      AgreementField.nightEnd,
      'Ends',
      'Night',
      kind: ValueKind.time,
      value: clockTime(terms.nightEndMinute),
      of: (terms) => clockTime(terms.nightEndMinute),
      description: AgreementPropertyWords.nightEnd,
    ),
    item(
      AgreementField.nightMultiplier,
      'Multiplier',
      'Night',
      kind: ValueKind.number,
      value: terms.nightMultiplier,
      of: (terms) => terms.nightMultiplier,
      display: (value) => multiplierOf(value) ?? '',
      text: formatMultiplier(terms.nightMultiplier),
      description: AgreementPropertyWords.multiplier,
    ),
    item(
      AgreementField.holidays,
      'Holidays',
      'Public holidays',
      kind: ValueKind.choice,
      choices: _holidayChoices,
      value: terms.holidayCalendar,
      of: (terms) => terms.holidayCalendar,
      description: AgreementPropertyWords.holidays,
    ),
    item(
      AgreementField.holidayMultiplier,
      'Multiplier',
      'Public holidays',
      kind: ValueKind.number,
      value: terms.holidayMultiplier,
      of: (terms) => terms.holidayMultiplier,
      display: (value) => multiplierOf(value) ?? '',
      text: formatMultiplier(terms.holidayMultiplier),
      description: AgreementPropertyWords.multiplier,
    ),
    item(
      AgreementField.stacking,
      'Premiums',
      'When several apply',
      kind: ValueKind.choice,
      choices: _stackingChoices,
      value: terms.premiumStacking,
      of: (terms) => terms.premiumStacking,
      description: AgreementPropertyWords.stacking,
    ),
    item(
      AgreementField.vacationPercent,
      'Vacation %',
      'Leave pay',
      kind: ValueKind.number,
      value: terms.vacationPay,
      of: (terms) => terms.vacationPay,
      display: percentOf,
      text: formatPercent(terms.vacationPay),
      description: AgreementPropertyWords.vacation,
    ),
    item(
      AgreementField.sickPercent,
      'Sick, first days %',
      'Leave pay',
      kind: ValueKind.number,
      value: terms.sickPay,
      of: (terms) => terms.sickPay,
      display: percentOf,
      text: formatPercent(terms.sickPay),
      description: AgreementPropertyWords.sick,
    ),
    item(
      AgreementField.sickDays,
      'Sick days the employer pays',
      'Leave pay',
      kind: ValueKind.number,
      value: terms.sickEmployerDays,
      of: (terms) => terms.sickEmployerDays,
      display: (value) => '${value ?? ''}',
      text: '${terms.sickEmployerDays}',
      description: AgreementPropertyWords.sickDays,
    ),
    if (saved != null && row != null) ...[
      PropertyItem(
        key: 'paidShifts',
        label: 'Paid shifts',
        category: 'Use',
        kind: ValueKind.number,
        value: row.paidShifts,
        display: '${row.paidShifts}',
        readOnlyReason: AgreementPropertyWords.use,
      ),
      PropertyItem(
        key: 'paysLeave',
        label: 'Pays leave',
        category: 'Use',
        value: row.paysLeave ? 'Yes' : 'No',
        readOnlyReason: AgreementPropertyWords.use,
      ),
      PropertyItem(
        key: 'firstUse',
        label: 'First paid day',
        category: 'Use',
        kind: ValueKind.date,
        value: row.firstUse,
        readOnlyReason: AgreementPropertyWords.use,
      ),
      PropertyItem(
        key: 'lastUse',
        label: 'Last paid day',
        category: 'Use',
        kind: ValueKind.date,
        value: row.lastUse,
        readOnlyReason: AgreementPropertyWords.use,
      ),
    ],
    if (onEmployment != null)
      PropertyItem(
        key: 'employment',
        label: 'Employment',
        category: 'Belongs to',
        value: employmentName ?? '',
        description: AgreementPropertyWords.employment,
        onFollow: onEmployment,
      ),
  ];
}
