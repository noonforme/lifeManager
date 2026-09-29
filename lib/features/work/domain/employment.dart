import 'facts.dart';
import 'ids.dart';

enum EmploymentStatus { active, archived }

final class Employment {
  const Employment({
    required this.id,
    required this.name,
    required this.legalLabel,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.revision,
  });

  factory Employment.create({
    required EmploymentId id,
    required String name,
    required String? legalLabel,
    required DateTime nowUtc,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name');
    }
    _requireUtc(nowUtc, 'nowUtc');
    return Employment(
      id: id,
      name: normalizedName,
      legalLabel: _trimOptional(legalLabel),
      status: EmploymentStatus.active,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      revision: const Revision(0),
    );
  }

  final EmploymentId id;
  final String name;
  final String? legalLabel;
  final EmploymentStatus status;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final Revision revision;

  Employment archive({required DateTime nowUtc}) {
    _requireUtc(nowUtc, 'nowUtc');
    return Employment(
      id: id,
      name: name,
      legalLabel: legalLabel,
      status: EmploymentStatus.archived,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: nowUtc,
      revision: revision.next(),
    );
  }
}

String? _trimOptional(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name);
}
