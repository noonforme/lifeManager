import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/local_date.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/facts.dart';
import '../../features/work/domain/ids.dart';
import '../../features/work/domain/pay_period.dart';
import '../../features/work/domain/payslip.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import '../production_work_providers.dart';
import 'work_records.dart';

enum PayKind { periods, payslips }

/// Saved money evidence is immutable. Only new records get an edit session.
final class PayRecord {
  const PayRecord.period(PayPeriod value) : period = value, payslip = null;
  const PayRecord.payslip(Payslip value) : period = null, payslip = value;
  final PayPeriod? period;
  final Payslip? payslip;
  WorkRecordId get id => period?.id ?? payslip!.id;
  Revision get revision => period?.revision ?? payslip!.revision;
  PayKind get kind => period == null ? PayKind.payslips : PayKind.periods;
  @override
  bool operator ==(Object other) =>
      other is PayRecord && other.id == id && other.revision == revision;
  @override
  int get hashCode => Object.hash(id, revision);
}

/// Raw amount text preserves invalid input and optional blanks. Parsing is
/// exact in cents; optional invalid values never silently become null.
final class PayValues {
  const PayValues({
    required this.start,
    required this.end,
    required this.issued,
    this.period,
    this.paid,
    this.amount = '',
    this.basis = const GrossBasis(),
    this.gross = '',
    this.net = '',
    this.deductions = '',
    this.label = '',
    this.reference = '',
    this.note = '',
  });
  final LocalDate start, end, issued;
  final PayPeriodId? period;
  final LocalDate? paid;
  final String amount, gross, net, deductions, label, reference, note;
  final RateBasis basis;
  PayValues withField(String key, Object? value) => PayValues(
    start: key == 'start' ? value as LocalDate : start,
    end: key == 'end' ? value as LocalDate : end,
    issued: key == 'issued' ? value as LocalDate : issued,
    period: key == 'period' ? value as PayPeriodId? : period,
    paid: key == 'paid' ? value as LocalDate? : paid,
    amount: key == 'amount' ? '${value ?? ''}' : amount,
    gross: key == 'gross' ? '${value ?? ''}' : gross,
    net: key == 'net' ? '${value ?? ''}' : net,
    deductions: key == 'deductions' ? '${value ?? ''}' : deductions,
    label: key == 'label' ? '${value ?? ''}' : label,
    reference: key == 'reference' ? '${value ?? ''}' : reference,
    note: key == 'note' ? '${value ?? ''}' : note,
    basis: key == 'basis' ? value as RateBasis : basis,
  );
  static PayValues ofPayslip(Payslip value) => PayValues(
    start: value.issuedDate,
    end: value.issuedDate,
    issued: value.issuedDate,
    period: value.periodId,
    paid: value.paidDate,
    amount: centsText(value.amount.minorUnits),
    basis: value.basis,
    gross: centsText(value.grossMinorUnits),
    net: centsText(value.netMinorUnits),
    deductions: centsText(value.deductionMinorUnits),
    reference: value.reference ?? '',
    note: value.note ?? '',
  );
  RecordPayslipCommand command({PayslipId? id}) => RecordPayslipCommand(
    id: id,
    periodId: period!,
    issuedDate: issued,
    paidDate: paid,
    amountMinorUnits: parseCents(amount)!,
    basis: basis,
    grossMinorUnits: parseCents(gross),
    netMinorUnits: parseCents(net),
    deductionMinorUnits: parseCents(deductions),
    reference: optionalPayText(reference),
    note: optionalPayText(note),
  );
  Object get _key => (
    start,
    end,
    issued,
    period,
    paid,
    amount,
    basis,
    gross,
    net,
    deductions,
    label,
    reference,
    note,
  );
  @override
  bool operator ==(Object other) => other is PayValues && other._key == _key;
  @override
  int get hashCode => _key.hashCode;
}

String? optionalPayText(String value) =>
    value.trim().isEmpty ? null : value.trim();
int? parseCents(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final whole = int.tryParse(match[1]!);
  if (whole == null || whole > 90071992547409) return null;
  return whole * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
}

String centsText(int? value) => value == null
    ? ''
    : '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
Map<String, String> validatePay(PayKind kind, PayValues value) =>
    kind == PayKind.periods
    ? {
        if (value.end.compareTo(value.start) < 0)
          'end': 'End must be on or after Start.',
      }
    : {
        if (value.period == null) 'period': 'Choose a pay period.',
        if ((parseCents(value.amount) ?? 0) <= 0)
          'amount': 'Enter a positive amount with at most two decimal places.',
        for (final (field, text) in [
          ('gross', value.gross),
          ('net', value.net),
          ('deductions', value.deductions),
        ])
          if (text.trim().isNotEmpty && parseCents(text) == null)
            field:
                'Enter a non-negative amount with at most two decimal places.',
      };

const recordPayslipRequest = ConfirmRequest(
  title: 'Record payslip',
  message: 'Record this payslip as money evidence? Its saved facts will be read-only; later changes use Correct….',
  proceed: 'Record payslip',
  revert: 'Discard',
);

final class PayAdapter implements RecordEditAdapter<PayRecord, PayValues> {
  PayAdapter({
    required this.kind,
    required this.work,
    required this.reads,
    required this.employment,
    required this.defaults,
  });
  final PayKind kind;
  final ProductionWorkProviders work;
  final WorkReads reads;
  final EmploymentId employment;
  final PayValues defaults;
  WorkRecordId? _sent;
  @override
  PayValues draftOf(PayRecord? saved) => saved?.payslip != null
      ? PayValues.ofPayslip(saved!.payslip!)
      : saved?.period != null
      ? PayValues(
          start: saved!.period!.start,
          end: saved.period!.end,
          issued: defaults.issued,
          label: saved.period!.label ?? '',
        )
      : defaults;
  @override
  Map<String, String> validate(PayValues draft) => validatePay(kind, draft);
  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final key in fields.keys)
      (key == 'range' ? 'end' : key): key == 'range'
          ? 'The dates overlap an existing period, or the range is invalid.'
          : 'Check this value.',
  };
  @override
  Future<ConfirmRequest?> guard(PayRecord? baseline, PayValues draft) async =>
      kind == PayKind.payslips ? recordPayslipRequest : null;
  @override
  Future<SubmitResult<PayRecord>> submit(
    PayRecord? baseline,
    PayValues draft, {
    Object? consent,
  }) async {
    if (baseline != null) {
      return const Submitted(
        Invalid({
          'record': [FieldIssue(FieldIssueCode.invalid)],
        }),
      );
    }
    if (kind == PayKind.periods) {
      final id = work.evidenceIds.payPeriodId();
      _sent = id;
      return Submitted(
        _map(
          await work.periods.createPeriod(
            CreatePayPeriodCommand(
              id: id,
              employmentId: employment,
              start: draft.start,
              end: draft.end,
              label: optionalPayText(draft.label),
            ),
          ),
          PayRecord.period,
        ),
      );
    }
    final period = draft.period == null
        ? null
        : await reads.period(draft.period!);
    if (period == null || period.employmentId != employment) {
      return const Submitted(
        Invalid({
          'period': [FieldIssue(FieldIssueCode.invalid)],
        }),
      );
    }
    final id = work.evidenceIds.payslipId();
    _sent = id;
    return Submitted(
      _map(
        await work.payslips.recordPayslip(draft.command(id: id)),
        PayRecord.payslip,
      ),
    );
  }

  @override
  Future<ReadBack<PayRecord>> readBack(
    PayRecord? baseline,
    PayValues? submitted,
  ) async {
    final id = baseline?.id ?? _sent;
    if (id == null) return const ReadUnknown();
    final current = switch (id) {
      PayPeriodId() => switch (await reads.period(id)) {
        final value? => PayRecord.period(value),
        null => null,
      },
      PayslipId() => switch (await reads.payslip(id)) {
        final value? => PayRecord.payslip(value),
        null => null,
      },
      _ => null,
    };
    if (current == null) {
      return baseline == null ? const ReadNotSaved() : const ReadGone();
    }
    return ReadFound(current, saved: submitted != null && current.id == _sent);
  }
}

MutationOutcome<S> _map<T, S>(MutationOutcome<T> result, S Function(T) wrap) =>
    switch (result) {
      Committed(:final value) => Committed(wrap(value)),
      Invalid(:final fields) => Invalid(fields),
      Stale() => const Stale(),
      Missing() => const Missing(),
      Unavailable(:final code) => Unavailable(code),
      Uncertain(:final code) => Uncertain(code),
    };
