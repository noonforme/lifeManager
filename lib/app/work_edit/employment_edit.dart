import 'package:flutter/foundation.dart';

import '../../core/outcomes/mutation_outcome.dart';
import '../../core/time/app_clock.dart';
import '../../features/work/application/employment_service.dart';
import '../../features/work/application/work_commands.dart';
import '../../features/work/domain/employment.dart';
import '../edit_session/confirm.dart';
import '../edit_session/record_edit_adapter.dart';
import 'work_outcomes.dart';
import 'work_records.dart';

/// The pending facts of an employment.
@immutable
final class EmploymentValues {
  const EmploymentValues({required this.name, this.legalLabel});

  final String name;
  final String? legalLabel;

  @override
  bool operator ==(Object other) =>
      other is EmploymentValues &&
      other.name == name &&
      other.legalLabel == legalLabel;

  @override
  int get hashCode => Object.hash(name, legalLabel);
}

/// Words for an employment's problems, by field key.
abstract final class EmploymentProblems {
  static const name = 'Enter a name.';
  static const archived = 'This employment is archived; it cannot change.';
}

/// Creates and updates an employment through `EmploymentService` and its
/// validation (spec 4.2 save matrix, employment row). Saving asks nothing;
/// a new employment left with entered values asks Save / Discard / Cancel
/// (spec 4.3). Archive and delete stay explicit actions. One adapter
/// serves one session.
final class EmploymentAdapter
    implements RecordEditAdapter<EmploymentRecord, EmploymentValues> {
  EmploymentAdapter({
    required this.service,
    required this.reads,
    required this.clock,
  });

  final EmploymentService service;
  final WorkReads reads;
  final AppClock clock;

  /// When the last create was sent.
  DateTime? _sentAt;

  @override
  EmploymentValues draftOf(EmploymentRecord? saved) => saved == null
      ? const EmploymentValues(name: '')
      : EmploymentValues(
          name: saved.value.name,
          legalLabel: saved.value.legalLabel,
        );

  @override
  Map<String, String> validate(EmploymentValues draft) => {
    if (draft.name.trim().isEmpty) 'name': EmploymentProblems.name,
  };

  @override
  Map<String, String> describe(Map<String, List<FieldIssue>> fields) => {
    for (final key in fields.keys)
      key: switch (key) {
        'name' => EmploymentProblems.name,
        'employment' => EmploymentProblems.archived,
        _ => WorkProblems.unknownField,
      },
  };

  @override
  Future<ConfirmRequest?> guard(
    EmploymentRecord? baseline,
    EmploymentValues draft,
  ) async => null;

  @override
  Future<SubmitResult<EmploymentRecord>> submit(
    EmploymentRecord? baseline,
    EmploymentValues draft, {
    Object? consent,
  }) async {
    final stored = _stored(draft);
    final MutationOutcome<Employment> outcome;
    if (baseline == null) {
      _sentAt = clock.nowUtc();
      outcome = await service.createEmployment(
        CreateEmploymentCommand(
          name: stored.name,
          legalLabel: stored.legalLabel,
        ),
      );
    } else {
      outcome = await service.updateEmployment(
        UpdateEmploymentCommand(
          employmentId: baseline.value.id,
          expectedRevision: baseline.value.revision,
          name: stored.name,
          legalLabel: stored.legalLabel,
        ),
      );
    }
    return Submitted(
      await settle(outcome, (value) async => EmploymentRecord(value)),
    );
  }

  @override
  Future<ReadBack<EmploymentRecord>> readBack(
    EmploymentRecord? baseline,
    EmploymentValues? submitted,
  ) async {
    if (baseline != null) {
      final current = await reads.employment(baseline.value.id);
      if (current == null) return const ReadGone();
      return ReadFound(
        current,
        saved:
            submitted != null &&
            current.value.revision != baseline.value.revision &&
            draftOf(current) == _stored(submitted),
      );
    }
    final sentAt = _sentAt;
    if (submitted == null || sentAt == null) return const ReadUnknown();
    for (final value in await reads.employments()) {
      final found = EmploymentRecord(value);
      if (!value.createdAtUtc.isBefore(sentAt) &&
          draftOf(found) == _stored(submitted)) {
        return ReadFound(found, saved: true);
      }
    }
    return const ReadNotSaved();
  }
}

/// [values] as the service stores them: trimmed, an empty label none.
EmploymentValues _stored(EmploymentValues values) {
  final label = values.legalLabel?.trim();
  return EmploymentValues(
    name: values.name.trim(),
    legalLabel: label == null || label.isEmpty ? null : label,
  );
}
