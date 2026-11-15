import 'package:lifeos/core/outcomes/mutation_outcome.dart';
import 'package:lifeos/features/work/application/shift_lifecycle_service.dart';
import 'package:lifeos/features/work/domain/facts.dart';
import 'package:lifeos/features/work/domain/ids.dart';
import 'package:lifeos/features/work/domain/shift.dart';

/// What the next correction or void reports, and whether it writes first.
typedef ScriptedCommit = ({bool write, MutationOutcome<WorkShift> report});

/// The real shift lifecycle storage, except that the next correction or
/// void can report [next] instead of its own outcome: after writing (a
/// commit whose result was lost) or without writing (a failure before the
/// commit). Counts every correction and void it is asked for.
final class ScriptedLifecycle implements ShiftLifecycleRepository {
  ScriptedLifecycle(this.real);

  final ShiftLifecycleRepository real;
  ScriptedCommit? next;
  int commits = 0;

  Future<MutationOutcome<WorkShift>> _scripted(
    Future<MutationOutcome<WorkShift>> Function() write,
  ) async {
    commits++;
    final script = next;
    next = null;
    if (script == null) return write();
    if (script.write) await write();
    return script.report;
  }

  @override
  Future<MutationOutcome<WorkShift>> commitFinalization(
    ShiftId id, {
    required Revision expected,
  }) => real.commitFinalization(id, expected: expected);

  @override
  Future<MutationOutcome<WorkShift>> commitCorrection(
    ShiftId originalId, {
    required Revision expected,
    required ShiftId replacementId,
    required String voidReason,
    required DateTime nowUtc,
  }) => _scripted(
    () => real.commitCorrection(
      originalId,
      expected: expected,
      replacementId: replacementId,
      voidReason: voidReason,
      nowUtc: nowUtc,
    ),
  );

  @override
  Future<MutationOutcome<WorkShift>> commitVoid(
    ShiftId id, {
    required Revision expected,
    required String voidReason,
    required DateTime nowUtc,
  }) => _scripted(
    () => real.commitVoid(
      id,
      expected: expected,
      voidReason: voidReason,
      nowUtc: nowUtc,
    ),
  );
}
