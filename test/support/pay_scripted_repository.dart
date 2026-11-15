import 'package:lifeos/app/work_edit/pay_edit.dart';
import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/payslip_service.dart';
import 'package:lifeos/features/work/application/work_commands.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/payslip.dart';

typedef ReadSlip = Future<Payslip?> Function(PayslipId);

final class ScriptedPayslips implements PayslipRepository {
  ScriptedPayslips(
    this.real,
    this.read, {
    this.result,
    this.write = false,
    this.gate,
    this.onRecord,
  });
  final PayslipService real;
  final ReadSlip read;
  final MutationOutcome<Payslip>? result;
  final bool write;
  final Future<void>? gate;
  final Future<int> Function(Payslip)? onRecord;
  int calls = 0;
  @override
  Future<int> insertPayslip(Payslip value) async => onRecord!(value);
  @override
  Future<Payslip?> payslipById(PayslipId id) => read(id);
  @override
  Future<MutationOutcome<Payslip>> correctPayslip(
    PayslipId originalId, {
    required Revision expected,
    required Payslip replacement,
    required String voidReason,
    required DateTime nowUtc,
  }) async {
    calls++;
    await gate;
    MutationOutcome<Payslip>? saved;
    if (write) {
      saved = await real.correctPayslip(
        CorrectPayslipCommand(
          originalId: originalId,
          replacementId: replacement.id,
          expectedRevision: expected,
          voidReason: voidReason,
          replacement: PayValues.ofPayslip(replacement).command(),
        ),
      );
    }
    return result ?? saved!;
  }
}
